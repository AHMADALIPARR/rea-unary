// page.tsx -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Provenance: stage3/web/backend (worker3), v1. Parents: none.
export default function Page() {
  return (
    <main style={{ fontFamily: 'monospace', padding: 24 }}>
      <h1>rea-unary / stage3 — pipeline status</h1>
      <p>
        API routes: <code>/api/ledger</code>, <code>/api/verification</code>,{' '}
        <code>/api/counterexamples</code>, <code>POST /api/loop/trigger</code>
      </p>
      <p>
        The React demo frontend lives in <code>stage3/web/frontend</code> and
        consumes these routes.
      </p>
    </main>
  );
}
