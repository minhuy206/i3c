# Module: CSR Registers + Device Address Table (DAT)

> Status: Complete
> Reference: `i3c-core/src/csr/I3CCSR.sv` (7,710 lines) + `I3CCSR_pkg.sv` (2,640 lines)
> Estimated LoC: ~410 lines

## 1. Purpose

The CSR (Control and Status Register) module provides the software-accessible register interface for configuring and monitoring the I3C controller. It includes:

1. **Control/Status Registers** — Enable/disable controller, interrupt management, timing configuration
2. **Device Address Table (DAT)** — Maps device indices to I3C dynamic addresses and I2C static addresses (up to 32 entries)
3. **Queue Port Registers** — Software access points for the HCI FIFOs (CMD, TX, RX, RESP)
4. **Queue Status** — FIFO full/empty flags visible to software

## 2. Dependencies

### Sub-modules

- None (pure register logic)

### Parent modules

- `i3c_controller_top` (top-level)

### Packages

- `controller_pkg` — For `dat_entry_t`, `fifo_status_t`, and `hc_control_cfg_t`

### Shared Types

**DAT Entry (32-bit, simplified from reference 64-bit):**

```systemverilog
typedef struct packed {
  logic        device;           // [31]    1 = I2C legacy device
  logic [7:0]  reserved_30_23;   // [30:23] Reserved
  logic [6:0]  dynamic_address;  // [22:16] I3C dynamic address
  logic [8:0]  reserved_15_7;    // [15:7]  Reserved
  logic [6:0]  static_address;   // [6:0]   I2C static address
} dat_entry_t;
```

## 3. Parameters

| Parameter      | Type | Default | Description                    |
| -------------- | ---- | ------- | ------------------------------ |
| `DatDepth`     | int  | 32      | Number of DAT entries          |
| `AddrWidth`    | int  | 12      | Register bus address width     |
| `DataWidth`    | int  | 32      | Register bus data width        |
| `CounterWidth` | int  | 20      | Width of timing counter fields |
| `CmdDataWidth` | int  | 64      | Width of CMD descriptor        |

## 4. Ports / Interfaces

### Clock and Reset

| Signal   | Direction | Width | Description            |
| -------- | --------- | ----- | ---------------------- |
| `clk_i`  | Input     | 1     | System clock           |
| `rst_ni` | Input     | 1     | Active-low async reset |

### Register Bus (Simple Bus Interface)

| Signal    | Direction | Width     | Description             |
| --------- | --------- | --------- | ----------------------- |
| `addr_i`  | Input     | AddrWidth | Register address        |
| `wdata_i` | Input     | DataWidth | Write data              |
| `wen_i`   | Input     | 1         | Write enable            |
| `ren_i`   | Input     | 1         | Read enable             |
| `rdata_o` | Output    | DataWidth | Read data               |
| `ready_o` | Output    | 1         | Transaction acknowledge |

### Hardware Interface — Controller Configuration Outputs

| Signal          | Direction | Width | Description                          |
| --------------- | --------- | ----- | ------------------------------------ |
| `hc_control_cfg_o` | Output | `hc_control_cfg_t` | Packed control configuration: `ctrl_enable`, `i3c_fsm_en`, `broadcast_header_enable`, and `abort` (from `HC_CONTROL`) plus `sw_reset` (from `RESET_CONTROL[0]`) |

### Hardware Interface — Timing Outputs (system clock cycles)

| Signal       | Direction | Width        | Description      |
| ------------ | --------- | ------------ | ---------------- |
| `t_r_o`      | Output    | CounterWidth | Rise time        |
| `t_f_o`      | Output    | CounterWidth | Fall time        |
| `t_low_o`    | Output    | CounterWidth | SCL LOW period   |
| `t_low_od_o` | Output    | CounterWidth | Open-drain SCL LOW period |
| `t_high_o`   | Output    | CounterWidth | SCL HIGH period  |
| `t_su_sta_o` | Output    | CounterWidth | START setup time |
| `t_hd_sta_o` | Output    | CounterWidth | START hold time  |
| `t_su_sto_o` | Output    | CounterWidth | STOP setup time  |
| `t_su_dat_o` | Output    | CounterWidth | Data setup time  |
| `t_hd_dat_o` | Output    | CounterWidth | Data hold time   |
| `t_bus_free_o` | Output  | CounterWidth | Bus-free time after STOP |
| `i2c_t_low_o` | Output | CounterWidth | I2C SCL LOW period |
| `i2c_t_high_o` | Output | CounterWidth | I2C SCL HIGH period |
| `i2c_t_su_sta_o` | Output | CounterWidth | I2C START setup time |
| `i2c_t_hd_sta_o` | Output | CounterWidth | I2C START hold time |
| `i2c_t_su_sto_o` | Output | CounterWidth | I2C STOP setup time |
| `i2c_t_su_dat_o` | Output | CounterWidth | I2C data setup time |
| `i2c_t_buf_o` | Output | CounterWidth | I2C bus-free time |

### Hardware Interface — DAT Access (from controller_active)

| Signal             | Direction | Width            | Description          |
| ------------------ | --------- | ---------------- | -------------------- |
| `dat_read_valid_i` | Input     | 1                | HW requests DAT read |
| `dat_index_i`      | Input     | $clog2(DatDepth) | DAT entry index      |
| `dat_rdata_o`      | Output    | 32               | DAT entry data       |

### Hardware Interface — Queue Ports (bridge to HCI queues)

| Signal          | Direction | Width        | Description                                            |
| --------------- | --------- | ------------ | ------------------------------------------------------ |
| `cmd_wvalid_o`  | Output    | 1            | CMD FIFO write valid (from SW write to CMD_QUEUE_PORT) |
| `cmd_wdata_o`   | Output    | CmdDataWidth | CMD descriptor assembled                               |
| `cmd_wready_i`  | Input     | 1            | CMD FIFO ready                                         |
| `tx_wvalid_o`   | Output    | 1            | TX FIFO write valid                                    |
| `tx_wdata_o`    | Output    | DataWidth    | TX data                                                |
| `tx_wready_i`   | Input     | 1            | TX FIFO ready                                          |
| `rx_rvalid_i`   | Input     | 1            | RX FIFO has data                                       |
| `rx_rdata_i`    | Input     | DataWidth    | RX data                                                |
| `rx_rready_o`   | Output    | 1            | RX FIFO read request / consumer ready                  |
| `resp_rvalid_i` | Input     | 1            | RESP FIFO has data                                     |
| `resp_rdata_i`  | Input     | DataWidth    | Response descriptor                                    |
| `resp_rready_o` | Output    | 1            | RESP FIFO read request / consumer ready                |

### Hardware Interface — Queue Status (from HCI queues)

| Signal         | Direction | Width | Description     |
| -------------- | --------- | ----- | --------------- |
| `cmd_status_i`  | Input | `fifo_status_t` | CMD FIFO `full`/`empty` status |
| `tx_status_i`   | Input | `fifo_status_t` | TX FIFO `full`/`empty` status |
| `rx_status_i`   | Input | `fifo_status_t` | RX FIFO `full`/`empty` status |
| `resp_status_i` | Input | `fifo_status_t` | RESP FIFO `full`/`empty` status |

### Hardware Interface — Status Inputs

| Signal           | Direction | Width | Description            |
| ---------------- | --------- | ----- | ---------------------- |
| `i3c_fsm_idle_i` | Input     | 1     | Controller FSM is idle |

## 5. Functional Description

### 5.1. Register Map

| Offset      | Name             | R/W   | Reset | Description                          |
| ----------- | ---------------- | ----- | ----- | ------------------------------------ |
| 0x004       | `HC_CONTROL`     | RW    | 0x0   | Controller control register          |
| 0x010       | `RESET_CONTROL`  | W/SC  | 0x0   | Software reset control               |
| 0x014       | `HC_STATUS`      | R     | 0x5*  | Read-only live controller status     |
| 0x020       | Unmapped         | -     | -     | Reads return 0; writes ignored       |
| 0x080       | `CMD_QUEUE_PORT` | W     | -     | Write command descriptor (2x writes) |
| 0x084       | `RESP_PORT`      | R     | -     | Read response descriptor             |
| 0x088       | `PIO_DATA_PORT` | W/R | - | Write TX data / read RX data         |
| 0x0B4       | `QUEUE_STATUS`   | R     | -     | Queue full/empty flags               |
| 0x32C       | `T_R_REG`        | RW    | 0x4   | Shared I3C/I2C rise time             |
| 0x330       | `T_F_REG`        | RW    | 0x4   | Shared I3C/I2C fall time             |
| 0x334       | `T_SU_DAT_REG`   | RW    | 0x1   | I3C data setup time                  |
| 0x338       | `I2C_T_SU_DAT_REG` | RW  | 0x22  | I2C data setup time                  |
| 0x33C       | `T_HD_DAT_REG`   | RW    | 0x0   | Shared I3C/I2C data hold time        |
| 0x340       | `T_HIGH_REG`     | RW    | 0xB   | I3C SCL HIGH period                  |
| 0x34C       | `I2C_T_HIGH_REG` | RW    | 0x12C | I2C SCL HIGH period                  |
| 0x350       | `T_LOW_REG`      | RW    | 0x10  | I3C SCL LOW period                   |
| 0x354       | `T_LOW_OD_REG`   | RW    | 0x43  | I3C open-drain SCL LOW period        |
| 0x358       | `I2C_T_LOW_REG`  | RW    | 0x216 | I2C SCL LOW period                   |
| 0x35C       | `T_HD_STA_REG`   | RW    | 0xD   | I3C START hold time                  |
| 0x360       | `I2C_T_HD_STA_REG` | RW  | 0xC8  | I2C START hold time                  |
| 0x368       | `T_SU_STA_REG`   | RW    | 0x7   | I3C START setup time                 |
| 0x36C       | `I2C_T_SU_STA_REG` | RW  | 0xC8  | I2C START setup time                 |
| 0x370       | `T_SU_STO_REG`   | RW    | 0x7   | I3C STOP setup time                  |
| 0x374       | `I2C_T_SU_STO_REG` | RW  | 0x1B2 | I2C STOP setup time                  |
| 0x37C       | `T_BUS_FREE_REG` | RW    | 0xD   | I3C bus free time                    |
| 0x380       | `I2C_T_BUF_REG`  | RW    | 0x1B2 | I2C bus free time                    |
| 0x400–0x47C | `DAT[0..31]`     | RW    | 0x0   | Device Address Table entries         |

### 5.2. Register Bit Fields

#### HC_CONTROL (0x004)

| Bit    | Field      | Access | Reset | Description                     |
| ------ | ---------- | ------ | ----- | ------------------------------- |
| [0]    | `IBA_INCLUDE` | RW  | 0 | 1 = Start fresh private I3C read/write with `START + 7E/W + Sr` |
| [29]   | `ABORT`    | RW     | 0     | 1 = Request controller abort; cleared by SW writing 0 or async reset |
| [31]   | `BUS_ENABLE` | RW   | 0     | 1 = Enable controller           |
| others | Reserved/upstream unsupported | RO | 0 | Writes ignored, reads 0 |

#### RESET_CONTROL (0x010)

| Bit    | Field      | Access | Reset | Description                     |
| ------ | ---------- | ------ | ----- | ------------------------------- |
| [0]    | `SOFT_RST` | W/SC   | 0     | 1 = Reset FIFOs and CSR CMD/TX staging |
| [31:1] | Reserved   | RO     | 0     | -                               |

**SOFT_RST usage constraint:** SOFT_RST flushes the CMD, TX, RX, and RESP FIFOs only when `HC_STATUS[FSM_IDLE]` is 1. It does **not** reset the protocol FSM. If software writes `SOFT_RST=1` while a transaction is in progress (`FSM_IDLE=0`), the write is accepted but ignored: no internal `sw_reset` pulse is generated, queues and CSR staging are preserved, and the active transfer continues.

**Safe usage sequence:**
1. Poll `HC_STATUS[FSM_IDLE]` until it reads 1.
2. Assert `RESET_CONTROL[SOFT_RST] = 1`. The pulse is self-clearing (one clock cycle).

#### HC_STATUS (0x014)

| Bit    | Field        | Access | Reset | Description                |
| ------ | ------------ | ------ | ----- | -------------------------- |
| [0]    | `FSM_IDLE`   | R      | 1     | 1 = Controller FSM is idle |
| [1]    | `CMD_FULL`   | R      | 0     | 1 = CMD FIFO full          |
| [2]    | `RESP_EMPTY` | R      | 1     | 1 = RESP FIFO empty        |
| [31:3] | Reserved     | -      | 0     | -                          |

`HC_STATUS` is not a sticky W1C register. It is a read-only live view of `i3c_fsm_idle_i`, `cmd_status_i.full`, and `resp_status_i.empty`. The normal post-reset visible value is `0x5` when the controller FSM is idle, CMD FIFO is not full, and RESP FIFO is empty.

#### Unmapped Hole (0x020)

Offset `0x020` is not implemented. Reads return `0`, writes are ignored, and there are no side effects.

#### Timing Registers (0x32C–0x380)

| Bits             | Field    | Description                         |
| ---------------- | -------- | ----------------------------------- |
| [CounterWidth-1:0]| `VALUE` | Timing value in system clock cycles |
| [31:CounterWidth] | Reserved| -                                   |

Default values assume a 333.333 MHz system clock. I3C defaults target SDR timing, and the separate I2C timing defaults target FM 400 kHz timing.

#### CMD_QUEUE_PORT (0x080) — Write Only

First write stores DWORD0 in a staging register. Second write provides DWORD1 and triggers a 64-bit write to the CMD FIFO.

```systemverilog
// cmd_write FF block
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    cmd_staging_valid <= 1'b0;
    cmd_wvalid <= '0;
    cmd_dword0 <= '0;
    cmd_wdata <= '0;
  end else if (sw_reset || (cmd_wvalid && cmd_wready_i)) begin
    cmd_staging_valid <= 1'b0;
    cmd_wvalid <= '0;
  end else if (wen_i && addr_i == 12'h080 && !cmd_wvalid) begin
    if (!cmd_staging_valid) begin
      cmd_dword0 <= wdata_i;
      cmd_staging_valid <= 1'b1;
    end else begin
      cmd_wdata <= {wdata_i, cmd_dword0};
      cmd_wvalid <= 1'b1;
      cmd_staging_valid <= '0;
    end
  end
end
```

#### PIO_DATA_PORT (0x088) — Write TX / Read RX

```systemverilog
// tx_write FF block
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    tx_wdata  <= '0;
    tx_wvalid <= '0;
  end else if (sw_reset) begin
    tx_wdata  <= '0;
    tx_wvalid <= '0;
  end else if (tx_wvalid && tx_wready_i) begin
    tx_wvalid <= '0;
  end else if (wen_i && (addr_i == 12'h088) && !tx_wvalid) begin
    tx_wdata  <= wdata_i;
    tx_wvalid <= 1'b1;
  end
end
// tx_wvalid_o = tx_wvalid; tx_wdata_o = tx_wdata; (assigned separately)
```

#### QUEUE_STATUS (0x0B4) — Read Only

| Bit    | Field        | Description     |
| ------ | ------------ | --------------- |
| [0]    | `CMD_FULL`   | CMD FIFO full   |
| [1]    | `CMD_EMPTY`  | CMD FIFO empty  |
| [2]    | `TX_FULL`    | TX FIFO full    |
| [3]    | `TX_EMPTY`   | TX FIFO empty   |
| [4]    | `RX_FULL`    | RX FIFO full    |
| [5]    | `RX_EMPTY`   | RX FIFO empty   |
| [6]    | `RESP_FULL`  | RESP FIFO full  |
| [7]    | `RESP_EMPTY` | RESP FIFO empty |
| [31:8] | Reserved     | 0               |

#### DAT Entries (0x400–0x47C)

32 entries, each 32-bit, at offsets `0x400 + (index * 4)`:

| Bit     | Field             | Access | Description           |
| ------- | ----------------- | ------ | --------------------- |
| [6:0]   | `STATIC_ADDRESS`  | RW     | I2C static address    |
| [15:7]  | Reserved          | -      | -                     |
| [22:16] | `DYNAMIC_ADDRESS` | RW     | I3C dynamic address   |
| [30:23] | Reserved          | -      | -                     |
| [31]    | `DEVICE`          | RW     | 1 = I2C legacy device |

### 5.3. Sequential Processes

The module has five `always_ff` blocks:

1. **`reg_write`** — Latches `hc_enable`, `broadcast_header_enable`, `hc_abort` (from `HC_CONTROL`), `sw_reset` (from `RESET_CONTROL`), all timing registers, and the 32-entry `dat_mem[]` on accepted write cycles (`wen_i && ready_o`). This is the main configuration register FF.
2. **`cmd_write`** — 64-bit two-DWORD staging for `CMD_QUEUE_PORT`. Holds DWORD0 until DWORD1 arrives, then pulses `cmd_wvalid_o`.
3. **`tx_write`** — TX FIFO push: asserts `tx_wvalid_o` and holds `tx_wdata_o` until the TX FIFO accepts the write.
4. **`reg_read_reg`** — Registers the read mux output into `rdata_o`.
5. **DAT hardware read FF** — Registers `dat_mem[dat_index_i]` into `dat_rdata_o` when `dat_read_valid_i` is asserted.

### 5.4. Read Logic

```systemverilog
always_comb begin
  rdata_d = '0;
  resp_rready = 1'b0;
  rx_rready   = 1'b0;

  if (ren_i) begin
    case (addr_i)
      12'h004: rdata_d = hc_control;
      12'h010: rdata_d = '0;              // RESET_CONTROL reads 0
      12'h014: rdata_d = hc_status;
      // 12'h020 is unmapped and falls through to the default zero value.
      12'h32C: rdata_d = {12'b0, t_r};
      // ... other timing regs (0x330 .. 0x380) ...
      12'h088: begin                      // PIO_DATA_PORT (read = RX pop)
        rx_rready = ren_i;
        if (rx_rvalid_i) rdata_d = rx_rdata_i;
      end
      12'h084: begin                      // RESP_PORT
        resp_rready = ren_i;
        if (resp_rvalid_i) rdata_d = resp_rdata_i;
      end
      12'h0B4: rdata_d = queue_status;
      default: begin
        if (addr_i >= 12'h400 && addr_i < 12'h480)
          rdata_d = dat_mem[(addr_i - 12'h400) >> 2];
      end
    endcase
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) rdata_q <= '0;
  else rdata_q <= rdata_d;
end
```

`rdata_o` is registered, so read data is visible one clock after `ren_i`. `rx_rready_o` pulses on every `PIO_DATA_PORT` read, and `resp_rready_o` pulses on every `RESP_PORT` read. These signals are the CSR-side consumer-ready requests; the FIFO only removes an entry when both ready and valid are high (`rready && rvalid`). Therefore, reading an empty RX/RESP port returns zero on the registered read-data cycle and does not pop or underflow the FIFO, even though the CSR read still asserts the corresponding `rready_o` for that cycle.

### 5.5. DAT Hardware Read Path

The controller hardware reads DAT entries using a separate read port (no bus contention):

```systemverilog
always_ff @(posedge clk_i) begin
  if (dat_read_valid_i)
    dat_rdata_o <= dat_mem[dat_index_i];
end
```

This is a 1-cycle latency read (registered output). `flow_active` and `entdaa_controller` share this port via a MUX in `controller_active`.

## 6. Timing Requirements

| Aspect         | Requirement                                  |
| -------------- | -------------------------------------------- |
| Register write | 1 cycle latency (value available next cycle) |
| Register read  | 1 cycle latency (registered `rdata_o`)       |
| DAT HW read    | 1 cycle latency (registered)                 |
| CMD staging    | 2 writes required for 64-bit entry           |
| SOFT_RST pulse | Self-clearing after 1 cycle                  |

## 7. Changes from Reference Design

| Aspect           | Reference                            | This Design                     |
| ---------------- | ------------------------------------ | ------------------------------- |
| Size             | 14,342 lines (auto-generated)        | ~410 lines (manual)             |
| Generation tool  | PeakRDL toolchain                    | Hand-written                    |
| Register count   | 530+ typedefs, ~100 registers        | ~26 registers + 32 DAT entries  |
| Access patterns  | 5-level nested struct navigation     | Direct `case` statement         |
| Bus interface    | AXI4 + AHB-Lite adapters             | Simple addr/data/wen/ren bus    |
| DAT entry width  | 64-bit (with DCR/BCR fields)         | 32-bit (address + device flag)  |
| DAT depth        | 128 entries                          | 32 entries                      |
| DCT              | Separate table (128 x 128-bit)       | Removed (SW stores PID/BCR/DCR) |
| IBI registers    | IBI queue config, enable, status     | Removed                         |
| Target mode regs | Static address, BCR, DCR, PID config | Removed                         |

## 8. Error Handling

| Error                    | Handling                               |
| ------------------------ | -------------------------------------- |
| Write to read-only reg   | Ignored (no side effects)              |
| Read from write-only reg | Returns 0                              |
| Invalid address          | Returns 0, no side effects             |
| Write to full CMD/TX     | CSR captures one pending write, holds valid/data, and deasserts `ready_o` for further writes until the FIFO accepts it |
| Read from empty RX/RESP  | Returns 0; CSR asserts rready, FIFO does not pop because rvalid is 0 |

## 9. Test Plan

### Scenarios

1. **Register write/read:** Write value to each RW register; read back and verify
2. **Timing register defaults:** Verify all timing registers have correct reset values
3. **HC_CONTROL enable:** Set ENABLE bit; verify `hc_control_cfg_o.ctrl_enable` and `hc_control_cfg_o.i3c_fsm_en` assert
4. **SOFT_RST self-clear:** Set RESET_CONTROL[SOFT_RST]; verify it clears after 1 cycle and `hc_control_cfg_o.sw_reset` pulses
5. **HC_STATUS live fields:** Verify FSM_IDLE, CMD_FULL, RESP_EMPTY reflect hardware inputs
6. **Unmapped 0x020 behavior:** Read/write `0x020`; verify reads return 0 and writes have no side effects
7. **HC_ABORT:** Set and clear `HC_CONTROL[29]`; verify `hc_control_cfg_o.abort` follows the register bit
8. **DAT write/read via bus:** Write all 32 DAT entries via register bus; read back and verify
9. **DAT hardware read:** Write DAT via bus; read via hw port (`dat_read_valid_i`); verify 1-cycle latency
10. **CMD 64-bit staging:** Write DWORD0, then DWORD1 to CMD_QUEUE_PORT; verify 64-bit `cmd_wdata_o` and `cmd_wvalid_o` pulse
11. **TX write-through:** Write to PIO_DATA_PORT; verify `tx_wvalid_o` and `tx_wdata_o`
12. **RX/RESP read-through:** With data in FIFOs, read PIO_DATA_PORT / RESP_PORT; verify registered data and rready signals
13. **QUEUE_STATUS accuracy:** Verify all 8 flag bits match actual FIFO states
14. **Invalid address:** Read/write to unmapped address; verify no side effects

### UVM Test Structure

```
src/verification/uvm_i3c/
  sequences/
    i3c_base_vseq.sv
    i3c_entdaa_vseq.sv
    i3c_private_write_vseq.sv
    i3c_private_read_vseq.sv
    i3c_i2c_write_vseq.sv
  tests/
    i3c_base_test.sv
    i3c_entdaa_test.sv
    i3c_private_rw_test.sv
    i3c_i2c_test.sv
    i3c_error_test.sv
```

**Module coverage note:** `csr_registers` is exercised by all tests — CSR configuration (timing parameters, HC_CONTROL, DAT) must be written before any transaction can be initiated.

## 10. Implementation Notes

- The `ready_o` output is normally HIGH. It deasserts for `CMD_QUEUE_PORT` or `PIO_DATA_PORT` writes while the corresponding pending valid is still waiting for FIFO acceptance, or for those writes during the one-cycle `SW_RESET` pulse, so software/reg-agent writes are held instead of silently dropped.
- The CMD staging register introduces state — if only DWORD0 is written before a reset, the staging state is lost (by design). Software always writes both DWORDs in sequence.
- DAT entries use 32-bit width (not 64-bit as in reference). The reference's upper 32 bits contained DCR/BCR/PID fields which are stored in software after ENTDAA.
- Timing register defaults assume a 333.333 MHz system clock. I3C defaults target SDR timing, and I2C defaults target FM 400 kHz timing.
- The write-side FF processes (`reg_write`, `cmd_write`, `tx_write`) are kept separate for clarity; registered CSR readback and DAT hardware readback use their own FF blocks.
