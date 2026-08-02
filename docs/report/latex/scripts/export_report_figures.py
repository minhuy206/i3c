#!/usr/bin/env python3
"""Export TeX/TikZ figures and annotated waveforms as presentation-ready PNG files."""

from __future__ import annotations

import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageStat


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "figures/png"


@dataclass(frozen=True)
class Figure:
    number: str
    title: str
    kind: str
    source: str

    @property
    def stem(self) -> str:
        safe = self.title.lower().replace(" ", "_").replace("/", "_")
        return f"fig_{self.number.replace('.', '_')}_{safe}"


FIGURES = (
    Figure("2.1", "start_repeated_start_stop", "tex", "start_repeated_start_stop.tex"),
    Figure("2.2", "i3c_low_handoff", "tex", "i3c_low_handoff_timing.tex"),
    Figure("2.3", "i3c_read_takeover", "tex", "i3c_read_takeover_timing.tex"),
    Figure("2.4", "sdr_private_write_read", "tex", "sdr_private_transfer_frame.tex"),
    Figure("2.5", "entdaa_frame", "tex", "entdaa_frame.tex"),
    Figure("2.6", "enec_disec_frames", "tex", "ccc_frames.tex"),
    Figure("3.1", "controller_architecture", "tex", "i3c_controller_top_architecture_tikz.tex"),
    Figure("3.2", "csr_fifo_handshake", "tex", "csr_queue_handshake.tex"),
    Figure("3.3", "transaction_processor_flow", "tex", "i3c_primary_controller_fsm.tex"),
    Figure("3.4", "entdaa_processor_flow", "tex", "entdaa_fsm.tex"),
    Figure("4.1", "uvm_architecture", "tex", "uvm_i3c_verification_architecture_with_legend.tex"),
    Figure("4.2", "scoreboard_flow", "tex", "i3c_scoreboard_flow_tikz.tex"),
    Figure("4.3", "virtual_sequence_coordination", "tex", "vseq_two_agent_sequence.tex"),
    Figure("5.1", "i3c_write_waveform", "tex", "result_i3c_write_waveform.tex"),
    Figure("5.2", "i3c_read_abort_waveform", "tex", "result_i3c_read_abort_waveform.tex"),
    Figure("5.3", "enec_broadcast_waveform", "tex", "result_enec_broadcast_waveform.tex"),
    Figure("5.4", "enec_direct_waveform", "tex", "result_enec_direct_waveform.tex"),
    Figure("5.5", "entdaa_part1_waveform", "tex", "result_entdaa_part1_waveform.tex"),
    Figure("5.6", "entdaa_part2_waveform", "tex", "result_entdaa_part2_waveform.tex"),
    Figure("5.7", "entdaa_part3_waveform", "tex", "result_entdaa_part3_waveform.tex"),
    Figure("5.8", "i2c_write_waveform", "tex", "result_i2c_write_waveform.tex"),
)


PREAMBLE = r"""\documentclass[border=6pt]{standalone}
\usepackage{fontspec}
\setmainfont{Times New Roman}
\usepackage{graphicx}
\graphicspath{{figures/}}
\usepackage[export]{adjustbox}
\usepackage[table,xcdraw]{xcolor}
\usepackage{tikz}
\usetikzlibrary{calc,automata,positioning,arrows.meta,shapes.geometric,chains,fit,backgrounds,patterns}
\usepackage{circuitikz}
\usepackage{tikz-timing}
\usepackage{myacronyms}
\usepackage{thesisterms}
\setlength{\textwidth}{165mm}
\begin{document}
"""


def run(command: list[str], cwd: Path) -> None:
    result = subprocess.run(command, cwd=cwd, text=True, capture_output=True)
    if result.returncode:
        detail = result.stdout[-3000:] + result.stderr[-3000:]
        raise RuntimeError(f"Command failed: {' '.join(command)}\n{detail}")


def render_tex(fig: Figure, temp: Path, destination: Path) -> None:
    wrapper = temp / f"{fig.stem}.tex"
    wrapper.write_text(PREAMBLE + f"\\input{{figures/{fig.source}}}\n\\end{{document}}\n")
    run(
        [
            "xelatex",
            "-interaction=nonstopmode",
            "-halt-on-error",
            f"-output-directory={temp}",
            str(wrapper),
        ],
        ROOT,
    )
    pdf = temp / f"{fig.stem}.pdf"
    prefix = temp / fig.stem
    run(
        ["pdftocairo", "-png", "-transp", "-singlefile", "-r", "220", str(pdf), str(prefix)],
        ROOT,
    )
    destination.write_bytes((temp / f"{fig.stem}.png").read_bytes())


def validate(path: Path) -> tuple[int, int, float, float]:
    with Image.open(path) as image:
        rgb = image.convert("RGB")
        mean = sum(ImageStat.Stat(rgb).mean) / 3
        if image.width < 100 or image.height < 50:
            raise ValueError(f"Suspiciously small image: {path} ({image.size})")
        if mean > 254.8:
            raise ValueError(f"Image appears blank: {path}")
        alpha = image.getchannel("A")
        transparent = alpha.histogram()[0] / (image.width * image.height)
        if transparent == 0:
            raise ValueError(f"Image has no transparent background: {path}")
        return image.width, image.height, mean, transparent


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for stale in OUTPUT.glob("fig_*.png"):
        stale.unlink()
    with tempfile.TemporaryDirectory(prefix="i3c-report-figures-") as tmp:
        temp = Path(tmp)
        rows = []
        for fig in FIGURES:
            destination = OUTPUT / f"{fig.stem}.png"
            render_tex(fig, temp, destination)
            width, height, mean, transparent = validate(destination)
            rows.append(
                f"{fig.number}\t{fig.title}\t{destination.name}\t{width}x{height}"
                f"\t{mean:.1f}\t{transparent:.1%}"
            )

    manifest = "figure\ttitle\tfile\tsize\tmean_rgb\ttransparent\n" + "\n".join(rows) + "\n"
    (OUTPUT / "manifest.tsv").write_text(manifest)
    print(f"Exported and validated {len(FIGURES)} figures in {OUTPUT}")


if __name__ == "__main__":
    main()
