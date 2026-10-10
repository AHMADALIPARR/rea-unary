/*
 * driver.c -- rea-unary
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
// Provenance: stage3/driver (worker3), v1. Parents: stage3/driver/proto.h.
// Full hashes in stage3/PROVENANCE.json.
//
// Driver CLI: spawns mock-target as a child process over two pipes and speaks
// the proto.h wire protocol. Exposes: load image, run, read back state/traces.
// Usage:
//   ./driver load <file> [hexoff]   load a firmware image into mock flash
//   ./driver run                     run the behavioral model on the target
//   ./driver state                   read back result/flag registers
//   ./driver trace                   read back the run as CSV
//   ./driver read <hexoff> <hexlen>  hex dump of mock flash
//   ./driver sha <hexoff> <hexlen>   SHA-256 of a mock flash region
// The mock target path is argv-driven (default: same dir as the driver).
#define _POSIX_C_SOURCE 200809L
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <libgen.h>
#include "proto.h"

static FILE *to_dev, *from_dev;
static pid_t child;

static void spawn_target(const char *self, const char *flash)
{
    int c2p[2], p2c[2];
    char dirbuf[4096], target[4352];
    if (pipe(c2p) || pipe(p2c)) { perror("pipe"); exit(1); }
    strncpy(dirbuf, self, sizeof dirbuf - 1);
    dirbuf[sizeof dirbuf - 1] = '\0';
    snprintf(target, sizeof target, "%s/mock-target", dirname(dirbuf));
    child = fork();
    if (child < 0) { perror("fork"); exit(1); }
    if (child == 0) {
        dup2(p2c[0], STDIN_FILENO);
        dup2(c2p[1], STDOUT_FILENO);
        close(p2c[0]); close(p2c[1]); close(c2p[0]); close(c2p[1]);
        execl(target, "mock-target", flash, (char *)NULL);
        perror("execl mock-target");
        _exit(127);
    }
    close(p2c[0]); close(c2p[1]);
    to_dev = fdopen(p2c[1], "w");
    from_dev = fdopen(c2p[0], "r");
    if (!to_dev || !from_dev) { perror("fdopen"); exit(1); }
}

/* send one command; print reply lines; consume through END for multi-line */
static void transact(const char *cmd, int multiline)
{
    char line[PROTO_MAX_LINE];
    fprintf(to_dev, "%s\n", cmd);
    fflush(to_dev);
    while (fgets(line, sizeof line, from_dev)) {
        fputs(line, stdout);
        if (!multiline) break;
        if (strcmp(line, "END\n") == 0) break;
        if (strncmp(line, "ERR", 3) == 0) break; /* errors are single-line */
    }
    fflush(stdout);
}

int main(int argc, char **argv)
{
    const char *flash;
    char cmd[PROTO_MAX_LINE];
    int multiline = 0;

    if (argc < 2) {
        fprintf(stderr,
            "usage: %s load <file> [hexoff] | run | state | trace |\n"
            "       %s read <hexoff> <hexlen> | sha <hexoff> <hexlen>\n",
            argv[0], argv[0]);
        return 2;
    }
    flash = getenv("MOCK_FLASH");
    if (!flash) flash = "../flash.bin"; /* relative to driver cwd */
    spawn_target(argv[0], flash);

    if (strcmp(argv[1], "load") == 0 && argc >= 3) {
        snprintf(cmd, sizeof cmd, "LOAD %s %s", argc >= 4 ? argv[3] : "0x0", argv[2]);
    } else if (strcmp(argv[1], "run") == 0) {
        snprintf(cmd, sizeof cmd, "RUN");
    } else if (strcmp(argv[1], "state") == 0) {
        snprintf(cmd, sizeof cmd, "STATE"); multiline = 1;
    } else if (strcmp(argv[1], "trace") == 0) {
        snprintf(cmd, sizeof cmd, "TRACE"); multiline = 1;
    } else if (strcmp(argv[1], "read") == 0 && argc >= 4) {
        snprintf(cmd, sizeof cmd, "READ %s %s", argv[2], argv[3]); multiline = 1;
    } else if (strcmp(argv[1], "sha") == 0 && argc >= 4) {
        snprintf(cmd, sizeof cmd, "SHA %s %s", argv[2], argv[3]);
    } else {
        fprintf(stderr, "unknown command\n");
        return 2;
    }

    transact(cmd, multiline);
    fprintf(to_dev, "QUIT\n");
    fflush(to_dev);
    if (fgets(cmd, sizeof cmd, from_dev))
        fputs(cmd, stdout); /* "OK bye" */
    fclose(to_dev);
    fclose(from_dev);
    waitpid(child, NULL, 0);
    return 0;
}
