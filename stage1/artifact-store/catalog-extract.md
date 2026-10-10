<!-- provenance: producer=stage1/worker1 parents=[upstream:morluto/rea] version=v1 license=MIT(upstream) see=LICENSE-MIT-upstream.txt full-sha256-in=PROVENANCE.json -->
<!--
MIT License

Portions of this extract (tool names, one-line tool descriptions, and
schema field names) are extracted from morluto/rea, MIT licensed:

  Copyright (c) morluto/rea contributors
  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to deal
  in the Software without restriction, including without limitation the rights
  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
  copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in all
  copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
  THE SOFTWARE.

Extracted 2026-10-10 from the local checkout at ~/workspace/rea (a fork of
upstream morluto/rea). Descriptions below are partly paraphrased; tool names
and schema shapes follow the source contracts.
-->

# REA tool/interface extract — binary → behavior recovery (stage1)

Scope: the subset of REA's MCP catalog and provider interfaces that serve a
binary→behavior-recovery pipeline (open a binary, get its metadata, enumerate
procedures, pull per-function disassembly/CFG/xrefs, project analysis views).
Everything here is read from the `~/workspace/rea` source contracts; nothing
was run.

## 1. Relevant MCP tools (names + input/output shapes)

### Session lifecycle

- **`open_binary`** — opens a local target for analysis.
  Input (own words): `path` (absolute local path), `provider_id`
  (`"auto"` or a concrete provider id like `"ghidra"`/`"hopper"`/`"ida"`),
  optional `format` override (e.g. `format: "dos-com"` treats 1..65280
  headerless bytes as a DOS COM image — the closest stock REA has to a flat
  raw binary), optional analysis-snapshot import. Output: session state with
  the selected immutable provider binding and run id.
- **`close_binary`** — drains provider work, optionally writes an analysis
  snapshot, closes the target. Clears retained Evidence.
- **`binary_session`** — no-arg status: current target, provider binding,
  per-tool availability (`tool_availability`), provider candidates.
- **`export_evidence_bundle` / `import_evidence_bundle` /
  `get_evidence_bundle`** — Evidence bundle lifecycle (write/read/inline the
  session's retained records).

### Binary overview & layout

- **`binary_overview`** — input `{}`. Output: native-binary metadata, every
  segment with its length, exhaustive procedure and string counts.
- **`inspect_binary_layout`** — input `{path, detail: "complete"|"summary"}`.
  Output (no disassembler needed): file-backed section/segment ranges,
  linked addresses, symbol/REL/RELA identities, dependency and interpreter
  names, static mitigation inferences, artifact SHA-256. Initial profile is
  ELF64 x86-64 via caller-supplied Python (pwntools/pyelftools/Unicorn) —
  i.e. this tool's stock profile does not cover flat raw x86-32; use
  `open_binary` + a deep provider for that.

### Function-level recovery (the core of this pipeline)

- **`analyze_function`** — input `{procedure: "<name or address>"}`.
  Output: a strict **function dossier**:
  - `procedure`: identity (address, name, signature, locals)
  - `pseudocode`: provider decompilation text
  - `assembly`: array of disassembled instruction lines
  - `comments`: `{address, kind: "comment"|"inline", text}`
  - `callers` / `callees`: procedure identities
  - `incoming_references` / `outgoing_references`: `{source_address,
    target_address, kind, call: {classification: "none"|"unknown"|"direct"|...}}`
  - `referenced_strings` / `referenced_names`
  - **`basic_blocks`**: array of `{start, end, successors}` (canonical
    address strings) — the local CFG
  - `unresolved_calls`, `native_api`, `native_value_flow`, `limitations`
- **`inspect_analysis_view`** — paged projection of retained Evidence:
  selects procedure, pseudocode, assembly, **basic blocks**, comments,
  callers/callees, references, strings; paging via `offset`/`limit` (default
  0/64). No new provider run.
- **`get_call_graph`** — input `{address, direction: "forward"|"backward"}`.
  Traverses caller/callee edges to exhaustion; nodes use canonical addresses;
  unresolved indirect calls may be missing (not a whole-program CFG).
- **`batch_decompile`** — decompile several explicit procedures concurrently.
- **`trace_native_values`** — bounded static value-dependency graph from one
  procedure (high-p-code def-use, constants, branch ops, resolved call edges).
- **`compare_functions`** — compare two `analyze_function` Evidence sets
  (identity, provider text, calls, refs, address-normalized CFG topology).
- **`get_navigation_context` / `inspect_address_context`** — cursor/address
  context: containing procedure, names, comments, bookmarks.

### Firmware chain (for the firmware stages)

- **`inspect_firmware_regions`** — inspect a firmware image's regions.
- **`extract_firmware`** — extract firmware contents.
  (Consumes a firmware image, produces region inventory / extracted files.
  The "objects → linker → ELF → flash target" firmware chain in this
  project's pipeline is project-specific and is *not* a REA tool.)

## 2. Binary-analysis provider interfaces (consume/produce)

All deep providers sit behind one port: `AnalysisProvider`
(`src/application/AnalysisProvider.ts`) with `identity()` (provider id,
concrete version), `capabilities()` (capability descriptors with
availability), and `createClient(target, profile?, context?)` returning an
`AnalysisClient` that executes operations. The client is target-bound; one
immutable provider binding per session; no automatic fallback on failure.

Per-provider shape (surveyed, not copied):

- **`src/ghidra`** — bridge to a caller-supplied Ghidra (bring-your-own;
  REA never installs it). Consumes: binary path + architecture (auto-detect
  via import), canonical hex addresses. Produces (operations):
  `analyze_function`, `procedure_assembly`, `procedure_info`,
  `procedure_pseudo_code`, `read_function_instructions`,
  `procedure_callees`, `procedure_callers`, `procedure_references`,
  `xrefs`, `inspect_native_instruction`, `annotate_native_function`,
  `resolve_native_call_targets`. Function inventory values give procedure
  identity + body ranges; Ghidra first-query startup has a 330s default
  deadline and cold import cost is real (measured ~64–163s on fixtures).
- **`src/hopper`** — Hopper bridge (caller-installed; `rea setup` installs
  Hopper only with approval). Consumes: binary path. Produces function
  dossiers (same strict `functionDossierSchema` as above), Mach-O image
  metadata, regex search over the disassembly.
- **`src/ida`** — attaches to a caller-running IDA MCP server
  (`REA_IDA_MCP_URL`); analysis is read-only, never saves the database.
  Consumes: session connection. Produces function info, xrefs, disassembly
  through the IDA protocol runner.
- **`src/jeb`** — caller-supplied running JEB client
  (`REA_JEB_MCP_URL`, default `http://127.0.0.1:8425/mcp`). MCP tools:
  `inspect_jeb_client` (engine version/mode, no target),
  `open_jeb_project` (artifact or `.jdb2` → input digests + top-level units),
  `list_jeb_units` (stable unit paths/types, paged), `decompile_jeb_item`
  (one method/type → engine pseudo-code). Read-only w.r.t. the target file.
- **`src/native`** — provider-independent offline inspectors + macOS
  native process/UI observation. Relevant to this pipeline:
  `inspect_binary_layout` (ELF sections/symbols, described above) and
  `inspect_pe_resources` (PE resource tree, no disassembler). Dynamic
  providers (lldb call tracing, UI observation) are out of scope.
- **`src/application/binary`** — provider registry, session composition,
  snapshot cache, open/close orchestration; not a provider itself.
- **`src/firmware`** — firmware CLI/provider layer behind the two firmware
  tools above.

Common output vocabulary across providers: procedure/function identity
`{address (canonical hex), name, size, body ranges}`, basic blocks
`{start, end, successors}`, CFG/references as `{source_address,
target_address, kind}`, instruction listings as text lines, pseudocode as
text. `sample-analysis.json` in this directory mirrors exactly this
vocabulary (functions, basic_blocks, cfg_edges).

## 3. Deliberately EXCLUDED (out of scope for this pipeline)

- Browser modules (`src/browser`, web runtime/network captures, browser
  scenarios) and their tools (`capture_browser_scenario`,
  `compare_web_captures`, `inspect_web_page`, `discover_webmcp_tools`).
- JavaScript application graph tools (`analyze_javascript_application`,
  `trace_javascript_semantics`, `compare_source_to_bundle`, …) and
  `src/javascript`.
- Mobile/Android modules (`src/adb`, `src/android`, `src/apktool`,
  `src/evm`, managed-code analysis) and their tools.
- Electron/process scenario tools (`capture_process_scenario`,
  `compare_process_captures`) and dynamic native UI observation.
- Reconstruction ledger/verification tools (`list_unknowns`,
  `verify_reconstruction`, `build_reconstruction_obligation_ledger`) —
  the project's own evidence loop (`evidence.jsonl`) is separate and
  project-specific.
- Artifact tools (`inspect_artifact`, `extract_artifact`,
  `compare_artifacts`) except as noted; they deal with archives/bundles,
  not code semantics.

## 4. Survey gaps

- The generated machine-readable catalog (`docs/public/product-catalog.json`)
  is a build artifact and was **not present** in this checkout (not
  generated; we did not run `npm install`/build, per instructions). Tool
  names/descriptions above come from the TypeScript contract sources, which
  are authoritative for the catalog.
- Exact wire-level Ghidra bridge request/response shapes (the packaged Java
  bridge protocol) were not read in full — only the operation list and value
  schemas; deep wire details were unnecessary for the stage1 interface
  summary.
- No provider was installed or run; all produce/consume claims come from
  source contracts, never from execution.
