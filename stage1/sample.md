<!-- provenance: producer=stage1/worker1 parents=[d50224621b99] version=v1 full-sha256-in=PROVENANCE.json -->
# sample.bin — byte-layout documentation (stage1 mock binary)

This file is the authoritative reference for `sample.bin`. It is a
hand-designed mock binary (see `README.md`); the byte values here are real
bytes on disk and every consumer must stay consistent with them.

## File identity

- File: `sample.bin` (stage1, 22 bytes)
- SHA-256: `d50224621b998b581e94ab675aa70449d9988ea163cc884d1972ca5d7f872850`
- Format: flat raw x86-32 machine code, little-endian. **No header.**
  File offset 0 is the first instruction byte.
- Documented load base: `0x401020`. Address of a byte = `0x401020 + file_offset`.

## Byte map

```
file offset : bytes                    virtual address : instruction
0x00        : 01 D8                    0x401020        : ADD EAX, EBX
0x02        : 83 F8 0A                 0x401022        : CMP EAX, 10
0x05        : 7E 07                    0x401025        : JLE 0x40102E
0x07        : B8 01 00 00 00           0x401027        : MOV EAX, 1
0x0C        : EB 05                    0x40102C        : JMP 0x401033
0x0E        : B8 00 00 00 00           0x40102E        : MOV EAX, 0
0x13        : 89 C3                    0x401033        : MOV EBX, EAX
0x15        : C3                       0x401035        : RET
```

## Instruction-set encoding table (x86-32, real encodings — not invented)

| Encoding            | Mnemonic        | Semantics (real x86-32 behavior) |
|---------------------|-----------------|----------------------------------|
| `01 /r` (r/m32,r32) | `ADD EAX, EBX`  | EAX ← (EAX + EBX) mod 2³²; update CF, PF, AF, ZF, SF, OF. 32-bit wraparound addition, no carry-out beyond 32 bits: `\addmod{x}{y}{2^{32}}`. |
| `83 /7 ib`          | `CMP EAX, imm8` | Compare EAX with sign-extended imm8 (here 10): set flags as `EAX − 10`, discard result. |
| `7E cb`             | `JLE rel8`      | Jump if (ZF=1) or (SF≠OF): target = next_IP + sign-extended rel8. |
| `B8+rd id`          | `MOV EAX, imm32`| EAX ← imm32 (little-endian). No flags changed. |
| `EB cb`             | `JMP rel8`      | Unconditional jump: target = next_IP + sign-extended rel8. |
| `89 /r` (r32,r/m32) | `MOV EBX, EAX`  | EBX ← EAX. No flags changed. |
| `C3`                | `RET`           | Near return. |

## Canonical seed instruction (verbatim per user spec)

File offset `0x00` (address `0x401020`):

- Bytes: `01 D8`
- Instruction: `ADD EAX, EBX` (x86, 32-bit mode)
- Semantics: Add EBX to EAX, store the result in EAX, and update the relevant flags (CF, PF, AF, ZF, SF, OF). The addition is **mod-2³² wraparound** (`\addmod{x}{y}{2^{32}}` in the formal spec): the stored 32-bit result discards any carry out of bit 31 (CF reports it).
- Canonical IR shape (verbatim):
  ```
  %result = add.i32 %a, %b
  store.i32 %result, %destination
  ```
  where `%a` = EBX, `%b` = EAX's old value, `%destination` = EAX.

## Expected behavior, instruction by instruction

Program contract (inputs: EAX, EBX at entry; outputs: EAX, EBX at RET):

1. `0x401020 ADD EAX, EBX` — EAX ← (EAX + EBX) mod 2³²; CF, PF, AF, ZF, SF, OF updated from the addition.
2. `0x401022 CMP EAX, 10` — set flags from (EAX − 10) without storing a result.
3. `0x401025 JLE 0x40102E` — if the sum was ≤ 10 (signed), go to the `MOV EAX, 0` block; otherwise fall through.
4. `0x401027 MOV EAX, 1` — sum > 10 path: EAX ← 1.
5. `0x40102C JMP 0x401033` — skip the zero block.
6. `0x40102E MOV EAX, 0` — sum ≤ 10 path: EAX ← 0.
7. `0x401033 MOV EBX, EAX` — EBX ← EAX.
8. `0x401035 RET` — return.

Net behavior: `EAX = ((EAX_in + EBX_in) mod 2³² > 10) ? 1 : 0`, `EBX = EAX`.
It is a signed 32-bit threshold/step predicate on the wrapped sum. The `ADD`
also sets all six arithmetic flags; the `CMP` then overwrites them before the
conditional branch, so the branch tests the comparison, not the addition.
(Worker 2's unary-flag mapping must stay consistent with the mod-2³²
wraparound of step 1.)

Worked examples:
- EAX_in = 3, EBX_in = 4 → sum 7 ≤ 10 → EAX = 0, EBX = 0.
- EAX_in = 3, EBX_in = 9 → sum 12 > 10 → EAX = 1, EBX = 1.
- EAX_in = 0xFFFFFFFF, EBX_in = 2 → sum wraps to 1 ≤ 10 → EAX = 0, EBX = 0.

## Jump-target verification

- JLE at 0x401025: target = 0x401025 + 2 + 0x07 = 0x40102E. ✓ lands on `MOV EAX, 0`.
- JMP at 0x40102C: target = 0x40102C + 2 + 0x05 = 0x401033. ✓ lands on `MOV EBX, EAX`.
- No branch target falls mid-instruction. Total size 22 = 0x16 bytes.
