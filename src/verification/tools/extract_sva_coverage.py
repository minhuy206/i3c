#!/usr/bin/env python3
"""Aggregate per-instance SVA results across Xcelium regression UCD files.

Usage (from src/verification/):
    python3 tools/extract_sva_coverage.py [cov_work_dir] [output_report]

Defaults:
    cov_work_dir  = cov_work
    output_report = sva_coverage_report.txt

Set UCD2SVA to override the converter path. Otherwise tools/ucd2sva is used.
"""

import json
import os
import subprocess
import sys
from collections import Counter, defaultdict
from pathlib import Path


def find_ucd_files(cov_work: str) -> list[Path]:
    scope_dir = Path(cov_work) / "scope"
    if not scope_dir.is_dir():
        return []
    return sorted(scope_dir.glob("*/*.ucd"))


def run_ucd2sva(binary: str, ucd: Path) -> list[dict]:
    proc = subprocess.run([binary, str(ucd)], capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        detail = proc.stderr.strip() or f"exit status {proc.returncode}"
        raise RuntimeError(f"ucd2sva failed for {ucd}: {detail}")

    rows = []
    for line_number, line in enumerate(proc.stdout.splitlines(), start=1):
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as err:
            raise RuntimeError(f"invalid JSON from ucd2sva for {ucd}:{line_number}: {err}") from err
        required = {"instance", "directive", "kind", "bin", "count"}
        if not required.issubset(row):
            missing = ", ".join(sorted(required - set(row)))
            raise RuntimeError(f"incomplete ucd2sva row for {ucd}:{line_number}: missing {missing}")
        rows.append(row)
    return rows


def assertion_status(counts: Counter) -> str:
    if counts["fail"] > 0:
        return "FAIL"
    if counts["pass"] > 0:
        return "PASS"
    if counts["vacuous"] > 0:
        return "VACUOUS"
    return "MISS"


def cover_status(counts: Counter) -> str:
    return "HIT" if counts["cover"] > 0 else "MISS"


def format_report(ucd_files: list[Path], totals: dict, testers: dict) -> str:
    assertion_stats = Counter()
    cover_stats = Counter()

    for (kind, _instance, _directive), counts in totals.items():
        if kind == "assert":
            assertion_stats[assertion_status(counts)] += 1
        else:
            cover_stats[cover_status(counts)] += 1

    assertion_total = sum(assertion_stats.values())
    cover_total = sum(cover_stats.values())
    assertion_closed = assertion_stats["PASS"]
    cover_closed = cover_stats["HIT"]
    assertion_pct = 100.0 * assertion_closed / assertion_total if assertion_total else 0.0
    cover_pct = 100.0 * cover_closed / cover_total if cover_total else 0.0

    lines = [
        "I3C SVA Coverage Report",
        f"Tests analysed   : {len(ucd_files)}",
        f"Assertions       : {assertion_total}",
        f"  PASS           : {assertion_stats['PASS']}",
        f"  VACUOUS        : {assertion_stats['VACUOUS']}",
        f"  FAIL           : {assertion_stats['FAIL']}",
        f"  MISS           : {assertion_stats['MISS']}",
        f"  Closure        : {assertion_pct:.1f}%",
        f"Cover properties : {cover_total}",
        f"  HIT            : {cover_stats['HIT']}",
        f"  MISS           : {cover_stats['MISS']}",
        f"  Closure        : {cover_pct:.1f}%",
    ]

    by_instance = defaultdict(list)
    for key in totals:
        _kind, instance, _directive = key
        by_instance[instance].append(key)

    separator = "=" * 100
    for instance in sorted(by_instance):
        lines.extend(["", separator, f"Instance: {instance}", separator])
        for key in sorted(by_instance[instance], key=lambda item: (item[0], item[2])):
            kind, _instance, directive = key
            counts = totals[key]
            active_tests = set().union(*testers[key].values()) if testers[key] else set()
            if kind == "assert":
                status = assertion_status(counts)
                lines.append(
                    f"[{status:<7}] ASSERT {directive:<52} "
                    f"pass={counts['pass']:<6} fail={counts['fail']:<6} "
                    f"vacuous={counts['vacuous']:<6} attempts={counts['attempt']:<6} "
                    f"tests={len(active_tests)}"
                )
            else:
                status = cover_status(counts)
                lines.append(
                    f"[{status:<7}] COVER  {directive:<52} "
                    f"hits={counts['cover']:<6} tests={len(testers[key]['cover'])}"
                )

    return "\n".join(lines) + "\n"


def main() -> None:
    cov_work = sys.argv[1] if len(sys.argv) > 1 else "cov_work"
    outfile = sys.argv[2] if len(sys.argv) > 2 else "sva_coverage_report.txt"
    if len(sys.argv) > 3:
        sys.exit("Usage: extract_sva_coverage.py [cov_work_dir] [output_report]")

    script_dir = Path(__file__).parent
    converter = os.environ.get("UCD2SVA", str(script_dir / "ucd2sva"))
    if not os.path.isfile(converter) or not os.access(converter, os.X_OK):
        sys.exit(f"Error: executable converter {converter} not found — build with: make tools")

    ucd_files = find_ucd_files(cov_work)
    if not ucd_files:
        sys.exit(f"Error: no .ucd files found under {cov_work}/scope/")

    totals = defaultdict(Counter)
    testers = defaultdict(lambda: defaultdict(set))

    try:
        for ucd in ucd_files:
            test_name = ucd.parent.name
            for row in run_ucd2sva(converter, ucd):
                kind = row["kind"]
                if kind not in {"assert", "cover"}:
                    raise RuntimeError(f"unsupported SVA kind {kind!r} in {ucd}")
                key = (kind, row["instance"], row["directive"])
                bin_name = row["bin"]
                count = int(row["count"])
                totals[key][bin_name] += count
                if count > 0:
                    testers[key][bin_name].add(test_name)
    except (OSError, RuntimeError, ValueError) as err:
        sys.exit(f"Error: {err}")

    if not totals:
        sys.exit("Error: no per-instance SVA records found in the coverage database")

    report = format_report(ucd_files, totals, testers)
    try:
        Path(outfile).write_text(report, encoding="utf-8")
    except OSError as err:
        sys.exit(f"Error: cannot write report {outfile}: {err}")

    print("\n".join(report.splitlines()[:12]))
    print(f"\nReport written to: {outfile}")


if __name__ == "__main__":
    main()
