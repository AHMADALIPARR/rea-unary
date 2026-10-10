/*
 * contract-check.c -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// Provenance: stage3 (worker3), v1. Parents: stage3/add32.dfy (contracts),
//   stage3/addmod.h, stage3/addmod.c (implementation). Full hashes in PROVENANCE.json.
//
// Behavioral correspondence: evaluates every ensures-clause of add32.dfy
// against the C11 model (addmod32) on the 10 shared test vectors.
// This is the contract<->implementation correspondence check the Dafny
// toolchain could not complete in reasonable time (see README).
#include <stdint.h>
#include <stdio.h>
#include "addmod.h"

static const uint32_t VA[10] = {
    0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu, 0x00000008u, 0x00000003u,
    0x00000001u, 0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xFFFFFFFFu
};
static const uint32_t VB[10] = {
    0x00000000u, 0x00000001u, 0x00000001u, 0x00000008u, 0x00000000u,
    0x00000000u, 0x80000000u, 0x7FFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu
};

/* independent even-parity of a byte (spec of parity_even8, iterative) */
static int parity_even8_spec(uint32_t x)
{
    int ones = 0;
    for (int k = 0; k < 8; k++)
        ones += (int)((x >> k) & 1u);
    return (ones % 2) == 0;
}

int main(void)
{
    int pass = 0, fail = 0;
    printf("behavioral correspondence: add32.dfy ensures-clauses vs "
           "C11 model (addmod32), 10 shared vectors\n");
    for (int v = 0; v < 10; v++) {
        uint32_t a = VA[v], b = VB[v];
        add_flags_t f;
        uint32_t r = addmod32(a, b, &f);
        uint64_t full = (uint64_t)a + (uint64_t)b;
        /* each ensures-clause, evaluated independently of the implementation */
        int c_r  = (r == (uint32_t)(full % 0x100000000uLL));
        int c_cf = (f.cf == (full >= 0x100000000uLL));
        int c_zf = (f.zf == (r == 0u));
        int c_sf = (f.sf == (r >= 0x80000000u));
        int c_af = (f.af == (((a & 0xFu) + (b & 0xFu)) >= 16u));
        int cin31 = (int)(((a & 0x7FFFFFFFu) + (b & 0x7FFFFFFFu)) >> 31);
        int cout31 = (int)(full >> 32);
        int c_of = (f.of == ((cin31 ^ cout31) & 1));
        int c_pf = (f.pf == parity_even8_spec(r & 0xFFu));
        int ok = c_r && c_cf && c_zf && c_sf && c_af && c_of && c_pf;
        printf("vec %d a=%08X b=%08X: r=%d cf=%d zf=%d sf=%d af=%d of=%d pf=%d -> %s\n",
               v, a, b, c_r, c_cf, c_zf, c_sf, c_af, c_of, c_pf,
               ok ? "PASS" : "FAIL");
        if (ok) pass++; else fail++;
    }
    printf("correspondence: %d/10 vectors satisfy all 7 contract clauses\n",
           pass);
    return fail ? 1 : 0;
}
