# Chapter 2 — Theoretical Background

> **Draft brief.** Protocol + methodology grounding so Ch.4–7 need not re-explain basics. Narrative +
> citations + one feature-matrix table; avoid code listings. Easiest chapter to write first — no RTL
> dependency. Sources: `phase1_spec_v2.md` §2–7, MIPI I3C Basic v1.1.1 spec, UVM 1.2 (Context7), specs 02/03.

## 2.1 I²C recap

**Brief.** Electrical model (open-drain + pull-ups, wired-AND), START/STOP, 7-bit addressing + R/W,
ACK/NACK, clock stretching. Frame the limitations I3C removes. One annotated address-byte figure.

> ┌─ FIGURE (Ch.2) — address byte ──────────────────────────────────────────────────────────
> │ Shows:  9-bit address byte A6..A0 + RnW + ACK, MSB first
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/address_byte.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.2 MIPI I3C Basic v1.1.1 (SDR, frame format)

**Brief.** I3C electrical changes (1.8 V LV-CMOS push-pull for data), SDR mode, the broadcast address
0x7E, the SDR private write/read frames, and **T-bit semantics** (odd-parity bit in writes;
end-of-data signalling bit in reads). Present the two SDR frame skeletons.

> ┌─ FIGURE (Ch.2/5) — SDR write frame ─────────────────────────────────────────────────────
> │ Shows:  S · addr+W · ACK · {data+T}×N · P   (T = odd parity)
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/sdr_write_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
> ┌─ FIGURE (Ch.2/5) — SDR read frame ──────────────────────────────────────────────────────
> │ Shows:  S · addr+R · ACK · {data,T=1}… {data,T=0} · P   (T = end-of-data)
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/sdr_read_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.3 Bus conditions (START / STOP / Sr)

**Brief.** Define START (SDA fall while SCL high), STOP (SDA rise while SCL high), repeated-START, and
bus-available/idle timing. Tie to the controller's `bus_monitor` and `scl_generator` later.

> ┌─ FIGURE F2.3 — bus conditions ──────────────────────────────────────────────────────────
> │ Shows:  START / repeated-START / STOP — SDA edge relative to SCL high
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/bus_conditions.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.4 Open-drain vs push-pull

**Brief.** Why address/ACK phases stay open-drain (legacy arbitration, hot devices) while data phases
go push-pull (speed). Define the OD→PP boundary and the role of a `sel_od_pp` select.

> ┌─ FIGURE F2.2 — OD vs PP phases ─────────────────────────────────────────────────────────
> │ Shows:  open-drain (addr/ACK) vs push-pull (data); OD→PP boundary; sel_od_pp signal
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/od_vs_pp.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.5 Dynamic address assignment (ENTDAA)

**Brief.** The ENTDAA algorithm from the master's perspective: broadcast 0x7E+W, the ENTDAA CCC, Sr,
then per-device 0x7E+R reading 64-bit {PID, BCR, DCR}, assigning a dynamic address + parity, ACK, looping
until no device responds. Set up Ch.5.7's two-FSM implementation.

> ┌─ FIGURE F2.4 — ENTDAA arbitration ──────────────────────────────────────────────────────
> │ Shows:  7E+W·ACK·CCC·Sr·7E+R · 64-bit PID+BCR+DCR · dyn-addr+parity · ACK loop
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/entdaa_arbitration.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.6 CCC overview

**Brief.** Common Command Codes: broadcast vs direct framing; the subset this controller supports
(ENTDAA 0x07, ENEC/DISEC broadcast + direct). One frame-shape figure.

> ┌─ FIGURE (Ch.2) — CCC frame ─────────────────────────────────────────────────────────────
> │ Shows:  broadcast + direct CCC frame format
> │ Source: phase1_spec_v2.md · Render: WaveDrom (bus/ccc_frame.json) · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 2.7 I3C-vs-I²C comparison

**Brief.** A consolidated feature-matrix table: speed, electrical, addressing, IBI, CCCs, in-band
interrupts, backward compatibility. Mark which rows are in this design's scope.

> [TABLE T2.1 — I3C-vs-I²C feature matrix · source: MIPI spec]  (NOT YET FILLED)
> [TABLE T2.2 — SDR + I²C-FM timing parameters · source: phase1_spec_v2.md]  (NOT YET FILLED)

## 2.8 UVM 1.2 methodology overview

**Brief.** Component model (test → env → agent {driver/monitor/sequencer} → sequence), TLM analysis
ports, `uvm_config_db`, factory. Just enough to ground Ch.6–7. Cite Accellera UVM 1.2 (verify current
details via Context7 at write time).

> ┌─ FIGURE F2.5 — UVM testbench layering ──────────────────────────────────────────────────
> │ Shows:  test→env→agents→sequencer/driver/monitor; TLM ports
> │ Render: TikZ · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────
