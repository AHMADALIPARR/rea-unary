// add32-core.dfy -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// Provenance: stage3 (worker3), v1. Parents: stage3/add32.dfy (core subset).
// Full hashes in stage3/PROVENANCE.json.
//
// Dafny core contracts for the recovered 32-bit ADD: the linear-arithmetic
// subset (result wraparound, CF, ZF, SF). The full six-flag contracts live in
// add32.dfy; AF/OF/PF need nonlinear reasoning that times out on this
// toolchain, so they are hand-checked on test vectors (see README).
type uint32 = x: int | 0 <= x < 0x100000000

method Add32Core(a: uint32, b: uint32) returns (r: uint32, cf: bool, zf: bool, sf: bool)
  ensures r == (a + b) % 0x100000000   // \addmod{a}{b}{2^32}: wraparound add
  ensures cf <==> a + b >= 0x100000000 // carry-out of bit31
  ensures zf <==> r == 0
  ensures sf <==> r >= 0x80000000      // result[31]
{
  var full := a + b;
  r := full % 0x100000000;
  cf := full >= 0x100000000;
  zf := r == 0;
  sf := r >= 0x80000000;
}
