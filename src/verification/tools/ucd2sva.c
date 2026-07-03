/*
 * ucd2sva.c — Dump per-instance SVA data from an Xcelium .ucd file as JSONL.
 *
 * Design-unit aggregate records are intentionally excluded because the same
 * assertion data is also stored on each bound module instance.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "ucis.h"

#define MAX_DEPTH 128
#define NAME_LEN 512

typedef struct {
    uint64_t types[MAX_DEPTH];
    char     names[MAX_DEPTH][NAME_LEN];
    int      depth;
    int      overflow_depth;
} walk_state_t;

static void json_str(const char *str) {
    fputc('"', stdout);
    for (; str && *str; str++) {
        if (*str == '"' || *str == '\\') {
            fputc('\\', stdout);
            fputc(*str, stdout);
        } else if (*str == '\n') {
            fputs("\\n", stdout);
        } else if (*str != '\r') {
            fputc(*str, stdout);
        }
    }
    fputc('"', stdout);
}

static void json_instance_path(const walk_state_t *state, int directive_index) {
    int first = 1;

    fputc('"', stdout);
    for (int i = 0; i < directive_index; i++) {
        if (state->types[i] != (uint64_t)UCIS_INSTANCE || state->names[i][0] == '\0') continue;
        if (!first) fputc('/', stdout);
        for (const char *str = state->names[i]; *str; str++) {
            if (*str == '"' || *str == '\\') fputc('\\', stdout);
            fputc(*str, stdout);
        }
        first = 0;
    }
    fputc('"', stdout);
}

static const char *bin_kind(const char *name, uint64_t type, int is_cover) {
    if (name) {
        if (strcmp(name, "coverbin") == 0) return "cover";
        if (strcmp(name, "passbin") == 0) return "pass";
        if (strcmp(name, "failbin") == 0) return "fail";
        if (strcmp(name, "vacuousbin") == 0) return "vacuous";
        if (strcmp(name, "attemptbin") == 0) return "attempt";
        if (strcmp(name, "disabledbin") == 0) return "disabled";
        if (strcmp(name, "activebin") == 0) return "active";
        if (strcmp(name, "peakactivebin") == 0) return "peak_active";
    }

    if (type == (uint64_t)UCIS_ASSERTBIN || type == (uint64_t)UCIS_FAILBIN) return "fail";
    if (type == (uint64_t)UCIS_VACUOUSBIN) return "vacuous";
    if (type == (uint64_t)UCIS_ATTEMPTBIN) return "attempt";
    if (type == (uint64_t)UCIS_DISABLEDBIN) return "disabled";
    if (type == (uint64_t)UCIS_ACTIVEBIN) return "active";
    if (type == (uint64_t)UCIS_PEAKACTIVEBIN) return "peak_active";
    if (is_cover) return "cover";
    if (type == (uint64_t)UCIS_PASSBIN) return "pass";
    return "unknown";
}

static int is_sva_bin(uint64_t type) {
    return type == (uint64_t)UCIS_COVERBIN ||
           type == (uint64_t)UCIS_ASSERTBIN ||
           type == (uint64_t)UCIS_PASSBIN ||
           type == (uint64_t)UCIS_FAILBIN ||
           type == (uint64_t)UCIS_VACUOUSBIN ||
           type == (uint64_t)UCIS_DISABLEDBIN ||
           type == (uint64_t)UCIS_ATTEMPTBIN ||
           type == (uint64_t)UCIS_ACTIVEBIN ||
           type == (uint64_t)UCIS_PEAKACTIVEBIN;
}

static ucisCBReturnT walk_cb(void *userdata, ucisCBDataT *cbdata) {
    walk_state_t *state = (walk_state_t *)userdata;

    switch (cbdata->reason) {
    case UCIS_REASON_SCOPE: {
        ucisScopeT scope = (ucisScopeT)cbdata->obj;
        const char *name = ucis_GetStringProperty(cbdata->db, (ucisObjT)scope, -1,
                                                  UCIS_STR_SCOPE_NAME);

        if (state->depth < MAX_DEPTH) {
            state->types[state->depth] = (uint64_t)ucis_GetScopeType(cbdata->db, scope);
            snprintf(state->names[state->depth], NAME_LEN, "%s", name ? name : "");
            state->depth++;
        } else {
            state->overflow_depth++;
        }
        break;
    }

    case UCIS_REASON_ENDSCOPE:
        if (state->overflow_depth > 0) state->overflow_depth--;
        else if (state->depth > 0) state->depth--;
        break;

    case UCIS_REASON_CVBIN: {
        ucisScopeT parent = (ucisScopeT)cbdata->obj;
        ucisCoverDataT data;
        char *name = NULL;
        uint64_t count = 0;
        int directive_index = -1;
        int has_instance = 0;
        int is_cover;

        memset(&data, 0, sizeof(data));
        if (state->overflow_depth > 0) break;
        if (ucis_GetCoverData(cbdata->db, parent, cbdata->coverindex, &name, &data, NULL) != 0)
            break;
        if (!is_sva_bin((uint64_t)data.type)) break;

        for (int i = state->depth - 1; i >= 0; i--) {
            if (state->types[i] == (uint64_t)UCIS_ASSERT ||
                state->types[i] == (uint64_t)UCIS_COVER) {
                directive_index = i;
                break;
            }
        }
        if (directive_index < 0) break;

        for (int i = 0; i < directive_index; i++) {
            if (state->types[i] == (uint64_t)UCIS_INSTANCE) {
                has_instance = 1;
                break;
            }
        }
        if (!has_instance) break;

        /* Xcelium 18 stores cover properties under UCIS_ASSERT scopes. The
         * repository's mandatory cp_* label convention disambiguates them. */
        is_cover = state->types[directive_index] == (uint64_t)UCIS_COVER ||
                   strncmp(state->names[directive_index], "cp_", 3) == 0;

        if (data.flags & UCIS_IS_64BIT) count = (uint64_t)data.data.int64;
        else if (data.flags & UCIS_IS_32BIT) count = (uint64_t)data.data.int32;

        fputs("{\"instance\":", stdout);
        json_instance_path(state, directive_index);
        fputs(",\"directive\":", stdout);
        json_str(state->names[directive_index]);
        fputs(",\"kind\":", stdout);
        json_str(is_cover ? "cover" : "assert");
        fputs(",\"bin\":", stdout);
        json_str(bin_kind(name, (uint64_t)data.type, is_cover));
        fputs(",\"raw_bin\":", stdout);
        json_str(name ? name : "");
        fprintf(stdout, ",\"count\":%llu}\n", (unsigned long long)count);
        break;
    }

    default:
        break;
    }

    return UCIS_SCAN_CONTINUE;
}

int main(int argc, char *argv[]) {
    walk_state_t state;
    ucisT db;
    int rc;

    if (argc != 2) {
        fprintf(stderr, "Usage: ucd2sva <file.ucd>\n");
        return 1;
    }

    db = ucis_Open(argv[1]);
    if (!db) {
        fprintf(stderr, "ucd2sva: cannot open '%s'\n", argv[1]);
        return 1;
    }

    memset(&state, 0, sizeof(state));
    rc = ucis_CallBack(db, NULL, walk_cb, &state);
    ucis_Close(db);

    if (rc != 0) {
        fprintf(stderr, "ucd2sva: traversal error on '%s'\n", argv[1]);
        return 1;
    }
    return 0;
}
