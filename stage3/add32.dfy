// add32.dfy -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// Provenance: stage3 (worker3), v1. Parents: stage1/sample.md (behavioral spec).
// Full hashes in stage3/PROVENANCE.json.
//
// Dafny contracts for the recovered 32-bit ADD (x86 `01 D8`).
// Formal spec: result = \addmod{a}{b}{2^{32}} (wraparound, no carry beyond bit31).
// Flags per documented Intel ADD semantics.

type uint32 = x: int | 0 <= x < 0x100000000

function method pow2(k: int): int
  requires 0 <= k
  decreases k
{
  if k == 0 then 1 else 2 * pow2(k - 1)
}

// "bits k..7 of x have even parity" (x is a byte)
function method parity_even8(x: int, k: int): bool
  requires 0 <= x < 256 && 0 <= k <= 8
  decreases 8 - k
{
  if k == 8 then true
  else (((x / pow2(k)) % 2 == 0) == parity_even8(x, k + 1))
}

method Add32(a: uint32, b: uint32)
  returns (r: uint32, cf: bool, pf: bool, af: bool, zf: bool, sf: bool, of: bool)
  ensures r == (a + b) % 0x100000000     // \addmod{a}{b}{2^32}: wraparound add
  ensures cf <==> a + b >= 0x100000000   // carry-out of bit31
  ensures zf <==> r == 0
  ensures sf <==> r >= 0x80000000        // result[31]
  ensures af <==> (a % 16) + (b % 16) >= 16   // carry-out of bit3
  // OF = (carry into bit31) XOR (carry out of bit31)
  ensures of <==> (((a % 0x80000000 + b % 0x80000000) / 0x80000000) == 1)
                  != (((a + b) / 0x100000000) == 1)
  ensures pf <==> parity_even8(r % 256, 0)    // even parity of result[7:0]
{
  var full := a + b;
  r := full % 0x100000000;
  cf := full >= 0x100000000;
  zf := r == 0;
  sf := r >= 0x80000000;
  af := (a % 16) + (b % 16) >= 16;
  var carry_in31 := (a % 0x80000000 + b % 0x80000000) / 0x80000000;
  var carry_out31 := full / 0x100000000;
  of := (carry_in31 == 1) != (carry_out31 == 1);
  pf := parity_even8(r % 256, 0);
}
