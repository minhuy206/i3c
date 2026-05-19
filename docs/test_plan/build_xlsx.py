#!/usr/bin/env python3
"""
build_xlsx.py — Generate I3C_Testplan.xlsx from I3C_Testplan.md
Uses only Python stdlib (zipfile + xml.etree / string building).
Run: python3 docs/test_plan/build_xlsx.py
"""
import re
import zipfile
import os
import sys
from xml.sax.saxutils import escape

MD_PATH = os.path.join(os.path.dirname(__file__), "I3C_Testplan.md")
XLSX_PATH = os.path.join(os.path.dirname(__file__), "I3C_Testplan.xlsx")


# ---------------------------------------------------------------------------
# Markdown parser helpers
# ---------------------------------------------------------------------------

def parse_md_table(lines):
    """Parse a markdown table from a list of lines; return list-of-list of strings."""
    rows = []
    for line in lines:
        line = line.strip()
        if not line.startswith("|"):
            continue
        # skip separator rows like |---|---|
        if re.match(r"^\|[-| :]+\|$", line):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        rows.append(cells)
    return rows


def extract_section_tables(md_text, section_re):
    """
    Find the section matching section_re and collect all markdown table rows
    within it (stopping at the next same-or-higher-level heading).
    Returns list-of-list-of-strings.
    """
    lines = md_text.splitlines()
    in_section = False
    section_level = 0
    table_rows = []
    current_category = ""
    results = []  # (category, rows_for_this_table)

    for line in lines:
        # Detect target section
        m = re.match(r"^(#{1,6})\s+(.*)", line)
        if m:
            level = len(m.group(1))
            heading = m.group(2)
            if re.search(section_re, heading, re.IGNORECASE):
                in_section = True
                section_level = level
                continue
            elif in_section and level <= section_level:
                # Exited the section
                break
            elif in_section:
                # Sub-section heading — extract category name
                current_category = heading
                continue

        if not in_section:
            continue

        if line.strip().startswith("|"):
            # separator row
            if re.match(r"^\s*\|[-| :]+\|\s*$", line):
                continue
            cells = [c.strip() for c in line.strip().strip("|").split("|")]
            results.append((current_category, cells))

    return results


# ---------------------------------------------------------------------------
# TestCase sheet data (Sections 4.1–4.16)
# ---------------------------------------------------------------------------

def collect_test_cases(md_text):
    """
    Collect all functional test case rows from sections 4.x.
    Returns list of dicts with keys:
      category, no, test_item, test_name, description,
      test_flow, pass_condition, priority, related_module, coverage_tags
    """
    lines = md_text.splitlines()
    in_section4 = False
    current_category = ""
    rows = []
    header_seen = False

    for line in lines:
        m = re.match(r"^(#{1,6})\s+(.*)", line)
        if m:
            level = len(m.group(1))
            heading = m.group(2)
            # Enter Section 4
            if re.match(r"^4\.\s+Test Plan", heading, re.IGNORECASE):
                in_section4 = True
                continue
            # Exit at Section 5 or higher-level
            if in_section4 and level <= 2 and re.match(r"^[5-9]|^10", heading):
                break
            # Sub-section → update category
            if in_section4 and level == 3:
                # e.g. "4.1 Category 1 — Register Interface Tests"
                cat_m = re.match(r"4\.\d+\s+Category\s+\d+\s+[—–-]+\s+(.*)", heading)
                if cat_m:
                    current_category = cat_m.group(1).strip()
                else:
                    current_category = heading.strip()
                header_seen = False
            continue

        if not in_section4:
            continue

        if not line.strip().startswith("|"):
            continue

        # skip separator
        if re.match(r"^\s*\|[-| :]+\|\s*$", line):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]

        # First non-separator row is the header
        if not header_seen:
            header_seen = True
            continue  # skip header row

        if len(cells) < 8:
            continue

        # Pad cells to 9
        while len(cells) < 9:
            cells.append("")

        row = {
            "category": current_category,
            "no": cells[0],
            "test_item": cells[1],
            "test_name": cells[2],
            "description": cells[3],
            "test_flow": cells[4],
            "pass_condition": cells[5],
            "priority": cells[6],
            "related_module": cells[7],
            "coverage_tags": cells[8] if len(cells) > 8 else "",
        }
        rows.append(row)

    return rows


# ---------------------------------------------------------------------------
# Performance sheet data (Section 5)
# ---------------------------------------------------------------------------

def collect_perf_overview(md_text):
    """Extract performance overview table from Section 5.1."""
    lines = md_text.splitlines()
    in_sec = False
    rows = []
    header_seen = False

    for line in lines:
        m = re.match(r"^#{1,6}\s+(.*)", line)
        if m:
            h = m.group(1)
            if re.search(r"5\.1.*Performance Categor", h, re.IGNORECASE):
                in_sec = True
                continue
            elif in_sec and re.search(r"5\.\d", h):
                break
            elif in_sec and re.match(r"^[6-9]|^1[0-9]", h):
                break
            continue

        if not in_sec:
            continue
        if not line.strip().startswith("|"):
            continue
        if re.match(r"^\s*\|[-| :]+\|\s*$", line):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not header_seen:
            header_seen = True
            continue
        rows.append(cells)

    return rows


def collect_perf_tests(md_text):
    """Extract performance test cases from Section 5.2."""
    lines = md_text.splitlines()
    in_sec = False
    rows = []
    header_seen = False

    for line in lines:
        m = re.match(r"^#{1,6}\s+(.*)", line)
        if m:
            h = m.group(1)
            if re.search(r"5\.2.*Performance Test", h, re.IGNORECASE):
                in_sec = True
                continue
            elif in_sec and re.match(r"^[6-9]", h):
                break
            continue

        if not in_sec:
            continue
        if not line.strip().startswith("|"):
            continue
        if re.match(r"^\s*\|[-| :]+\|\s*$", line):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if not header_seen:
            header_seen = True
            continue
        rows.append(cells)

    return rows


# ---------------------------------------------------------------------------
# Coverage sheet data (Section 6)
# ---------------------------------------------------------------------------

def collect_coverage(md_text):
    """Extract coverpoints and crosses from Section 6."""
    lines = md_text.splitlines()
    in_sec = False
    coverpoints = []
    crosses = []
    in_cp_table = False
    in_cross_table = False
    cp_header = False
    cross_header = False

    for line in lines:
        m = re.match(r"^#{1,6}\s+(.*)", line)
        if m:
            h = m.group(1)
            if re.search(r"6\.1.*Coverpoints", h, re.IGNORECASE):
                in_sec = True
                in_cp_table = True
                in_cross_table = False
                cp_header = False
                continue
            elif re.search(r"6\.2.*Cross", h, re.IGNORECASE):
                in_sec = True
                in_cp_table = False
                in_cross_table = True
                cross_header = False
                continue
            elif in_sec and re.match(r"^[7-9]|^1[0-9]", h):
                break
            continue

        if not in_sec:
            continue
        if not line.strip().startswith("|"):
            continue
        if re.match(r"^\s*\|[-| :]+\|\s*$", line):
            continue

        cells = [c.strip() for c in line.strip().strip("|").split("|")]

        if in_cp_table:
            if not cp_header:
                cp_header = True
                continue
            coverpoints.append(cells)

        if in_cross_table:
            if not cross_header:
                cross_header = True
                continue
            crosses.append(cells)

    return coverpoints, crosses


# ---------------------------------------------------------------------------
# OOXML builder
# ---------------------------------------------------------------------------

CONTENT_TYPES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet2.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet3.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/worksheets/sheet4.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
  <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
</Types>"""

RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>"""

WORKBOOK = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"
          xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="TestCase" sheetId="1" r:id="rId1"/>
    <sheet name="Coverage" sheetId="2" r:id="rId2"/>
    <sheet name="Performance" sheetId="3" r:id="rId3"/>
    <sheet name="Performance test" sheetId="4" r:id="rId4"/>
  </sheets>
</workbook>"""

WORKBOOK_RELS = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet2.xml"/>
  <Relationship Id="rId3" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet3.xml"/>
  <Relationship Id="rId4" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet4.xml"/>
  <Relationship Id="rId5" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>
  <Relationship Id="rId6" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Workbook_RELS>""".replace("</Workbook_RELS>", "</Relationships>")

STYLES = """<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font><sz val="11"/><name val="Calibri"/></font>
    <font><sz val="11"/><b/><name val="Calibri"/></font>
  </fonts>
  <fills count="2">
    <fill><patternFill patternType="none"/></fill>
    <fill><patternFill patternType="gray125"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="3">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0">
      <alignment wrapText="1"/>
    </xf>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0">
      <alignment wrapText="1"/>
    </xf>
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0">
      <alignment wrapText="1" vertical="top"/>
    </xf>
  </cellXfs>
</styleSheet>"""


class SharedStrings:
    def __init__(self):
        self._strings = []
        self._index = {}

    def idx(self, s):
        s = str(s)
        if s not in self._index:
            self._index[s] = len(self._strings)
            self._strings.append(s)
        return self._index[s]

    def xml(self):
        count = len(self._strings)
        parts = [
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
            f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{count}" uniqueCount="{count}">',
        ]
        for s in self._strings:
            parts.append(f'<si><t xml:space="preserve">{escape(s)}</t></si>')
        parts.append("</sst>")
        return "\n".join(parts)


def col_name(n):
    """0-indexed column number to Excel column letter (A, B, ..., Z, AA, ...)"""
    name = ""
    n += 1
    while n > 0:
        n, r = divmod(n - 1, 26)
        name = chr(65 + r) + name
    return name


def build_sheet(rows_of_cells, ss, header_row=None):
    """
    Build a worksheet XML string.
    rows_of_cells: list of list of str
    ss: SharedStrings instance
    header_row: if provided, first row uses bold style (s="1")
    """
    parts = [
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>',
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
        '<sheetData>',
    ]

    all_rows = []
    if header_row:
        all_rows.append((header_row, True))
    for r in rows_of_cells:
        all_rows.append((r, False))

    for row_idx, (cells, is_header) in enumerate(all_rows, start=1):
        parts.append(f'<row r="{row_idx}">')
        for col_idx, cell_val in enumerate(cells):
            cell_ref = f"{col_name(col_idx)}{row_idx}"
            style = 1 if is_header else 2
            si = ss.idx(cell_val)
            parts.append(f'<c r="{cell_ref}" t="s" s="{style}"><v>{si}</v></c>')
        parts.append("</row>")

    parts.extend(["</sheetData>", "</worksheet>"])
    return "\n".join(parts)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    if not os.path.exists(MD_PATH):
        print(f"ERROR: {MD_PATH} not found", file=sys.stderr)
        sys.exit(1)

    with open(MD_PATH, encoding="utf-8") as f:
        md_text = f.read()

    ss = SharedStrings()

    # ---- Sheet 1: TestCase ----
    test_cases = collect_test_cases(md_text)
    tc_header = ["Category", "No", "Test Item", "Test Name", "Description",
                 "Test flow", "Pass Condition", "Priority", "Related Module", "Coverage Tags"]
    prev_category = ""
    tc_rows = []
    for tc in test_cases:
        cat = tc["category"] if tc["category"] != prev_category else ""
        prev_category = tc["category"]
        tc_rows.append([
            cat,
            tc["no"],
            tc["test_item"],
            tc["test_name"],
            tc["description"],
            tc["test_flow"],
            tc["pass_condition"],
            tc["priority"],
            tc["related_module"],
            tc["coverage_tags"],
        ])

    sheet1_xml = build_sheet(tc_rows, ss, header_row=tc_header)

    # ---- Sheet 2: Coverage ----
    coverpoints, crosses = collect_coverage(md_text)
    cov_rows = []
    cov_rows.append(["Coverpoints", "", ""])
    for cp in coverpoints:
        while len(cp) < 3:
            cp.append("")
        cov_rows.append(["", cp[0], cp[2] if len(cp) > 2 else ""])
    cov_rows.append(["", "", ""])
    cov_rows.append(["Cross coverage", "", ""])
    for cx in crosses:
        while len(cx) < 3:
            cx.append("")
        cov_rows.append(["", cx[0], cx[2] if len(cx) > 2 else ""])
    cov_header = ["Section", "Name / Cross", "Bins / Description"]
    sheet2_xml = build_sheet(cov_rows, ss, header_row=cov_header)

    # ---- Sheet 3: Performance ----
    perf_overview = collect_perf_overview(md_text)
    perf_header = ["Category", "What to Measure", "Notes"]
    sheet3_xml = build_sheet(perf_overview, ss, header_row=perf_header)

    # ---- Sheet 4: Performance test ----
    perf_tests = collect_perf_tests(md_text)
    pt_header = ["No", "Category", "Test Name", "Description", "Main Metric"]
    sheet4_xml = build_sheet(perf_tests, ss, header_row=pt_header)

    # ---- Write XLSX ----
    with zipfile.ZipFile(XLSX_PATH, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("[Content_Types].xml", CONTENT_TYPES)
        zf.writestr("_rels/.rels", RELS)
        zf.writestr("xl/workbook.xml", WORKBOOK)
        zf.writestr("xl/_rels/workbook.xml.rels", WORKBOOK_RELS)
        zf.writestr("xl/styles.xml", STYLES)
        zf.writestr("xl/sharedStrings.xml", ss.xml())
        zf.writestr("xl/worksheets/sheet1.xml", sheet1_xml)
        zf.writestr("xl/worksheets/sheet2.xml", sheet2_xml)
        zf.writestr("xl/worksheets/sheet3.xml", sheet3_xml)
        zf.writestr("xl/worksheets/sheet4.xml", sheet4_xml)

    print(f"Generated {XLSX_PATH}")
    print(f"  TestCase sheet:       {len(tc_rows)} rows")
    print(f"  Coverage sheet:       {len(cov_rows)} rows ({len(coverpoints)} coverpoints, {len(crosses)} crosses)")
    print(f"  Performance sheet:    {len(perf_overview)} rows")
    print(f"  Performance test:     {len(perf_tests)} rows")
    print(f"  Shared strings:       {len(ss._strings)}")


if __name__ == "__main__":
    main()
