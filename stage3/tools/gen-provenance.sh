# gen-provenance.sh -- rea-unary
# Copyright (C) 2026 Ahmad Ali Parr
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
#
# Licensed under the GNU Affero General Public License v3 with an
# additional no-AI-training term (see LICENSE). This code may not be
# used to train machine-learning models.
#!/bin/bash
# Provenance: stage3/tools (worker3), v1. Generates stage3/PROVENANCE.json.
# Usage: run from ~/workspace/rea-unary/stage3.
# Verifies with: jq -r '.artifacts[] | "\(.sha256)  \(.name)"' PROVENANCE.json | sha256sum -c -
set -u
cd "$(dirname "$0")/.."
TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# name|comma-separated parents (stage3-relative, or ../stage1|../stage2 paths)
read -r -d '' TABLE <<'EOF'
add_core.vhd|../stage1/sample.md
tb_add_core.vhd|add_core.vhd
traces.csv|add_core.vhd,tb_add_core.vhd
ghdl-sim.log|add_core.vhd,tb_add_core.vhd
w2-traces.csv|../stage2/add_core.vhd,tb_add_core.vhd
w2-sim.log|../stage2/add_core.vhd,tb_add_core.vhd
addmod.h|../stage1/sample.md
addmod.c|addmod.h,../stage1/sample.md
add_core_model.c|add_core.vhd,addmod.h,addmod.c
add_core_model|add_core_model.c,addmod.c
diff-oracle.c|addmod.h,addmod.c,traces.csv
diff-oracle|diff-oracle.c,addmod.c
differential-log.txt|diff-oracle.c,traces.csv
counterexample-turn.log|diff-oracle.c
contract-check.c|add32.dfy,addmod.h,addmod.c
contract-check|contract-check.c,addmod.c
contract-check.log|contract-check.c
add32.dfy|../stage1/sample.md
add32-core.dfy|add32.dfy
dafny-verify.log|add32.dfy
dafny-core-verify.log|add32-core.dfy
fw/add.c|addmod.c
fw/main.c|fw/add.c
fw/link.ld|
fw/add.o|fw/add.c
fw/main.o|fw/main.c
fw/firmware.elf|fw/add.o,fw/main.o,fw/link.ld
fw/firmware.bin|fw/firmware.elf
flash.bin|fw/firmware.bin
flash.bin.state|driver/mock-target
flash-verify.log|fw/firmware.bin,flash.bin
sql-checks.sql|traces.csv
sql-results.txt|sql-checks.sql,traces.csv
test-vectors.md|differential-log.txt,traces.csv
hw-translation.md|add_core.vhd,add_core_model.c,differential-log.txt
interface-contract.md|../stage1/sample.md,addmod.h,sql-checks.sql
driver/proto.h|
driver/sha256.h|
driver/sha256.c|driver/sha256.h
driver/mock-target.c|driver/proto.h,driver/sha256.h,addmod.c
driver/driver.c|driver/proto.h
driver/mock-target|driver/mock-target.c,driver/sha256.c
driver/driver|driver/driver.c
driver/driver-run.log|driver/driver,driver/mock-target,fw/firmware.bin
frontend/rea_contract.gd|interface-contract.md
frontend/demo_scene.gd|frontend/rea_contract.gd
frontend/demo_scene.tscn|frontend/demo_scene.gd
frontend/GDSCRIPT_REVIEW.md|frontend/rea_contract.gd,frontend/demo_scene.gd
web/backend/package.json|
web/backend/tsconfig.json|
web/backend/next.config.js|
web/backend/app/layout.tsx|
web/backend/app/page.tsx|
web/backend/app/globals.css|
web/backend/app/api/ledger/route.ts|
web/backend/app/api/verification/route.ts|
web/backend/app/api/counterexamples/route.ts|
web/backend/app/api/loop/trigger/route.ts|
web/backend/api-smoke.log|web/backend/app/api/ledger/route.ts,web/backend/app/api/loop/trigger/route.ts
web/frontend/package.json|
web/frontend/tsconfig.json|
web/frontend/vite.config.ts|
web/frontend/index.html|
web/frontend/src/main.tsx|
evidence-ledger.jsonl|../stage1/evidence.jsonl,../stage2/hypotheses.jsonl,differential-log.txt,counterexample-turn.log,router-e1-run.log
router-e1-run.log|../stage1/router/router.c
Makefile|
tools/gen-provenance.sh|
README.md|
EOF

declare -A HASH
# first pass: hash every artifact that exists on disk
while IFS='|' read -r name _; do
  [ -z "$name" ] && continue
  if [ -f "$name" ]; then
    HASH["$name"]=$(sha256sum "$name" | cut -d' ' -f1)
  else
    echo "MISSING: $name" >&2
  fi
done <<< "$TABLE"
# parent hashes for ../stage1 and ../stage2 files (hash on demand)
phash() {
  local p="$1"
  if [[ "$p" == ../* ]]; then
    sha256sum "$p" | cut -d' ' -f1
  else
    printf '%s' "${HASH[$p]:-MISSING}"
  fi
}

jq -n --arg ts "$TS" '{generated_at:$ts, producer:"stage3/worker3", version:"v1",
  note:"sha256 values are real, computed at generation time. parents[] lists source files; parent_hashes[] their hashes. ../stage1 and ../stage2 parents are outside stage3 (read-only reference / Worker-2 output).",
  artifacts:[]}' > PROVENANCE.json.tmp

while IFS='|' read -r name parents; do
  [ -z "$name" ] && continue
  h="${HASH[$name]:-MISSING}"
  pj=$(jq -n --arg h "$h" '[]')
  ph=$(jq -n '[]')
  if [ -n "$parents" ]; then
    IFS=',' read -ra PA <<< "$parents"
    for p in "${PA[@]}"; do
      pj=$(jq --arg p "$p" '. + [$p]' <<< "$pj")
      ph=$(jq --arg h "$(phash "$p")" '. + [$h]' <<< "$ph")
    done
  fi
  jq --arg n "$name" --arg h "$h" --arg ts "$TS" --argjson pj "$pj" --argjson ph "$ph" \
    '.artifacts += [{name:$n, origin:"stage3/worker3", sha256:$h, version:"v1", timestamp:$ts, parents:$pj, parent_hashes:$ph}]' \
    PROVENANCE.json.tmp > PROVENANCE.json.tmp2 && mv PROVENANCE.json.tmp2 PROVENANCE.json.tmp
done <<< "$TABLE"
mv PROVENANCE.json.tmp PROVENANCE.json
echo "wrote PROVENANCE.json with $(jq '.artifacts | length' PROVENANCE.json) artifacts"
