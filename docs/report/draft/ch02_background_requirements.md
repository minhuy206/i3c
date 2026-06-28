# Chapter 2 — Theoretical Background and System Requirements

> **Draft brief.** ~9 pages ⚠️ (page risk — keep §2.1 short, prefer the comparison/timing tables over
> prose). This is the "theoretical basis" chapter; the system-requirements/specification content is folded
> in as the closing sections (§2.9–2.13). Protocol + methodology grounding so Ch.3–4 need not re-explain
> basics. Narrative + citations + feature-matrix table; avoid code listings. Easiest chapter to write first
> — no RTL dependency. Sources: `phase1_spec_v2.md` §2–7 + §1/§7/§9–10, MIPI I3C Basic v1.1.1 spec, UVM 1.2
> (Context7), specs 02/03/07, outline §3–4.

---
## Part A — Theoretical background
---

## 2.1 I²C recap

**Brief.** Electrical model (Open Drain (OD) + pull-ups, wired-AND), START/STOP, 7-bit addressing +
RnW (Read/Write) bit, ACK/NACK, clock stretching. Frame the limitations I3C removes. One annotated
address-byte figure. *(Keep this section tight — it is the first lever if the chapter overflows.)*

> ┌─ FIGURE (Ch.2) — address byte ──────────────────────────────────────────────────────────
> │ Shows:  9-bit address byte A6..A0 + RnW + ACK, MSB first
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/address_byte.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.2 MIPI I3C Basic v1.1.1 (SDR, frame format)

**Brief.** I3C electrical changes (1.8 V LV-CMOS Push-Pull (PP) for data), SDR (Single Data Rate) Mode,
the I3C Broadcast Address (7'h7E), the SDR private write/read frames, and **T-Bit (Transition Bit)
semantics** (odd-parity value in writes; end-of-data signalling value in reads). Present the two SDR
frame skeletons.

> ┌─ FIGURE (Ch.2/3) — SDR write frame ─────────────────────────────────────────────────────
> │ Shows:  S · addr+W · ACK · {data+T}×N · P   (T = odd parity)
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/sdr_write_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE (Ch.2/3) — SDR read frame ──────────────────────────────────────────────────────
> │ Shows:  S · addr+R · ACK · {data,T=1}… {data,T=0} · P   (T = end-of-data)
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/sdr_read_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.3 Bus conditions (START / Repeated START (Sr) / STOP)

**Brief.** Define START (SDA fall while SCL high), STOP (SDA rise while SCL high), Repeated START (Sr),
and the three distinct **Bus Free / Bus Available / Bus Idle Conditions** (spec §5.1.3.2 — do not merge
them). Tie to the Controller's `bus_monitor` and `scl_generator` later (§3.11/§3.12).

> ┌─ FIGURE F2.3 — bus conditions ──────────────────────────────────────────────────────────
> │ Shows:  START / Repeated START (Sr) / STOP — SDA edge relative to SCL high
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/bus_conditions.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.4 Open Drain vs Push-Pull

**Brief.** Why address/ACK phases stay Open Drain (OD) (legacy arbitration, hot devices) while data
phases go Push-Pull (PP) (speed). Define the OD→PP boundary and the role of a `sel_od_pp` select.

> ┌─ FIGURE F2.2 — OD vs PP phases ─────────────────────────────────────────────────────────
> │ Shows:  Open Drain (OD) (addr/ACK) vs Push-Pull (PP) (data); OD→PP boundary; sel_od_pp signal
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/od_vs_pp.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.5 Dynamic Address Assignment (DAA) via ENTDAA

**Brief.** The Dynamic Address Assignment (DAA) algorithm from the Controller's perspective: broadcast
0x7E+W, the ENTDAA CCC, Repeated START (Sr), then per-Target 0x7E+R reading the 64-bit {Provisioned ID
(PID), Bus Characteristics Register (BCR), Device Characteristics Register (DCR)}, assigning a Dynamic
Address + parity, ACK, looping until no Target responds. Set up §3.14's two-FSM implementation.

> ┌─ FIGURE F2.4 — ENTDAA arbitration ──────────────────────────────────────────────────────
> │ Shows:  7E+W·ACK·CCC·Sr·7E+R · 64-bit PID+BCR+DCR · dyn-addr+parity · ACK loop
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/entdaa_arbitration.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.6 CCC overview

**Brief.** Common Command Codes (CCC): Broadcast CCC vs Direct CCC framing; the subset this Controller
supports (ENTDAA 0x07, ENEC/DISEC broadcast + direct). One frame-shape figure.

> ┌─ FIGURE (Ch.2) — CCC frame ─────────────────────────────────────────────────────────────
> │ Shows:  Broadcast CCC + Direct CCC frame format
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/ccc_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.7 I3C-vs-I²C comparison

**Brief.** A consolidated feature-matrix table: speed, electrical, addressing, In-Band Interrupt (IBI),
CCCs, Hot-Join, backward compatibility. Mark which rows are in this design's scope.

> [TABLE T2.1 — I3C-vs-I²C feature matrix · source: MIPI spec]  (NOT YET FILLED)
> [TABLE T2.2 — SDR + I²C-FM timing parameters · source: phase1_spec_v2.md]  (NOT YET FILLED)

## 2.8 UVM 1.2 methodology overview

**Brief.** Maximum half a page defining only the UVM vocabulary required by the verification requirements:
test, sequence, agent, driver, monitor, sequencer, scoreboard, coverage collector, and TLM analysis port.
The project-specific topology, configuration, and signal flow belong only in Ch.4. Cite Accellera UVM 1.2
(verify current details via Context7 at write time); do not add a second topology figure here.

---
## Part B — System requirements and specifications
---

> **Brief (part).** Concrete, testable spec that Ch.3 satisfies and Ch.4 verifies. Dominant format =
> bullet lists + tables; avoid long prose. Sources: `phase1_spec_v2.md` §1/§7/§9–10, outline §3–4, spec 07.

## 2.9 Functional requirements

**Brief.** Enumerate the required behaviours as testable line items: SDR private write, SDR private read,
Immediate Data Transfer (≤4 inline bytes carried in the Command Descriptor), I²C-FM legacy write/read,
START / Repeated START (Sr) / STOP generation + Bus Free Condition detection, OD↔PP phase switching,
ENTDAA multi-Target DAA loop, ENEC/DISEC (broadcast + direct), 32-bit register read/write contract,
Response Queue + RX Data Buffer reporting.

> [TABLE T2.3 — functional requirements list · source: phase1_spec_v2.md §7]  (NOT YET FILLED)

## 2.10 Out-of-scope features

**Brief.** Restate the deliberate exclusions with one-line rationale each (In-Band Interrupt (IBI),
Hot-Join, HDR, FM+, Secondary Controller / multi-Controller, Target mode, bus recovery, Device
Characteristics Table (DCT), other CCCs, full HCI compliance). Cross-reference §1.3.

> [TABLE T2.5 — out-of-scope features + rationale · source: scope analysis]  (NOT YET FILLED)

## 2.11 Performance targets

**Brief.** SCL targets: SDR ≤12.5 MHz, I²C-FM 400 kHz. System clock ≥333 MHz (single domain) so the
counter-based SCL timing meets tSCO and the OD/PP timing windows. State the default timing-CSR values
(for example, T_LOW=16 and T_HIGH=11) and derive the corresponding ns values and SCL margin.

> [TABLE T2.4 — performance targets + timing-CSR defaults · source: improvements.md, csr_registers.sv]  (NOT YET FILLED)

## 2.12 SW-visible interface (32-bit register bus)

**Brief.** Define the simple (non-AXI/AHB) register contract: write = `reg_addr_i[11:0]` +
`reg_wdata_i[31:0]` + `reg_wen_i`; read = `reg_addr_i[11:0]` + `reg_ren_i` → `reg_rdata_o[31:0]` +
`reg_ready_o`. Note Command Descriptor 2-DWORD staging and the TX/RX Data Buffer read/write windows.

> ┌─ FIGURE F2.6 — register-bus read/write protocol ────────────────────────────────────────
> │ Shows:  single-cycle write handshake + read-with-ready timing on the 32-bit reg bus
> │ Source: csr_registers.sv · Render: WaveDrom or TikZ timing · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.13 Verification requirements

**Brief.** Verification closure criteria: directed vseqs per category pass; scoreboard cross-checks
(cmd/resp/rx/csr/dat) clean; SystemVerilog Assertions (SVA) bound and silent; regression targets green.
List the error codes the design is required to generate so the scoreboard can be checked against them.

> [TABLE T2.x — generated error-status codes: 0x0, 0x4, 0x5, 0x6, 0x7, 0x8, 0xA · source: phase1_spec_v2.md §9.4]  (NOT YET FILLED)

> **Note.** Only the *generated* error-code set above is in scope — do not claim codes the RTL never emits.
> Present this error-code table once (here or in §3.7) — not twice.
