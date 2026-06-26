// i3c_csr_addr_pkg.sv
// CSR address offsets and field positions for i3c_controller_top
// Source of truth: src/csr/csr_register.sv (lines 74-91)
// WARNING: Any CSR map change in RTL must be reflected here manually

`ifndef I3C_CSR_ADDR_PKG_SV
`define I3C_CSR_ADDR_PKG_SV

package i3c_csr_addr_pkg;

  // 1. Address Offsets

  // Control & Status
  localparam bit [11:0] ADDR_HC_CONTROL = 12'h004;
  localparam bit [11:0] ADDR_RESET_CONTROL = 12'h010;
  localparam bit [11:0] ADDR_HC_STATUS = 12'h014;

  // Timing Registers
  localparam bit [11:0] ADDR_T_R = 12'h32C;
  localparam bit [11:0] ADDR_T_F = 12'h330;
  localparam bit [11:0] ADDR_T_SU_DAT = 12'h334;
  localparam bit [11:0] ADDR_I2C_T_SU_DAT = 12'h338;
  localparam bit [11:0] ADDR_T_HD_DAT = 12'h33C;
  localparam bit [11:0] ADDR_T_HIGH = 12'h340;
  localparam bit [11:0] ADDR_I2C_T_HIGH = 12'h34C;
  localparam bit [11:0] ADDR_T_LOW = 12'h350;
  localparam bit [11:0] ADDR_T_LOW_OD = 12'h354;
  localparam bit [11:0] ADDR_I2C_T_LOW = 12'h358;
  localparam bit [11:0] ADDR_T_HD_STA = 12'h35C;
  localparam bit [11:0] ADDR_I2C_T_HD_STA = 12'h360;
  localparam bit [11:0] ADDR_T_SU_STA = 12'h368;
  localparam bit [11:0] ADDR_I2C_T_SU_STA = 12'h36C;
  localparam bit [11:0] ADDR_T_SU_STO = 12'h370;
  localparam bit [11:0] ADDR_I2C_T_SU_STO = 12'h374;
  localparam bit [11:0] ADDR_T_BUS_FREE = 12'h37C;
  localparam bit [11:0] ADDR_I2C_T_BUF = 12'h380;

  // Queue Ports
  localparam bit [11:0] ADDR_CMD_QUEUE = 12'h080;
  localparam bit [11:0] ADDR_RESP = 12'h084;
  localparam bit [11:0] ADDR_PIO_DATA_PORT = 12'h088;
  localparam bit [11:0] ADDR_QUEUE_STATUS = 12'h0B4;

  // Device Address Table
  localparam bit [11:0] ADDR_DAT_BASE = 12'h400;
  localparam int unsigned DAT_DEPTH = 32;
  localparam bit [11:0] ADDR_DAT_END = ADDR_DAT_BASE + 12'(DAT_DEPTH * 4);

  // 2. Field Bit Positions

  // HC_CONTROL (upstream-style layout)
  localparam int HC_CTRL_IBA_INCLUDE_BIT = 0;
  localparam int HC_CTRL_BROADCAST_HEADER_ENABLE_BIT = HC_CTRL_IBA_INCLUDE_BIT;
  localparam int HC_CTRL_HC_ABORT_BIT = 29;  // SW rw level bit; cleared by SW writing 0 or async reset
  localparam int HC_CTRL_ABORT_BIT = HC_CTRL_HC_ABORT_BIT;
  localparam int HC_CTRL_ENABLE_BIT = 31;
  localparam int HC_CTRL_BUS_ENABLE_BIT = HC_CTRL_ENABLE_BIT;

  // RESET_CONTROL
  localparam int RESET_CTRL_SOFT_RST_BIT = 0;

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

  // 3. Timing Register Reset Values
  // All values in system clock cycles @ 333.333 MHz simulation clock
  // Expected by the CSR/module specification; these constants are the DV oracle
  // for CSR_001 and must not be copied from current RTL behavior.

  localparam bit [19:0] RST_T_R = 20'd4;
  localparam bit [19:0] RST_T_F = 20'd4;
  localparam bit [19:0] RST_T_LOW = 20'd16;
  localparam bit [19:0] RST_T_HIGH = 20'd11;
  localparam bit [19:0] RST_T_SU_STA = 20'd7;
  localparam bit [19:0] RST_T_HD_STA = 20'd13;
  localparam bit [19:0] RST_T_SU_STO = 20'd7;
  localparam bit [19:0] RST_T_SU_DAT = 20'd1;
  localparam bit [19:0] RST_T_HD_DAT = 20'd0;
  localparam bit [19:0] RST_T_BUS_FREE = 20'd13;
  localparam bit [19:0] RST_T_LOW_OD = 20'd67;
  localparam bit [19:0] RST_I2C_T_LOW = 20'd534;
  localparam bit [19:0] RST_I2C_T_HIGH = 20'd300;
  localparam bit [19:0] RST_I2C_T_SU_STA = 20'd200;
  localparam bit [19:0] RST_I2C_T_HD_STA = 20'd200;
  localparam bit [19:0] RST_I2C_T_SU_STO = 20'd434;
  localparam bit [19:0] RST_I2C_T_SU_DAT = 20'd34;
  localparam bit [19:0] RST_I2C_T_BUF = 20'd434;

  // 4. Helper Functions

  function automatic bit [31:0] hc_control_value(bit bus_enable = 1'b0,
                                                 bit iba_include = 1'b0,
                                                 bit abort = 1'b0);
    bit [31:0] value;
    value = '0;
    value[HC_CTRL_BUS_ENABLE_BIT] = bus_enable;
    value[HC_CTRL_IBA_INCLUDE_BIT] = iba_include;
    value[HC_CTRL_ABORT_BIT] = abort;
    return value;
  endfunction

  // Compute DAT entry address from 0-based index
  // Usage: csr_wr(dat_addr(0), dat_entry);  // writes index 0
  function automatic bit [11:0] dat_addr(int unsigned index);
    bit [11:0] offset;
`ifndef SYNTHESIS
    assert (index < DAT_DEPTH)
    else $fatal(1, "dat_addr: index %0d exceeds DAT_DEPTH %0d", index, DAT_DEPTH);
`endif
    offset = index << 2;
    return ADDR_DAT_BASE + offset;
  endfunction

endpackage : i3c_csr_addr_pkg

`endif
