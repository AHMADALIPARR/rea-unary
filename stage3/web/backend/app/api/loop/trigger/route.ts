// route.ts -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Provenance: stage3/web/backend (worker3), v1. Parents: stage3/diff-oracle (binary).
// POST /api/loop/trigger -> re-runs the stage3 differential oracle binary
// (real x86 silicon vs C model vs GHDL sim) and returns its summary.
import { NextResponse } from 'next/server';
import { execFile } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const run = promisify(execFile);

export async function POST() {
  const stage3 = path.join(process.cwd(), '..', '..');
  const oracle = path.join(stage3, 'diff-oracle');
  try {
    const { stdout } = await run(oracle, [], { cwd: stage3, timeout: 60000 });
    const lines = stdout.trim().split('\n');
    const summary = lines.filter((l) => l.includes('differential summary'));
    return NextResponse.json({ ok: true, summary, tail: lines.slice(-8) });
  } catch (e: unknown) {
    const err = e as { stdout?: string; message?: string };
    return NextResponse.json(
      { ok: false, error: err.message ?? 'oracle failed', stdout: err.stdout ?? '' },
      { status: 500 },
    );
  }
}

export const dynamic = 'force-dynamic';
