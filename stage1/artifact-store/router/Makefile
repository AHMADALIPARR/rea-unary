# Makefile -- rea-unary
# Copyright (C) 2026 Ahmad Ali Parr
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
#
# Licensed under the GNU Affero General Public License v3 with an
# additional no-AI-training term (see LICENSE). This code may not be
# used to train machine-learning models.
# provenance: producer=stage1/coordinator parents=[router.c enc_registry.c] version=v1 full-sha256-in=PROVENANCE.json
# stage1/router — ALP evidence routing: validate -> decode -> select route -> render.
CC = gcc
CFLAGS = -std=c11 -Wall -Wextra -O2

all: router

router: router.c enc_registry.c enc_registry.h
	$(CC) $(CFLAGS) -o $@ router.c enc_registry.c

# End-to-end demo on the canonical e1 record.
run: router
	ROUTER_DIR=. ./router ../alp-evidence.jsonl

# Executed test: decode must yield "unsigned addition", route must resolve.
test: router
	ROUTER_DIR=. ./router ../alp-evidence.jsonl > test-out.txt
	@grep -q 'decode.*unsigned addition' test-out.txt && echo "PASS: decode"
	@grep -q 'route.*binary/arithmetic.*arithmetic-analysis.mustache' test-out.txt && echo "PASS: route"
	@grep -q 'Analyze this candidate operation: unsigned addition' test-out.txt && echo "PASS: render"

clean:
	rm -f router test-out.txt

.PHONY: all run test clean
