/*
 * add.c -- rea-unary
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
// Provenance: stage3/fw (worker3), v1. Parents: stage3/addmod.c (same logic,
//   made self-contained for the firmware image). Full hashes in PROVENANCE.json.
//
// Recovered ADD behavior for the firmware image: EAX <- (EAX+EBX) mod 2^32
// (\addmod{}{}{2^{32}}), flags CF/PF/AF/ZF/SF/OF per documented Intel semantics.
// Freestanding ISO C only (stdint.h); no vendor libraries.
#include <stdint.h>

typedef struct {
    uint8_t cf, pf, af, zf, sf, of;
} add_flags_t;

static uint8_t parity_even8(uint32_t r)
{
    uint8_t b = (uint8_t)(r & 0xFFu);
    b ^= b >> 4;
    b ^= b >> 2;
    b ^= b >> 1;
    return (uint8_t)((~b) & 1u);
}

uint32_t addmod32(uint32_t a, uint32_t b, add_flags_t *f)
{
    uint64_t full = (uint64_t)a + (uint64_t)b;
    uint32_t r = (uint32_t)(full & 0xFFFFFFFFu);
    uint64_t carry_out31 = full >> 32;
    uint64_t carry_in31 =
        (((uint64_t)(a & 0x7FFFFFFFu) + (uint64_t)(b & 0x7FFFFFFFu)) >> 31);

    if (f) {
        f->cf = (uint8_t)carry_out31;
        f->pf = parity_even8(r);
        f->af = (uint8_t)(((a & 0xFu) + (b & 0xFu)) > 0xFu);
        f->zf = (uint8_t)(r == 0u);
        f->sf = (uint8_t)((r >> 31) & 1u);
        f->of = (uint8_t)((carry_in31 ^ carry_out31) & 1u);
    }
    return r;
}
