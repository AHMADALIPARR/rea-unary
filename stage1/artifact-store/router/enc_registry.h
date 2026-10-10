/*
 * enc_registry.h -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
/* provenance: producer=stage1/coordinator parents=[none:hand-authored] version=v1 full-sha256-in=PROVENANCE.json */
/*
 * enc_registry.h — ALP evidence-routing: encoding registry.
 * rea-unary stage1/router. Fresh authorship, C11.
 *
 * Each evidence payload may name an encoding; the registry maps the
 * encoding name to its decoder. Decoders return a freshly allocated
 * string the caller must free.
 */
#ifndef ENC_REGISTRY_H
#define ENC_REGISTRY_H

#include <stddef.h>

typedef char *(*decode_fn)(const char *input);

typedef struct {
    const char *name;
    decode_fn decode;
} Encoding;

/* Find an encoding by name; NULL if unknown. */
const Encoding *enc_find(const char *name);

/* Number of registered encodings. */
size_t enc_count(void);

#endif
