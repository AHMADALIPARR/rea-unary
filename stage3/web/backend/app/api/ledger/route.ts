// route.ts -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Provenance: stage3/web/backend (worker3), v1. Parents: stage3/evidence-ledger.jsonl (data).
// GET /api/ledger -> the evidence ledger as JSON.
import { NextResponse } from 'next/server';
import { readFile } from 'fs/promises';
import path from 'path';

export async function GET() {
  const p = path.join(process.cwd(), 'data', 'evidence-ledger.jsonl');
  const text = await readFile(p, 'utf8');
  const records = text
    .split('\n')
    .map((l) => l.trim())
    .filter((l) => l.length > 0)
    .map((l) => JSON.parse(l));
  return NextResponse.json({ records });
}

export const dynamic = 'force-dynamic';
