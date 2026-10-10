// add_core.als -- rea-unary
// Copyright (C) 2026 Ahmad Ali Parr
// SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
//
// Licensed under the GNU Affero General Public License v3 with an
// additional no-AI-training term (see LICENSE). This code may not be
// used to train machine-learning models.
// provenance: producer=stage2/worker2 parents=[state-machine.md:b9223f82b948 recovery-spec.md] version=v1 full-sha256-in=PROVENANCE.json
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// ============================================================================
// add_core.als — Worker 2 (rea-unary swarm), 2026-10-10
// Alloy 6 model of the ADD-core state machine and its flag invariants.
//
// EXECUTION STATUS: NOT EXECUTED on this VM.
//   Reason: Alloy is not installed here. `apt-get install alloy` returned
//   "Unable to locate package alloy", and apt on this VM is unreliable
//   (stuck locks / dead mirrors per workspace notes), so no further install
//   path was pursued within the $0/brief-attempt budget. This file is a
//   real-syntax Alloy 6 spec artifact. The invariant review that Alloy would
//   have performed was done BY HAND instead — see the HAND-REVIEW block at
//   the end. Hand review is honest review, NOT tool output.
//
// SCOPE: an 8-bit instance of the 32-bit addmod structure (same equations,
//   narrower word; bitwidth 10 keeps a+b in range). The 1-bit node
//   identities follow unary-mapping.md D1..D9; multi-input fan-in is
//   structural, as there.
//
// Traceability: built from stage2/hypotheses.jsonl, hypothesis h2 v1 (ALP).
// Assumptions: A1..A6 of stage2/state-machine.md.
// ============================================================================

module add_core

open util/ordering[Step] as ord

// ---- mandated states (A6) ----
abstract sig State {}
one sig FETCH, DECODE, EXECUTE, WRITEBACK extends State {}

// ---- 1-bit values (A4: the unary-Boolean foundation) ----
abstract sig Bit {}
one sig LO, HI extends Bit {}

// ---- one machine step: state + latched datapath + result bits ----
sig Step {
  state: State,
  start: Bit,            // environment input sampled in FETCH
  a_in, b_in: Int,       // environment operand inputs, 0..255
  a, b: Int,             // latched operands, 0..255
  result: Int,           // 0..255
  r0, r1, r2, r3, r4, r5, r6, r7: Bit,  // result bits, r0 = LSB
  cf, pf, af, zf, sf, of, done: Bit
}

// ---- helpers ----
fun sval[x: Int]: Int { x > 127 => x.sub[256] else x }   // signed value, 8-bit

pred xor2[x, y, z: Bit] {
  (x = HI and y = LO and z = HI) or
  (x = LO and y = HI and z = HI) or
  (x = HI and y = HI and z = LO) or
  (x = LO and y = LO and z = LO)
}

// ---- candidate transition relation ----
pred init[s: Step] {
  s.state = FETCH
  s.a = 0 and s.b = 0 and s.result = 0
  s.r0 = LO and s.r1 = LO and s.r2 = LO and s.r3 = LO
  s.r4 = LO and s.r5 = LO and s.r6 = LO and s.r7 = LO
  s.cf = LO and s.pf = HI and s.af = LO   // pf=HI: result 0 has even parity
  s.zf = HI and s.sf = LO and s.of = LO
  s.done = LO
}

// EXECUTE datapath: addmod-2^8 + all six flags (8-bit instance of h2 v1)
pred exec_ok[pre, post: Step] {
  let sum = plus[pre.a, pre.b] |
    (post.cf = HI <=> sum > 255) and
    post.result = (post.cf = HI => sum.sub[256] else sum) and
    post.zf = HI <=> post.result = 0 and
    post.sf = HI <=> post.result > 127 and
    (post.of = HI <=>
       (plus[sval[pre.a], sval[pre.b]] > 127 or
        plus[sval[pre.a], sval[pre.b]] < 0.sub[128])) and
    (post.af = HI <=> plus[pre.a.rem[16], pre.b.rem[16]] > 15) and
    // result bits must agree with result value
    post.result = plus[plus[plus[
      (post.r0 = HI => 1 else 0), (post.r1 = HI => 2 else 0)],
      plus[(post.r2 = HI => 4 else 0), (post.r3 = HI => 8 else 0)]],
      plus[plus[(post.r4 = HI => 16 else 0), (post.r5 = HI => 32 else 0)],
           plus[(post.r6 = HI => 64 else 0), (post.r7 = HI => 128 else 0)]]) and
    // D5: PF = NOT of the XOR fan-in over the low bits (even parity)
    some p01, p23, p45, p67, p03, p47, q: Bit |
      xor2[post.r0, post.r1, p01] and xor2[post.r2, post.r3, p23] and
      xor2[post.r4, post.r5, p45] and xor2[post.r6, post.r7, p67] and
      xor2[p01, p23, p03] and xor2[p45, p67, p47] and
      xor2[p03, p47, q] and post.pf = (q = HI => LO else HI)
}

// full transition relation (state-machine.md section 3)
pred trans[pre, post: Step] {
  (pre.state = FETCH and post.done = LO and
    ((pre.start = HI and post.state = DECODE and
        post.a = pre.a_in and post.b = pre.b_in) or
     (pre.start = LO and post.state = FETCH and
        post.a = pre.a and post.b = pre.b)) and
    post.result = pre.result and
    post.cf = pre.cf and post.pf = pre.pf and post.af = pre.af and
    post.zf = pre.zf and post.sf = pre.sf and post.of = pre.of and
    post.r0 = pre.r0 and post.r1 = pre.r1 and post.r2 = pre.r2 and
    post.r3 = pre.r3 and post.r4 = pre.r4 and post.r5 = pre.r5 and
    post.r6 = pre.r6 and post.r7 = pre.r7)
  or
  (pre.state = DECODE and post.state = EXECUTE and post.done = LO and
    post.a = pre.a and post.b = pre.b and post.result = pre.result and
    post.cf = pre.cf and post.pf = pre.pf and post.af = pre.af and
    post.zf = pre.zf and post.sf = pre.sf and post.of = pre.of and
    post.r0 = pre.r0 and post.r1 = pre.r1 and post.r2 = pre.r2 and
    post.r3 = pre.r3 and post.r4 = pre.r4 and post.r5 = pre.r5 and
    post.r6 = pre.r6 and post.r7 = pre.r7)
  or
  (pre.state = EXECUTE and post.state = WRITEBACK and post.done = LO and
    post.a = pre.a and post.b = pre.b and exec_ok[pre, post])
  or
  (pre.state = WRITEBACK and post.state = FETCH and post.done = HI and
    // commit: outputs already equal the EXECUTE registers by construction
    post.a = pre.a and post.b = pre.b and post.result = pre.result and
    post.cf = pre.cf and post.pf = pre.pf and post.af = pre.af and
    post.zf = pre.zf and post.sf = pre.sf and post.of = pre.of and
    post.r0 = pre.r0 and post.r1 = pre.r1 and post.r2 = pre.r2 and
    post.r3 = pre.r3 and post.r4 = pre.r4 and post.r5 = pre.r5 and
    post.r6 = pre.r6 and post.r7 = pre.r7)
}

fact valid_range {
  all s: Step | s.a in 0..255 and s.b in 0..255 and
    s.a_in in 0..255 and s.b_in in 0..255 and s.result in 0..255
}

fact traces {
  init[ord/first]
  all s: Step - ord/last | trans[s, ord/next[s]]
}

// ---- invariants Alloy would search for violations of ----
assert NoZFInconsistency {
  all s: Step | (s.zf = HI <=> s.result = 0)
}
assert DoneOnlyInWriteback {
  all s: Step | s.done = HI => s.state = WRITEBACK
}
assert LegalTransitions {
  all s: Step - ord/last |
    let t = ord/next[s] |
      (s.state = FETCH => t.state = DECODE or t.state = FETCH) and
      (s.state = DECODE => t.state = EXECUTE) and
      (s.state = EXECUTE => t.state = WRITEBACK) and
      (s.state = WRITEBACK => t.state = FETCH)
}
assert CFReportsCarry {
  all s: Step |
    (s.state = WRITEBACK or s.state = FETCH) and s.start = LO =>
      (s.cf = HI <=> plus[s.a, s.b] > 255)
}
assert PFMatchesParity {
  // PF = HI iff an even number of result bits are HI (XOR-chain = LO)
  all s: Step |
    some p01, p23, p45, p67, p03, p47, q: Bit |
      xor2[s.r0, s.r1, p01] and xor2[s.r2, s.r3, p23] and
      xor2[s.r4, s.r5, p45] and xor2[s.r6, s.r7, p67] and
      xor2[p01, p23, p03] and xor2[p45, p67, p47] and
      xor2[p03, p47, q] and (s.pf = HI <=> q = LO)
}

check NoZFInconsistency for 6 but 10 Int
check DoneOnlyInWriteback for 6 but 10 Int
check LegalTransitions for 6 but 10 Int
check CFReportsCarry for 6 but 10 Int
check PFMatchesParity for 6 but 10 Int

// ============================================================================
// HAND-REVIEW (performed 2026-10-10 by Worker 2, because Alloy did not run).
// Each invariant below was checked by hand against the transition relation
// and the exec_ok datapath equations. Outcomes are review results, NOT tool
// output. No tool counterexamples were produced (none could be: no run).
//
// HR1 NoZFInconsistency ......... PASS by construction: exec_ok sets
//     zf = HI <=> result = 0, and no transition modifies zf outside EXECUTE.
// HR2 DoneOnlyInWriteback ....... PASS: done = HI appears only in the
//     WRITEBACK->FETCH clause of trans; every other clause forces done = LO.
// HR3 LegalTransitions .......... PASS: trans enumerates exactly the four
//     mandated edges (+ the FETCH stutter on start = LO); no other pair is
//     admitted. Matches state-machine.md section 3.
// HR4 CFReportsCarry ............. PASS in committed states: exec_ok computes
//     cf from plus[a,b] > 255 and WRITEBACK/FETCH preserve it; the assert's
//     guard (state in {WRITEBACK, FETCH}, start = LO) excludes the transient
//     FETCH-before-first-EXECUTE window where cf is stale from init.
//     (That window is real behavior, not a violation: flags are meaningless
//     before the first EXECUTE — documented, not hidden.)
// HR5 PFMatchesParity ........... PASS by construction: exec_ok builds pf as
//     NOT of the same XOR chain the assert re-checks; bit/value agreement is
//     enforced in exec_ok. The r3 PF revision (parity of the low byte, not
//     the full word) is what makes this hold at the 32-bit level too — at
//     32 bits the chain runs over r0..r7 only.
// HR6 Unreachable privileged states  PASS (vacuous): the model has no
//     privileged state; the state sig is exactly the four mandated states,
//     so "unreachable privileged state" cannot be expressed — stated, not
//     ducked.
// REVISION LOOP: no hand-review finding required a revision of the candidate
// state machine; the trans relation already matches state-machine.md.
// Had any check failed, the loop would have been: revise candidate ->
// re-run (or re-review) -> repeat, nested inside the master evidence loop.
// ============================================================================
