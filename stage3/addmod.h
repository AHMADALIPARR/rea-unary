/*
 * addmod.h -- rea-unary
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
// Provenance: stage3 (worker3), v1. Parents: stage1/sample.md. Full hashes in PROVENANCE.json.
#ifndef ADDMOD_H
#define ADDMOD_H

#include <stdint.h>

/* x86 ADD flag bundle (CF, PF, AF, ZF, SF, OF). */
typedef struct {
    uint8_t cf, pf, af, zf, sf, of;
} add_flags_t;

/*
 * addmod32: recovered 32-bit ADD semantics.
 * result = (a + b) mod 2^32  i.e. \addmod{a}{b}{2^{32}} in the formal spec.
 * Flags per documented Intel ADD semantics:
 *   CF = carry-out of bit31
 *   PF = even parity of result[7:0]
 *   AF = carry-out of bit3
 *   ZF = (result == 0)
 *   SF = result[31]
 *   OF = (carry into bit31) XOR (carry out of bit31)
 */
uint32_t addmod32(uint32_t a, uint32_t b, add_flags_t *f);

#endif /* ADDMOD_H */
