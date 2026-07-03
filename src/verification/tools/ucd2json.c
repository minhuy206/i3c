/*
 * ucd2json.c — Dump Xcelium .ucd coverage database to JSONL.
 *
 * Each output line is one JSON object per covergroup-type bin:
 *   {"cg":"covergroup","cp":"coverpoint","cr":"cross",
 *    "bs":"binscope","bin":"bin_name","count":42}
 *
 * Xcelium stores the same functional coverage bins below both the covergroup
 * type and its UCIS_COVERINSTANCE.  Instance subtrees are intentionally
 * suppressed so every bin is emitted once with its covergroup type identity.
 *
 * "bs" (binscope) is non-empty only for array/transition bins that sit
 * inside a UCIS_CVGBINSCOPE sub-scope (e.g. bins name[] = (A => B)).
 *
 * Build (from src/verification/):
 *   UCIS_INC=$XCELIUM_HOME/tools.lnx86/ucd/include
 *   UCIS_LIB=$XCELIUM_HOME/tools.lnx86/ucd/lib/64bit
 *   gcc -std=c11 -Wall -Wextra -m64 -I$UCIS_INC -L$UCIS_LIB \
 *       -o tools/ucd2json tools/ucd2json.c -lucis
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include "ucis.h"

#define MAX_DEPTH  64
#define NAME_LEN   512

typedef struct {
    uint64_t types[MAX_DEPTH];
    int      depth;
    int      overflow_depth;
    int      in_instance;
    int      scope_overflow;
    int      extraction_error;
    char     cg[NAME_LEN];   /* current covergroup type name */
    char     cp[NAME_LEN];   /* current coverpoint name      */
    char     cr[NAME_LEN];   /* current cross name           */
    char     bs[NAME_LEN];   /* current binscope name (array/transition bins) */
} WalkState;

static void copy_name(char dst[NAME_LEN], const char *src) {
    snprintf(dst, NAME_LEN, "%s", src ? src : "");
}

static void json_str(const char *s) {
    fputc('"', stdout);
    for (; s && *s; s++) {
        if      (*s == '"')  { fputc('\\', stdout); fputc('"',  stdout); }
        else if (*s == '\\') { fputc('\\', stdout); fputc('\\', stdout); }
        else if (*s == '\n') { fputc('\\', stdout); fputc('n',  stdout); }
        else if (*s == '\r') { /* skip */ }
        else fputc(*s, stdout);
    }
    fputc('"', stdout);
}

static ucisCBReturnT walk_cb(void *userdata, ucisCBDataT *cbdata) {
    WalkState *st = (WalkState *)userdata;

    switch (cbdata->reason) {

    case UCIS_REASON_SCOPE: {
        ucisScopeT     scope = (ucisScopeT)cbdata->obj;
        uint64_t       type  = (uint64_t)ucis_GetScopeType(cbdata->db, scope);
        const char    *name  = ucis_GetStringProperty(cbdata->db, (ucisObjT)scope,
                                                      -1, UCIS_STR_SCOPE_NAME);
        if (!name) name = "";

        if (st->overflow_depth > 0 || st->depth >= MAX_DEPTH) {
            st->overflow_depth++;
            st->scope_overflow = 1;
            st->extraction_error = 1;
            break;
        }

        st->types[st->depth++] = type;

        if (type == UCIS_COVERINSTANCE) st->in_instance++;

        if      (type == UCIS_COVERGROUP) copy_name(st->cg, name);
        else if (type == UCIS_COVERPOINT) {
            copy_name(st->cp, name);
            st->cr[0] = '\0';
            st->bs[0] = '\0';
        } else if (type == UCIS_CROSS) {
            copy_name(st->cr, name);
            st->cp[0] = '\0';
            st->bs[0] = '\0';
        } else if (type == UCIS_CVGBINSCOPE ||
                   type == UCIS_ILLEGALBINSCOPE ||
                   type == UCIS_IGNOREBINSCOPE) {
            copy_name(st->bs, name);
        }
        break;
    }

    case UCIS_REASON_ENDSCOPE: {
        if (st->overflow_depth > 0) {
            st->overflow_depth--;
            break;
        }

        if (st->depth > 0) {
            st->depth--;
            uint64_t type = st->types[st->depth];
            if      (type == UCIS_COVERGROUP)    { st->cg[0] = '\0'; }
            else if (type == UCIS_COVERINSTANCE) { st->in_instance--; }
            else if (type == UCIS_COVERPOINT)    { st->cp[0] = '\0'; st->bs[0] = '\0'; }
            else if (type == UCIS_CROSS)         { st->cr[0] = '\0'; st->bs[0] = '\0'; }
            else if (type == UCIS_CVGBINSCOPE ||
                     type == UCIS_ILLEGALBINSCOPE ||
                     type == UCIS_IGNOREBINSCOPE) { st->bs[0] = '\0'; }
        }
        break;
    }

    case UCIS_REASON_CVBIN: {
        ucisScopeT   parent = (ucisScopeT)cbdata->obj;
        char        *bin_name = NULL;
        ucisCoverDataT data;
        memset(&data, 0, sizeof(data));

        if (st->overflow_depth > 0 || st->in_instance > 0)
            break;

        if (ucis_GetCoverData(cbdata->db, parent, cbdata->coverindex,
                              &bin_name, &data, NULL) != 0) {
            fprintf(stderr, "ucd2json: cannot read coverage bin\n");
            st->extraction_error = 1;
            break;
        }

        if ((uint64_t)data.type != UCIS_CVGBIN)
            break;

        uint64_t count = 0;
        if      (data.flags & UCIS_IS_64BIT) count = (uint64_t)data.data.int64;
        else if (data.flags & UCIS_IS_32BIT) count = (uint64_t)data.data.int32;
        else {
            fprintf(stderr, "ucd2json: unsupported count encoding for bin '%s'\n",
                    bin_name ? bin_name : "");
            st->extraction_error = 1;
            break;
        }

        fputs("{\"cg\":", stdout);  json_str(st->cg);
        fputs(",\"cp\":", stdout);  json_str(st->cp);
        fputs(",\"cr\":", stdout);  json_str(st->cr);
        fputs(",\"bs\":", stdout);  json_str(st->bs);
        fputs(",\"bin\":", stdout); json_str(bin_name ? bin_name : "");
        fprintf(stdout, ",\"count\":%llu}\n", (unsigned long long)count);
        break;
    }

    default:
        break;
    }

    return UCIS_SCAN_CONTINUE;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: ucd2json <file.ucd>\n");
        return 1;
    }

    ucisT db = ucis_Open(argv[1]);
    if (!db) {
        fprintf(stderr, "ucd2json: cannot open '%s'\n", argv[1]);
        return 1;
    }

    WalkState st;
    memset(&st, 0, sizeof(st));

    int rc = ucis_CallBack(db, NULL, walk_cb, &st);
    ucis_Close(db);

    if (rc != 0 || st.extraction_error) {
        if (st.scope_overflow)
            fprintf(stderr, "ucd2json: scope nesting exceeds MAX_DEPTH=%d\n", MAX_DEPTH);
        fprintf(stderr, "ucd2json: traversal error on '%s'\n", argv[1]);
        return 1;
    }
    return 0;
}
