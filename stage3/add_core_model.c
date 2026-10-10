/*
 * add_core_model.c -- rea-unary
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
// Provenance: stage3 (worker3), v1. Parents: stage3/add_core.vhd, stage3/addmod.h,
//   stage3/addmod.c. Full hashes in stage3/PROVENANCE.json.
//
// C11 cycle-accurate model of add_core.vhd. Mirrors the VHDL structure:
// one C function per state (st_fetch/st_decode/st_execute/st_writeback),
// same state names (FETCH/DECODE/EXECUTE/WRITEBACK), same register names
// (a_reg, b_reg), same outputs (result, cf/pf/af/zf/sf/of, done), synchronous
// reset, single clock (core_clock dispatches on the current state).
// Used for checked behavioral correspondence against the GHDL simulation.
#include <stdint.h>
#include <stdio.h>
#include "addmod.h"

typedef enum { FETCH, DECODE, EXECUTE, WRITEBACK } state_t;

typedef struct {
    state_t  state;                 /* state register */
    uint32_t a_reg, b_reg;          /* operand registers */
    uint32_t result;                /* result register */
    uint8_t  cf, pf, af, zf, sf, of;/* flag registers */
    uint8_t  done;                  /* done register */
} core_t;

static void core_reset(core_t *c)
{
    c->state = FETCH;
    c->a_reg = 0; c->b_reg = 0;
    c->result = 0;
    c->cf = 0; c->pf = 0; c->af = 0;
    c->zf = 0; c->sf = 0; c->of = 0;
    c->done = 0;
}

/* FETCH: capture operands when start is asserted */
static void st_fetch(core_t *c, uint8_t start, uint32_t a_in, uint32_t b_in)
{
    c->done = 0;
    if (start) {
        c->a_reg = a_in;
        c->b_reg = b_in;
        c->state = DECODE;
    }
}

/* DECODE: decode of 01 D8 (ADD r/m32, r32) -- fixed ADD datapath */
static void st_decode(core_t *c)
{
    (void)c;
    c->state = EXECUTE;
}

/* EXECUTE: \addmod{a}{b}{2^{32}} + flag computation (shared addmod32) */
static void st_execute(core_t *c)
{
    add_flags_t f;
    c->result = addmod32(c->a_reg, c->b_reg, &f);
    c->cf = f.cf; c->pf = f.pf; c->af = f.af;
    c->zf = f.zf; c->sf = f.sf; c->of = f.of;
    c->state = WRITEBACK;
}

/* WRITEBACK: raise done for one cycle */
static void st_writeback(core_t *c)
{
    c->done = 1;
    c->state = FETCH;
}

/* one clock: dispatch on current state (cf. VHDL case statement) */
static void core_clock(core_t *c, uint8_t start, uint32_t a_in, uint32_t b_in)
{
    switch (c->state) {
    case FETCH:     st_fetch(c, start, a_in, b_in); break;
    case DECODE:    st_decode(c);                    break;
    case EXECUTE:   st_execute(c);                   break;
    case WRITEBACK: st_writeback(c);                 break;
    }
}

static const uint32_t VA[10] = {
    0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu, 0x00000008u, 0x00000003u,
    0x00000001u, 0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xFFFFFFFFu
};
static const uint32_t VB[10] = {
    0x00000000u, 0x00000001u, 0x00000001u, 0x00000008u, 0x00000000u,
    0x00000000u, 0x80000000u, 0x7FFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu
};

int main(void)
{
    core_t c;
    /* per-vector final result/flags, for the correspondence check */
    for (int v = 0; v < 10; v++) {
        core_reset(&c);
        core_clock(&c, 0, VA[v], VB[v]); /* settle, FETCH */
        core_clock(&c, 1, VA[v], VB[v]); /* start -> DECODE */
        core_clock(&c, 0, VA[v], VB[v]); /* DECODE -> EXECUTE */
        core_clock(&c, 0, VA[v], VB[v]); /* EXECUTE -> WRITEBACK */
        core_clock(&c, 0, VA[v], VB[v]); /* WRITEBACK (done=1) -> FETCH */
        printf("vec %d a=%08X b=%08X result=%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u done=%u\n",
               v, VA[v], VB[v], c.result,
               c.cf, c.pf, c.af, c.zf, c.sf, c.of, c.done);
    }
    return 0;
}
