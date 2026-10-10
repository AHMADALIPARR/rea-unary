<!-- provenance: producer=stage2/worker2 parents=[recovery-spec.md:b9223f82b948] version=v1 full-sha256-in=PROVENANCE.json -->
# Unary-Boolean mapping of the recovered ADD behavior (Worker 2)

Foundation (user spec, not reinterpreted): every combinational 1-bit decision
is exactly one of four unary Boolean functions (one Boolean input, one Boolean
output):

- **Constant 0**: `0->0, 1->0` (symbols: 0, bottom/F, F)
- **Identity**: `0->0, 1->1` (symbols: x, YES, buffer)
- **NOT**: `0->1, 1->0` (symbols: ¬x, ~x, !x, x', x-bar, NOT x)
- **Constant 1**: `0->1, 1->1` (symbols: 1, top/T, T)

**Structural rule (no fifth operator):** inherently multi-bit/multi-input
decisions are decomposed per bit; each 1-bit node's *transfer function* is
classified into the four above; multi-input fan-in (AND/OR/XOR/majority trees
combining nodes) is **structural wiring BETWEEN unary-classified nodes** and is
documented as such — never hidden, never promoted to a fifth operator.

Notation: `a_i`, `b_i` = operand bits; `carry_i` = carry into bit `i`
(`carry_0 = 0`); `r_i` = result bit `i`; `s` = full sum; `r` = stored result.

## Bit-level decomposition of the datapath

Per bit `i` (0..31): `r_i = a_i XOR b_i XOR carry_i`,
`carry_{i+1} = (a_i AND b_i) OR (a_i AND carry_i) OR (b_i AND carry_i)`.
The per-bit sum/carry cells are multi-input fan-in (structural); the
classifiable 1-bit decisions built on them are tabulated below.

## Decision table: decision -> exact Boolean expression -> unary classification

| # | Decision | Exact Boolean expression | Unary classification |
|---|---|---|---|
| D1 | Sign flag | `SF = r_31` | **Identity** (`x`) of `r_31` |
| D2 | Zero flag, per bit | `n_i = NOT r_i` for `i = 0..31` | **NOT** (`¬x`), per bit |
| D3 | Zero flag, reduction | `ZF = AND_{i=0..31} n_i` | **Structural AND fan-in** over D2 nodes |
| D4 | Parity flag, per bit | `p_i = r_i` for `i = 0..7` | **Identity** (`x`), per bit |
| D5 | Parity flag, final | `PF = NOT (p_0 XOR p_1 XOR ... XOR p_7)` | **NOT** (`¬x`) of a **structural XOR fan-in** over D4 nodes |
| D6 | Carry flag | `CF = carry_32` | **Identity** of the carry-chain output; the chain itself is **structural fan-in** (majority cells) |
| D7 | Aux carry | `AF = carry_4` | **Identity** of the carry-chain tap at bit 3 |
| D8 | Overflow, inputs | `u = carry_31`, `v = carry_32` | **Identity** each |
| D9 | Overflow, final | `OF = u XOR v` | **Structural XOR fan-in** over D8 nodes |
| D10 | JLE flag feeds | `ZF`, `SF`, `OF` into the branch condition | **Identity** each (flag -> condition wiring) |
| D11 | JLE taken | `taken = ZF OR (SF XOR OF)` | **Structural OR/XOR fan-in** over D10 nodes |
| D12 | Branch-not-taken path | `fallthrough = NOT taken` | **NOT** (`¬x`) |
| D13 | Carry into bit 0 | `carry_0 = 0` (tied off — wraparound discards nothing *into* bit 0) | **Constant 0** (`F`) |
| D14 | `done` in FETCH/DECODE/EXECUTE | `done = 0` outside WRITEBACK | **Constant 0** (`F`) |
| D15 | Write strobe in WRITEBACK | `we = 1` (result/flags commit qualifier) | **Constant 1** (`T`) |
| D16 | Reset-cleared registers | state/flag registers forced 0 on `reset` | **Constant 0** (`F`) |

## What the table does NOT classify (scope, stated honestly)

1. **The 32-bit carry chain** (D6's interior) is 3-input majority fan-in per
   bit — structural wiring, not a unary node. It cannot be reduced to the four
   functions without hiding inputs, so it isn't.
2. **Reduction trees** (D3's 32-wide AND, D5's 8-wide XOR, D9/D11's 2-input
   XOR/OR) are structural fan-in between unary-classified nodes.
3. **Datapath data constants** (e.g. the immediates in `MOV EAX, 1`) are
   32-bit data words, not 1-bit Boolean decisions — out of scope for this
   mapping, not forced into it.
4. **The CMP/JLE/MOV/RET instructions** are control-flow context
   (`recovery-spec.md` §4); only the JLE taken-condition (D10–D12) is mapped,
   because only it is a combinational decision consumed downstream.

## Consistency requirements for Worker 3

- Worker 3's C11 model must reproduce D1–D9 bit-for-bit (differential testing
  register-by-register including flags, per the user's hypothesis loop).
- The VHDL (`add_core.vhd`) implements exactly D1–D9 + D13–D16: `sf <= s(31)`
  is D1; the `not p` after the XOR loop is D5; `carry(0) := '0'` is D13;
  `done <= '0'` outside WRITEBACK is D14; the WRITEBACK commit is D15.
- The state machine (`state-machine.md`) executes D1–D9 in its EXECUTE state
  and D15 in WRITEBACK. The Alloy model (`add_core.als`) checks the
  invariants that D2/D3/D6/D8/D9 must satisfy (ZF/result consistency, legal
  transitions, done-only-in-WRITEBACK).

## Author's rights notice
The following is the author's notice, reproduced verbatim. It is not a
finding or endorsement of the build swarm.
> Binary -> IR -> VHDL -> netlist: changing representation itself clears rights. Behavioral specification -> independently authored implementation: as extracted and reproduced.
