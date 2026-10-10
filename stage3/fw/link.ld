/*
 * link.ld -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
# Author's rights notice (Ahmad Ali Parr):
# Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
# Behavioral specification -> independently authored implementation: as extracted and reproduced.
# Provenance: stage3/fw (worker3), v1. Parents: none (standard GNU ld syntax).
# Full hashes in stage3/PROVENANCE.json.
#
# Linker script for the rea-unary firmware image (standard GNU ld syntax).
# The mock flash target (stage3/flash.bin) models a flash array whose file
# offset 0x0000 corresponds to flash address 0x08000000 (this script's
# FLASH origin). RAM origin 0x20000000 holds .bss (the results table).
ENTRY(_start)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 20K
}

SECTIONS
{
    .text :
    {
        *(.text*)
        *(.rodata*)
    } > FLASH

    .bss (NOLOAD) :
    {
        *(.bss*)
        *(COMMON)
    } > RAM

    _estack = ORIGIN(RAM) + LENGTH(RAM);
}
