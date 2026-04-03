# Module: CSR Registers + Device Address Table (DAT)

> Status: Improve
> Reference: `i3c-core/src/csr/I3CCSR.sv` (7,710 lines) + `I3CCSR_pkg.sv` (2,640 lines)
> Estimated LoC: ~300 lines

## 1. Purpose

The CSR (Control and Status Register) module provides the software-accessible register interface for configuring and monitoring the I3C controller. It includes:

1. **Control/Status Registers** — Enable/disable controller, interrupt management, timing configuration
2. **Device Address Table (DAT)** — Maps device indices to I3C dynamic addresses and I2C static addresses (up to 16 entries)
3. **Queue Port Registers** — Software access points for the HCI FIFOs (CMD, TX, RX, RESP)
4. **Queue Status** — FIFO full/empty flags visible to software

## 2. Dependencies

### Sub-modules

- None (pure register logic)

### Parent modules

- `i3c_controller_top` (top-level)

### Packages

- `i3c_pkg` — For `dat_entry_t` and other shared types

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

| Parameter   | Type | Default | Description                |
| ----------- | ---- | ------- | -------------------------- |
| `DatDepth`  | int  | 16      | Number of DAT entries      |
| `AddrWidth` | int  | 12      | Register bus address width |
| `DataWidth` | int  | 32      | Register bus data width    |

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
| `ctrl_enable_o` | Output    | 1     | Controller enable (HC_CONTROL[0])    |
| `i3c_fsm_en_o`  | Output    | 1     | I3C FSM enable                       |
| `sw_reset_o`    | Output    | 1     | Software reset pulse (HC_CONTROL[1]) |

### Hardware Interface — Timing Outputs (system clock cycles)

| Signal       | Direction | Width | Description      |
| ------------ | --------- | ----- | ---------------- |
| `t_r_o`      | Output    | 20    | Rise time        |
| `t_f_o`      | Output    | 20    | Fall time        |
| `t_low_o`    | Output    | 20    | SCL LOW period   |
| `t_high_o`   | Output    | 20    | SCL HIGH period  |
| `t_su_sta_o` | Output    | 20    | START setup time |
| `t_hd_sta_o` | Output    | 20    | START hold time  |
| `t_su_sto_o` | Output    | 20    | STOP setup time  |
| `t_su_dat_o` | Output    | 20    | Data setup time  |
| `t_hd_dat_o` | Output    | 20    | Data hold time   |

### Hardware Interface — DAT Access (from controller_active)

| Signal             | Direction | Width            | Description          |
| ------------------ | --------- | ---------------- | -------------------- |
| `dat_read_valid_i` | Input     | 1                | HW requests DAT read |
| `dat_index_i`      | Input     | $clog2(DatDepth) | DAT entry index      |
| `dat_rdata_o`      | Output    | 32               | DAT entry data       |

### Hardware Interface — Queue Ports (bridge to HCI queues)

| Signal          | Direction | Width | Description                                            |
| --------------- | --------- | ----- | ------------------------------------------------------ |
| `cmd_wvalid_o`  | Output    | 1     | CMD FIFO write valid (from SW write to CMD_QUEUE_PORT) |
| `cmd_wdata_o`   | Output    | 64    | CMD descriptor assembled                               |
| `cmd_wready_i`  | Input     | 1     | CMD FIFO ready                                         |
| `tx_wvalid_o`   | Output    | 1     | TX FIFO write valid                                    |
| `tx_wdata_o`    | Output    | 32    | TX data                                                |
| `tx_wready_i`   | Input     | 1     | TX FIFO ready                                          |
| `rx_rvalid_i`   | Input     | 1     | RX FIFO has data                                       |
| `rx_rdata_i`    | Input     | 32    | RX data                                                |
| `rx_rready_o`   | Output    | 1     | RX FIFO read acknowledge                               |
| `resp_rvalid_i` | Input     | 1     | RESP FIFO has data                                     |
| `resp_rdata_i`  | Input     | 32    | Response descriptor                                    |
| `resp_rready_o` | Output    | 1     | RESP FIFO read acknowledge                             |

### Hardware Interface — Queue Status (from HCI queues)

| Signal         | Direction | Width | Description     |
| -------------- | --------- | ----- | --------------- |
| `cmd_full_i`   | Input     | 1     | CMD FIFO full   |
| `cmd_empty_i`  | Input     | 1     | CMD FIFO empty  |
| `tx_full_i`    | Input     | 1     | TX FIFO full    |
| `tx_empty_i`   | Input     | 1     | TX FIFO empty   |
| `rx_full_i`    | Input     | 1     | RX FIFO full    |
| `rx_empty_i`   | Input     | 1     | RX FIFO empty   |
| `resp_full_i`  | Input     | 1     | RESP FIFO full  |
| `resp_empty_i` | Input     | 1     | RESP FIFO empty |

### Hardware Interface — Status Inputs

| Signal           | Direction | Width | Description            |
| ---------------- | --------- | ----- | ---------------------- |
| `i3c_fsm_idle_i` | Input     | 1     | Controller FSM is idle |

## 5. Functional Description

### 5.1. Register Map

| Offset      | Name             | R/W   | Reset | Description                          |
| ----------- | ---------------- | ----- | ----- | ------------------------------------ |
| 0x000       | `HC_CONTROL`     | RW    | 0x0   | Controller control register          |
| 0x004       | `HC_STATUS`      | R/W1C | 0x0   | Controller status register           |
| 0x010       | `T_R_REG`        | RW    | 0x4   | Rise time (system clock cycles)      |
| 0x014       | `T_F_REG`        | RW    | 0x4   | Fall time                            |
| 0x018       | `T_LOW_REG`      | RW    | 0x8   | SCL LOW period                       |
| 0x01C       | `T_HIGH_REG`     | RW    | 0x8   | SCL HIGH period                      |
| 0x020       | `T_SU_STA_REG`   | RW    | 0x8   | START setup time                     |
| 0x024       | `T_HD_STA_REG`   | RW    | 0x8   | START hold time                      |
| 0x028       | `T_SU_STO_REG`   | RW    | 0x4   | STOP setup time                      |
| 0x02C       | `T_SU_DAT_REG`   | RW    | 0x1   | Data setup time                      |
| 0x030       | `T_HD_DAT_REG`   | RW    | 0x4   | Data hold time                       |
| 0x100       | `CMD_QUEUE_PORT` | W     | -     | Write command descriptor (2x writes) |
| 0x104       | `TX_DATA_PORT`   | W     | -     | Write TX data                        |
| 0x108       | `RX_DATA_PORT`   | R     | -     | Read RX data                         |
| 0x10C       | `RESP_PORT`      | R     | -     | Read response descriptor             |
| 0x110       | `QUEUE_STATUS`   | R     | -     | Queue full/empty flags               |
| 0x200–0x23C | `DAT[0..15]`     | RW    | 0x0   | Device Address Table entries         |

### 5.2. Register Bit Fields

#### HC_CONTROL (0x000)

| Bit    | Field      | Access | Reset | Description                     |
| ------ | ---------- | ------ | ----- | ------------------------------- |
| [0]    | `ENABLE`   | RW     | 0     | 1 = Enable controller           |
| [1]    | `SW_RESET` | RW/SC  | 0     | 1 = Reset FIFOs (self-clearing) |
| [31:2] | Reserved   | -      | 0     | -                               |

#### HC_STATUS (0x004)

| Bit    | Field        | Access | Reset | Description                |
| ------ | ------------ | ------ | ----- | -------------------------- |
| [0]    | `FSM_IDLE`   | R      | 1     | 1 = Controller FSM is idle |
| [1]    | `CMD_FULL`   | R      | 0     | 1 = CMD FIFO full          |
| [2]    | `RESP_EMPTY` | R      | 1     | 1 = RESP FIFO empty        |
| [31:3] | Reserved     | -      | 0     | -                          |

#### Timing Registers (0x010–0x030)

| Bits    | Field    | Description                         |
| ------- | -------- | ----------------------------------- |
| [19:0]  | `VALUE`  | Timing value in system clock cycles |
| [31:20] | Reserved | -                                   |

Default values assume 333 MHz system clock targeting I3C SDR mode.

#### CMD_QUEUE_PORT (0x100) — Write Only

First write stores DWORD0 in a staging register. Second write provides DWORD1 and triggers a 64-bit write to the CMD FIFO.

```systemverilog
logic cmd_staging_valid;
logic [31:0] cmd_dword0;

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

#### DAT Entries (0x200–0x23C)

16 entries, each 32-bit, at offsets `0x200 + (index * 4)`:

| Bit     | Field             | Access | Description           |
| ------- | ----------------- | ------ | --------------------- |
| [6:0]   | `STATIC_ADDRESS`  | RW     | I2C static address    |
| [15:7]  | Reserved          | -      | -                     |
| [22:16] | `DYNAMIC_ADDRESS` | RW     | I3C dynamic address   |
| [30:23] | Reserved          | -      | -                     |
| [31]    | `DEVICE`          | RW     | 1 = I2C legacy device |

### 5.3. Read Logic

```systemverilog
always_comb begin
  rdata_o = '0;
  ready_o = 1'b1;
  rx_rready_o = 1'b0;
  resp_rready_o = 1'b0;

  if (ren_i) begin
    case (addr_i)
      12'h000: rdata_o = hc_control;
      12'h004: rdata_o = hc_status;
      12'h010: rdata_o = {12'b0, t_r_reg};
      // ... other timing regs ...
      12'h108: begin
        rdata_o = rx_rdata_i;
        rx_rready_o = rx_rvalid_i;  // Pop from RX FIFO on read
      end
      12'h10C: begin
        rdata_o = resp_rdata_i;
        resp_rready_o = resp_rvalid_i;  // Pop from RESP FIFO on read
      end
      12'h110: rdata_o = queue_status;
      default: begin
        if (addr_i >= 12'h200 && addr_i < 12'h240)
          rdata_o = dat_mem[(addr_i - 12'h200) >> 2];
      end
    endcase
  end
end
```

### 5.4. DAT Hardware Read Path

The controller hardware reads DAT entries using a separate read port (no bus contention):

```systemverilog
always_ff @(posedge clk_i) begin
  if (dat_read_valid_i)
    dat_rdata_o <= dat_mem[dat_index_i];
end
```

This is a 1-cycle latency read (registered output).

## 6. Timing Requirements

| Aspect         | Requirement                                  |
| -------------- | -------------------------------------------- |
| Register write | 1 cycle latency (value available next cycle) |
| Register read  | Combinational (same cycle as ren_i)          |
| DAT HW read    | 1 cycle latency (registered)                 |
| CMD staging    | 2 writes required for 64-bit entry           |
| SW_RESET pulse | Self-clearing after 1 cycle                  |

## 7. Changes from Reference Design

| Aspect           | Reference                            | This Design                     |
| ---------------- | ------------------------------------ | ------------------------------- |
| Size             | 14,342 lines (auto-generated)        | ~300 lines (manual)             |
| Generation tool  | PeakRDL toolchain                    | Hand-written                    |
| Register count   | 530+ typedefs, ~100 registers        | ~15 registers + 16 DAT entries  |
| Access patterns  | 5-level nested struct navigation     | Direct `case` statement         |
| Bus interface    | AXI4 + AHB-Lite adapters             | Simple addr/data/wen/ren bus    |
| DAT entry width  | 64-bit (with DCR/BCR fields)         | 32-bit (address + device flag)  |
| DAT depth        | 128 entries                          | 16 entries                      |
| DCT              | Separate table (128 x 128-bit)       | Removed (SW stores PID/BCR/DCR) |
| IBI registers    | IBI queue config, enable, status     | Removed                         |
| Target mode regs | Static address, BCR, DCR, PID config | Removed                         |

## 8. Error Handling

| Error                    | Handling                               |
| ------------------------ | -------------------------------------- |
| Write to read-only reg   | Ignored (no side effects)              |
| Read from write-only reg | Returns 0                              |
| Invalid address          | Returns 0, no side effects             |
| Write to full CMD/TX     | CSR passes write; FIFO ignores if full |
| Read from empty RX/RESP  | Returns 0, rready not asserted         |

## 9. Test Plan

### Scenarios

1. **Register write/read:** Write value to each RW register; read back and verify
2. **Timing register defaults:** Verify all timing registers have correct reset values
3. **HC_CONTROL enable:** Set ENABLE bit; verify `ctrl_enable_o` asserts
4. **SW_RESET self-clear:** Set SW_RESET bit; verify it clears after 1 cycle and `sw_reset_o` pulses
5. **HC_STATUS live fields:** Verify FSM_IDLE, CMD_FULL, RESP_EMPTY reflect hardware inputs
6. **DAT write/read via bus:** Write all 16 DAT entries via register bus; read back and verify
7. **DAT hardware read:** Write DAT via bus; read via hw port (`dat_read_valid_i`); verify 1-cycle latency
8. **CMD 64-bit staging:** Write DWORD0, then DWORD1 to CMD_QUEUE_PORT; verify 64-bit `cmd_wdata_o` and `cmd_wvalid_o` pulse
9. **TX write-through:** Write to TX_DATA_PORT; verify `tx_wvalid_o` and `tx_wdata_o`
10. **RX/RESP read-through:** With data in FIFOs, read RX_DATA_PORT / RESP_PORT; verify data and rready signals
11. **QUEUE_STATUS accuracy:** Verify all 8 flag bits match actual FIFO states
12. **Invalid address:** Read/write to unmapped address; verify no side effects

### cocotb Test Structure

```
tests/
  test_csr/
    test_csr_registers.py   # Register read/write tests
    test_dat.py              # DAT-specific tests
    test_queue_ports.py      # Queue port bridge tests
    Makefile
```

## 10. Implementation Notes

- The `ready_o` output is always HIGH (single-cycle access, no wait states). This simplifies the bus protocol at the cost of not supporting stall conditions. If a FIFO is full when SW writes, the write is silently dropped — software must check QUEUE_STATUS first.
- The CMD staging register introduces state — if only DWORD0 is written and then a reset occurs, the staging state is lost (by design). Software should always write both DWORDs in sequence.
- DAT entries use 32-bit width (not 64-bit as in reference). The reference's upper 32 bits contained DCR/BCR/PID fields which are now stored in software after ENTDAA.
- Timing register defaults target I3C SDR at 333 MHz. For I2C FM mode, software must write the appropriate timing values before initiating I2C transfers.
