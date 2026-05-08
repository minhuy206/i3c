// i3c_csr_addr_pkg.sv
// CSR address offsets and field positions for i3c_controller_top
// Source of truth: src/csr/csr_register.sv (lines 74-91)
// WARNING: Any CSR map change in RTL must be reflected here manually

`ifndef I3C_CSR_ADDR_PKG_SV
`define I3C_CSR_ADDR_PKG_SV

package i3c_csr_addr_pkg;

  // ──────────────────────────────────────────────
  // 1. Address Offsets
  // ──────────────────────────────────────────────

  // Control & Status
  localparam bit [11:0] ADDR_HC_CONTROL = 12'h000;
  localparam bit [11:0] ADDR_HC_STATUS = 12'h004;

  // Timing Registers
  localparam bit [11:0] ADDR_T_R = 12'h010;
  localparam bit [11:0] ADDR_T_F = 12'h014;
  localparam bit [11:0] ADDR_T_LOW = 12'h018;
  localparam bit [11:0] ADDR_T_HIGH = 12'h01C;
  localparam bit [11:0] ADDR_T_SU_STA = 12'h020;
  localparam bit [11:0] ADDR_T_HD_STA = 12'h024;
  localparam bit [11:0] ADDR_T_SU_STO = 12'h028;
  localparam bit [11:0] ADDR_T_SU_DAT = 12'h02C;
  localparam bit [11:0] ADDR_T_HD_DAT = 12'h030;

  // Queue Ports
  localparam bit [11:0] ADDR_CMD_QUEUE = 12'h100;
  localparam bit [11:0] ADDR_TX_DATA = 12'h104;
  localparam bit [11:0] ADDR_RX_DATA = 12'h108;
  localparam bit [11:0] ADDR_RESP = 12'h10C;
  localparam bit [11:0] ADDR_QUEUE_STATUS = 12'h110;

  // Device Address Table
  localparam bit [11:0] ADDR_DAT_BASE = 12'h200;
  localparam bit [11:0] ADDR_DAT_END = 12'h240;
  localparam int unsigned DAT_DEPTH = 16;

  // ──────────────────────────────────────────────
  // 2. Field Bit Positions
  // ──────────────────────────────────────────────

  // HC_CONTROL
  localparam int HC_CTRL_ENABLE_BIT = 0;
  localparam int HC_CTRL_SW_RESET_BIT = 1;

  // HC_STATUS
  localparam int HC_STS_FSM_IDLE_BIT = 0;
  localparam int HC_STS_CMD_FULL_BIT = 1;
  localparam int HC_STS_RESP_EMPTY_BIT = 2;

  // QUEUE_STATUS
  localparam int QS_CMD_FULL_BIT = 0;
  localparam int QS_CMD_EMPTY_BIT = 1;
  localparam int QS_TX_FULL_BIT = 2;
  localparam int QS_TX_EMPTY_BIT = 3;
  localparam int QS_RX_FULL_BIT = 4;
  localparam int QS_RX_EMPTY_BIT = 5;
  localparam int QS_RESP_FULL_BIT = 6;
  localparam int QS_RESP_EMPTY_BIT = 7;

  // ──────────────────────────────────────────────
  // 3. Timing Register Reset Values
  // ──────────────────────────────────────────────
  // All values in system clock cycles @ 100 MHz simulation clock
  // Match reset values in src/csr/csr_register.sv

  localparam bit [19:0] RST_T_R = 20'd4;
  localparam bit [19:0] RST_T_F = 20'd4;
  localparam bit [19:0] RST_T_LOW = 20'd13;
  localparam bit [19:0] RST_T_HIGH = 20'd13;
  localparam bit [19:0] RST_T_SU_STA = 20'd13;
  localparam bit [19:0] RST_T_HD_STA = 20'd13;
  localparam bit [19:0] RST_T_SU_STO = 20'd13;
  localparam bit [19:0] RST_T_SU_DAT = 20'd1;
  localparam bit [19:0] RST_T_HD_DAT = 20'd4;

  // ──────────────────────────────────────────────
  // 4. Helper Functions
  // ──────────────────────────────────────────────

  // Compute DAT entry address from 0-based index
  // Usage: csr_wr(dat_addr(0), dat_entry);  // writes index 0
  function automatic bit [11:0] dat_addr(int unsigned index);
`ifndef SYNTHESIS
    assert (index < DAT_DEPTH)
    else $fatal(1, "dat_addr: index %0d exceeds DAT_DEPTH %0d", index, DAT_DEPTH);
`endif
    return ADDR_DAT_BASE + bit'(index << 2);
  endfunction

endpackage : i3c_csr_addr_pkg

`endif  // I3C_CSR_ADDR_PKG_SV
