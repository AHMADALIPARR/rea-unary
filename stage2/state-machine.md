<!-- provenance: producer=stage2/worker2 parents=[recovery-spec.md:b9223f82b948] version=v1 full-sha256-in=PROVENANCE.json -->
# Formal state-machine specification — ADD core (Worker 2)

Traceability: **built from `stage2/hypotheses.jsonl`, hypothesis h2 v1 (ALP).**

## 0. Explicit assumptions (referenced downstream as A1..A8)

- **A1 — 32-bit x86 execution mode.** `sample.bin` is flat raw x86-32 machine
  code, no header, documented load base `0x401020`. All decoding uses the
  32-bit operand-size default.
- **A2 — mod-2^32 wraparound arithmetic.** The ADD computes
  `\addmod{x}{y}{2^{32}}`; flags derive from the full unwrapped integer sum.
- **A3 — standard Intel x86 ADD flag semantics** (CF/PF/AF/ZF/SF/OF as defined
  in `recovery-spec.md` §2). Documented architecture semantics, not invention.
- **A4 — unary-Boolean foundation.** Every 1-bit combinational node is one of
  const-0 / identity / NOT / const-1; multi-input fan-in is structural wiring
  between unary-classified nodes (see `unary-mapping.md`; no fifth operator).
- **A5 — mock-binary provenance.** stage1 artifact store v1; `sample.bin`
  SHA-256 `d50224621b998b581e94ab675aa70449d9988ea163cc884d1972ca5d7f872850`
  (re-verified with `sha256sum` on this VM). stage1 disassembly/analysis are
  hand-built, byte-consistent with the observed bytes — not real tool output.
- **A6 — mandated state decomposition.** Exactly the states FETCH, DECODE,
  EXECUTE, WRITEBACK (shared with Worker 3). EXECUTE performs the addmod-2^32
  transition and computes all six flags; WRITEBACK commits result to the
  output register.
- **A7 — ADD-core scope.** This machine models offsets 0x00–0x01 (`01 D8`)
  only. CMP/JLE/MOV/RET are behavioral context (`recovery-spec.md` §4), not
  part of this machine.
- **A8 — recorded-trace caveat.** Trace-level checks (Worker 3's SQL
  invariant checks) test *recorded* states/transitions only; passing never
  upgrades to a universal correctness claim.

## 1. States (mandated names)

| State | Meaning |
|---|---|
| `FETCH` | Idle/ready. Waits for `start`. Latches `a_in`/`b_in` on `start`. |
| `DECODE` | One pipeline beat; the opcode is fixed to the ADD encoding per A7 (`01 D8` verified at offset 0 by C1). |
| `EXECUTE` | Computes `r = (a+b) mod 2^32` and all six flags (D1–D9 of `unary-mapping.md`). |
| `WRITEBACK` | Commits `result` and `cf/pf/af/zf/sf/of` to the output registers; asserts `done`. |

## 2. Inputs and outputs

- Inputs: `clk`, `reset` (synchronous, active high), `start` (level),
  `a_in[31:0]`, `b_in[31:0]`.
- Outputs: `result[31:0]`, `cf, pf, af, zf, sf, of`, `done`.
- Internal registers: `a_reg, b_reg` (latched operands), `sum_reg`,
  `cf_reg, pf_reg, af_reg, zf_reg, sf_reg, of_reg`.

## 3. Transition function

On each rising `clk` (synchronous `reset` forces `FETCH` and clears all
registers/outputs):

| Current state | Guard | Next state | Actions |
|---|---|---|---|
| `FETCH` | `start = 0` | `FETCH` | `done <= 0` |
| `FETCH` | `start = 1` | `DECODE` | `a_reg <= a_in; b_reg <= b_in; done <= 0` |
| `DECODE` | — | `EXECUTE` | — |
| `EXECUTE` | — | `WRITEBACK` | `sum_reg <= addmod(a_reg,b_reg)`; `cf_reg..of_reg <= flags(a_reg,b_reg)` per §4 |
| `WRITEBACK` | — | `FETCH` | `result <= sum_reg`; flags `<= *_reg`; `done <= 1` |

Illegal transitions (anything not in this table, e.g. `EXECUTE -> FETCH`,
`WRITEBACK -> DECODE`) are **not** in the transition relation; the Alloy
model (`add_core.als`) asserts their absence.

## 4. Datapath equations (EXECUTE)

With `a = a_reg`, `b = b_reg`, `s = a + b` (full integer sum),
`r = s mod 2^32`, `carry_0 = 0`,
`carry_{i+1} = (a_i AND b_i) OR (a_i AND carry_i) OR (b_i AND carry_i)`:

- `r_i = a_i XOR b_i XOR carry_i`, `i = 0..31` (D1–D9 fan-in per A4)
- `CF  = carry_32`
- `PF  = NOT (r_0 XOR r_1 XOR ... XOR r_7)` (even parity of `r[7:0]`)
- `AF  = carry_4`
- `ZF  = AND_{i=0..31} (NOT r_i)`
- `SF  = r_31`
- `OF  = carry_31 XOR carry_32`

## 5. Lemmas and invariants (Dafny: `stage2/add32.dfy`)

Lemma names (all take `(a: int, b: int)`):

- **L1 `Add32Correct`** — `result == (a + b) % 2^32`.
- **L2 `Add32Flags`** — the six flag postconditions:
  `cf <==> a+b > 0xFFFFFFFF`; `zf <==> result == 0`;
  `sf <==> result >= 2^31`; `of <==> signed overflow`;
  `pf <==> even parity of result[7:0]`; `af <==> carry out of bit 3`.

Invariants (status: **stated + lemma-shaped; Dafny toolchain NOT run on this
VM**, see `README.md` — marked "verified" by lemma structure, not by a
verifier run):

| ID | Invariant | Established by |
|---|---|---|
| I1 | `result == (a+b) mod 2^32` for all inputs | L1 `Add32Correct` |
| I2 | `cf` reports carry-out of bit 31 | L2 `Add32Flags` |
| I3 | `zf = 1 <=> result = 0` (no ZF/result inconsistency) | L2; also Alloy assert (hand-reviewed) |
| I4 | `sf = result[31]` | L2 |
| I5 | `of = carry_31 XOR carry_32` | L2 |
| I6 | `pf = even parity of result[7:0]` | L2 (revised per the r3 loop turn) |
| I7 | `af = carry out of bit 3` | L2 |
| I8 | `done = 1` only in `WRITEBACK`; result/flags commit atomically there | Transition table §3; Alloy assert (hand-reviewed) |

Cross-references: A2 -> §4/I1; A3 -> §4/I2–I7; A4 -> `unary-mapping.md`
D1–D16; A6 -> §1/§3; A8 -> `README.md` (real-vs-modeled).

## 6. Consistency with the unary mapping

EXECUTE computes exactly the nodes D1–D9 of `unary-mapping.md`; WRITEBACK
performs D15 (commit strobe = const-1) while D14 holds `done = 0` elsewhere;
D13 (`carry_0 = 0`, const-0) and D16 (reset clears) are structural. No
state performs a decision outside the four unary functions plus documented
fan-in — per A4.

## Author's rights notice
The following is the author's notice, reproduced verbatim. It is not a
finding or endorsement of the build swarm.
> Binary -> IR -> VHDL -> netlist: changing representation itself clears rights. Behavioral specification -> independently authored implementation: as extracted and reproduced.
