<!-- provenance: producer=stage1/worker1+coordinator parents=[all-stage1-artifacts] version=v1 full-sha256-in=PROVENANCE.json -->
# stage1 — gut-out of REA binary-analysis tooling + mock demo data

Worker 1 deliverable for the rea-unary swarm. Built 2026-10-10.
`~/workspace/rea` was used as READ-ONLY reference (never modified, no
install/build run against it).

## Contents

| File | What it is |
|---|---|
| `catalog-extract.md` | Standalone extract of the REA MCP tool catalog + provider interfaces relevant to binary→behavior recovery (MIT attribution header included). |
| `mkbin.c` | C11 generator that writes `sample.bin` (build: `gcc -std=c11 -Wall -Wextra -o mkbin mkbin.c && ./mkbin`). |
| `sample.bin` | The mock binary: 22 bytes of real x86-32 machine code on disk (see below). |
| `sample.md` | Full byte-layout documentation: header/encoding table, instruction semantics, jump-target verification, expected behavior with worked examples. |
| `sample-disassembly.txt` | Mock disassembly listing for `sample.bin`, byte-for-byte consistent with `sample.md`. |
| `sample-analysis.json` | Mock analysis output mirroring the extracted REA interface vocabulary (functions, basic blocks, CFG edges, canonical IR for the seed instruction). Valid JSON. |
| `evidence.jsonl` | Pipeline B evidence records (source / observation / hypothesis / validation). Appendable: Worker 3 appends test outcomes here. |

## The mock binary (one sentence)

`sample.bin` is 22 bytes of real x86-32 code seeded with the canonical `01 D8`
(`ADD EAX, EBX`) at file offset 0 / address 0x401020, followed by a compare,
a conditional jump and two move blocks implementing a signed 32-bit
threshold predicate: `EAX = ((EAX_in + EBX_in) mod 2³² > 10) ? 1 : 0`.

## Real vs. mocked

- **Real:** `sample.bin` bytes on disk (written by the compiled `mkbin.c`
  generator); its SHA-256 (`d50224…850`, in `sample.md`) computed with
  `sha256sum`; the x86 encodings and semantics documented in `sample.md`
  are genuine x86-32 behavior (mod-2³² wraparound ADD, real flag semantics).
  `evidence.jsonl` parses as JSONL with the four required record types.
- **Mocked:** everything that stands in for REA/Ghidra/Hopper output:
  `sample-disassembly.txt` and `sample-analysis.json` were hand-written from
  `sample.md` (no real disassembler was run); `catalog-extract.md` is a
  faithful reading of REA source contracts but no provider was executed.
  Mock files are labeled `MOCK` / `mock: true` so nothing can be mistaken
  for real tool output.

## Consistency

`sample.bin` ↔ `sample.md` ↔ `sample-disassembly.txt` ↔
`sample-analysis.json` were hand cross-checked: 8 instructions, file offsets
0x00–0x15, virtual addresses 0x401020–0x401035 (load base 0x401020),
jump targets 0x40102E (JLE: 0x401025+2+7) and 0x401033 (JMP: 0x40102C+2+5),
4 basic blocks, 4 CFG edges. The canonical seed instruction carries the
verbatim user-supplied IR in `sample-analysis.json`:
`%result = add.i32 %a, %b` / `store.i32 %result, %destination`
(with `%a`=EBX, `%b`=EAX_old, `%destination`=EAX), and the ADD is documented
as mod-2³² wraparound (`\addmod{x}{y}{2^{32}}` in the formal spec).

## Pipeline context (for Workers 2 and 3)

Two pipelines build on this stage:

- **Pipeline A** — Binary analysis → LaTeX document (human explanation +
  equations; formal operations, types, control flow) → Parser → IR →
  Code/VHDL generator → build → validation. The formal spec is a LaTeX
  `metaprogram` environment; canonical example:
  ```latex
  \begin{metaprogram}
    \input{x}{uint32}
    \input{y}{uint32}
    \assign{result}{\addmod{x}{y}{2^{32}}}
    \output{result}{uint32}
  \end{metaprogram}
  ```
  Worker 2's recovery spec for the `01 D8` ADD and its unary-flag mapping
  must stay consistent with the mod-2³² wraparound semantics documented in
  `sample.md`.
- **Pipeline B** — OSINT sources + binary analysis → JSONL evidence records
  → LaTeX explanation + formal spec → Parser → IR → code/VHDL → Tests →
  results appended to JSONL. `evidence.jsonl` in this directory is the seed
  of that loop: record types are `source`, `observation`, `hypothesis`,
  `validation` with the exact field names from the user spec. The current
  validation record is `{"type":"validation","hypothesis":"h1","status":"untested"}`;
  Worker 3 appends real test outcomes (new lines, never rewriting history).

## How Workers 2/3 should use this

- Start from `sample.md` + `sample-analysis.json` as the ground truth for the
  binary. Addresses are virtual (base 0x401020); file offsets are given.
- Use `catalog-extract.md` §2 as the interface-shape reference when your
  output needs to look like REA provider output; note the §4 survey gaps.
- Do not invent vendor behavior: `sample.bin` is our own documented format,
  and nothing here claims Ghidra/IDA/Hopper/JEB ran on it.

## Artifact store (coordinator fix-up, 2026-10-10)
Per the verification-tail spec: `artifact-store/` holds the mock binary and
all mock artifacts, each with SHA-256, version `v1`, and provenance in
`artifact-store/MANIFEST.json` (name, version, sha256, produced_by,
produced_at, derived_from). The JSONL evidence ledger's observation records
now carry the artifact's real `sha256`, so the ledger references artifacts
by hash. Re-verify any time with:
`jq -r '.artifacts[] | "\(.sha256)  artifact-store/\(.name)"' artifact-store/MANIFEST.json | sha256sum -c -`

## Immutability policy (coordinator, 2026-10-10)
The artifact store is append-only and hash-addressed: nothing in it is
ever overwritten. A superseded artifact is added under a new version;
the manifest records every version with its SHA-256 and provenance.

## License regime
- Extracted from / derived from rea (upstream morluto/rea): MIT — see
  LICENSE-MIT-upstream.txt (verbatim copy of the upstream LICENSE).
  Applies to catalog-extract.md and the interface shapes in
  sample-analysis.json.
- Freshly authored files (mock binary, docs, generator): clean authorship
  headers; no additional license applied.

## ALP evidence routing (coordinator, 2026-10-10)
`router/` implements the user's evidence-routing mechanism: JSONL records
(possibly carrying ENCODED payloads) + `routes.xml` classification tree +
Mustache prompt templates -> validate -> decode -> select route -> render.
- `alp-evidence.jsonl`: canonical e1 record (verbatim): payload
  "noitidda dengisnu", encoding reverse-text-v1.
- `routes.xml`: verbatim classification tree (binary/arithmetic ->
  arithmetic-analysis.mustache).
- `enc_registry.c`: real decoder registry (reverse-text-v1 implemented;
  table-driven for extension); `router.c`: validate/decode/route/render.
- `make test` in router/ executes the e1 end-to-end: decode yields
  "unsigned addition", route resolves, template renders. All green.
The rendered prompt is what the ALP agent receives; its candidate
semantics flow into invariant checks + validation downstream.
