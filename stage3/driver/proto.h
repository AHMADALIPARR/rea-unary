/*
 * proto.h -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
// Author's rights notice (Ahmad Ali Parr):
// Binary -> IR -> VHDL -> netlist: changing representation itself clears rights.
// Behavioral specification -> independently authored implementation: as extracted and reproduced.
// Provenance: stage3/driver (worker3), v1. Parents: none (new protocol).
// Full hashes in stage3/PROVENANCE.json.
//
// Wire protocol between the driver and the (mock) FPGA/ASIC target.
// All commands and replies are LF-terminated text lines over pipes.
// The mock target is mock-target.c; its backing store is the flash.bin file.
//
// Commands (client -> device):
//   LOAD <hexoff> <path>   device reads file <path>, writes flash at <hexoff>
//                          -> "OK loaded <n> bytes at 0x<off>"
//   RUN                    run the behavioral model over the 10 vectors
//                          -> "OK ran 10 vectors"
//   STATE                  dump last-run registers (multi-line, ends with END)
//                          -> "OK" then "vec <i> a=.. b=.. result=.. cf=.. pf=.. af=.. zf=.. sf=.. of=.."
//   TRACE                  dump last-run trace as CSV (multi-line, ends with END)
//                          -> "OK" then CSV lines (header + 10 rows)
//   READ <hexoff> <hexlen> hex dump of flash (multi-line, ends with END)
//                          -> "OK" then "<hexoff>: <hex bytes>"
//   SHA <hexoff> <hexlen>  SHA-256 of a flash region (single line)
//                          -> "OK sha256=<hex>"
//   QUIT                   -> "OK bye", then the device exits(0)
//
// Errors: "ERR <message>" (single line).
// Multi-line replies always terminate with a line containing exactly "END".
#ifndef PROTO_H
#define PROTO_H

#define PROTO_MAX_LINE 4096

#endif /* PROTO_H */
