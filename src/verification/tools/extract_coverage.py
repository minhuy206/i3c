#!/usr/bin/env python3
"""
extract_coverage.py — aggregate functional coverage across all cov_work runs.

Usage (from src/verification/):
    python3 tools/extract_coverage.py [cov_work_dir] [output_report]

Defaults:
    cov_work_dir  = cov_work
    output_report = coverage_report.txt

Requires tools/ucd2json to be built first (make tools).
Each .ucd file under cov_work/scope/*/ is converted via ucd2json. The converter
emits only covergroup-type bins; per-instance duplicates are excluded. Bins are
identified by covergroup, coverpoint or cross, binscope, and bin name. Counts
are summed across tests and any positive aggregate count is considered covered.
"""

import json
import os
import subprocess
import sys
from collections import defaultdict
from pathlib import Path


def find_ucd_files(cov_work: str):
    scope_dir = Path(cov_work) / 'scope'
    if not scope_dir.is_dir():
        return []
    return sorted(p for p in scope_dir.glob('*/*.ucd'))


def run_ucd2json(binary: str, ucd: Path) -> list[dict]:
    proc = subprocess.run(
        [binary, str(ucd)], capture_output=True, text=True, check=False
    )
    if proc.returncode != 0:
        detail = proc.stderr.strip() or f"exit status {proc.returncode}"
        raise RuntimeError(f"ucd2json failed for {ucd}: {detail}")

    rows = []
    required = {"cg", "cp", "cr", "bs", "bin", "count"}
    for line_number, line in enumerate(proc.stdout.splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as err:
            raise RuntimeError(
                f"invalid JSON from ucd2json for {ucd}:{line_number}: {err}"
            ) from err
        if not required.issubset(row):
            missing = ", ".join(sorted(required - set(row)))
            raise RuntimeError(
                f"incomplete ucd2json row for {ucd}:{line_number}: missing {missing}"
            )
        if not row["cg"]:
            raise RuntimeError(
                f"ucd2json emitted a bin without covergroup identity for "
                f"{ucd}:{line_number}"
            )
        if bool(row["cp"]) == bool(row["cr"]):
            raise RuntimeError(
                f"ucd2json row must identify exactly one coverpoint or cross for "
                f"{ucd}:{line_number}"
            )
        rows.append(row)

    if not rows:
        raise RuntimeError(f"ucd2json produced no functional coverage rows for {ucd}")
    return rows


def display_bin(bs: str, bin_name: str) -> str:
    """Human-readable bin label for the report."""
    if not bs or bs == 'auto':
        return bin_name
    if bs == bin_name:
        return bin_name
    if bin_name.startswith(f"{bs}["):
        return bin_name
    return f"{bs}: {bin_name}"


def main():
    cov_work = sys.argv[1] if len(sys.argv) > 1 else 'cov_work'
    outfile  = sys.argv[2] if len(sys.argv) > 2 else 'coverage_report.txt'

    script_dir = Path(__file__).parent
    ucd2json   = str(script_dir / 'ucd2json')
    if not os.path.isfile(ucd2json) or not os.access(ucd2json, os.X_OK):
        sys.exit(f"Error: executable converter {ucd2json} not found — build with: make tools")

    ucd_files = find_ucd_files(cov_work)
    if not ucd_files:
        sys.exit(f"Error: no .ucd files found under {cov_work}/scope/")

    # key: (covergroup, item kind, item name, binscope, bin) → aggregate count
    totals  = defaultdict(int)
    testers = defaultdict(set)      # tests that hit each bin
    expected_schema = None

    try:
        for ucd in ucd_files:
            test_name = ucd.parent.name
            rows = run_ucd2json(ucd2json, ucd)
            file_keys = set()
            for row in rows:
                item_kind = "coverpoint" if row["cp"] else "cross"
                item_name = row["cp"] or row["cr"]
                key = (row["cg"], item_kind, item_name, row["bs"], row["bin"])
                if key in file_keys:
                    raise RuntimeError(f"duplicate functional coverage bin identity in {ucd}: {key}")
                file_keys.add(key)
                count = int(row["count"])
                if count < 0:
                    raise RuntimeError(f"negative functional coverage count in {ucd}: {key}")
                totals[key] += count
                if count > 0:
                    testers[key].add(test_name)

            if expected_schema is None:
                expected_schema = file_keys
            elif file_keys != expected_schema:
                missing = len(expected_schema - file_keys)
                extra = len(file_keys - expected_schema)
                raise RuntimeError(
                    f"functional coverage schema mismatch in {ucd}: "
                    f"{missing} missing, {extra} extra bin(s)"
                )
    except (OSError, RuntimeError, TypeError, ValueError) as err:
        sys.exit(f"Error: {err}")

    # Group by covergroup and coverage item.
    by_item = defaultdict(list)
    for key in sorted(totals):
        cg, item_kind, item_name, _bs, _bn = key
        by_item[(cg, item_kind, item_name)].append(key)

    report_lines = []
    total_bins   = 0
    covered_bins = 0

    SEP = '=' * 72

    for (cg, item_kind, item_name), keys in sorted(by_item.items()):
        grp_tot = len(keys)
        grp_cov = sum(1 for k in keys if totals[k] > 0)
        total_bins   += grp_tot
        covered_bins += grp_cov
        pct = 100.0 * grp_cov / grp_tot if grp_tot else 0.0

        report_lines.append(f"\n{SEP}")
        report_lines.append(f"Covergroup : {cg}")
        report_lines.append(f"{item_kind.title():<11}: {item_name}")
        report_lines.append(f"Coverage   : {grp_cov}/{grp_tot}  ({pct:.1f}%)")
        report_lines.append(SEP)

        for k in keys:
            _, _, _, bs, bn = k
            cnt   = totals[k]
            ntests = len(testers.get(k, set()))
            status = 'HIT ' if cnt > 0 else 'MISS'
            label  = display_bin(bs, bn)
            report_lines.append(
                f"  [{status}] {label:<52} count={cnt:>8}  in {ntests} test(s)")

    overall_pct = 100.0 * covered_bins / total_bins if total_bins else 0.0

    header = '\n'.join([
        "I3C Functional Coverage Report",
        f"Tests analysed : {len(ucd_files)}",
        f"Total bins     : {total_bins}",
        f"Covered bins   : {covered_bins}",
        f"Overall        : {overall_pct:.1f}%",
    ])

    report = header + '\n' + '\n'.join(report_lines) + '\n'

    try:
        Path(outfile).write_text(report, encoding="utf-8")
    except OSError as err:
        sys.exit(f"Error: cannot write report {outfile}: {err}")
    print(report)
    print(f"\nReport written to: {outfile}")


if __name__ == '__main__':
    main()
