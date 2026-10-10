/*
 * router.c -- rea-unary
 * Copyright (C) 2026 Ahmad Ali Parr
 * SPDX-License-Identifier: LicenseRef-AGPL-3.0-NoAI-1.0
 *
 * Licensed under the GNU Affero General Public License v3 with an
 * additional no-AI-training term (see LICENSE). This code may not be
 * used to train machine-learning models.
 */
/* provenance: producer=stage1/coordinator parents=[enc_registry.h] version=v1 full-sha256-in=PROVENANCE.json */
/*
 * router.c — ALP evidence-routing: validate -> decode -> select route -> render.
 * rea-unary stage1/router. Fresh authorship, C11.
 *
 * Reads one JSONL evidence record (file argument or stdin), validates its
 * fields, decodes the payload through the encoding registry, selects the
 * route's Mustache template from routes.xml, renders it with
 * {{decoded_payload}} and {{evidence}}, and prints the rendered prompt —
 * the structured evidence the ALP agent receives.
 *
 * The JSON/XML handling here is intentionally minimal and documented:
 * it parses exactly the fixed record/route shapes used by this pipeline,
 * not arbitrary JSON or XML.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "enc_registry.h"

#define MAX_LINE 4096
#define MAX_FIELD 1024

/* Extract the string value of "key" from a flat JSON object line. */
static int json_string_field(const char *line, const char *key,
                             char *out, size_t outsz) {
    char pat[MAX_FIELD];
    const char *p, *q;
    size_t n;

    snprintf(pat, sizeof pat, "\"%s\"", key);
    p = strstr(line, pat);
    if (!p)
        return -1;
    p = strchr(p + strlen(pat), ':');
    if (!p)
        return -1;
    p++;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p != '"')
        return -1;
    p++;
    q = strchr(p, '"');
    if (!q)
        return -1;
    n = (size_t)(q - p);
    if (n >= outsz)
        return -1;
    memcpy(out, p, n);
    out[n] = '\0';
    return 0;
}

/* Extract the raw [...] value of "key" (used for the evidence array). */
static int json_array_field(const char *line, const char *key,
                            char *out, size_t outsz) {
    char pat[MAX_FIELD];
    const char *p, *q;
    size_t n;

    snprintf(pat, sizeof pat, "\"%s\"", key);
    p = strstr(line, pat);
    if (!p)
        return -1;
    p = strchr(p + strlen(pat), ':');
    if (!p)
        return -1;
    p++;
    while (*p == ' ' || *p == '\t')
        p++;
    if (*p != '[')
        return -1;
    q = strchr(p, ']');
    if (!q)
        return -1;
    q++;
    n = (size_t)(q - p);
    if (n >= outsz)
        return -1;
    memcpy(out, p, n);
    out[n] = '\0';
    return 0;
}

/* Extract attr="value" from an XML tag line (minimal parse). */
static int xml_attr(const char *line, const char *attr,
                    char *out, size_t outsz) {
    char pat[MAX_FIELD];
    const char *p, *q;
    size_t n;

    snprintf(pat, sizeof pat, "%s=\"", attr);
    p = strstr(line, pat);
    if (!p)
        return -1;
    p += strlen(pat);
    q = strchr(p, '"');
    if (!q)
        return -1;
    n = (size_t)(q - p);
    if (n >= outsz)
        return -1;
    memcpy(out, p, n);
    out[n] = '\0';
    return 0;
}

/* Find the template file for a route path in routes.xml (minimal parse). */
static int route_template(const char *xmlpath, const char *route,
                          char *out, size_t outsz) {
    FILE *fp = fopen(xmlpath, "r");
    char line[MAX_LINE];
    char path[MAX_FIELD], tmpl[MAX_FIELD];

    if (!fp) {
        fprintf(stderr, "router: cannot open %s\n", xmlpath);
        return -1;
    }
    while (fgets(line, sizeof line, fp)) {
        if (strstr(line, "<route") &&
            xml_attr(line, "path", path, sizeof path) == 0 &&
            xml_attr(line, "template", tmpl, sizeof tmpl) == 0) {
            if (strcmp(path, route) == 0) {
                size_t n = strlen(tmpl);

                if (n >= outsz) {
                    fclose(fp);
                    return -1;
                }
                memcpy(out, tmpl, n + 1);
                fclose(fp);
                return 0;
            }
        }
    }
    fclose(fp);
    return -1;
}

/* Render a Mustache template with {{decoded_payload}} and {{evidence}}. */
static int render_template(const char *tmplpath, const char *decoded,
                           const char *evidence) {
    FILE *fp = fopen(tmplpath, "r");
    char line[MAX_LINE];
    const char *p, *mark;
    size_t mlen;

    if (!fp) {
        fprintf(stderr, "router: cannot open template %s\n", tmplpath);
        return -1;
    }
    while (fgets(line, sizeof line, fp)) {
        p = line;
        while ((mark = strstr(p, "{{")) != NULL) {
            const char *end = strstr(mark, "}}");

            if (!end)
                break;
            fwrite(p, 1, (size_t)(mark - p), stdout);
            mlen = (size_t)(end - (mark + 2));
            if (mlen == 15 && strncmp(mark + 2, "decoded_payload", 15) == 0)
                fputs(decoded, stdout);
            else if (mlen == 8 && strncmp(mark + 2, "evidence", 8) == 0)
                fputs(evidence, stdout);
            else
                fwrite(mark, 1, (size_t)(end + 2 - mark), stdout);
            p = end + 2;
        }
        fputs(p, stdout);
    }
    fclose(fp);
    return 0;
}

static char *read_line(FILE *fp) {
    static char buf[MAX_LINE];

    if (!fgets(buf, sizeof buf, fp))
        return NULL;
    buf[strcspn(buf, "\r\n")] = '\0';
    return buf;
}

int main(int argc, char **argv) {
    FILE *fp = stdin;
    char *line;
    char id[MAX_FIELD], route[MAX_FIELD], encoding[MAX_FIELD];
    char payload[MAX_FIELD], evidence[MAX_FIELD * 2];
    char tmpl[MAX_FIELD], tmplpath[MAX_LINE];
    const Encoding *enc;
    char *decoded;
    const char *xmldir;
    char xmlpath[MAX_LINE];

    if (argc > 1) {
        fp = fopen(argv[1], "r");
        if (!fp) {
            fprintf(stderr, "router: cannot open %s\n", argv[1]);
            return 1;
        }
    }
    line = read_line(fp);
    if (fp != stdin)
        fclose(fp);
    if (!line || !*line) {
        fprintf(stderr, "router: empty input\n");
        return 1;
    }

    /* 1. VALIDATE: required fields present. */
    if (json_string_field(line, "id", id, sizeof id) != 0 ||
        json_string_field(line, "route", route, sizeof route) != 0 ||
        json_string_field(line, "encoding", encoding, sizeof encoding) != 0 ||
        json_string_field(line, "payload", payload, sizeof payload) != 0 ||
        json_array_field(line, "evidence", evidence, sizeof evidence) != 0) {
        fprintf(stderr, "router: validation failed (missing field)\n");
        return 1;
    }
    printf("[validate] record %s: fields ok\n", id);

    /* 2. DECODE: payload through the encoding registry. */
    enc = enc_find(encoding);
    if (!enc) {
        fprintf(stderr, "router: unknown encoding '%s'\n", encoding);
        return 1;
    }
    decoded = enc->decode(payload);
    if (!decoded) {
        fprintf(stderr, "router: decode failed\n");
        return 1;
    }
    printf("[decode] encoding=%s payload -> \"%s\"\n", encoding, decoded);

    /* 3. SELECT ROUTE: routes.xml lives next to the binary or in cwd. */
    xmldir = getenv("ROUTER_DIR");
    snprintf(xmlpath, sizeof xmlpath, "%s/routes.xml",
             xmldir ? xmldir : ".");
    if (route_template(xmlpath, route, tmpl, sizeof tmpl) != 0) {
        fprintf(stderr, "router: no route for '%s'\n", route);
        free(decoded);
        return 1;
    }
    printf("[route] %s -> template %s\n", route, tmpl);

    /* 4. RENDER: template with decoded payload + evidence. */
    snprintf(tmplpath, sizeof tmplpath, "%s/%s", xmldir ? xmldir : ".", tmpl);
    printf("[render] ---- rendered prompt ----\n");
    if (render_template(tmplpath, decoded, evidence) != 0) {
        free(decoded);
        return 1;
    }
    printf("[render] ---- end prompt ----\n");

    free(decoded);
    return 0;
}
