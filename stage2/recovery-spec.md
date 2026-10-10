<!-- provenance: producer=stage2/worker2 parents=[stage1/sample.bin:d50224621b99] version=v1 full-sha256-in=PROVENANCE.json -->
# Behavior-recovery specification — `stage1/sample.bin` (Worker 2, rea-unary swarm)

Built 2026-10-10. Input: `~/workspace/rea-unary/stage1/` (byte-verified below).
Output stage: `stage2/` (recover behavior -> unary -> VHDL).

## 0. Byte verification (done on this VM, not assumed)

```
$ od -A x -t x1z ~/workspace/rea-unary/stage1/sample.bin
000000 01 d8 83 f8 0a 7e 07 b8 01 00 00 00 eb 05 b8 00  >.....~..........<
000010 00 00 00 89 c3 c3                                >......<
$ sha256sum ~/workspace/rea-unary/stage1/sample.bin
d50224621b998b581e94ab675aa70449d9988ea163cc884d1972ca5d7f872850
```

- First two bytes at file offset 0x00 are **`01 D8`** — confirmed by `od`, not by
  trusting the docs.
- SHA-256 matches the stage1 artifact store (`d5022462…850`). 22 bytes total.
- `~/workspace/rea` was NOT touched (read-only reference per swarm rules).

## 1. Hypothesis discipline (ALP propose -> reject loop)

Where the bytes + docs underdetermine a point, ALP proposes candidate
explanations and rejects any that violate a hard constraint. Hard constraints
used throughout:

- **C1** — the observed bytes on disk (od-verified above).
- **C2** — mod-2^32 wraparound: the ADD result is `\addmod{x}{y}{2^{32}}`.
- **C3** — standard Intel x86 flag definitions for ADD (documented architecture
  semantics, not invention).
- **C4** — stage1 docs (`sample.md`, `sample-disassembly.txt`,
  `sample-analysis.json`) where they are byte-consistent with C1.

Every propose/reject step is logged in `stage2/hypotheses.jsonl`
(12 proposed, 8 rejected, 4 accepted). The decisive ones are narrated inline
below; the full ledger carries the rest.

## 2. Canonical seed instruction — offset 0x00, bytes `01 D8`

- **Decode.** Opcode `01 /r` = ADD r/m32, r32 (32-bit mode, A1). ModRM byte
  `D8` = `11 011 000`: mod=3 (register direct), reg=011 (EBX, source),
  r/m=000 (EAX, destination).
  - *Propose h3 v1 (accepted):* dest = r/m32 = EAX, src = r32 = EBX.
  - *Propose r1 (REJECTED):* "result is stored in EBX". Violates C1/C4: the
    `01 /r` encoding writes the r/m operand, and the canonical IR binds
    `%destination` = EAX. Rejected.
- **Semantics (h2 v1, accepted):** `EAX <- (EAX_old + EBX) mod 2^32`
  (i.e. `\addmod{x}{y}{2^{32}}`), and update CF, PF, AF, ZF, SF, OF.
- **Flag computations (C3, explicit):** let `s = EAX_old + EBX` be the full
  (unwrapped) integer sum, `r = s mod 2^32` the stored result, and
  `carry_i` the carry into bit `i` of the addition (`carry_0 = 0`):
  - `CF  = carry_32` (carry-out of bit 31)
  - `PF  = 1` iff `r[7:0]` has even parity
  - `AF  = carry_4` (carry-out of bit 3)
  - `ZF  = 1` iff `r == 0`
  - `SF  = r[31]`
  - `OF  = carry_31 XOR carry_32` (carry into bit 31 XOR carry out of bit 31)
- *Propose r2 (REJECTED):* "CF is forced to 0 (carry silently discarded)."
  Violates C3: wraparound discards the carry from the *stored* result, but CF
  must still report it.
- *Propose r4 (REJECTED):* "OF = CF." Violates C3. Counterexample:
  `EAX=0x7FFFFFFF, EBX=1` -> `r=0x80000000`, OF=1 (signed overflow), CF=0.
- **Canonical IR (verbatim, per user spec):**
  ```
  %result = add.i32 %a, %b
  store.i32 %result, %destination
  ```
  with `%a` = EBX, `%b` = EAX_old, `%destination` = EAX. This is the IR that
  Worker 3's C11 model and the VHDL both implement.

## 3. Full loop turn, documented: the PF revision

This is the required wrong-hypothesis -> counterexample -> revision -> rebuild
turn, executed at the spec level:

1. **Wrong hypothesis proposed:** "PF = parity of the full 32-bit result."
2. **Counterexample:** take `r = 0x00000100`. Low byte `0x00` has 0 bits set
   (even parity) -> true PF = 1. Full 32-bit value has exactly 1 bit set
   (odd parity) -> wrong hypothesis predicts PF = 0. The two disagree, and the
   wrong one contradicts C3 (Intel defines PF on `r[7:0]` only).
3. **Rejected** (ledger record `r3`, reason cites the `0x100` counterexample
   and the violated constraint C3).
4. **Revised hypothesis accepted:** PF = even parity of `r[7:0]`, folded into
   `h2 v1`.
5. **Rebuild:** the flag equations above, `unary-mapping.md`, `spec.tex`,
   `add32.dfy`, and `add_core.vhd` all carry the corrected PF. Consistent.

## 4. Remaining instructions (same precision)

### 4.1 Offset 0x02 — `83 F8 0A`: CMP EAX, 10
- Decode: `83 /7 ib` = CMP r/m32, imm8 with sign-extended imm8 = 10.
- Semantics: compute `EAX - 10` exactly like a SUB (flags CF, PF, AF, ZF, SF,
  OF from the subtraction), **discard the result**; EAX unchanged.
- *Propose r6 (REJECTED):* "CMP writes the difference to EAX." Violates the
  documented CMP semantics (C4) and would corrupt the threshold predicate.
- Note for the branch: the borrow for `EAX - 10` is `NOT carry_32` of the
  subtraction; the JLE below consumes ZF/SF/OF from *this* instruction, not
  from the ADD (the ADD's flags are overwritten here — C4, `sample.md`).

### 4.2 Offset 0x05 — `7E 07`: JLE 0x40102E
- Decode: `7E cb` = JLE rel8. rel8 = `0x07` sign-extended = +7.
- *Propose h4 v1 (accepted):* target = next_IP + rel8 = `0x401025 + 2 + 7`
  = `0x40102E` (lands on `MOV EAX, 0`; no mid-instruction landing — C4).
- *Propose r7 (REJECTED):* "jump offsets are absolute." Then target = `0x07`,
  outside the function — contradicts C1/C4 jump-target verification.
- *Propose r5 (REJECTED):* "JLE taken iff ZF=1." Violates documented JLE
  semantics: taken iff `ZF=1 OR (SF != OF)`. Counterexample: sum = -1
  (signed) <= 10 is taken with ZF=0, SF=1, OF=0.

### 4.3 Offsets 0x07 / 0x0E — `B8 imm32`: MOV EAX, 1 / MOV EAX, 0
- `EAX <- 1` (bytes `B8 01 00 00 00`), `EAX <- 0` (bytes `B8 00 00 00 00`).
- **Flags unchanged.**
- *Propose r8 (REJECTED):* "MOV updates flags." Violates Intel MOV semantics;
  the JLE must test the CMP flags, and a flag-clobbering MOV would break the
  predicate.

### 4.4 Offset 0x0C — `EB 05`: JMP 0x401033
- Unconditional; target = `0x40102C + 2 + 5` = `0x401033` (`MOV EBX, EAX`).

### 4.5 Offset 0x13 — `89 C3`: MOV EBX, EAX
- `89 /r` (r32, r/m32): `EBX <- EAX`. Flags unchanged.

### 4.6 Offset 0x15 — `C3`: RET
- Near return. End of recovered behavior.

## 5. Recovered program contract

Inputs: EAX, EBX at entry. Outputs at RET:

```
EAX = ((EAX_in + EBX_in) mod 2^32 > 10_signed) ? 1 : 0
EBX = EAX
```

A signed 32-bit threshold/step predicate on the wrapped sum. The comparison
`> 10` is signed (JLE is a signed condition). Worked examples (from stage1,
re-checked):

- EAX_in=3, EBX_in=4 -> sum 7 <= 10 -> EAX=0, EBX=0.
- EAX_in=3, EBX_in=9 -> sum 12 > 10 -> EAX=1, EBX=1.
- EAX_in=0xFFFFFFFF, EBX_in=2 -> sum wraps to 1 <= 10 -> EAX=0, EBX=0.

## 6. Scope for downstream stages

The formal artifacts (`state-machine.md`, `spec.tex`, `add32.dfy`,
`add_core.als`, `add_core.vhd`) model **the ADD core only** (offsets
0x00–0x01): the addmod-2^32 datapath plus the six flags. The CMP/JLE/MOV/RET
instructions are documented here for control-flow context; their only
downstream consumer is the JLE taken-condition equation
(`ZF OR (SF XOR OF)`), which is classified in `unary-mapping.md`.

## Author's rights notice
The following is the author's notice, reproduced verbatim. It is not a
finding or endorsement of the build swarm.
> Binary -> IR -> VHDL -> netlist: changing representation itself clears rights. Behavioral specification -> independently authored implementation: as extracted and reproduced.
