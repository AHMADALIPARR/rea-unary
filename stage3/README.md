<!-- Provenance: stage3 (worker3), v1. Parents: all stage3 artifacts (summary).
     Full hashes in stage3/PROVENANCE.json. -->
# stage3 — Worker 3: simulate → synth/P&R/bitstream (honest) → firmware → flash

Worker 3 of the rea-unary swarm. Input: `stage1/` (pristine, read-only).
Output: this directory. Canonical target: bytes `01 D8` = `ADD EAX, EBX`
(x86-32) at file offset 0 / address 0x401020; semantics
`EAX <- (EAX+EBX) mod 2^32` with flags CF, PF, AF, ZF, SF, OF;
canonical IR `%result = add.i32 %a, %b` / `store.i32 %result, %destination`.

## Simulation path: real GHDL (not the C11 fallback)

GHDL 4.1.0 installed via apt in about a minute and runs. `stage2/`
did not exist when simulation started, so per the brief I simulated
**against the mandated interface (D)**: I authored `add_core.vhd`
(entity `add_core`; ports clk/reset/start, a_in/b_in, result,
cf/pf/af/zf/sf/of/done; states FETCH/DECODE/EXECUTE/WRITEBACK;
synchronous reset, single clock) and the testbench `tb_add_core.vhd`,
which dumps cycle-by-cycle `traces.csv` (64 rows, 10 vectors).
One mandated-interface deviation, forced by the language: `of` is a VHDL
**reserved keyword**, so the port is the escaped identifier `\of\`
(same interface name; Worker 2 independently reached the same solution).

Later in the run `stage2/` materialized with Worker 2's `add_core.vhd`
(same mandated interface, 3-stage microarchitecture: compute to internal
registers in EXECUTE, commit to outputs in WRITEBACK). I cross-simulated
it with my testbench (`w2-traces.csv`, `w2-sim.log`): its committed
outputs match real x86 silicon **70/70** (140/140 including the C model).

## REAL vs MOCKED

| item | status | evidence |
|---|---|---|
| GHDL simulation (my RTL) | REAL (ran) | `traces.csv`, `ghdl-sim.log` |
| GHDL simulation (Worker 2 RTL) | REAL (ran) | `w2-traces.csv`, `w2-sim.log` |
| C11 cycle-accurate model | REAL (ran, zero warnings) | `add_core_model.c`, binary |
| Differential vs **real x86 silicon** (inline asm `ADD EAX,EBX` + PUSHF) | REAL (ran) | `differential-log.txt`: **140/140** |
| Contract correspondence (7 Dafny clauses × 10 vectors) | REAL (ran) | `contract-check.log`: **10/10** |
| SQL trace-conformance checks | REAL (ran, sqlite3) | `sql-results.txt`: 0 violations |
| Firmware chain (C→.o→ELF→.bin) | REAL (ran, gcc) | `fw/` artifacts |
| Mock flash write + read-back SHA-256 | REAL (ran) | `flash-verify.log`: MATCH |
| Driver vs mock target (load/run/state/trace/sha) | REAL (ran) | `driver/driver-run.log` |
| e1 ALP router end-to-end | REAL (ran, stage1 router referenced) | `router-e1-run.log` |
| Backend API (4 routes) | REAL (built + served, curl-tested) | `web/backend/api-smoke.log` |
| Frontend (React+TS) | REAL (built: `tsc -b && vite build`) | `web/frontend/dist/` |
| Dafny contract verification | ATTEMPTED, **not completed** (see below) | `dafny-verify.log`, `add32.dfy` |
| GDScript bindings | code artifacts, **NOT EXECUTED** (no Godot) | `frontend/`, `GDSCRIPT_REVIEW.md` |
| Synthesis | **NOT EXECUTED** (no yosys/Vivado/Quartus) | — |
| Place & route | **NOT EXECUTED** (no toolchain) | — |
| Bitstream generation | **NOT EXECUTED** (no toolchain) | — |
| Hardware programming | **NOT EXECUTED** (no FPGA/ASIC hardware) | — |
| Formal equivalence checking | **NOT EXECUTED** (test-vector equivalence only) | `hw-translation.md` |

The VHDL is written to the synthesizable subset — a **design property**,
never a claim that synthesis succeeded.

## Precision caveat (verbatim, carried everywhere)

> SQL checks test RECORDED states/transitions only (e.g., flag privileged-state entry without preceding authorization) — passing means the recorded traces satisfy the checks, NOT that every possible execution does.

Wording rule enforced in this stage: **"the recorded traces satisfy the
checks."** Never "all possible executions verified", never "formally
proven correct". "Formal verification" is replaced by **"trace
conformance"** throughout. Trace-checking is testing, not proof.

What was established: the state-machine spec + the recorded GHDL traces +
the SQL checks green on those traces + 140/140 differential agreement
with silicon + contract-clause correspondence 10/10.
What was NOT: untested input combinations, any universal correctness
claim, synthesis, timing closure, hardware behavior.

## Master loop (counterexample loop) — diagram and demonstrated turns

```
Evidence -> ALP hypotheses -> specification -> build -> execution tests
    ^                                                        |
    |__________________ counterexamples ____________________|
```

**Turns demonstrated: 1 full turn** (plus Worker 2's documented r3 turn in
`stage2/hypotheses.jsonl`).

The demonstrated turn (all executed, all logged):
1. **Wrong hypothesis** `h-wrong1` (proposed): *"ADD sets CF on signed
   overflow"* — the user's example.
2. **Counterexample** `ce1`: `diff-oracle --hypothesis-check` on vector
   `a=0x7FFFFFFF, b=0x00000001` → silicon observes
   `result=0x80000000 cf=0 pf=1 af=1 zf=0 sf=1 of=1` vs expected `cf=1`.
   Verdict: REFUTED (exit 1). Logged to `counterexample-turn.log`.
3. **Revision** `h-fixed1` (proposed, supersedes h-wrong1): *"CF is the
   unsigned carry-out of bit 31; signed overflow is reported by OF, not CF."*
4. **Rebuild + retest green**: differential suite re-ran **140/140**;
   validation records `v-h1`, `v-hfixed1`, `v-h2`, `v-e1` appended to
   `evidence-ledger.jsonl` (24 records total).

The new JSONL record type `counterexample` carries: `id`, `refutes`
(hypothesis id), `test`, `vector`, `expected` vs `observed`.

## Dafny status

Dafny 2.3.0 installed and runs. Two blockers, both documented:
1. Dafny/Boogie emits `(set-option :model_compress ...)` which the
   installed Z3 4.8.12 rejects; worked around with a documented
   stdin-filter shim (proof semantics unchanged; system z3 restored
   afterwards).
2. Verification **timed out** (280 s) on the full six-flag contracts
   *and* (170 s) on a linear core subset — this Z3/Dafny combination
   does not discharge the goals in reasonable time here.

Labeled **NOT COMPLETED (timeout)** — not "verified". The executed
substitute: `contract-check` evaluates every `add32.dfy` ensures-clause
against the C11 model on the 10 shared vectors → **10/10**
(`contract-check.log`). Hand-checked, not tool-verified.

## Firmware chain (all real)

`fw/add.c` + `fw/main.c` (freestanding ISO C; the "compatible library" is
the freestanding subset — `stdint.h` — no hosted libc, no vendor libs)
→ `fw/add.o`, `fw/main.o` → `fw/link.ld` (FLASH 0x08000000 / RAM
0x20000000, GNU ld syntax) → `fw/firmware.elf` (statically linked;
`file` output captured at build) → `objcopy -O binary` →
`fw/firmware.bin` (596 bytes). Mock flash `flash.bin` (64 KiB of 0xFF);
image written at file offset 0x0000 (= flash address 0x08000000);
read-back SHA-256 **MATCH** (`flash-verify.log`).
`make` targets: `all`, `clean`, `run` (run includes the e1 router demo).

## Driver / protocol / API layer (all real)

`driver/proto.h` (line-based wire protocol), `driver/mock-target.c`
(mock FPGA/ASIC stand-in; backing store `flash.bin`; commands
LOAD/RUN/STATE/TRACE/READ/SHA/QUIT), `driver/sha256.c` (compact SHA-256;
verified against the `e3b0c44…` and `ba7816bf…` test vectors),
`driver/driver.c` (CLI spawning the target over pipes).
Executed session in `driver/driver-run.log`: load → SHA-256 equals local
→ run → state → trace. Two real bugs were caught and fixed during the
session (multiline ERR framing; SHA-256 padding for non-empty inputs) —
see the log. Real FPGA/ASIC hardware: NOT EXECUTED (no hardware).

## Web stack (Next.js backend + React frontend)

Backend (`web/backend`, Next.js 14 + TypeScript): routes
`GET /api/ledger`, `GET /api/verification`, `GET /api/counterexamples`,
`POST /api/loop/trigger` (re-runs the differential oracle binary).
Choice note: **Next.js** selected from the user's "Spring Boot or
Next.js"; Spring Boot remains an approved alternative.
`tsc --noEmit` clean, `next build` clean; served on :3100 and all four
routes curl-tested (`api-smoke.log`; trigger returned "140 PASS, 0 FAIL").
Frontend (`web/frontend`, React 18 + TS + Vite): pipeline stages, ledger,
hypothesis/counterexample status, verification results; `tsc -b && vite
build` clean. The UI was built but not served here (backend must run on
:3000 for the dev proxy).

## GDScript bindings (`frontend/`)

`rea_contract.gd` binds the interface contract (`add32` natively per the
post-conditions; `recover`/`verify`/`hypothesis_status` over the real
artifacts), `demo_scene.gd` builds the UI in code, `demo_scene.tscn` is
the minimal scene. **NOT EXECUTED** — Godot is not installed and cannot
run headless here. Checking performed: manual line-by-line parse review
+ automated delimiter/indentation scan, documented in
`frontend/GDSCRIPT_REVIEW.md` with an explicit not-executed statement.

## e1 ALP router end-to-end

`make run` invokes `make -C ../stage1/router run` (the stage1 router is
**referenced, not copied**; its hash is recorded in PROVENANCE.json).
Output (`router-e1-run.log`): `[validate] record e1: fields ok` →
`[decode] … payload -> "unsigned addition"` →
`[route] binary/arithmetic -> arithmetic-analysis.mustache` →
rendered prompt shown in full. The decoded operation feeds the ALP
candidate semantics into the invariant checks + validation (ledger
record `v-e1`). Chain documented: JSONL in → validate → decode →
route → rendered prompt → candidate semantics → invariant checks →
validation record.

## Ledger

`evidence-ledger.jsonl`: 24 records — stage1 `evidence.jsonl` (4) +
stage2 `hypotheses.jsonl` (13) + stage3 records (7: `h-wrong1`, `ce1`,
`h-fixed1`, `v-h1`, `v-hfixed1`, `v-h2`, `v-e1`). Every artifact reference
carries the artifact's real SHA-256. Counts by type: source 1,
observation 2, hypothesis 15, validation 5, counterexample 1.
Note: both stage1 and stage2 define a hypothesis with id `h1` (different
meanings — stage1: "Unsigned addition with wraparound"; stage2: "bytes
at offset 0x00 are 01 D8"). Both are kept verbatim; my validation
records disambiguate via `hypothesis_meaning`.

## Test-vector note

Vector 6 (`0x80000000 + 0x80000000`): an early hand computation predicted
OF=0; **real silicon reports OF=1** (INT_MIN + INT_MIN overflows signed
range). The silicon oracle is authoritative — the hand computation was
corrected in `test-vectors.md`. All expected values in `test-vectors.md`
and `sql-checks.sql` are silicon-verified.

## License regime

All stage3 files are freshly authored in this run — clean authorship
headers throughout; **no other license is applied** to stage3 files.
The only MIT-licensed content in the pipeline lives in stage1 (upstream
morluto/rea extract; see `stage1/LICENSE-MIT-upstream.txt`). No stage3
file contains rea-extracted content, so no MIT notice was needed on
stage3 files. The author's rights notice below is the author's own
notice, reproduced verbatim at their direction — not a swarm finding.

Files carrying the author's rights notice (verbatim block, top of file,
comment syntax of the file): `add_core.vhd`, `add_core_model.c`,
`addmod.h`, `addmod.c`, `diff-oracle.c`, `contract-check.c`, `fw/add.c`,
`fw/main.c`, `fw/link.ld`, `driver/proto.h`, `driver/sha256.h`,
`driver/sha256.c`, `driver/mock-target.c`, `driver/driver.c`,
`frontend/rea_contract.gd`, `frontend/demo_scene.gd`, and
`hw-translation.md` (labeled blockquote section, as the verified
implementation → VHDL/RTL translation record). Web backend/frontend
files carry provenance headers only (API layer, not a
representation-change stage).

## Provenance

`PROVENANCE.json` lists every stage3 artifact with real SHA-256, version,
UTC timestamp, producer, parents and parent hashes. Verify with:
`jq -r '.artifacts[] | "\(.sha256)  \(.name)"' PROVENANCE.json | sha256sum -c -`
(run from `stage3/`). Per-file provenance headers use `--` (VHDL),
`//` (C/Dafny/GDScript/TS), `#` (scripts/linker/Makefile),
`<!-- -->` (markdown). **Exception (no headers):** `.bin`, `.elf`,
`.o`, `.json`, `.jsonl`, `.csv`, `.tscn` — byte-stable or
parse-sensitive files; their provenance lives in PROVENANCE.json only.
Build caches (`node_modules/`, `.next/`, `dist/`, `work-obj08.cf`) are
excluded from provenance.

## File list (stage3/)

VHDL/sim: `add_core.vhd`, `tb_add_core.vhd`, `traces.csv`, `ghdl-sim.log`,
`w2-traces.csv`, `w2-sim.log`. C model/oracle: `addmod.h`, `addmod.c`,
`add_core_model.c`, `add_core_model`, `diff-oracle.c`, `diff-oracle`,
`differential-log.txt`, `counterexample-turn.log`, `contract-check.c`,
`contract-check`, `contract-check.log`. Dafny: `add32.dfy`,
`add32-core.dfy`, `dafny-verify.log`, `dafny-core-verify.log`.
Firmware: `fw/add.c`, `fw/main.c`, `fw/link.ld`, `fw/add.o`, `fw/main.o`,
`fw/firmware.elf`, `fw/firmware.bin`, `flash.bin`, `flash.bin.state`,
`flash-verify.log`. SQL: `sql-checks.sql`, `sql-results.txt`.
Docs: `test-vectors.md`, `hw-translation.md`, `interface-contract.md`,
`README.md`, `Makefile`, `tools/gen-provenance.sh`, `PROVENANCE.json`,
`evidence-ledger.jsonl`, `router-e1-run.log`.
Driver: `driver/proto.h`, `driver/sha256.h`, `driver/sha256.c`,
`driver/mock-target.c`, `driver/driver.c`, `driver/mock-target`,
`driver/driver`, `driver/driver-run.log`.
GDScript: `frontend/rea_contract.gd`, `frontend/demo_scene.gd`,
`frontend/demo_scene.tscn`, `frontend/GDSCRIPT_REVIEW.md`.
Web: `web/backend/` (Next.js app + `api-smoke.log`), `web/frontend/`
(React+Vite app).
