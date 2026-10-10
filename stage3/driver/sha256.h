/*
 * sha256.h -- rea-unary
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
// Provenance: stage3/driver (worker3), v1. Parents: none (fresh implementation
// of the public SHA-256 algorithm, FIPS 180-4). Full hashes in PROVENANCE.json.
#ifndef SHA256_H
#define SHA256_H
#include <stdint.h>
#include <stddef.h>
void sha256(const uint8_t *data, size_t len, uint8_t out[32]);
#endif
