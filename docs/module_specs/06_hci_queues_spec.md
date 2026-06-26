# Module: HCI Queues (CMD / TX / RX / RESP FIFOs)

> Status: Complete
> Reference: `i3c-core/src/hci/queues.sv` and submodules (2,500+ lines total)
> Estimated LoC: ~140 lines (4 FIFO instances + wrapper)

## 1. Purpose

The HCI (Host Controller Interface) queues provide the data path between software and the I3C controller hardware. Software enqueues commands and write data; hardware produces responses and read data. The queues decouple software timing from bus timing, allowing the controller to operate autonomously once a command is submitted.

Four synchronous FIFOs:

| Queue     | Direction | Width  | Software Side | Hardware Side |
| --------- | --------- | ------ | ------------- | ------------- |
| CMD FIFO  | SW → HW   | 64-bit | Write port    | Read port     |
| TX FIFO   | SW → HW   | 32-bit | Write port    | Read port     |
| RX FIFO   | HW → SW   | 32-bit | Write port    | Read port     |
| RESP FIFO | HW → SW   | 32-bit | Write port    | Read port     |

## 2. Dependencies

### Sub-modules

- `sync_fifo` — Generic synchronous FIFO (parameterized width/depth); no own spec, cross-referenced here

### Parent modules

- `i3c_controller_top` (top-level)

### Packages

- `i3c_pkg` — For descriptor type definitions (used by connected modules, not internally)

## 3. Parameters

| Parameter       | Type | Default | Description              |
| --------------- | ---- | ------- | ------------------------ |
| `CmdFifoDepth`  | int  | 64      | CMD FIFO depth (entries) |
| `TxFifoDepth`   | int  | 64      | TX FIFO depth            |
| `RxFifoDepth`   | int  | 64      | RX FIFO depth            |
| `RespFifoDepth` | int  | 64      | RESP FIFO depth          |
| `CmdDataWidth`  | int  | 64      | CMD entry width (bits)   |
| `TxDataWidth`   | int  | 32      | TX entry width           |
| `RxDataWidth`   | int  | 32      | RX entry width           |
| `RespDataWidth` | int  | 32      | RESP entry width         |

Four derived `localparam`s size the depth ports (each `= $clog2(Depth + 1)`, to represent counts `0..Depth`):

| Localparam     | Value                      | Description               |
| -------------- | --------------------------- | -------------------------- |
| `CmdDepthW`    | `$clog2(CmdFifoDepth + 1)`  | Width of `cmd_depth_o`     |
| `TxDepthW`     | `$clog2(TxFifoDepth + 1)`   | Width of `tx_depth_o`      |
| `RxDepthW`     | `$clog2(RxFifoDepth + 1)`   | Width of `rx_depth_o`      |
| `RespDepthW`   | `$clog2(RespFifoDepth + 1)` | Width of `resp_depth_o`    |

## 4. Ports / Interfaces

### Clock and Reset

| Signal   | Direction | Width | Description            |
| -------- | --------- | ----- | ---------------------- |
| `clk_i`  | Input     | 1     | System clock           |
| `rst_ni` | Input     | 1     | Active-low async reset |

### Software-Side Reset

| Signal       | Direction | Width | Description                                     |
| ------------ | --------- | ----- | ----------------------------------------------- |
| `sw_reset_i` | Input     | 1     | Software-initiated FIFO reset (from HC_CONTROL) |

### CMD FIFO — Software Write / Hardware Read

| Signal         | Direction | Width | Description                |
| -------------- | --------- | ----- | -------------------------- |
| `cmd_wvalid_i` | Input     | 1     | SW write valid             |
| `cmd_wready_o` | Output    | 1     | FIFO ready to accept       |
| `cmd_wdata_i`  | Input     | 64    | Command descriptor from SW |
| `cmd_rvalid_o` | Output    | 1     | Data available for HW      |
| `cmd_rready_i` | Input     | 1     | HW read acknowledge        |
| `cmd_rdata_o`  | Output    | 64    | Command descriptor to HW   |
| `cmd_full_o`   | Output    | 1     | FIFO full flag             |
| `cmd_empty_o`  | Output    | 1     | FIFO empty flag            |
| `cmd_depth_o`  | Output    | `CmdDepthW`  | Current FIFO occupancy (entries) |

### TX FIFO — Software Write / Hardware Read

| Signal        | Direction | Width | Description           |
| ------------- | --------- | ----- | --------------------- |
| `tx_wvalid_i` | Input     | 1     | SW write valid        |
| `tx_wready_o` | Output    | 1     | FIFO ready to accept  |
| `tx_wdata_i`  | Input     | 32    | TX data from SW       |
| `tx_rvalid_o` | Output    | 1     | Data available for HW |
| `tx_rready_i` | Input     | 1     | HW read acknowledge   |
| `tx_rdata_o`  | Output    | 32    | TX data to HW         |
| `tx_full_o`   | Output    | 1     | FIFO full flag        |
| `tx_empty_o`  | Output    | 1     | FIFO empty flag       |
| `tx_depth_o`  | Output    | `TxDepthW`   | Current FIFO occupancy (entries) |

### RX FIFO — Hardware Write / Software Read

| Signal        | Direction | Width | Description           |
| ------------- | --------- | ----- | --------------------- |
| `rx_wvalid_i` | Input     | 1     | HW write valid        |
| `rx_wready_o` | Output    | 1     | FIFO ready to accept  |
| `rx_wdata_i`  | Input     | 32    | RX data from HW       |
| `rx_rvalid_o` | Output    | 1     | Data available for SW |
| `rx_rready_i` | Input     | 1     | SW read acknowledge   |
| `rx_rdata_o`  | Output    | 32    | RX data to SW         |
| `rx_full_o`   | Output    | 1     | FIFO full flag        |
| `rx_empty_o`  | Output    | 1     | FIFO empty flag       |
| `rx_depth_o`  | Output    | `RxDepthW`   | Current FIFO occupancy (entries) |

### RESP FIFO — Hardware Write / Software Read

| Signal          | Direction | Width | Description                 |
| --------------- | --------- | ----- | --------------------------- |
| `resp_wvalid_i` | Input     | 1     | HW write valid              |
| `resp_wready_o` | Output    | 1     | FIFO ready to accept        |
| `resp_wdata_i`  | Input     | 32    | Response descriptor from HW |
| `resp_rvalid_o` | Output    | 1     | Data available for SW       |
| `resp_rready_i` | Input     | 1     | SW read acknowledge         |
| `resp_rdata_o`  | Output    | 32    | Response descriptor to SW   |
| `resp_full_o`   | Output    | 1     | RESP FIFO full flag         |
| `resp_empty_o`  | Output    | 1     | RESP FIFO empty flag        |
| `resp_depth_o`  | Output    | `RespDepthW` | Current FIFO occupancy (entries) |

## 5. Functional Description

### 5.1. sync_fifo Sub-module Interface

Each FIFO is an instance of `sync_fifo` (no own spec; parameterized via width/depth):

```systemverilog
module sync_fifo #(
  parameter int unsigned Width = 32,
  parameter int unsigned Depth = 64
)(
  input  logic             clk_i,
  input  logic             rst_ni,
  input  logic             flush_i,    // Synchronous flush (sw_reset)

  // Write port
  input  logic             wvalid_i,
  output logic             wready_o,
  input  logic [Width-1:0] wdata_i,

  // Read port
  output logic             rvalid_o,
  input  logic             rready_i,
  output logic [Width-1:0] rdata_o,

  // Status
  output logic             full_o,
  output logic             empty_o,
  output logic [DepthW-1:0] depth_o
);
```

**Implementation:**

- Circular buffer using `logic [Width-1:0] mem [0:Depth-1]`
- Write pointer (`wptr`) and read pointer (`rptr`), both `$clog2(Depth)+1` bits wide (extra MSB for full/empty detection)
- `full_o  = (rptr_q == {~wptr_q[PtrW], wptr_q[PtrW-1:0]})` — same lower bits, opposite MSB
- `empty_o = (wptr_q == rptr_q)` — all bits equal
- `depth_o = wptr_q - rptr_q` — current occupancy in entries, width `DepthW = $clog2(Depth + 1)`
- `wready_o = ~full_o`
- `rvalid_o = ~empty_o`
- Write occurs when `wvalid_i & wready_o`; read occurs when `rvalid_o & rready_i`
- `flush_i` resets both pointers to 0 (does NOT clear memory)

### 5.2. HCI Queue Wrapper Structure

```systemverilog
module hci_queues #(...) (...);
  sync_fifo #(.Width(CmdDataWidth),  .Depth(CmdFifoDepth))  cmd_fifo  (...);
  sync_fifo #(.Width(TxDataWidth),   .Depth(TxFifoDepth))   tx_fifo   (...);
  sync_fifo #(.Width(RxDataWidth),   .Depth(RxFifoDepth))   rx_fifo   (...);
  sync_fifo #(.Width(RespDataWidth), .Depth(RespFifoDepth)) resp_fifo (...);
endmodule
```

All four `flush_i` ports are wired to `sw_reset_i`.

### 5.3. Queue Data Formats

**CMD FIFO Entry (64-bit):** See `i3c_pkg` for descriptor types:

| Command Type            | Attr Code | DWORD1                                           | DWORD0                                                               |
| ----------------------- | --------- | ------------------------------------------------ | -------------------------------------------------------------------- |
| Immediate Data Transfer | `3'b001`  | `{data_byte4, data_byte3, data_byte2, def_or_data_byte1}` | `{toc, wroc, rnw, mode, dtt, rsvd, dev_idx, cp, cmd, tid, attr}` |
| Regular Transfer        | `3'b000`  | `{data_length, rsvd, def_byte}`                  | `{toc, wroc, rnw, mode, dbp, sre, rsvd, dev_idx, cp, cmd, tid, attr}` |
| Address Assignment      | `3'b010`  | `{rsvd}`                                         | `{toc, wroc, dev_count, rsvd, dev_idx, rsvd, cmd, tid, attr}`       |

**TX FIFO Entry (32-bit):** Raw data DWORD — up to 4 bytes of payload per entry.

**RX FIFO Entry (32-bit):** Raw data DWORD — up to 4 bytes received per entry.

**RESP FIFO Entry (32-bit):**

```
Bits [31:28] — err_status (i3c_resp_err_status_e)
Bits [27:24] — tid (Transaction ID, matches CMD)
Bits [23:16] — reserved
Bits [15:0]  — data_length (actual bytes transferred)
```

## 6. Timing Requirements

| Aspect        | Requirement                                                        |
| ------------- | ------------------------------------------------------------------ |
| Write latency | Data available for read 1 cycle after write (if FIFO was empty)    |
| Read latency  | Data on `rdata_o` same cycle as `rvalid_o` (combinational output)  |
| Throughput    | 1 entry per clock cycle (write or read)                            |
| Flush latency | 1 cycle to reset pointers                                          |

## 7. Changes from Reference Design

| Aspect                   | Reference                                 | This Design                        |
| ------------------------ | ----------------------------------------- | ---------------------------------- |
| Complexity               | 2,500+ lines with threshold system        | ~140 lines, simple FIFOs           |
| Threshold interrupts     | Complex start/ready threshold per queue   | Removed — use full/empty flags     |
| IBI queue                | 5th FIFO for In-Band Interrupts           | Removed (IBI out of scope)         |
| TTI (Target Transaction) | `tti.sv` (600+ lines)                     | Removed (target mode out of scope) |
| CSRI wrapper             | `csri.sv` (74 lines)                      | Removed                            |
| Queue depth indicators   | Per-queue depth with threshold comparison | Removed (full/empty only)          |
| Reset control            | Per-queue individual reset                | Single `sw_reset_i` for all        |

## 8. Register Interface

The queues are accessed via the CSR register interface at these offsets (see spec 07):

| Register         | Offset | Access | Description                                              |
| ---------------- | ------ | ------ | -------------------------------------------------------- |
| `CMD_QUEUE_PORT` | 0x080  | W      | Write CMD descriptor (2x 32-bit writes for 64-bit entry) |
| `PIO_DATA_PORT`  | 0x088  | W/R    | Write TX data DWORD / read RX data DWORD                 |
| `RESP_PORT`      | 0x084  | R      | Read response descriptor                                 |
| `QUEUE_STATUS`   | 0x0B4  | R      | Full/empty flags for all queues                          |

**CMD FIFO 64-bit write protocol:** Software writes DWORD0 first (offset 0x080), then DWORD1 (offset 0x080 again). The CSR module assembles the 64-bit entry and writes to CMD FIFO as a single transaction.

## 9. Error Handling

| Error              | Detection          | Behavior                        |
| ------------------ | ------------------ | ------------------------------- |
| Write to full FIFO | `wvalid & ~wready` | Write ignored, data lost        |
| Read from empty    | `rready & ~rvalid` | No data transferred             |
| Overflow           | `full_o` flag      | Reported to SW via QUEUE_STATUS |

Software is responsible for checking full/empty status before accessing queue ports. The controller hardware checks `tx_queue_empty` before popping TX data and `resp_queue_full` before pushing responses.

## 10. Test Plan

### Scenarios

1. **Basic write/read:** Write N entries, read N entries; verify data integrity (FIFO order preserved)
2. **Full flag:** Write until full; verify `full_o` asserts at correct depth; verify additional writes are ignored
3. **Empty flag:** Read all entries; verify `empty_o` asserts; verify reads produce no data
4. **Flush:** Fill FIFO, assert `flush_i`; verify `empty_o` immediately
5. **Simultaneous read/write:** With FIFO partially full, write and read on same cycle; verify correct behavior
6. **Back-pressure:** Assert `wvalid` while full; verify `wready == 0` and no corruption
7. **CMD 64-bit integrity:** Write 64-bit descriptors; verify DWORD1:DWORD0 alignment preserved
8. **All four queues:** Exercise all 4 FIFOs simultaneously; verify no cross-talk
9. **Reset behavior:** Verify all FIFOs empty after `rst_ni` assertion
10. **sw_reset_i flush:** Write data to all FIFOs, assert `sw_reset_i`; verify all empty

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

**Module coverage note:** `hci_queues` is exercised by all tests — the CMD FIFO, TX FIFO, RX FIFO, and RESP FIFO are used in every transaction type.

## 11. Implementation Notes

- `sync_fifo` uses a circular buffer with extra-MSB pointer comparison for full/empty detection. Pointers are `$clog2(Depth)+1` bits wide; the MSB wraps independently and allows distinguishing full from empty when lower bits are equal. For FPGA, the synthesizer will infer block RAM for depth >= 16 entries.
- The CMD FIFO is 64-bit wide — on a 32-bit register bus, the CSR module handles the 2-write assembly. The FIFO itself always handles full 64-bit entries.
- The reference design's threshold system (`start_thld`, `ready_thld`, `thld_trig` signals) is removed. The simplified design relies on `full` / `empty` flags. If interrupt-driven operation is needed later, a simple comparator on `depth_o` can be added in the CSR module.
- `depth_o` IS exposed at the `hci_queues` level: each `sync_fifo`'s internally computed `depth_o` is wired straight through to a per-queue port (`cmd_depth_o`, `tx_depth_o`, `rx_depth_o`, `resp_depth_o`), sized by the corresponding `*DepthW` localparam.
