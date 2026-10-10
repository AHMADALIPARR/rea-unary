<!-- Provenance: stage3 (worker3), v1. Parents: stage3/differential-log.txt
     (silicon oracle), stage3/traces.csv (GHDL sim). Full hashes in PROVENANCE.json. -->
# Test vectors — `01 D8` ADD EAX, EBX recovery

Expected values below are **silicon-verified**: each row was produced by
executing the real x86 `ADD EAX, EBX` on this machine (inline asm + PUSHF)
and cross-checked against the C11 model and the GHDL simulation
(`differential-log.txt`: 140/140 register comparisons match, 0 failures).

| # | a | b | result | CF | PF | AF | ZF | SF | OF | notes |
|---|---|---|--------|----|----|----|----|----|----|-------|
| 0 | 00000000 | 00000000 | 00000000 | 0 | 1 | 0 | 1 | 0 | 0 | zero + zero; ZF, PF set |
| 1 | FFFFFFFF | 00000001 | 00000000 | 1 | 1 | 1 | 1 | 0 | 0 | wraparound; CF, AF |
| 2 | 7FFFFFFF | 00000001 | 80000000 | 0 | 1 | 1 | 0 | 1 | 1 | signed overflow; **OF=1, CF=0** (counterexample vector) |
| 3 | 00000008 | 00000008 | 00000010 | 0 | 0 | 1 | 0 | 0 | 0 | half-carry; AF |
| 4 | 00000003 | 00000000 | 00000003 | 0 | 1 | 0 | 0 | 0 | 0 | even parity; PF=1 |
| 5 | 00000001 | 00000000 | 00000001 | 0 | 0 | 0 | 0 | 0 | 0 | odd parity; PF=0 |
| 6 | 80000000 | 80000000 | 00000000 | 1 | 1 | 0 | 1 | 0 | 1 | CF=1 **and** OF=1 (INT_MIN+INT_MIN overflows) |
| 7 | 7FFFFFFF | 7FFFFFFF | FFFFFFFE | 0 | 0 | 1 | 0 | 1 | 1 | OF=1, CF=0 |
| 8 | 80000000 | FFFFFFFF | 7FFFFFFF | 1 | 1 | 0 | 0 | 0 | 1 | CF=1, OF=1 |
| 9 | FFFFFFFF | FFFFFFFF | FFFFFFFE | 1 | 0 | 1 | 0 | 1 | 0 | CF=1, OF=0 |

## Pass / fail

- C11 model (`add_core_model` / `addmod32`) vs silicon: **70/70** register
  comparisons pass (10 vectors × 7 registers).
- GHDL simulation (`traces.csv` EXECUTE rows) vs silicon: **70/70** pass.
- SQL trace-conformance suite (`sql-results.txt`): check-a 0 violations / 10
  EXECUTE rows; check-b 0 violations; check-c 0 violations; check-d vacuous
  pass (0 privileged rows); check-e done exactly on 10 WRITEBACK rows.
- Dafny contract clauses vs C11 model (`contract-check.log`): **10/10**
  vectors satisfy all 7 clauses (behavioral correspondence, hand-checked).

Note on vector 6: an early hand computation predicted OF=0; real silicon
reports OF=1 (adding two INT_MIN values overflows signed 32-bit range).
The silicon oracle is authoritative — the hand computation was corrected.
