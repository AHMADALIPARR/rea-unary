// route.ts -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Provenance: stage3/web/backend (worker3), v1. Parents: stage3/sql-results.txt,
// stage3/differential-log.txt, stage3/ghdl-sim.log (data).
// GET /api/verification -> verification status (trace-conformance results).
import { NextResponse } from 'next/server';
import { readFile } from 'fs/promises';
import path from 'path';

async function tail(p: string, n: number): Promise<string> {
  const text = await readFile(p, 'utf8');
  return text.split('\n').slice(-n).join('\n');
}

export async function GET() {
  const data = path.join(process.cwd(), 'data');
  const sql = await readFile(path.join(data, 'sql-results.txt'), 'utf8');
  const differential = await tail(path.join(data, 'differential-log.txt'), 6);
  const ghdl = await tail(path.join(data, 'ghdl-sim.log'), 8);
  return NextResponse.json({
    wording:
      'the recorded traces satisfy the checks (trace conformance; not a proof over all executions)',
    sql,
    differential,
    ghdl,
  });
}

export const dynamic = 'force-dynamic';
