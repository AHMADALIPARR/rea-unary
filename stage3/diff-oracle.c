/*
 * diff-oracle.c -- rea-unary
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
// Provenance: stage3 (worker3), v1. Parents: stage3/addmod.h, stage3/addmod.c,
//   stage3/traces.csv. Full hashes in stage3/PROVENANCE.json.
//
// Differential oracle: executes the REAL x86 `ADD EAX, EBX` (bytes 01 D8) on
// this machine's silicon via inline assembly, captures EAX and EFLAGS, and
// compares register-by-register (result + CF, PF, AF, ZF, SF, OF) against:
//   (1) the C11 model (addmod32), and
//   (2) the GHDL simulation's EXECUTE rows from traces.csv.
// Also: --hypothesis-check mode tests one specific hypothesis claim against
// silicon (used for the counterexample-loop demo).
//
// Usage:
//   ./diff-oracle                 -- full differential run over 10 vectors
//   ./diff-oracle --hypothesis-check
//                                 -- test "ADD sets CF on signed overflow"
//                                    on a=0x7FFFFFFF,b=0x00000001; exit 1 if refuted
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "addmod.h"

/* ---- real silicon: execute ADD EAX, EBX, capture EAX + EFLAGS ---- */
static void silicon_add(uint32_t a, uint32_t b, uint32_t *res, uint32_t *eflags)
{
    uint32_t r, fl;
    __asm__ volatile (
        "movl %2, %%eax\n\t"
        "movl %3, %%ebx\n\t"
        "addl %%ebx, %%eax\n\t"   /* the actual 01 D8 operation */
        "pushfq\n\t"
        "popq %%rdx\n\t"
        "movl %%eax, %0\n\t"
        "movl %%edx, %1\n\t"
        : "=r" (r), "=r" (fl)
        : "r" (a), "r" (b)
        : "eax", "ebx", "edx", "cc");
    *res = r;
    *eflags = fl;
}

#define F_CF (1u << 0)
#define F_PF (1u << 2)
#define F_AF (1u << 4)
#define F_ZF (1u << 6)
#define F_SF (1u << 7)
#define F_OF (1u << 11)

typedef struct {
    uint32_t result;
    uint8_t cf, pf, af, zf, sf, of;
} regset_t;

static regset_t from_silicon(uint32_t a, uint32_t b)
{
    uint32_t r, fl;
    regset_t s;
    silicon_add(a, b, &r, &fl);
    s.result = r;
    s.cf = (fl & F_CF) != 0;
    s.pf = (fl & F_PF) != 0;
    s.af = (fl & F_AF) != 0;
    s.zf = (fl & F_ZF) != 0;
    s.sf = (fl & F_SF) != 0;
    s.of = (fl & F_OF) != 0;
    return s;
}

static regset_t from_cmodel(uint32_t a, uint32_t b)
{
    add_flags_t f;
    regset_t s;
    s.result = addmod32(a, b, &f);
    s.cf = f.cf; s.pf = f.pf; s.af = f.af;
    s.zf = f.zf; s.sf = f.sf; s.of = f.of;
    return s;
}

static const uint32_t VA[10] = {
    0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu, 0x00000008u, 0x00000003u,
    0x00000001u, 0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xFFFFFFFFu
};
static const uint32_t VB[10] = {
    0x00000000u, 0x00000001u, 0x00000001u, 0x00000008u, 0x00000000u,
    0x00000000u, 0x80000000u, 0x7FFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu
};

static int cmp_reg(const char *impl, int vec, const char *reg,
                   uint32_t got, uint32_t want, int *pass, int *fail)
{
    if (got == want) {
        (*pass)++;
        printf("  [PASS] vec %d %-4s %-6s got=%08X want=%08X\n",
               vec, impl, reg, got, want);
        return 1;
    }
    (*fail)++;
    printf("  [FAIL] vec %d %-4s %-6s got=%08X want=%08X\n",
           vec, impl, reg, got, want);
    return 0;
}

/* read the i-th EXECUTE row (0-based) from traces.csv */
static int read_ghdl_exec_row(int idx, regset_t *out)
{
    FILE *fp = fopen("traces.csv", "r");
    char line[256];
    int n = -1;
    if (!fp) { perror("traces.csv"); return 0; }
    if (!fgets(line, sizeof line, fp)) { fclose(fp); return 0; } /* header */
    while (fgets(line, sizeof line, fp)) {
        char state[16], sa[9], sb[9], sr[9];
        int cf, pf, af, zf, sf, of;
        unsigned cyc;
        if (sscanf(line, "%u,%15[^,],%8[^,],%8[^,],%8[^,],%d,%d,%d,%d,%d,%d",
                   &cyc, state, sa, sb, sr, &cf, &pf, &af, &zf, &sf, &of) != 11)
            continue; /* 11 conversions; the trailing `done` column is not needed here */
        if (strcmp(state, "EXECUTE") != 0)
            continue;
        if (++n == idx) {
            out->result = (uint32_t)strtoul(sr, NULL, 16);
            out->cf = (uint8_t)cf; out->pf = (uint8_t)pf;
            out->af = (uint8_t)af; out->zf = (uint8_t)zf;
            out->sf = (uint8_t)sf; out->of = (uint8_t)of;
            fclose(fp);
            return 1;
        }
    }
    fclose(fp);
    return 0;
}

static int hypothesis_check(void)
{
    /* Wrong hypothesis h-wrong1: "ADD sets CF on signed overflow".
     * Test vector: a=0x7FFFFFFF, b=0x00000001 (signed overflow: +max + 1). */
    const uint32_t a = 0x7FFFFFFFu, b = 0x00000001u;
    regset_t s = from_silicon(a, b);
    printf("hypothesis: h-wrong1 \"ADD sets CF on signed overflow\"\n");
    printf("vector: a=0x%08X b=0x%08X\n", a, b);
    printf("expected_per_hypothesis: cf=1\n");
    printf("observed_silicon: result=0x%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u\n",
           s.result, s.cf, s.pf, s.af, s.zf, s.sf, s.of);
    if (s.cf == 1) {
        printf("verdict: CONFIRMED (unexpected)\n");
        return 0;
    }
    printf("verdict: REFUTED -- silicon shows CF=0, OF=1 on signed overflow; "
           "CF is the unsigned carry-out, OF reports signed overflow\n");
    return 1;
}

int main(int argc, char **argv)
{
    if (argc > 1 && strcmp(argv[1], "--hypothesis-check") == 0)
        return hypothesis_check();

    int pass = 0, fail = 0;
    printf("differential oracle: real x86 silicon (ADD EAX,EBX) vs "
           "C11 model vs GHDL sim\n");
    printf("registers compared per vector: result cf pf af zf sf of\n\n");

    for (int v = 0; v < 10; v++) {
        regset_t sil = from_silicon(VA[v], VB[v]);
        regset_t cm  = from_cmodel(VA[v], VB[v]);
        regset_t gh;
        int have_ghdl = read_ghdl_exec_row(v, &gh);

        printf("vec %d a=%08X b=%08X\n", v, VA[v], VB[v]);
        printf("  silicon: result=%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u\n",
               sil.result, sil.cf, sil.pf, sil.af, sil.zf, sil.sf, sil.of);
        printf("  cmodel : result=%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u\n",
               cm.result, cm.cf, cm.pf, cm.af, cm.zf, cm.sf, cm.of);
        cmp_reg("cmodel", v, "result", cm.result, sil.result, &pass, &fail);
        cmp_reg("cmodel", v, "cf", cm.cf, sil.cf, &pass, &fail);
        cmp_reg("cmodel", v, "pf", cm.pf, sil.pf, &pass, &fail);
        cmp_reg("cmodel", v, "af", cm.af, sil.af, &pass, &fail);
        cmp_reg("cmodel", v, "zf", cm.zf, sil.zf, &pass, &fail);
        cmp_reg("cmodel", v, "sf", cm.sf, sil.sf, &pass, &fail);
        cmp_reg("cmodel", v, "of", cm.of, sil.of, &pass, &fail);

        if (have_ghdl) {
            printf("  ghdl   : result=%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u\n",
                   gh.result, gh.cf, gh.pf, gh.af, gh.zf, gh.sf, gh.of);
            cmp_reg("ghdl", v, "result", gh.result, sil.result, &pass, &fail);
            cmp_reg("ghdl", v, "cf", gh.cf, sil.cf, &pass, &fail);
            cmp_reg("ghdl", v, "pf", gh.pf, sil.pf, &pass, &fail);
            cmp_reg("ghdl", v, "af", gh.af, sil.af, &pass, &fail);
            cmp_reg("ghdl", v, "zf", gh.zf, sil.zf, &pass, &fail);
            cmp_reg("ghdl", v, "sf", gh.sf, sil.sf, &pass, &fail);
            cmp_reg("ghdl", v, "of", gh.of, sil.of, &pass, &fail);
        } else {
            printf("  ghdl   : MISSING EXECUTE row %d in traces.csv\n", v);
            fail += 7;
        }
        printf("\n");
    }
    printf("differential summary: %d PASS, %d FAIL (140 comparisons = "
           "10 vectors x 7 registers x 2 implementations)\n", pass, fail);
    return fail ? 1 : 0;
}
