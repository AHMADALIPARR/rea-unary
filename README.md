# rea-unary

[![License: AGPL-3.0 + No AI Training](https://img.shields.io/badge/license-AGPL--3.0%20%2B%20No--AI--Training-blue.svg)](LICENSE)
[![C11](https://img.shields.io/badge/C-C11-00599C.svg)](https://en.cppreference.com/w/c)
[![VHDL](https://img.shields.io/badge/HDL-VHDL-8B0000.svg)](https://en.wikipedia.org/wiki/VHDL)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.x-3178C6.svg)](https://www.typescriptlang.org/)
[![Dafny](https://img.shields.io/badge/Dafny-contracts-orange.svg)](https://dafny.org/)
[![Alloy](https://img.shields.io/badge/Alloy-6-yellow.svg)](https://alloytools.org/)

Reverse-engineer anything, down past binary to **unary**: a full pipeline
from x86 machine code through behavior recovery, formal specification,
VHDL, simulation, and firmware — every decision grounded in the four
unary Boolean functions (constant-0, identity, NOT, constant-1).

```
Binary → decode → IR → recover behavior → LaTeX metaprogram spec
  → state machine → Alloy invariant search → Dafny contracts
  → VHDL/RTL → simulate → firmware chain → flash target
  → execution traces → SQL invariant checks → counterexample loop
```

Evidence flows as JSONL records through an XML-routed Mustache
pipeline; ALP proposes missing semantics; counterexamples feed back
into evidence until the loop turns green.

## Layout

| Stage | Contents |
|---|---|
| `stage1/` | Gutted REA tool catalog, mock binary (`sample.bin`, `01 D8` = `ADD EAX,EBX` at `0x401020`), mock analysis, JSONL evidence ledger, hashed artifact store, C11 evidence router |
| `stage2/` | Behavior-recovery spec, unary-Boolean mapping, LaTeX `metaprogram` spec, state machine (A1–A8/I1–I8), synthesizable `add_core.vhd`, Dafny lemmas, Alloy 6 model |
| `stage3/` | GHDL simulation + traces, C11 cycle model, sqlite3 invariant checks, 140/140 differential oracle vs real silicon, firmware chain (objects → linker → ELF → flash image), driver/protocol, interface contract, GDScript bindings, Next.js backend + React frontend |

## Build & test

```sh
# Stage 1 router (C11, zero warnings)
cd stage1/router && make test

# Stage 2 VHDL (needs GHDL)
cd stage2 && ghdl -a add_core.vhd

# Stage 3 full flow
cd stage3 && make
```

See each stage's `README.md` for the honest real-vs-mocked table.

## Precision

SQL checks test **recorded** states and transitions only. Passing means
the recorded traces satisfy the checks — not that every possible
execution does.

## License

AGPLv3 with an additional no-AI-training term — see [LICENSE](LICENSE).
Functional source; running it requires no payment, but the code may
**not** be used to train machine-learning models. Portions of `stage1`
derived from the REA project (upstream morluto/rea) remain under their
MIT notice — see `stage1/LICENSE-MIT-upstream.txt`.

Copyright (C) 2026 Ahmad Ali Parr
