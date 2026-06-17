# Chapter 3 — System Requirements and Specifications

> **Draft brief.** Concrete, testable spec that Ch.4–5 satisfy and Ch.6–7 verify. Dominant format =
> bullet lists + tables; avoid long prose. Sources: `phase1_spec_v2.md` §1/§7/§9–10, outline §3–4, spec 07.

## 3.1 Functional requirements

**Brief.** Enumerate the required behaviours as testable line items: SDR private write, SDR private read,
immediate data transfer (≤4 inline bytes carried in the CMD descriptor), I²C-FM legacy write/read,
START/Sr/STOP generation + bus-idle detection, OD↔PP phase switching, ENTDAA multi-device DAA loop,
ENEC/DISEC (broadcast + direct), 32-bit register read/write contract, response + RX FIFO reporting.

> [TABLE T3.1 — functional requirements list · source: phase1_spec_v2.md §7]  (NOT YET FILLED)

## 3.2 Out-of-scope features

**Brief.** Restate the deliberate exclusions with one-line rationale each (IBI, Hot-Join, HDR, FM+,
multi-master, target mode, bus recovery, DCT, other CCCs, full HCI compliance). Cross-reference §1.3.

> [TABLE T3.3 — out-of-scope features + rationale · source: scope analysis]  (NOT YET FILLED)

## 3.3 Performance targets

**Brief.** SCL targets: SDR ≤12.5 MHz, I²C-FM 400 kHz. System clock ≥333 MHz (single domain) so the
counter-based SCL timing meets tSCO and the OD/PP timing windows. State the default timing-CSR values
(T_LOW/T_HIGH counts) that yield 12.5 MHz, and the derivation.

> [TABLE T3.2 — performance targets + timing-CSR defaults · source: improvements.md, csr_registers.sv]  (NOT YET FILLED)

## 3.4 SW-visible interface (32-bit register bus)

**Brief.** Define the simple (non-AXI/AHB) register contract: write = `reg_addr_i[11:0]` +
`reg_wdata_i[31:0]` + `reg_wen_i`; read = `reg_addr_i[11:0]` + `reg_ren_i` → `reg_rdata_o[31:0]` +
`reg_ready_o`. Note CMD descriptor 2-DWORD staging and the data-FIFO read/write windows.

> ┌─ FIGURE F3.1 — register-bus read/write protocol ────────────────────────────────────────
> │ Shows:  single-cycle write handshake + read-with-ready timing on the 32-bit reg bus
> │ Source: csr_registers.sv · Render: WaveDrom or TikZ timing · NOT YET DRAWN
> └──────────────────────────────────────────────────────────────────────────────────────────

## 3.5 Verification requirements

**Brief.** Phase-1 closure criteria: directed vseqs per category pass; scoreboard cross-checks
(cmd/resp/rx/csr/dat) clean; SVA bound and silent; regression targets green. List the error codes the
design is required to generate so the scoreboard can be checked against them.

> [TABLE T3.x — generated error-status codes: 0x0, 0x4, 0x5, 0x6, 0x7, 0x8, 0xA · source: phase1_spec_v2.md §9.4]  (NOT YET FILLED)

> **Note.** Only the *generated* error-code set above is in scope — do not claim codes the RTL never emits.
