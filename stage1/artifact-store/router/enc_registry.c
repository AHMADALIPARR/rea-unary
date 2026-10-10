/*
 * enc_registry.c -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
/* provenance: producer=stage1/coordinator parents=[enc_registry.h] version=v1 full-sha256-in=PROVENANCE.json */
/*
 * enc_registry.c — ALP evidence-routing: encoding registry implementation.
 * rea-unary stage1/router. Fresh authorship, C11.
 */
#include "enc_registry.h"

#include <stdlib.h>
#include <string.h>

/* reverse-text-v1: the payload is plain text written backwards. */
static char *reverse_text_v1_decode(const char *in) {
    size_t n = strlen(in);
    char *out = malloc(n + 1);
    size_t i;

    if (!out)
        return NULL;
    for (i = 0; i < n; i++)
        out[i] = in[n - 1 - i];
    out[n] = '\0';
    return out;
}

/*
 * Registry table. To add a new encoding, implement a decode function
 * above and append a row here — no other code changes needed.
 */
static const Encoding registry[] = {
    { "reverse-text-v1", reverse_text_v1_decode },
};

const Encoding *enc_find(const char *name) {
    size_t i;

    for (i = 0; i < sizeof registry / sizeof registry[0]; i++) {
        if (strcmp(registry[i].name, name) == 0)
            return &registry[i];
    }
    return NULL;
}

size_t enc_count(void) {
    return sizeof registry / sizeof registry[0];
}
