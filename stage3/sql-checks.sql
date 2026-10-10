-- sql-checks.sql -- rea-unary
-- Copyright (C) 2026 Ahmad Ali Parr
-- SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
--
-- Licensed under the GNU Affero General Public License v3 with an
-- additional no-AI-training term (see LICENSE). This code may not be
-- used to train machine-learning models.
-- Provenance: stage3 (worker3), v1. Parents: stage3/traces.csv (GHDL sim output).
-- Full hashes in stage3/PROVENANCE.json.
--
-- Trace-conformance checks over the RECORDED GHDL simulation trace.
-- WORDING RULE (enforced): these checks test RECORDED states/transitions only.
-- Passing means the recorded traces satisfy the checks, NOT that every
-- possible execution does. This is trace conformance (testing), not proof.
.headers on
.mode list

DROP TABLE IF EXISTS trace;
CREATE TABLE trace(
  cycle  INTEGER,
  state  TEXT,
  a_in   TEXT, b_in TEXT, result TEXT,
  cf INTEGER, pf INTEGER, af INTEGER, zf INTEGER, sf INTEGER, of INTEGER,
  done INTEGER
);

-- expected values below are cross-verified: GHDL sim == C11 model == real x86
-- silicon (stage3/differential-log.txt: 140/140 register comparisons match).
DROP TABLE IF EXISTS expected;
CREATE TABLE expected(
  a_hex TEXT, b_hex TEXT, r_hex TEXT,
  a_int INTEGER, b_int INTEGER,
  cf INTEGER, pf INTEGER, af INTEGER, zf INTEGER, sf INTEGER, of INTEGER
);
INSERT INTO expected VALUES
 ('00000000','00000000','00000000',          0,          0, 0,1,0,1,0,0),
 ('FFFFFFFF','00000001','00000000', 4294967295,          1, 1,1,1,1,0,0),
 ('7FFFFFFF','00000001','80000000', 2147483647,          1, 0,1,1,0,1,1),
 ('00000008','00000008','00000010',          8,          8, 0,0,1,0,0,0),
 ('00000003','00000000','00000003',          3,          0, 0,1,0,0,0,0),
 ('00000001','00000000','00000001',          1,          0, 0,0,0,0,0,0),
 ('80000000','80000000','00000000', 2147483648, 2147483648, 1,1,0,1,0,1),
 ('7FFFFFFF','7FFFFFFF','FFFFFFFE', 2147483647, 2147483647, 0,0,1,0,1,1),
 ('80000000','FFFFFFFF','7FFFFFFF', 2147483648, 4294967295, 1,1,0,0,0,1),
 ('FFFFFFFF','FFFFFFFF','FFFFFFFE', 4294967295, 4294967295, 1,0,1,0,1,0);

-- nibble parity table: p = 1 when the nibble has an odd number of 1-bits
DROP TABLE IF EXISTS nibble;
CREATE TABLE nibble(n INTEGER PRIMARY KEY, p INTEGER);
INSERT INTO nibble VALUES (0,0),(1,1),(2,1),(3,0),(4,1),(5,0),(6,0),(7,1),
                         (8,1),(9,0),(10,0),(11,1),(12,0),(13,1),(14,1),(15,0);

.print '=== importing traces.csv ==='
.import --csv --skip 1 /home/hatch/workspace/rea-unary/stage3/traces.csv trace

.print '=== check-a: EXECUTE rows match silicon-verified result+flags ==='
SELECT 'check-a' AS chk,
  (SELECT COUNT(*) FROM trace t JOIN expected e
     ON t.a_in = e.a_hex AND t.b_in = e.b_hex
   WHERE t.state = 'EXECUTE'
     AND (t.result != e.r_hex OR t.cf != e.cf OR t.pf != e.pf
          OR t.af != e.af OR t.zf != e.zf OR t.sf != e.sf OR t.of != e.of)
  ) AS violations,
  (SELECT COUNT(*) FROM trace WHERE state = 'EXECUTE') AS exec_rows;

.print '=== check-b: flags recomputed in SQL from operand ints ==='
SELECT 'check-b' AS chk, COUNT(*) AS violations FROM trace t
JOIN expected e ON t.a_in = e.a_hex AND t.b_in = e.b_hex
WHERE t.state IN ('EXECUTE','WRITEBACK') AND (
  /* r = (a+b) mod 2^32; cf/zf/sf/af/of/pf recomputed per Intel ADD semantics */
  (CASE WHEN e.a_int + e.b_int >= 4294967296 THEN 1 ELSE 0 END) != t.cf
  OR (CASE WHEN (e.a_int + e.b_int) % 4294967296 = 0 THEN 1 ELSE 0 END) != t.zf
  OR (CASE WHEN (e.a_int + e.b_int) % 4294967296 >= 2147483648 THEN 1 ELSE 0 END) != t.sf
  OR (CASE WHEN (e.a_int % 16) + (e.b_int % 16) > 15 THEN 1 ELSE 0 END) != t.af
  OR (((((e.a_int % 2147483648) + (e.b_int % 2147483648)) / 2147483648)
        + ((e.a_int + e.b_int) / 4294967296)) % 2) != t.of
  OR (CASE WHEN (SELECT p FROM nibble WHERE n = ((e.a_int + e.b_int) % 4294967296) % 16)
                = (SELECT p FROM nibble WHERE n = (((e.a_int + e.b_int) % 4294967296) / 16) % 16)
           THEN 1 ELSE 0 END) != t.pf
);

.print '=== check-c: state sequence follows FETCH->DECODE->EXECUTE->WRITEBACK ==='
SELECT 'check-c' AS chk, COUNT(*) AS violations FROM (
  SELECT state, LEAD(state) OVER (ORDER BY cycle) AS nxt FROM trace
) WHERE (state = 'FETCH'     AND nxt NOT IN ('FETCH','DECODE'))
     OR (state = 'DECODE'    AND nxt != 'EXECUTE')
     OR (state = 'EXECUTE'   AND nxt != 'WRITEBACK')
     OR (state = 'WRITEBACK' AND nxt != 'FETCH');

.print '=== check-d: privileged-state entry without authorization (vacuous) ==='
SELECT 'check-d' AS chk,
  COUNT(*) AS privileged_state_rows,
  'VACUOUSLY PASSING -- no privileged/supervisor states exist in the FETCH/DECODE/EXECUTE/WRITEBACK machine' AS note
FROM trace WHERE state IN ('SUPERVISOR','PRIVILEGED','KERNEL','MACHINE');

.print '=== check-e: done asserted exactly on WRITEBACK rows ==='
SELECT 'check-e' AS chk,
  (SELECT COUNT(*) FROM trace WHERE done = 1 AND state != 'WRITEBACK') AS done_outside_writeback,
  (SELECT COUNT(*) FROM trace WHERE state = 'WRITEBACK' AND done != 1) AS writeback_without_done,
  (SELECT COUNT(*) FROM trace WHERE state = 'WRITEBACK') AS writeback_rows;

.print '=== trace shape ==='
SELECT 'shape' AS chk, COUNT(*) AS total_rows,
  (SELECT COUNT(DISTINCT a_in || b_in) FROM trace) AS distinct_vectors FROM trace;
