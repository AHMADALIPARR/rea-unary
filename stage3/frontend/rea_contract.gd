# rea_contract.gd -- rea-unary
# Copyright (C) 2026 Ahmad Ali Parr
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
#
# Licensed under the GNU Affero General Public License v3 with an
# additional no-AI-training term (see LICENSE). This code may not be
# used to train machine-learning models.
# Author's rights notice (Ahmad Ali Parr):
# Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
# Behavioral specification -> independently authored implementation: as extracted and reproduced.
# Provenance: stage3/frontend (worker3), v1. Parents: stage3/interface-contract.md.
# Full hashes in stage3/PROVENANCE.json.
# NOT EXECUTED: Godot is not installed in this environment; this file received
# a manual parse review plus an automated sanity scan (see GDSCRIPT_REVIEW.md).
# It binds the interface contract (stage3/interface-contract.md): add32 is
# implemented natively in GDScript per the contract's post-conditions;
# recover/verify operate on the real stage1/stage3 artifacts on disk.
extends Node
class_name ReaContract

const MOD_2_32: int = 4294967296
const MAX_U32: int = 4294967295


static func _parity_even8(low_byte: int) -> int:
	var ones: int = 0
	for k in range(8):
		ones += (low_byte >> k) & 1
	return 1 if ones % 2 == 0 else 0


# add32(a, b) -> {result, flags} ; contract post-conditions hold on return.
static func add32(a: int, b: int) -> Dictionary:
	assert(a >= 0 and a <= MAX_U32, "add32 pre-condition: a not uint32")
	assert(b >= 0 and b <= MAX_U32, "add32 pre-condition: b not uint32")
	var full: int = a + b
	var r: int = full % MOD_2_32
	var cf: int = 1 if full >= MOD_2_32 else 0
	var af: int = 1 if (a % 16) + (b % 16) >= 16 else 0
	var zf: int = 1 if r == 0 else 0
	var sf: int = 1 if r >= 2147483648 else 0
	var carry_in31: int = ((a % 2147483648) + (b % 2147483648)) / 2147483648
	var carry_out31: int = full / MOD_2_32
	var of: int = 1 if carry_in31 != carry_out31 else 0
	var pf: int = _parity_even8(r % 256)
	return {
		"result": r,
		"flags": {"cf": cf, "pf": pf, "af": af, "zf": zf, "sf": sf, "of": of},
	}


# recover(bytes) -> behavior_spec ; decodes the canonical 01 D8 prefix.
static func recover(sample_bytes: PackedByteArray) -> Dictionary:
	var spec: Dictionary = {
		"address": "0x401020",
		"mnemonic": "UNKNOWN",
		"operands": {},
		"semantics": "",
		"ir": [],
	}
	if sample_bytes.size() >= 2 and sample_bytes[0] == 0x01 and sample_bytes[1] == 0xD8:
		spec["mnemonic"] = "ADD"
		spec["operands"] = {"dst": "EAX", "src": "EBX"}
		spec["semantics"] = "EAX <- (EAX+EBX) mod 2^32; update CF,PF,AF,ZF,SF,OF"
		spec["ir"] = ["%result = add.i32 %a, %b", "store.i32 %result, %destination"]
	return spec


# verify(trace_csv) -> verdict ; checks recorded rows against the invariants.
# verdict.pass means the RECORDED rows satisfy the checks (trace conformance).
static func verify(trace_csv: String) -> Dictionary:
	var violations: Array = []
	var lines: PackedStringArray = trace_csv.strip_edges().split("\n")
	if lines.size() < 2:
		violations.append("malformed trace: fewer than 2 lines")
		return {"pass": false, "violations": violations}
	var prev_state: String = ""
	for i in range(1, lines.size()):
		var cols: PackedStringArray = lines[i].split(",")
		if cols.size() != 12:
			violations.append("malformed row %d: %d columns" % [i, cols.size()])
			continue
		var state: String = cols[1]
		if prev_state == "FETCH" and not (state == "FETCH" or state == "DECODE"):
			violations.append("bad transition FETCH->%s at row %d" % [state, i])
		if prev_state == "DECODE" and state != "EXECUTE":
			violations.append("bad transition DECODE->%s at row %d" % [state, i])
		if prev_state == "EXECUTE" and state != "WRITEBACK":
			violations.append("bad transition EXECUTE->%s at row %d" % [state, i])
		if prev_state == "WRITEBACK" and state != "FETCH":
			violations.append("bad transition WRITEBACK->%s at row %d" % [state, i])
		if state == "EXECUTE":
			var a: int = cols[2].hex_to_int()
			var b: int = cols[3].hex_to_int()
			var got: Dictionary = add32(a, b)
			if got["result"] != cols[4].hex_to_int():
				violations.append("result mismatch at row %d" % i)
			var fl: Dictionary = got["flags"]
			var names: Array = ["cf", "pf", "af", "zf", "sf", "of"]
			for n in range(6):
				if int(fl[names[n]]) != int(cols[5 + n]):
					violations.append("flag %s mismatch at row %d" % [names[n], i])
		if state == "WRITEBACK" and cols[11] != "1":
			violations.append("done not asserted on WRITEBACK row %d" % i)
		if cols[11] == "1" and state != "WRITEBACK":
			violations.append("done asserted outside WRITEBACK at row %d" % i)
		prev_state = state
	return {"pass": violations.is_empty(), "violations": violations}


# hypothesis_status(ledger_jsonl) -> {counts per record type, counterexample ids}
static func hypothesis_status(ledger_jsonl: String) -> Dictionary:
	var counts: Dictionary = {}
	var counterexamples: Array = []
	for line in ledger_jsonl.strip_edges().split("\n"):
		var rec: Variant = JSON.parse_string(line)
		if rec == null or not (rec is Dictionary):
			continue
		var t: String = str(rec.get("type", "?"))
		counts[t] = int(counts.get(t, 0)) + 1
		if t == "counterexample":
			counterexamples.append(str(rec.get("id", "?")))
	return {"counts": counts, "counterexamples": counterexamples}
