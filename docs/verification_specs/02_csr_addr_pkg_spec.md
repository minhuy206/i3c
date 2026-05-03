# File: i3c_csr_addr_pkg.sv

> Status: New
> Location: `verification/uvm_i3c/dv_inc/i3c_csr_addr_pkg.sv`

## 1. Purpose

Provide a SystemVerilog package containing all CSR address offsets and field positions as named constants. This allows UVM sequences and scoreboard to reference registers symbolically rather than using raw hex literals, improving readability and maintainability.

The constants mirror those defined in `src/csr/csr_register.sv` (lines 74–91).

## 2. Dependencies

### Used By

- `i3c_env_pkg` (scoreboard uses field positions)
- `i3c_base_vseq` and all virtual sequences (helper tasks use address constants)
- `reg_seq_item` constraints (optional — constrain addr to valid range)

### Sources From

- `src/csr/csr_register.sv` — authoritative address map

## 3. Package Contents

### 3.1. Address Offsets

```systemverilog
package i3c_csr_addr_pkg;

  // Control & Status
  localparam bit [11:0] ADDR_HC_CONTROL   = 12'h000;
  localparam bit [11:0] ADDR_HC_STATUS    = 12'h004;

  // Timing Registers
  localparam bit [11:0] ADDR_T_R          = 12'h010;
  localparam bit [11:0] ADDR_T_F          = 12'h014;
  localparam bit [11:0] ADDR_T_LOW        = 12'h018;
  localparam bit [11:0] ADDR_T_HIGH       = 12'h01C;
  localparam bit [11:0] ADDR_T_SU_STA     = 12'h020;
  localparam bit [11:0] ADDR_T_HD_STA     = 12'h024;
  localparam bit [11:0] ADDR_T_SU_STO     = 12'h028;
  localparam bit [11:0] ADDR_T_SU_DAT     = 12'h02C;
  localparam bit [11:0] ADDR_T_HD_DAT     = 12'h030;

  // Queue Ports
  localparam bit [11:0] ADDR_CMD_QUEUE    = 12'h100;
  localparam bit [11:0] ADDR_TX_DATA      = 12'h104;
  localparam bit [11:0] ADDR_RX_DATA      = 12'h108;
  localparam bit [11:0] ADDR_RESP         = 12'h10C;
  localparam bit [11:0] ADDR_QUEUE_STATUS = 12'h110;

  // Device Address Table
  localparam bit [11:0] ADDR_DAT_BASE     = 12'h200;
  localparam bit [11:0] ADDR_DAT_END      = 12'h240;
  localparam int unsigned DAT_DEPTH       = 16;

endpackage
```

### 3.2. HC_CONTROL Field Positions

```systemverilog
  // HC_CONTROL bit positions
  localparam int HC_CTRL_ENABLE_BIT  = 0;
  localparam int HC_CTRL_SW_RESET_BIT = 1;
```

### 3.3. HC_STATUS Field Positions

```systemverilog
  // HC_STATUS bit positions
  localparam int HC_STS_FSM_IDLE_BIT  = 0;
  localparam int HC_STS_CMD_FULL_BIT  = 1;
  localparam int HC_STS_RESP_EMPTY_BIT = 2;
```

### 3.4. QUEUE_STATUS Field Positions

```systemverilog
  // QUEUE_STATUS bit positions
  localparam int QS_CMD_FULL_BIT   = 0;
  localparam int QS_CMD_EMPTY_BIT  = 1;
  localparam int QS_TX_FULL_BIT    = 2;
  localparam int QS_TX_EMPTY_BIT   = 3;
  localparam int QS_RX_FULL_BIT    = 4;
  localparam int QS_RX_EMPTY_BIT   = 5;
  localparam int QS_RESP_FULL_BIT  = 6;
  localparam int QS_RESP_EMPTY_BIT = 7;
```

### 3.5. Timing Register Default Values

Match the reset values from `csr_register.sv`:

```systemverilog
  // Default timing values (system clock cycles @ 100 MHz in simulation)
  localparam bit [19:0] RST_T_R      = 20'd4;
  localparam bit [19:0] RST_T_F      = 20'd4;
  localparam bit [19:0] RST_T_LOW    = 20'd13;
  localparam bit [19:0] RST_T_HIGH   = 20'd13;
  localparam bit [19:0] RST_T_SU_STA = 20'd13;
  localparam bit [19:0] RST_T_HD_STA = 20'd13;
  localparam bit [19:0] RST_T_SU_STO = 20'd13;
  localparam bit [19:0] RST_T_SU_DAT = 20'd1;
  localparam bit [19:0] RST_T_HD_DAT = 20'd4;
```

### 3.6. Helper Functions

```systemverilog
  // Compute DAT entry address from index
  function automatic bit [11:0] dat_addr(int unsigned index);
    return ADDR_DAT_BASE + (index << 2);
  endfunction
```

## 4. Implementation Notes

- This package is compiled early in the filelist (before agents and env) since sequences import it
- All values MUST be kept in sync with `src/csr/csr_register.sv` — any CSR map change in RTL must be reflected here
- The package does NOT import `i3c_pkg` or `controller_pkg` to avoid circular dependencies; it duplicates the needed constants
