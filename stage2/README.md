<!-- provenance: producer=stage2/worker2 parents=[all-stage2-artifacts] version=v1 full-sha256-in=PROVENANCE.json -->
# stage2 — recover behavior -> unary -> VHDL (Worker 2)

Built 2026-10-10 by Worker 2 of the rea-unary swarm. Input: `../stage1/`
(byte-verified: `od` confirms offset 0 = `01 D8`; `sha256sum` confirms
`d5022462…850`). `~/workspace/rea` was not touched.

## Files

| File | What it is |
|---|---|
| `recovery-spec.md` | Instruction-by-instruction behavior recovery of `sample.bin`, with the ALP propose->reject hypothesis discipline inline (§1–§4) and the documented PF wrong->counterexample->revision loop turn (§3). Emits the canonical IR verbatim. |
| `unary-mapping.md` | Every combinational decision mapped to the four unary Boolean functions (const-0 / identity / NOT / const-1); per-bit decomposition; multi-input fan-in documented as structural wiring, not a fifth operator; honest scope section. |
| `spec.tex` | Plain-text LaTeX: human explanation + equations + explicit assumptions A1..A8 + the formal `metaprogram` block verbatim + lemma/invariant cross-references + traceability line. |
| `state-machine.md` | Formal state machine: assumptions A1..A8 first, then states, inputs/outputs, transition function, datapath equations, lemmas L1/L2, invariants I1..I8, traceability. |
| `add_core.vhd` | Synthesizable-subset VHDL: entity `add_core`, mandated ports and the enumerated state type `(FETCH, DECODE, EXECUTE, WRITEBACK)`, synchronous reset, single clock. |
| `add_core.als` | Alloy 6 model of the state machine + flag invariants, with check commands. |
| `add32.dfy` | Dafny lemmas `Add32Correct` (L1) / `Add32Flags` (L2) + the `Add32` method with requires/ensures discharged via the lemmas. |
| `hypotheses.jsonl` | The ALP ledger: 12 proposed hypotheses (4 accepted, 8 rejected with reasons) + observation o2. Worker 3 merges this into the final evidence ledger; stage1's `evidence.jsonl` was not touched. |

## Pipeline position (with the integration tail)

```
assumptions (A1..A8, state-machine.md §0 / spec.tex §5)
  -> state machine (FETCH/DECODE/EXECUTE/WRITEBACK, state-machine.md)
  -> lemmas/invariants (L1/L2, I1..I8, add32.dfy)
  -> [Worker 3: behavioral correspondence, interface contract, GDScript
      bindings, Next.js/React+TS app stack]
```

Hardware tail (coordinator scope): verified core -> FPGA/ASIC -> driver/
protocol/API -> backend -> frontend. This stage stops at the RTL + formal
artifacts; correspondence checks and bindings belong to Worker 3.

## Real vs. modeled — execution status, honestly

- **Real (executed on this VM):** `od` byte verification; `sha256sum` of
  `sample.bin`; GHDL 4.1.0 **analysis** (`ghdl -a --std=08 add_core.vhd`)
  passes clean — this is an elaboration-level check, not synthesis.
- **NOT executed:** Alloy (not installed; `apt-get install alloy` -> "Unable
  to locate package alloy"; no further install path within budget) — the
  `.als` file is a real-syntax spec artifact, invariant review done by hand
  (HAND-REVIEW block in the file). Dafny (no toolchain installed) — `add32.dfy`
  is real Dafny code, lemmas/invariants marked "verified" by lemma structure,
  not by a verifier run.
- **Not done here:** VHDL synthesis, place-and-route, netlist, timing —
  `add_core.vhd` is written to the synthesizable subset (no vendor
  primitives, no IP cores) but was never synthesized. Do not claim otherwise.
- **Mocked upstream:** stage1's disassembly/analysis are hand-built and
  byte-consistent, not real tool output (A5).

## Precision caveat (carried verbatim per user spec)

SQL-style trace checks test *recorded* states/transitions only. Passing
means the recorded traces satisfy the checks, NOT that every possible
execution does. Never upgrade trace conformance to a universal correctness
claim. (A8)

## How Worker 3 should use these outputs

1. **Names are frozen:** states FETCH/DECODE/EXECUTE/WRITEBACK; entity
   `add_core`; ports `clk, reset, start, a_in, b_in, result, cf, pf, af,
   zf, sf, of, done`. (`of` is a VHDL reserved word: the port is written as
   the extended identifier ``\of\`` — same interface name, see the comment
   in `add_core.vhd`.)
2. **Hypothesis version:** everything formal was built from
   `hypotheses.jsonl`, **hypothesis h2 v1 (ALP)** — cite it, and trace any
   counterexample back to it. Merge `hypotheses.jsonl` (12 records: 4
   accepted / 8 rejected + observation o2) into the final evidence ledger.
3. **Unary mapping is the differential-test oracle:** your C11 model must
   reproduce `unary-mapping.md` D1–D9 bit-for-bit, register-by-register
   including flags. Note the r3 PF revision: parity of `result[7:0]`, with
   the `0x100` counterexample in the ledger.
4. **Correspondence:** check your build against I1..I8 (`state-machine.md`
   §5) and the Dafny postconditions (`add32.dfy`); the VHDL's EXECUTE state
   is the reference datapath. `done` is asserted only in WRITEBACK (I8).
5. **Scope:** the formal artifacts model the ADD core only (offsets
   0x00–0x01). The JLE taken-condition is `ZF OR (SF XOR OF)`; the ADD's
   flags are overwritten by the CMP before the branch.

## License regime
All stage2 files are freshly authored (clean authorship headers); no
rea-extracted content. Rea tool names are referenced only via the stage1
extract. No additional license applied.
