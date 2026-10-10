# Makefile -- rea-unary
# Copyright (C) 2026 Ahmad Ali Parr
# SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
#
# Licensed under the GNU Affero General Public License v3 with an
# additional no-AI-training term (see LICENSE). This code may not be
# used to train machine-learning models.
# Provenance: stage3 (worker3), v1. Parents: none (build driver).
# Full hashes in stage3/PROVENANCE.json.
# stage3 Makefile — drives the rea-unary Worker-3 pipeline.
#   make all    build + verify everything (regenerates all logs)
#   make run    all + e1 router e2e demo + summary
#   make clean  remove generated artifacts and logs (sources untouched)
CC      = gcc
CFLAGS  = -std=c11 -Wall -Wextra -O2
STAGE1  = ../stage1

.PHONY: all clean run sim cmodel oracle contract-check diff firmware flash \
        flash-verify sql driver driver-run web-data

all: sim cmodel oracle contract-check diff firmware flash flash-verify sql driver driver-run

# --- 1. GHDL simulation (real) -> traces.csv + ghdl-sim.log ---
sim: traces.csv
traces.csv: add_core.vhd tb_add_core.vhd
	{ echo "=== ghdl -a add_core.vhd ==="; ghdl -a --std=08 add_core.vhd; \
	  echo "=== ghdl -a tb_add_core.vhd ==="; ghdl -a --std=08 tb_add_core.vhd; \
	  echo "=== ghdl -e tb_add_core ==="; ghdl -e --std=08 tb_add_core; \
	  echo "=== ghdl -r tb_add_core ==="; ghdl -r --std=08 tb_add_core; } 2>&1 | tee ghdl-sim.log
	test -f traces.csv

# --- C11 model, differential oracle, contract correspondence ---
cmodel: add_core_model
add_core_model: add_core_model.c addmod.c addmod.h
	$(CC) $(CFLAGS) -o $@ add_core_model.c addmod.c

oracle: diff-oracle
diff-oracle: diff-oracle.c addmod.c addmod.h
	$(CC) $(CFLAGS) -o $@ diff-oracle.c addmod.c

contract-check: contract-check.c addmod.c addmod.h
	$(CC) $(CFLAGS) -o $@ contract-check.c addmod.c

diff: diff-oracle traces.csv
	./diff-oracle | tee differential-log.txt
	./contract-check | tee contract-check.log

# --- 3. firmware chain: C -> objects -> ELF -> image ---
firmware: fw/firmware.bin
fw/add.o: fw/add.c
	$(CC) $(CFLAGS) -ffreestanding -c fw/add.c -o fw/add.o
fw/main.o: fw/main.c
	$(CC) $(CFLAGS) -ffreestanding -c fw/main.c -o fw/main.o
fw/firmware.elf: fw/add.o fw/main.o fw/link.ld
	$(CC) -static -ffreestanding -nostdlib -T fw/link.ld -o fw/firmware.elf fw/add.o fw/main.o
	file fw/firmware.elf
fw/firmware.bin: fw/firmware.elf
	objcopy -O binary fw/firmware.elf fw/firmware.bin
	sha256sum fw/firmware.bin

# --- mock flash target: pre-erased file, write image, read-back verify ---
flash: flash.bin
flash.bin:
	dd if=/dev/zero bs=65536 count=1 2>/dev/null | tr '\000' '\377' > flash.bin

flash-verify: flash.bin fw/firmware.bin
	{ echo "=== mock flash: 64 KiB pre-erased to 0xFF ==="; \
	  echo "=== write fw/firmware.bin at file offset 0x0000 (flash addr 0x08000000) ==="; \
	  FW=$$(stat -c%s fw/firmware.bin); \
	  dd if=fw/firmware.bin of=flash.bin bs=512 conv=notrunc 2>/dev/null; \
	  echo "written: $$FW bytes"; \
	  echo "=== read-back + SHA-256 compare ==="; \
	  dd if=flash.bin of=/tmp/rb.bin bs=512 count=$$(( ($$FW + 511) / 512 )) 2>/dev/null; \
	  head -c $$FW /tmp/rb.bin > /tmp/rb-trim.bin; \
	  echo "firmware.bin: $$(sha256sum fw/firmware.bin | cut -d' ' -f1)"; \
	  echo "read-back   : $$(sha256sum /tmp/rb-trim.bin | cut -d' ' -f1)"; \
	  cmp -s fw/firmware.bin /tmp/rb-trim.bin && echo "VERIFY: MATCH" || echo "VERIFY: MISMATCH"; \
	  rm -f /tmp/rb.bin /tmp/rb-trim.bin; } 2>&1 | tee flash-verify.log

# --- 5. SQL trace-conformance checks ---
sql: sql-results.txt
sql-results.txt: sql-checks.sql traces.csv
	sqlite3 :memory: < sql-checks.sql > sql-results.txt

# --- driver vs mock target ---
driver: driver/driver driver/mock-target
driver/mock-target: driver/mock-target.c driver/sha256.c driver/sha256.h driver/proto.h
	$(CC) $(CFLAGS) -o driver/mock-target driver/mock-target.c driver/sha256.c
driver/driver: driver/driver.c driver/proto.h
	$(CC) $(CFLAGS) -o driver/driver driver/driver.c

driver-run: driver
	cd driver && { echo "=== driver session vs mock target (mock FPGA/ASIC stand-in) ==="; \
	  FW_SHA=$$(sha256sum ../fw/firmware.bin | cut -d' ' -f1); \
	  FW_LEN=$$(stat -c%s ../fw/firmware.bin); \
	  echo "\$$ ./driver load ../fw/firmware.bin 0x0"; ./driver load ../fw/firmware.bin 0x0; \
	  echo "local firmware.bin: len=$$FW_LEN sha256=$$FW_SHA"; \
	  echo "\$$ ./driver sha 0x0 $$FW_LEN"; ./driver sha 0x0 $$FW_LEN; \
	  echo "\$$ ./driver run"; ./driver run; \
	  echo "\$$ ./driver state"; ./driver state; \
	  echo "\$$ ./driver trace"; ./driver trace; } > driver-run.log 2>&1
	test -s driver/driver-run.log

# --- web data bundle for the backend ---
web-data: evidence-ledger.jsonl
	mkdir -p web/backend/data
	cp evidence-ledger.jsonl sql-results.txt differential-log.txt ghdl-sim.log web/backend/data/

# --- full demo: everything + e1 ALP router end-to-end ---
run: all
	@echo "=== e1 ALP evidence-routing end-to-end (stage1 router, referenced not copied) ==="
	$(MAKE) -C $(STAGE1)/router run | tee router-e1-run.log
	@echo "=== differential: silicon vs C model vs GHDL ==="
	./diff-oracle | tail -1
	@echo "=== SQL trace-conformance ==="
	sqlite3 :memory: < sql-checks.sql | grep -E "^check"
	@echo "=== demo complete ==="

clean:
	rm -f traces.csv ghdl-sim.log work-obj08.cf
	rm -f add_core_model diff-oracle contract-check
	rm -f differential-log.txt contract-check.log counterexample-turn.log router-e1-run.log
	rm -f sql-results.txt flash.bin flash.bin.state flash-verify.log
	rm -f fw/add.o fw/main.o fw/firmware.elf fw/firmware.bin
	rm -f driver/driver driver/mock-target driver/driver-run.log
