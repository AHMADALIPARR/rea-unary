// main.tsx -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// Provenance: stage3/web/frontend (worker3), v1. Parents:
// stage3/web/backend API routes (consumed). NOT EXECUTED beyond build:
// the UI was built (tsc + vite build) but not served in this environment.
import React, { useEffect, useState } from 'react';
import ReactDOM from 'react-dom/client';

type LedgerRecord = { type?: string; id?: string; [k: string]: unknown };

const API = '/api';

async function getJSON<T>(p: string): Promise<T> {
  const r = await fetch(`${API}${p}`);
  if (!r.ok) throw new Error(`${p}: ${r.status}`);
  return (await r.json()) as T;
}

function Section(props: { title: string; children: React.ReactNode }) {
  return (
    <section style={{ border: '1px solid #2a3350', borderRadius: 8, padding: 12, marginBottom: 12 }}>
      <h2 style={{ marginTop: 0 }}>{props.title}</h2>
      {props.children}
    </section>
  );
}

function App() {
  const [ledger, setLedger] = useState<LedgerRecord[]>([]);
  const [verification, setVerification] = useState<string>('');
  const [counterexamples, setCounterexamples] = useState<LedgerRecord[]>([]);
  const [loopMsg, setLoopMsg] = useState<string>('');
  const [error, setError] = useState<string>('');

  useEffect(() => {
    (async () => {
      try {
        const l = await getJSON<{ records: LedgerRecord[] }>('/ledger');
        setLedger(l.records);
        const v = await getJSON<{ sql: string }>('/verification');
        setVerification(v.sql);
        const c = await getJSON<{ records: LedgerRecord[] }>('/counterexamples');
        setCounterexamples(c.records);
      } catch (e) {
        setError(`backend not reachable (is it running on :3000?): ${(e as Error).message}`);
      }
    })();
  }, []);

  const counts: Record<string, number> = {};
  for (const r of ledger) {
    const t = String(r.type ?? '?');
    counts[t] = (counts[t] ?? 0) + 1;
  }

  async function triggerLoop() {
    setLoopMsg('triggering…');
    try {
      const r = await fetch(`${API}/loop/trigger`, { method: 'POST' });
      const j = (await r.json()) as { ok: boolean; summary?: string[]; error?: string };
      setLoopMsg(j.ok ? `loop re-ran: ${(j.summary ?? []).join(' ')}` : `failed: ${j.error}`);
    } catch (e) {
      setLoopMsg(`failed: ${(e as Error).message}`);
    }
  }

  return (
    <main style={{ fontFamily: 'monospace', padding: 24, background: '#0b0e14', color: '#d7dce2', minHeight: '100vh' }}>
      <h1>rea-unary · stage3 demo</h1>
      {error && <p style={{ color: '#ff8a8a' }}>{error}</p>}

      <Section title="Pipeline stages">
        <ol>
          <li>binary analysis → sample.bin (01 D8 = ADD EAX, EBX)</li>
          <li>recovery → behavior spec + canonical IR</li>
          <li>GHDL simulation → traces.csv (real run)</li>
          <li>differential vs x86 silicon → 140/140</li>
          <li>SQL trace-conformance → recorded traces satisfy the checks</li>
          <li>firmware chain → firmware.bin on mock flash (SHA-256 verified)</li>
        </ol>
        <button onClick={triggerLoop}>Run the loop (re-run differential oracle)</button>
        {loopMsg && <p>{loopMsg}</p>}
      </Section>

      <Section title="Evidence ledger">
        <p>records by type: {JSON.stringify(counts)}</p>
        <ul>
          {ledger.slice(-8).map((r, i) => (
            <li key={i}>
              <code>{String(r.type)}</code> {String(r.id ?? '')}
            </li>
          ))}
        </ul>
      </Section>

      <Section title="Hypotheses / counterexamples">
        {counterexamples.length === 0 ? (
          <p>no counterexample records</p>
        ) : (
          <ul>
            {counterexamples.map((c, i) => (
              <li key={i}>
                <code>{String(c.id)}</code> refutes <code>{String(c.refutes ?? '?')}</code>
              </li>
            ))}
          </ul>
        )}
      </Section>

      <Section title="Verification results">
        <pre style={{ whiteSpace: 'pre-wrap' }}>{verification || 'loading…'}</pre>
      </Section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
);
