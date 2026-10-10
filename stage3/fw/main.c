/*
 * main.c -- rea-unary
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
// Provenance: stage3/fw (worker3), v1. Parents: stage3/fw/add.c. Full hashes in PROVENANCE.json.
//
// Firmware harness: runs the 10 canonical ADD vectors through addmod32 and
// stores {a, b, result, flags} records into a RAM-resident results table,
// then halts. Freestanding: no hosted libc, no vendor libraries -- the
// "compatible library" is the ISO C freestanding subset (stdint.h).
#include <stdint.h>

typedef struct {
    uint8_t cf, pf, af, zf, sf, of;
} add_flags_t;

uint32_t addmod32(uint32_t a, uint32_t b, add_flags_t *f);

#define NVEC 10

typedef struct {
    uint32_t  a, b, result;
    add_flags_t flags;
} result_rec_t;

/* RAM-resident results table (.bss -> RAM via link.ld). Volatile: the
 * records are the firmware's observable output on the mock target. */
volatile result_rec_t results[NVEC];

static const uint32_t VA[NVEC] = {
    0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu, 0x00000008u, 0x00000003u,
    0x00000001u, 0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xFFFFFFFFu
};
static const uint32_t VB[NVEC] = {
    0x00000000u, 0x00000001u, 0x00000001u, 0x00000008u, 0x00000000u,
    0x00000000u, 0x80000000u, 0x7FFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu
};

void _start(void)
{
    for (uint32_t i = 0; i < NVEC; i++) {
        add_flags_t fl;
        uint32_t r = addmod32(VA[i], VB[i], &fl);
        results[i].a = VA[i];
        results[i].b = VB[i];
        results[i].result = r;
        results[i].flags = fl;
    }
    for (;;) {
        __asm__ volatile ("" ::: "memory");
    }
}
