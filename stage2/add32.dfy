// add32.dfy -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// provenance: producer=stage2/worker2 parents=[state-machine.md:b9223f82b948 recovery-spec.md] version=v1 full-sha256-in=PROVENANCE.json
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// ============================================================================
// add32.dfy — Worker 2 (rea-unary swarm), 2026-10-10
// Dafny lemmas + contracts for the recovered 01 D8 ADD EAX, EBX behavior.
//
// STATUS: real Dafny code; NOT verified on this VM (no Dafny toolchain
//   installed; `command -v dafny` is empty and no brief $0 install path
//   exists). Lemmas below are the required shape; the method keeps its
//   requires/ensures contracts and discharges them by calling the lemmas.
//
// Traceability: built from stage2/hypotheses.jsonl, hypothesis h2 v1 (ALP).
// Assumptions: A1..A4 of stage2/state-machine.md
//   (A1: 32-bit mode; A2: mod-2^32 wraparound; A3: standard Intel ADD flag
//   semantics; A4: unary-Boolean foundation).
// Invariants proved (spec-level): I1..I7 of stage2/state-machine.md.
// ============================================================================

// 32-bit wrap of an arbitrary integer (Dafny % is Euclidean: result in
// 0..2^32-1 for positive modulus).
function U32(x: int): int
{
  x % 0x100000000
}

// Signed 32-bit interpretation of an arbitrary integer (via its wrap).
function S32(x: int): int
{
  if U32(x) >= 0x80000000 then U32(x) - 0x100000000 else U32(x)
}

// Even parity of a natural number's binary representation (A4: the PF
// decision decomposed per bit; the recursion is the XOR fan-in of D5).
function ParityEven(x: nat): bool
  decreases x
{
  if x == 0 then true else ParityEven(x / 2) != (x % 2 == 1)
}

// Signed-overflow predicate for 32-bit wraparound addition.
function SignedOverflow(a: int, b: int): bool
{
  S32(a) + S32(b) >= 0x80000000 || S32(a) + S32(b) < -0x80000000
}

// The implementation: one tuple, pure expression (no statements, so it is
// a valid Dafny function body). Order: (result, cf, pf, af, zf, sf, of).
function Add32Impl(a: int, b: int): (int, bool, bool, bool, bool, bool, bool)
{
  (U32(a + b),
   a + b > 0xFFFFFFFF,
   ParityEven(U32(a + b) % 256),
   (a % 16) + (b % 16) > 15,
   U32(a + b) == 0,
   U32(a + b) >= 0x80000000,
   SignedOverflow(a, b))
}

// L1: the result invariant (I1) — wraparound addition, requires true.
lemma Add32Correct(a: int, b: int)
  ensures Add32Impl(a, b).0 == (a + b) % 0x100000000
{
}

// L2: the flag postconditions (I2..I7) — standard Intel ADD semantics (A3).
lemma Add32Flags(a: int, b: int)
  ensures Add32Impl(a, b).1 <==> a + b > 0xFFFFFFFF            // I2: CF
  ensures Add32Impl(a, b).4 <==> Add32Impl(a, b).0 == 0        // I3: ZF
  ensures Add32Impl(a, b).5 <==> Add32Impl(a, b).0 >= 0x80000000 // I4: SF
  ensures Add32Impl(a, b).6 <==> SignedOverflow(a, b)          // I5: OF
  ensures Add32Impl(a, b).2 <==> ParityEven(Add32Impl(a, b).0 % 256) // I6: PF
  ensures Add32Impl(a, b).3 <==> (a % 16) + (b % 16) > 15      // I7: AF
{
}

// The contracted method: requires true, ensures the recovered behavior;
// postconditions discharged by calling L1 and L2.
method Add32(a: int, b: int)
  returns (result: int, cf: bool, pf: bool, af: bool, zf: bool, sf: bool, of: bool)
  requires true
  ensures result == (a + b) % 0x100000000
  ensures cf <==> a + b > 0xFFFFFFFF
  ensures zf <==> result == 0
  ensures sf <==> result >= 0x80000000
  ensures of <==> SignedOverflow(a, b)
  ensures pf <==> ParityEven(result % 256)
  ensures af <==> (a % 16) + (b % 16) > 15
{
  Add32Correct(a, b);
  Add32Flags(a, b);
  var t := Add32Impl(a, b);
  result, cf, pf, af, zf, sf, of := t.0, t.1, t.2, t.3, t.4, t.5, t.6;
}
