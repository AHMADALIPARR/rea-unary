# demo_scene.gd -- rea-unary
# Copyright (C) 2026 Ahmad Ali Parr
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
#
# Licensed under the GNU Affero General Public License v3 with an
# additional no-AI-training term (see LICENSE). This code may not be
# used to train machine-learning models.
# Author's rights notice (Ahmad Ali Parr):
# Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
# Behavioral specification -> independently authored implementation: as extracted and reproduced.
# Provenance: stage3/frontend (worker3), v1. Parents: stage3/frontend/rea_contract.gd.
# Full hashes in stage3/PROVENANCE.json.
# NOT EXECUTED: Godot is not installed in this environment; this file received
# a manual parse review plus an automated sanity scan (see GDSCRIPT_REVIEW.md).
# Minimal demo scene script: builds the UI in code, feeds the canonical
# sample.bin bytes through the contract, and displays results + hypothesis status.
extends Control

var _contract: ReaContract
var _out: RichTextLabel


func _ready() -> void:
	_contract = ReaContract.new()
	add_child(_contract)

	var title := Label.new()
	title.text = "rea-unary — ADD core demo (stage3)"
	title.position = Vector2(16, 12)
	add_child(title)

	var run_btn := Button.new()
	run_btn.text = "Run contract demo"
	run_btn.position = Vector2(16, 44)
	run_btn.pressed.connect(_on_run_pressed)
	add_child(run_btn)

	_out = RichTextLabel.new()
	_out.position = Vector2(16, 84)
	_out.size = Vector2(760, 500)
	_out.bbcode_enabled = true
	add_child(_out)

	_out.text = "[i]Press the button to run the interface-contract demo.[/i]"


func _on_run_pressed() -> void:
	var lines: Array = []
	# 1. feed the canonical input bytes (stage1 sample.bin, first two bytes)
	var bytes: PackedByteArray = _load_sample_head()
	lines.append("[b]input bytes:[/b] %s" % _hex(bytes))
	# 2. recover -> behavior spec
	var spec: Dictionary = ReaContract.recover(bytes)
	lines.append("[b]recover:[/b] %s %s -> %s" % [
		spec.get("mnemonic", "?"),
		str(spec.get("operands", {}).get("dst", "?")),
		str(spec.get("semantics", "")),
	])
	# 3. add32 on the counterexample vector (0x7FFFFFFF + 1)
	var r: Dictionary = ReaContract.add32(0x7FFFFFFF, 1)
	var fl: Dictionary = r["flags"]
	lines.append("[b]add32(0x7FFFFFFF, 1):[/b] result=0x%X cf=%d of=%d" % [
		int(r["result"]), int(fl["cf"]), int(fl["of"])])
	# 4. verify the recorded trace
	var verdict: Dictionary = ReaContract.verify(_load_traces_csv())
	lines.append("[b]verify(trace):[/b] pass=%s violations=%d" % [
		str(verdict["pass"]), (verdict["violations"] as Array).size()])
	# 5. hypothesis / counterexample status from the ledger
	var status: Dictionary = ReaContract.hypothesis_status(_load_ledger())
	lines.append("[b]ledger:[/b] %s" % str(status["counts"]))
	lines.append("[b]counterexamples:[/b] %s" % str(status["counterexamples"]))
	_out.text = "\n".join(lines)


func _hex(b: PackedByteArray) -> String:
	var parts: PackedStringArray = []
	for x in b:
		parts.append("%02X" % x)
	return " ".join(parts)


# In a real deployment these read the stage artifacts; here the paths are
# relative to the project root the scene is opened from.
func _load_sample_head() -> PackedByteArray:
	var f := FileAccess.open("../stage1/sample.bin", FileAccess.READ)
	if f == null:
		return PackedByteArray([0x01, 0xD8])
	var head: PackedByteArray = f.get_buffer(2)
	f.close()
	return head


func _load_traces_csv() -> String:
	var f := FileAccess.open("traces.csv", FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t


func _load_ledger() -> String:
	var f := FileAccess.open("evidence-ledger.jsonl", FileAccess.READ)
	if f == null:
		return ""
	var t: String = f.get_as_text()
	f.close()
	return t
