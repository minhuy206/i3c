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

- `controller_pkg` — For `dat_entry_t`, `fifo_status_t`, `hc_control_cfg_t`, and `intr_event_t`

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
| `hc_control_cfg_o` | Output | `hc_control_cfg_t` | Packed control configuration from `HC_CONTROL`: `ctrl_enable`, `i3c_fsm_en`, `sw_reset`, `broadcast_header_enable`, and `abort` |

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
| `i2c_t_r_o` | Output | CounterWidth | I2C rise time |
| `i2c_t_f_o` | Output | CounterWidth | I2C fall time |
| `i2c_t_low_o` | Output | CounterWidth | I2C SCL LOW period |
| `i2c_t_high_o` | Output | CounterWidth | I2C SCL HIGH period |
| `i2c_t_su_sta_o` | Output | CounterWidth | I2C START setup time |
| `i2c_t_hd_sta_o` | Output | CounterWidth | I2C START hold time |
| `i2c_t_su_sto_o` | Output | CounterWidth | I2C STOP setup time |
| `i2c_t_su_dat_o` | Output | CounterWidth | I2C data setup time |
| `i2c_t_hd_dat_o` | Output | CounterWidth | I2C data hold time |
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

### Hardware Interface — Interrupt Event Inputs

| Signal         | Direction | Width | Description |
| -------------- | --------- | ----- | ----------- |
| `intr_event_i` | Input | `intr_event_t` | Sticky interrupt-status event pulses sampled into `INTR_STATUS` |

### Hardware Interface — Status Inputs

| Signal           | Direction | Width | Description            |
| ---------------- | --------- | ----- | ---------------------- |
| `i3c_fsm_idle_i` | Input     | 1     | Controller FSM is idle |

## 5. Functional Description

### 5.1. Register Map

| Offset      | Name             | R/W   | Reset | Description                          |
| ----------- | ---------------- | ----- | ----- | ------------------------------------ |
| 0x000       | `HC_CONTROL`     | RW    | 0x0   | Controller control register          |
| 0x004       | `HC_STATUS`      | R     | 0x5*  | Read-only live controller status     |
| 0x008       | `INTR_STATUS`    | R/W1C | 0x0   | Sticky interrupt status              |
| 0x010       | `T_R_REG`        | RW    | 0x4   | Rise time (system clock cycles)      |
| 0x014       | `T_F_REG`        | RW    | 0x4   | Fall time                            |
| 0x018       | `T_LOW_REG`      | RW    | 0x10  | SCL LOW period                       |
| 0x01C       | `T_LOW_OD_REG`   | RW    | 0x43  | Open-drain SCL LOW period            |
| 0x020       | `T_HIGH_REG`     | RW    | 0xB   | SCL HIGH period                      |
| 0x024       | `T_SU_STA_REG`   | RW    | 0x7   | START setup time                     |
| 0x028       | `T_HD_STA_REG`   | RW    | 0xD   | START hold time                      |
| 0x02C       | `T_SU_STO_REG`   | RW    | 0x7   | STOP setup time                      |
| 0x030       | `T_SU_DAT_REG`   | RW    | 0x1   | Data setup time                      |
| 0x034       | `T_HD_DAT_REG`   | RW    | 0x0   | Data hold time                       |
| 0x038       | `T_BUS_FREE_REG` | RW    | 0xD   | Bus free time                        |
| 0x040       | `I2C_T_R_REG`    | RW    | 0x64  | I2C rise time                        |
| 0x044       | `I2C_T_F_REG`    | RW    | 0x64  | I2C fall time                        |
| 0x048       | `I2C_T_LOW_REG`  | RW    | 0x216 | I2C SCL LOW period                   |
| 0x04C       | `I2C_T_HIGH_REG` | RW    | 0x12C | I2C SCL HIGH period                  |
| 0x050       | `I2C_T_SU_STA_REG` | RW  | 0xC8  | I2C START setup time                 |
| 0x054       | `I2C_T_HD_STA_REG` | RW  | 0xC8  | I2C START hold time                  |
| 0x058       | `I2C_T_SU_STO_REG` | RW  | 0x1B2 | I2C STOP setup time                  |
| 0x05C       | `I2C_T_SU_DAT_REG` | RW  | 0x22  | I2C data setup time                  |
| 0x060       | `I2C_T_HD_DAT_REG` | RW  | 0x0   | I2C data hold time                   |
| 0x064       | `I2C_T_BUF_REG`  | RW    | 0x1B2 | I2C bus free time                    |
| 0x100       | `CMD_QUEUE_PORT` | W     | -     | Write command descriptor (2x writes) |
| 0x104       | `TX_DATA_PORT`   | W     | -     | Write TX data                        |
| 0x108       | `RX_DATA_PORT`   | R     | -     | Read RX data                         |
| 0x10C       | `RESP_PORT`      | R     | -     | Read response descriptor             |
| 0x110       | `QUEUE_STATUS`   | R     | -     | Queue full/empty flags               |
| 0x200–0x27C | `DAT[0..31]`     | RW    | 0x0   | Device Address Table entries         |

### 5.2. Register Bit Fields

#### HC_CONTROL (0x000)

| Bit    | Field      | Access | Reset | Description                     |
| ------ | ---------- | ------ | ----- | ------------------------------- |
| [0]    | `ENABLE`   | RW     | 0     | 1 = Enable controller           |
| [1]    | `SW_RESET` | RW/SC  | 0     | 1 = Reset FIFOs (self-clearing) |
| [2]    | `BROADCAST_ADDR_ENABLE` | RW | 0 | 1 = Start fresh private I3C read/write with `START + 7E/W + Sr` |
| [3]    | `HC_ABORT` | RW     | 0     | 1 = Request controller abort; cleared by SW writing 0 or async reset |
| [31:4] | Reserved   | -      | 0     | -                               |

**SW_RESET usage constraint:** SW_RESET flushes the CMD, TX, RX, and RESP FIFOs. It does **not** reset the protocol FSM. Asserting SW_RESET while a transaction is in progress is undefined behavior.

**Safe usage sequence:**
1. Poll `HC_STATUS[FSM_IDLE]` until it reads 1.
2. Assert `HC_CONTROL[SW_RESET] = 1`. The pulse is self-clearing (one clock cycle).

#### HC_STATUS (0x004)

| Bit    | Field        | Access | Reset | Description                |
| ------ | ------------ | ------ | ----- | -------------------------- |
| [0]    | `FSM_IDLE`   | R      | 1     | 1 = Controller FSM is idle |
| [1]    | `CMD_FULL`   | R      | 0     | 1 = CMD FIFO full          |
| [2]    | `RESP_EMPTY` | R      | 1     | 1 = RESP FIFO empty        |
| [31:3] | Reserved     | -      | 0     | -                          |

`HC_STATUS` is not a sticky W1C register. It is a read-only live view of `i3c_fsm_idle_i`, `cmd_status_i.full`, and `resp_status_i.empty`. The normal post-reset visible value is `0x5` when the controller FSM is idle, CMD FIFO is not full, and RESP FIFO is empty.

#### INTR_STATUS (0x008)

Sticky interrupt-status register. Bits are set by `intr_event_i` and cleared by software writes of 1 to the corresponding W1C bit. Writes to reserved bits are ignored, and reserved bits read as 0.

| Bit | Field | Access | Reset | Description |
| --- | ----- | ------ | ----- | ----------- |
| [10] | `HC_INTERNAL_ERR_STAT` | R/W1C | 0 | Internal host-controller error |
| [11] | `HC_SEQ_CANCEL_STAT` | R/W1C | 0 | Command sequence canceled |
| [12] | `HC_WARN_CMD_SEQ_STALL_STAT` | R/W1C | 0 | Command sequencer stall warning |
| [13] | `HC_ERR_CMD_SEQ_TIMEOUT_STAT` | R/W1C | 0 | Command sequencer timeout error |
| [14] | `SCHED_CMD_MISSED_TICK_STAT` | R/W1C | 0 | Scheduler command missed tick |
| [9:0], [31:15] | Reserved | - | 0 | - |

#### Timing Registers (0x010–0x064)

| Bits             | Field    | Description                         |
| ---------------- | -------- | ----------------------------------- |
| [CounterWidth-1:0]| `VALUE` | Timing value in system clock cycles |
| [31:CounterWidth] | Reserved| -                                   |

Default values assume a 333.333 MHz system clock. I3C defaults target SDR timing, and the separate I2C timing defaults target FM 400 kHz timing.

#### CMD_QUEUE_PORT (0x100) — Write Only

First write stores DWORD0 in a staging register. Second write provides DWORD1 and triggers a 64-bit write to the CMD FIFO.

```systemverilog
// cmd_write FF block
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || sw_reset) begin
    cmd_staging_valid <= 1'b0;
    cmd_dword0 <= '0;
  end else if (wen_i && addr_i == 12'h100) begin
    if (!cmd_staging_valid) begin
      cmd_dword0 <= wdata_i;
      cmd_staging_valid <= 1'b1;
    end else begin
      // Trigger 64-bit write: {wdata_i (DWORD1), cmd_dword0 (DWORD0)}
      cmd_staging_valid <= 1'b0;
    end
  end
end
```

#### TX_DATA_PORT (0x104) — Write Only

```systemverilog
// tx_write FF block
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni || sw_reset) begin
    tx_wvalid_o <= 1'b0;
    tx_wdata_o  <= '0;
  end else begin
    tx_wvalid_o <= wen_i && (addr_i == 12'h104);
    if (wen_i && addr_i == 12'h104)
      tx_wdata_o <= wdata_i;
  end
end
```

#### QUEUE_STATUS (0x110) — Read Only

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

#### DAT Entries (0x200–0x27C)

32 entries, each 32-bit, at offsets `0x200 + (index * 4)`:

| Bit     | Field             | Access | Description           |
| ------- | ----------------- | ------ | --------------------- |
| [6:0]   | `STATIC_ADDRESS`  | RW     | I2C static address    |
| [15:7]  | Reserved          | -      | -                     |
| [22:16] | `DYNAMIC_ADDRESS` | RW     | I3C dynamic address   |
| [30:23] | Reserved          | -      | -                     |
| [31]    | `DEVICE`          | RW     | 1 = I2C legacy device |

### 5.3. Sequential Processes

The module has five `always_ff` blocks:

1. **`reg_write`** — Latches `hc_enable`, `sw_reset`, `broadcast_header_enable`, `hc_abort`, `INTR_STATUS`, all 21 timing registers, and the 32-entry `dat_mem[]` on accepted write cycles (`wen_i && ready_o`). This is the main configuration register FF.
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
      12'h000: rdata_d = hc_control;
      12'h004: rdata_d = hc_status;
      12'h008: rdata_d = intr_status;
      12'h010: rdata_d = {12'b0, t_r};
      // ... other timing regs ...
      12'h108: begin
        rx_rready = 1'b1;
        if (rx_rvalid_i) rdata_d = rx_rdata_i;
      end
      12'h10C: begin
        resp_rready = 1'b1;
        if (resp_rvalid_i) rdata_d = resp_rdata_i;
      end
      12'h110: rdata_d = queue_status;
      default: begin
        if (addr_i >= 12'h200 && addr_i < 12'h280)
          rdata_d = dat_mem[(addr_i - 12'h200) >> 2];
      end
    endcase
  end
end

always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) rdata_q <= '0;
  else rdata_q <= rdata_d;
end
```

`rdata_o` is registered, so read data is visible one clock after `ren_i`. `rx_rready_o` pulses on every `RX_DATA_PORT` read, and `resp_rready_o` pulses on every `RESP_PORT` read. These signals are the CSR-side consumer-ready requests; the FIFO only removes an entry when both ready and valid are high (`rready && rvalid`). Therefore, reading an empty RX/RESP port returns zero on the registered read-data cycle and does not pop or underflow the FIFO, even though the CSR read still asserts the corresponding `rready_o` for that cycle.

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
| SW_RESET pulse | Self-clearing after 1 cycle                  |

## 7. Changes from Reference Design

| Aspect           | Reference                            | This Design                     |
| ---------------- | ------------------------------------ | ------------------------------- |
| Size             | 14,342 lines (auto-generated)        | ~410 lines (manual)             |
| Generation tool  | PeakRDL toolchain                    | Hand-written                    |
| Register count   | 530+ typedefs, ~100 registers        | ~29 registers + 32 DAT entries  |
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
4. **SW_RESET self-clear:** Set SW_RESET bit; verify it clears after 1 cycle and `hc_control_cfg_o.sw_reset` pulses
5. **HC_STATUS live fields:** Verify FSM_IDLE, CMD_FULL, RESP_EMPTY reflect hardware inputs
6. **INTR_STATUS W1C:** Pulse each `intr_event_i` source, verify sticky status, then clear with W1C writes
7. **HC_ABORT:** Set and clear `HC_CONTROL[3]`; verify `hc_control_cfg_o.abort` follows the register bit
8. **DAT write/read via bus:** Write all 32 DAT entries via register bus; read back and verify
9. **DAT hardware read:** Write DAT via bus; read via hw port (`dat_read_valid_i`); verify 1-cycle latency
10. **CMD 64-bit staging:** Write DWORD0, then DWORD1 to CMD_QUEUE_PORT; verify 64-bit `cmd_wdata_o` and `cmd_wvalid_o` pulse
11. **TX write-through:** Write to TX_DATA_PORT; verify `tx_wvalid_o` and `tx_wdata_o`
12. **RX/RESP read-through:** With data in FIFOs, read RX_DATA_PORT / RESP_PORT; verify registered data and rready signals
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

- The `ready_o` output is normally HIGH. It deasserts for `CMD_QUEUE_PORT` or `TX_DATA_PORT` writes while the corresponding pending valid is still waiting for FIFO acceptance, or for those writes during the one-cycle `SW_RESET` pulse, so software/reg-agent writes are held instead of silently dropped.
- The CMD staging register introduces state — if only DWORD0 is written before a reset, the staging state is lost (by design). Software always writes both DWORDs in sequence.
- DAT entries use 32-bit width (not 64-bit as in reference). The reference's upper 32 bits contained DCR/BCR/PID fields which are stored in software after ENTDAA.
- Timing register defaults assume a 333.333 MHz system clock. I3C defaults target SDR timing, and I2C defaults target FM 400 kHz timing.
- The write-side FF processes (`reg_write`, `cmd_write`, `tx_write`) are kept separate for clarity; registered CSR readback and DAT hardware readback use their own FF blocks.
