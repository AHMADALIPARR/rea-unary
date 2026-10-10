/*
 * mkbin.c -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
/* provenance: producer=stage1/worker1 parents=[none:hand-authored] version=v1 full-sha256-in=PROVENANCE.json */
/* mkbin.c - generate stage1/sample.bin
 *
 * Writes a flat 22-byte raw x86-32 code image to sample.bin.
 * No file header: file offset 0 is the first instruction byte.
 * Load base is 0x401020 (documented in sample.md), so the
 * 01 D8 seed sits at address 0x401020.
 * Documented in sample.md. Build: gcc -std=c11 -Wall -Wextra -o mkbin mkbin.c
 *
 * License: MIT (extract/work tooling for the rea-unary project).
 */
#include <stdio.h>
#include <stdlib.h>

/* Instruction stream (file offsets 0x00..0x15):
 *  01 D8             ADD EAX, EBX        (the canonical 01 D8 seed)
 *  83 F8 0A          CMP EAX, 10
 *  7E 07             JLE  +7  -> offset 0x0E
 *  B8 01 00 00 00    MOV EAX, 1
 *  EB 05             JMP  +5  -> offset 0x13
 *  B8 00 00 00 00    MOV EAX, 0
 *  89 C3             MOV EBX, EAX
 *  C3                RET
 */
static const unsigned char PROGRAM[] = {
    0x01, 0xD8,             /* 0x00: ADD EAX, EBX */
    0x83, 0xF8, 0x0A,       /* 0x02: CMP EAX, 10 */
    0x7E, 0x07,             /* 0x05: JLE 0x0E */
    0xB8, 0x01, 0x00, 0x00, 0x00, /* 0x07: MOV EAX, 1 */
    0xEB, 0x05,             /* 0x0C: JMP 0x13 */
    0xB8, 0x00, 0x00, 0x00, 0x00, /* 0x0E: MOV EAX, 0 */
    0x89, 0xC3,             /* 0x13: MOV EBX, EAX */
    0xC3                    /* 0x15: RET */
};

int main(void)
{
    FILE *f = fopen("sample.bin", "wb");
    if (!f) {
        perror("fopen");
        return 1;
    }
    if (fwrite(PROGRAM, 1, sizeof PROGRAM, f) != sizeof PROGRAM) {
        perror("fwrite");
        fclose(f);
        return 1;
    }
    fclose(f);
    printf("wrote sample.bin (%zu bytes)\n", sizeof PROGRAM);
    return 0;
}
