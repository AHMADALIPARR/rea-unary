<!-- Provenance: stage3/frontend (worker3), v1. Parents:
     stage3/frontend/rea_contract.gd, stage3/frontend/demo_scene.gd,
     stage3/frontend/demo_scene.tscn. Full hashes in stage3/PROVENANCE.json. -->
# GDScript review record — `stage3/frontend/`

## Status: NOT EXECUTED

Godot is **not installed** in this environment and cannot run headless here,
so none of the GDScript was executed. The files are code artifacts, honestly
labeled. What follows is exactly the checking that *was* done.

## 1. Manual parse review (line-by-line, against GDScript/Godot 4 grammar)

Reviewed `rea_contract.gd` (5 static funcs) and `demo_scene.gd` (6 funcs):

- `extends` / `class_name` headers well-formed; no cyclic class references.
- All `func` declarations have `-> ReturnType` annotations; `static func`
  used for the contract functions (called without an instance).
- Ternary form `a if cond else b` used consistently (GDScript order).
- `assert(cond, msg)` calls have constant string messages.
- Dictionary literals use `"key": value`; array literals `[...]`; typed
  locals (`var x: int`) match assigned expressions.
- `for k in range(8)` / `for i in range(1, lines.size())` — valid iteration.
- `FileAccess.open(path, FileAccess.READ)` null-checked before use.
- `JSON.parse_string` result null-checked and `is Dictionary`-checked.
- Signal connect: `run_btn.pressed.connect(_on_run_pressed)` — Godot 4 form.
- String formatting uses `"..." % [...]` with matching placeholder counts
  (checked per call).
- `"0x%X" % x` / `"%02X" % x` — valid format specifiers.
- One judgment call: `cols[n].hex_to_int()` is applied to bare-hex CSV
  fields (no `0x` prefix added) — the form that parses under Godot 4.
- `demo_scene.tscn`: `[gd_scene]`, `[ext_resource]`, `[node]` blocks follow
  the Godot 4 scene format; `uid` is a placeholder unique to this demo.

## 2. Automated sanity scan (executed)

A delimiter/indentation scanner was run over both `.gd` files:

- `rea_contract.gd`: parens BALANCED, brackets BALANCED, braces BALANCED,
  indentation TABS-ONLY, 5 funcs, `extends Node`.
- `demo_scene.gd`: parens BALANCED, brackets BALANCED, braces BALANCED,
  indentation TABS-ONLY, 6 funcs, `extends Control`.

## 3. What was NOT checked

- Runtime behavior in Godot (no engine available): signal dispatch, UI
  layout, `FileAccess` paths at runtime, and JSON parsing of the real
  ledger are unexecuted.
- The `.tscn` was not loaded by any Godot editor/import pipeline.

## Files

- `rea_contract.gd` — interface-contract bindings (`add32`, `recover`,
  `verify`, `hypothesis_status`).
- `demo_scene.gd` — scene script building the UI in code.
- `demo_scene.tscn` — minimal demo scene referencing the script.
