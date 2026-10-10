/*
 * mock-target.c -- rea-unary
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
// Provenance: stage3/driver (worker3), v1. Parents: stage3/driver/proto.h,
//   stage3/driver/sha256.h, stage3/addmod.c (behavioral model logic, inlined).
// Full hashes in stage3/PROVENANCE.json.
//
// Mock FPGA/ASIC target: speaks the proto.h wire protocol on stdin/stdout.
// Backing store is a flash image FILE (default ../flash.bin, overridable via
// argv[1] or MOCK_FLASH). The real FPGA/ASIC hardware is NOT EXECUTED here;
// this process is the labeled stand-in the driver talks to.
#define _POSIX_C_SOURCE 200809L
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "proto.h"
#include "sha256.h"

/* ---- behavioral model: same addmod32 equations as stage3/addmod.c ---- */
typedef struct { uint8_t cf, pf, af, zf, sf, of; } flags_t;
static uint8_t parity_even8(uint32_t r)
{
    uint8_t b = (uint8_t)(r & 0xFFu);
    b ^= b >> 4; b ^= b >> 2; b ^= b >> 1;
    return (uint8_t)((~b) & 1u);
}
static uint32_t addmod32(uint32_t a, uint32_t b, flags_t *f)
{
    uint64_t full = (uint64_t)a + (uint64_t)b;
    uint32_t r = (uint32_t)full;
    uint64_t co = full >> 32;
    uint64_t ci = (((uint64_t)(a & 0x7FFFFFFFu) + (b & 0x7FFFFFFFu)) >> 31);
    if (f) {
        f->cf = (uint8_t)co;
        f->pf = parity_even8(r);
        f->af = (uint8_t)(((a & 0xFu) + (b & 0xFu)) > 0xFu);
        f->zf = (uint8_t)(r == 0u);
        f->sf = (uint8_t)(r >> 31);
        f->of = (uint8_t)((ci ^ co) & 1u);
    }
    return r;
}

static const uint32_t VA[10] = {
    0x00000000u, 0xFFFFFFFFu, 0x7FFFFFFFu, 0x00000008u, 0x00000003u,
    0x00000001u, 0x80000000u, 0x7FFFFFFFu, 0x80000000u, 0xFFFFFFFFu
};
static const uint32_t VB[10] = {
    0x00000000u, 0x00000001u, 0x00000001u, 0x00000008u, 0x00000000u,
    0x00000000u, 0x80000000u, 0x7FFFFFFFu, 0xFFFFFFFFu, 0xFFFFFFFFu
};

typedef struct { uint32_t a, b, result; flags_t f; } runrec_t;
static runrec_t last_run[10];
static int have_run = 0;
static char state_path[4096];

/* device state persists across target invocations (non-volatile device regs) */
static void state_load(void)
{
    FILE *fp = fopen(state_path, "rb");
    if (fp && fread(last_run, sizeof last_run, 1, fp) == 1)
        have_run = 1;
    if (fp) fclose(fp);
}

static void state_save(void)
{
    FILE *fp = fopen(state_path, "wb");
    if (fp) {
        fwrite(last_run, sizeof last_run, 1, fp);
        fclose(fp);
    }
}

static const char *flash_path;

static long flash_size(void)
{
    FILE *fp = fopen(flash_path, "rb");
    long n;
    if (!fp) return -1;
    fseek(fp, 0, SEEK_END);
    n = ftell(fp);
    fclose(fp);
    return n;
}

static void cmd_load(const char *off_s, const char *path)
{
    unsigned long off = strtoul(off_s, NULL, 0);
    FILE *in = fopen(path, "rb");
    FILE *fl;
    uint8_t buf[4096];
    size_t n, total = 0;
    if (!in) { printf("ERR cannot open %s\n", path); return; }
    fl = fopen(flash_path, "r+b");
    if (!fl) { fclose(in); printf("ERR cannot open flash %s\n", flash_path); return; }
    if (fseek(fl, (long)off, SEEK_SET) != 0) {
        fclose(in); fclose(fl); printf("ERR seek failed\n"); return;
    }
    while ((n = fread(buf, 1, sizeof buf, in)) > 0) {
        if (fwrite(buf, 1, n, fl) != n) {
            fclose(in); fclose(fl); printf("ERR flash write failed\n"); return;
        }
        total += n;
    }
    fclose(in); fclose(fl);
    printf("OK loaded %zu bytes at 0x%lx\n", total, off);
}

static void cmd_run(void)
{
    for (int i = 0; i < 10; i++) {
        last_run[i].a = VA[i];
        last_run[i].b = VB[i];
        last_run[i].result = addmod32(VA[i], VB[i], &last_run[i].f);
    }
    have_run = 1;
    state_save();
    printf("OK ran 10 vectors\n");
}

static void cmd_state(void)
{
    if (!have_run) { printf("ERR no run yet\n"); return; }
    printf("OK\n");
    for (int i = 0; i < 10; i++)
        printf("vec %d a=%08X b=%08X result=%08X cf=%u pf=%u af=%u zf=%u sf=%u of=%u\n",
               i, last_run[i].a, last_run[i].b, last_run[i].result,
               last_run[i].f.cf, last_run[i].f.pf, last_run[i].f.af,
               last_run[i].f.zf, last_run[i].f.sf, last_run[i].f.of);
    printf("END\n");
}

static void cmd_trace(void)
{
    if (!have_run) { printf("ERR no run yet\n"); return; }
    printf("OK\n");
    printf("vec,a,b,result,cf,pf,af,zf,sf,of\n");
    for (int i = 0; i < 10; i++)
        printf("%d,%08X,%08X,%08X,%u,%u,%u,%u,%u,%u\n",
               i, last_run[i].a, last_run[i].b, last_run[i].result,
               last_run[i].f.cf, last_run[i].f.pf, last_run[i].f.af,
               last_run[i].f.zf, last_run[i].f.sf, last_run[i].f.of);
    printf("END\n");
}

static void cmd_read(const char *off_s, const char *len_s)
{
    unsigned long off = strtoul(off_s, NULL, 0);
    unsigned long len = strtoul(len_s, NULL, 0);
    FILE *fl = fopen(flash_path, "rb");
    uint8_t buf[256];
    if (!fl) { printf("ERR cannot open flash\n"); return; }
    if (fseek(fl, (long)off, SEEK_SET) != 0) { fclose(fl); printf("ERR seek\n"); return; }
    printf("OK\n");
    while (len > 0) {
        size_t want = len > sizeof buf ? sizeof buf : len;
        size_t n = fread(buf, 1, want, fl);
        if (n == 0) break;
        printf("%08lX:", off);
        for (size_t i = 0; i < n; i++) printf(" %02X", buf[i]);
        printf("\n");
        off += n; len -= n;
    }
    fclose(fl);
    printf("END\n");
}

static void cmd_sha(const char *off_s, const char *len_s)
{
    unsigned long off = strtoul(off_s, NULL, 0);
    unsigned long len = strtoul(len_s, NULL, 0);
    FILE *fl = fopen(flash_path, "rb");
    uint8_t *buf, hash[32];
    if (!fl) { printf("ERR cannot open flash\n"); return; }
    buf = malloc(len ? len : 1);
    if (!buf) { fclose(fl); printf("ERR oom\n"); return; }
    if (fseek(fl, (long)off, SEEK_SET) != 0 || fread(buf, 1, len, fl) != len) {
        free(buf); fclose(fl); printf("ERR read\n"); return;
    }
    fclose(fl);
    sha256(buf, len, hash);
    free(buf);
    printf("OK sha256=");
    for (int i = 0; i < 32; i++) printf("%02x", hash[i]);
    printf("\n");
}

int main(int argc, char **argv)
{
    char line[PROTO_MAX_LINE];
    flash_path = argc > 1 ? argv[1] : getenv("MOCK_FLASH");
    if (!flash_path) flash_path = "../flash.bin";
    if (flash_size() < 0) {
        fprintf(stderr, "mock-target: cannot stat flash %s\n", flash_path);
        return 1;
    }
    snprintf(state_path, sizeof state_path, "%s.state", flash_path);
    state_load();
    setvbuf(stdout, NULL, _IOLBF, 0);
    while (fgets(line, sizeof line, stdin)) {
        char *cmd = strtok(line, " \t\r\n");
        char *a1, *a2;
        if (!cmd) continue;
        a1 = strtok(NULL, " \t\r\n");
        a2 = strtok(NULL, " \t\r\n");
        if (strcmp(cmd, "QUIT") == 0) { printf("OK bye\n"); return 0; }
        else if (strcmp(cmd, "LOAD") == 0 && a1 && a2) cmd_load(a1, a2);
        else if (strcmp(cmd, "RUN") == 0) cmd_run();
        else if (strcmp(cmd, "STATE") == 0) cmd_state();
        else if (strcmp(cmd, "TRACE") == 0) cmd_trace();
        else if (strcmp(cmd, "READ") == 0 && a1 && a2) cmd_read(a1, a2);
        else if (strcmp(cmd, "SHA") == 0 && a1 && a2) cmd_sha(a1, a2);
        else printf("ERR unknown or malformed command\n");
    }
    return 0;
}
