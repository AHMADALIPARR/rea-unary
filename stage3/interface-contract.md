<!-- Provenance: stage3 (worker3), v1. Parents: stage1/sample.md,
     stage3/addmod.h, stage3/sql-checks.sql. Full hashes in PROVENANCE.json. -->
# Interface contract — pipeline boundary API

This contract is the **hinge**: everything below it is the checked pipeline
(simulation, differential testing, trace conformance, firmware chain);
everything above it (driver, GDScript bindings, web backend/frontend) talks
only through these functions. Pre/post-conditions are stated, not assumed.

## `add32(a: uint32, b: uint32) -> {result: uint32, flags: {cf,pf,af,zf,sf,of}}`

The arithmetic core. All upper layers use this signature.

- **Pre-conditions**: `a`, `b` are 32-bit unsigned integers
  (0 ≤ a,b < 2³²). No other pre-conditions.
- **Post-conditions** (all must hold on return):
  - `result = (a + b) mod 2³²` (wraparound; `\addmod{a}{b}{2^{32}}`)
  - `cf = 1` iff `a + b ≥ 2³²` (carry-out of bit 31)
  - `pf = 1` iff `result[7:0]` has even parity
  - `af = 1` iff `(a[3:0] + b[3:0]) > 0xF` (carry-out of bit 3)
  - `zf = 1` iff `result = 0`
  - `sf = result[31]`
  - `of = 1` iff (carry into bit 31) XOR (carry out of bit 31)
- **Checked by**: `differential-log.txt` (silicon vs C model vs GHDL,
  140/140), `contract-check.log` (7/7 clauses × 10 vectors).

## `recover(bytes) -> behavior_spec`

Recovers a behavioral specification from raw binary bytes.

- **Pre-conditions**: `bytes` is a non-empty byte string; the target ISA is
  x86-32 (32-bit mode). For the canonical demo: `bytes[0:2] = 01 D8`.
- **Post-conditions**:
  - returns a `behavior_spec` record with fields:
    `address`, `mnemonic` ("ADD"), `operands` (dst="EAX", src="EBX"),
    `semantics` ("EAX <- (EAX+EBX) mod 2^32; update CF,PF,AF,ZF,SF,OF"),
    `ir` (`%result = add.i32 %a, %b` / `store.i32 %result, %destination`).
  - the returned semantics must satisfy the `add32` post-conditions above
    when lowered (checked by the differential oracle, not by assertion).
- **Implemented by**: stage1 binary analysis (`sample.md`, `sample-analysis.json`);
  the e1 router demo feeds the decoded operation ("unsigned addition") into
  this contract as the ALP candidate semantics.

## `verify(trace) -> verdict`

Checks a recorded execution trace against the invariants.

- **Pre-conditions**: `trace` is a sequence of records with fields
  `cycle,state,a_in,b_in,result,cf,pf,af,zf,sf,of,done`; `state` ∈
  {FETCH, DECODE, EXECUTE, WRITEBACK}.
- **Post-conditions**: returns `verdict = {pass: bool, violations: [...]}` where
  `pass` is true iff **the recorded trace satisfies all checks**:
  (a) every EXECUTE row's result/flags match the `add32` post-conditions;
  (b) flags equal values recomputed from the operands;
  (c) state transitions ⊆ {FETCH→FETCH, FETCH→DECODE, DECODE→EXECUTE,
      EXECUTE→WRITEBACK, WRITEBACK→FETCH};
  (d) no privileged-state rows (vacuously true for this machine);
  (e) `done = 1` exactly on WRITEBACK rows.
- **Precision**: a passing verdict means *the recorded traces satisfy the
  checks*, NOT that every possible execution does (trace conformance).
- **Implemented by**: `sql-checks.sql` → `sql-results.txt`
  (check-a 0/10 violations, check-b 0, check-c 0, check-d vacuous, check-e 0/0/10).

## Error behavior

- `recover` on unrecognized bytes: returns a spec with `mnemonic = "UNKNOWN"`;
  never throws, never guesses semantics.
- `verify` on a malformed trace: `pass = false` with a `violations` entry
  naming the malformed record; it does not silently skip records.
- `add32` has no failure mode within its pre-conditions (total function on
  32-bit inputs).
