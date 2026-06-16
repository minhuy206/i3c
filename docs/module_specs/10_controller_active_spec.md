# Module: controller_active

> Status: Complete
> Reference: `i3c-core/src/ctrl/controller_active.sv` (292 lines)
> Estimated LoC: ~330 lines

## 1. Purpose

The `controller_active` module is the structural wrapper that instantiates and interconnects all controller core sub-modules. It is primarily a wiring module — its behavioral additions over a pure pass-through are:

1. **`daa_restart_pending_q` latch** — extends the 1-cycle `req_restart_o` pulse from `entdaa_controller` so `scl_generator` sees it (M-7 fix)
2. **TX/RX bus MUX** — selects between `flow_active` and `entdaa_controller` as the active bus source
3. **DAT read MUX** — selects between `flow_active` and `entdaa_controller` on the single hardware DAT read port
4. **SDA priority MUX** — `scl_generator` wins SDA when driving START/STOP/Sr (M-2 fix)
5. **OD/PP assignment** — forced open-drain when `scl_generator` drives SDA; otherwise follows `bus_tx_flow` (M-4 fix)

## 2. Dependencies

### Sub-modules

| Module               | Instance    | Role                                |
| -------------------- | ----------- | ----------------------------------- |
| `flow_active`        | `u_flow_fsm`| Command flow FSM                    |
| `bus_tx_flow`        | `u_tx_flow` | TX serializer                       |
| `bus_rx_flow`        | `u_rx_flow` | RX deserializer                     |
| `bus_monitor`        | `u_bus_mon` | START/STOP/Sr detection             |
| `scl_generator`      | `u_scl_gen` | SCL clock generation                |
| `entdaa_controller`  | `u_daa_ctrl`| ENTDAA loop manager (7-state FSM)   |

### Parent modules

- `i3c_controller_top` (top-level integration)

### Packages

- `i3c_pkg` — `bus_state_t`
- `controller_pkg` — `dat_entry_t`

## 3. Parameters

| Parameter  | Type | Default | Description     |
| ---------- | ---- | ------- | --------------- |
| `DatDepth` | int  | 32      | DAT table depth |

## 4. Ports / Interfaces

### Clock and Reset

| Signal   | Direction | Width | Description            |
| -------- | --------- | ----- | ---------------------- |
| `clk_i`  | Input     | 1     | System clock           |
| `rst_ni` | Input     | 1     | Active-low async reset |

### Physical Bus Interface (to/from i3c_phy)

| Signal        | Direction | Width | Description               |
| ------------- | --------- | ----- | ------------------------- |
| `ctrl_scl_i`  | Input     | 1     | Synchronized SCL from PHY |
| `ctrl_sda_i`  | Input     | 1     | Synchronized SDA from PHY |
| `ctrl_scl_o`  | Output    | 1     | SCL drive to PHY          |
| `ctrl_sda_o`  | Output    | 1     | SDA drive to PHY          |
| `ctrl_sda_oe_o` | Output | 1     | SDA output-enable to PHY  |
| `sel_od_pp_o` | Output    | 1     | OD/PP mode select to PHY  |

### HCI Queue Interfaces

Passed through from `flow_active`: CMD read, TX read, RX write, RESP write — all using `valid`/`ready` handshake.

### DAT Interface (Single Muxed Hardware Read Port)

`controller_active` exposes one hardware read port to `csr_registers`. Internally, it arbitrates between `flow_active` and `entdaa_controller` on this single port — they are never simultaneously active.

| Signal                | Direction | Width              | Description                  |
| --------------------- | --------- | ------------------ | ---------------------------- |
| `dat_read_valid_hw_o` | Output    | 1                  | DAT read request             |
| `dat_index_hw_o`      | Output    | `$clog2(DatDepth)` | DAT entry index              |
| `dat_rdata_hw_i`      | Input     | 32                 | DAT read data                |

### Timing Configuration (from CSR)

| Signal           | Direction | Width | Description                            |
| ---------------- | --------- | ----- | -------------------------------------- |
| `t_r_i`          | Input     | 20    | I3C rise time                          |
| `t_f_i`          | Input     | 20    | I3C fall time                          |
| `t_low_i`        | Input     | 20    | I3C push-pull-capable SCL LOW period   |
| `t_low_od_i`     | Input     | 20    | I3C open-drain SCL LOW period          |
| `t_high_i`       | Input     | 20    | I3C SCL HIGH period                    |
| `t_su_sta_i`     | Input     | 20    | I3C START setup time                   |
| `t_hd_sta_i`     | Input     | 20    | I3C START hold time                    |
| `t_su_sto_i`     | Input     | 20    | I3C STOP setup time                    |
| `t_su_dat_i`     | Input     | 20    | I3C data setup time                    |
| `t_hd_dat_i`     | Input     | 20    | I3C data hold time                     |
| `t_bus_free_i`   | Input     | 20    | I3C bus-free time after STOP           |
| `i2c_t_r_i`      | Input     | 20    | I2C rise time                          |
| `i2c_t_f_i`      | Input     | 20    | I2C fall time                          |
| `i2c_t_low_i`    | Input     | 20    | I2C SCL LOW period                     |
| `i2c_t_high_i`   | Input     | 20    | I2C SCL HIGH period                    |
| `i2c_t_su_sta_i` | Input     | 20    | I2C START setup time                   |
| `i2c_t_hd_sta_i` | Input     | 20    | I2C START hold time                    |
| `i2c_t_su_sto_i` | Input     | 20    | I2C STOP setup time                    |
| `i2c_t_su_dat_i` | Input     | 20    | I2C data setup time                    |
| `i2c_t_hd_dat_i` | Input     | 20    | I2C data hold time                     |
| `i2c_t_buf_i`    | Input     | 20    | I2C bus-free time after STOP           |

### Control / Status

| Signal                             | Direction | Width | Description                                |
| ---------------------------------- | --------- | ----- | ------------------------------------------ |
| `ctrl_enable_i`                    | Input     | 1     | Controller enable (from CSR HC_CONTROL[0]) |
| `broadcast_header_enable_i`        | Input     | 1     | Enable private-transfer broadcast header   |
| `i3c_fsm_en_i`                     | Input     | 1     | FSM enable (from CSR)                      |
| `abort_i`                          | Input     | 1     | Abort active transfer request              |
| `hc_seq_cancel_event_o`            | Output    | 1     | Command sequence cancellation event        |
| `hc_err_cmd_seq_timeout_event_o`   | Output    | 1     | Missing/invalid continuation event         |
| `i3c_fsm_idle_o`                   | Output    | 1     | FSM idle status                            |

## 5. Functional Description

### 5.1. Signal Routing Overview

```
                 ┌──────────────────────────────────────────────────────┐
                 │                  controller_active                   │
                 │                                                      │
 HCI Queues ─────┤──► u_flow_fsm ──┬──► u_tx_flow ──┐                  │
                 │       │  ▲      │                 ├──► SDA (MUX)    │
                 │       │  │      └──► u_rx_flow ◄──┘                  │
                 │       │  │(daa_restart_pending_q)                    │
                 │       │  ◄── u_daa_ctrl ──────────┐                  │
                 │       │                           │                  │
                 │       └──► u_scl_gen ─────────────┼──► SCL          │
                 │                    └──► SDA (prio) ┘                 │
                 │       u_bus_mon ◄── SCL/SDA        │                 │
 Timing Regs ────┤──────────────────────────────────► │                 │
 DAT ────────────┤──── (MUX: flow / daa_ctrl) ───────►│                 │
                 └──────────────────────────────────────────────────────┘
```

### 5.2. `daa_restart_pending_q` Latch (M-7 Fix)

`entdaa_controller` asserts `req_restart_o` for exactly one clock cycle when a per-device ENTDAA round ends and another device may respond. `scl_generator` samples this signal at the start of its next active cycle, which may be several cycles later. Without a latch, the pulse would be missed.

`controller_active` extends the pulse:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni)
    daa_restart_pending_q <= 1'b0;
  else if (daa_ctrl_req_restart)
    daa_restart_pending_q <= 1'b1;
  else if (scl_gen_req_restart_ack)
    daa_restart_pending_q <= 1'b0;
end
```

`scl_generator` receives `daa_restart_pending_q` (not the raw 1-cycle pulse) and acknowledges via `req_restart_ack_o` when it acts on it.

### 5.3. TX/RX Bus MUX

When `entdaa_controller` is active (`daa_active = flow_ccc_valid`), it takes exclusive control of `bus_tx_flow` and `bus_rx_flow`:

```systemverilog
assign daa_active = flow_ccc_valid;

always_comb begin
  if (daa_active) begin
    // entdaa_controller drives the bus
    mux_tx_req_byte  = daa_tx_req_byte;
    mux_tx_req_bit   = 1'b0;          // entdaa_controller never uses bit-level TX
    mux_tx_req_value = daa_tx_req_value;
    mux_tx_sel_od_pp = 1'b0;          // always Open-Drain during ENTDAA
    mux_rx_req_byte  = 1'b0;          // entdaa_controller never uses byte-level RX
    mux_rx_req_bit   = daa_rx_req_bit;
  end else begin
    // flow_active drives the bus
    mux_tx_req_byte  = flow_tx_req_byte;
    mux_tx_req_bit   = flow_tx_req_bit;
    mux_tx_req_value = flow_tx_req_value;
    mux_tx_sel_od_pp = flow_tx_sel_od_pp;
    mux_rx_req_byte  = flow_rx_req_byte;
    mux_rx_req_bit   = flow_rx_req_bit;
  end
end
```

### 5.4. DAT Read MUX

`flow_active` and `entdaa_controller` share a single hardware DAT read port. They are never simultaneously active (`flow_active` reads DAT in `FetchDAT` before enabling `entdaa_controller`; during ENTDAA rounds `flow_active` waits for `ccc_done_i`):

```systemverilog
always_comb begin
  if (daa_active) begin
    dat_read_valid_hw_o = daa_dat_read_valid;
    dat_index_hw_o      = daa_dat_index;
  end else begin
    dat_read_valid_hw_o = flow_dat_read_valid;
    dat_index_hw_o      = flow_dat_index;
  end
end
assign daa_dat_rdata  = dat_rdata_hw_i;
assign flow_dat_rdata = dat_rdata_hw_i;
```

### 5.5. SDA Priority MUX (M-2 Fix)

SDA is driven from multiple sources. `scl_generator` wins priority during START/STOP/Sr conditions (it signals this via `sda_ctrl_active_o`):

```systemverilog
assign ctrl_sda_o = scl_gen_driving_sda ? scl_gen_sda
                  : !tx_flow_idle       ? tx_flow_sda
                  :                      1'b1;
```

Where `scl_gen_driving_sda` is `u_scl_gen.sda_ctrl_active_o`. The reference had a race condition where `scl_generator` and `bus_tx_flow` could simultaneously drive SDA at START/STOP boundaries.

### 5.6. OD/PP Assignment (M-4 Fix)

```systemverilog
assign sel_od_pp_o = scl_gen_driving_sda ? 1'b0 : tx_flow_sel_od_pp;
```

When `scl_generator` controls SDA (START/STOP/Sr), the bus is always open-drain. Otherwise, `bus_tx_flow` determines the mode based on the transaction phase.

### 5.7. Bus Monitor and TX Edge Connections

`bus_monitor` receives the active rise/fall timing selected by `flow_active.use_i2c_timing_o`. It monitors the synchronized PHY readback and provides bus state, START, repeated START, and STOP detection:

```systemverilog
bus_monitor u_bus_mon (
  .clk_i, .rst_ni,
  .enable_i  (ctrl_enable_i),
  .scl_i     (ctrl_scl_i),
  .sda_i     (ctrl_sda_i),
  .t_r_i     (active_t_r),
  .t_f_i     (active_t_f),
  .state_o   (bus_state)
);
```

For TX timing, the RTL intentionally uses a direct copy of `scl_generator.scl_o` rather than the delayed PHY/readback path. `controller_active` registers `scl_gen_scl` for one cycle and derives local TX edge/stable signals:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) scl_gen_scl_q <= 1'b1;
  else         scl_gen_scl_q <= scl_gen_scl;
end

assign scl_tx_negedge    =  scl_gen_scl_q & ~scl_gen_scl;
assign scl_tx_posedge    = ~scl_gen_scl_q &  scl_gen_scl;
assign scl_tx_stable_low = ~scl_gen_scl_q & ~scl_gen_scl;
```

These local TX timing signals are connected to `bus_tx_flow`. RX sampling and bus-condition detection continue to use `bus_monitor` readback:

```systemverilog
// bus_tx_flow
.scl_negedge_i    (scl_tx_negedge),
.scl_posedge_i    (scl_tx_posedge),
.scl_stable_low_i (scl_tx_stable_low),

// bus_rx_flow
.scl_posedge_i    (bus_state.scl.pos_edge),
.scl_stable_high_i(bus_state.scl.stable_high),
.sda_i            (bus_state.sda.value),

// scl_generator
.scl_i            (bus_state.scl.value),

// flow_active (bus events)
.bus_start_det_i  (bus_state.start_det),
.bus_rstart_det_i (bus_state.rstart_det),
.bus_stop_det_i   (bus_state.stop_det),
```

### 5.8. I3C/I2C Mode Selection

`flow_active` drives `sel_i3c_i2c_o` based on the current command's DAT entry:

```systemverilog
// flow_active → scl_generator
.sel_i3c_i2c_i(flow_sel_i3c_i2c),  // 0 = I2C FM, 1 = I3C SDR
```

## 6. Timing Requirements

No additional timing constraints beyond those of sub-modules. Behavioral sequential logic in this wrapper is limited to `daa_restart_pending_q` and the one-cycle `scl_gen_scl_q` register used to derive local TX edge/stable signals.

## 7. Changes from Reference Design

| Aspect                     | Reference                                                           | This Design                                                                     |
| -------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Parameters                 | `DatDepth`, `CmdFifoDepth`, `TxFifoDepth`, `RxFifoDepth`, `RespFifoDepth` | `DatDepth` only — FIFO depths owned by `i3c_controller_top`            |
| Bus instances              | Dual bus (`ctrl_bus_i[2]`, `ctrl_scl_o[2]`)                         | Single bus                                                                      |
| I2C controller FSM         | Full `i2c_controller_fsm` instance                                  | Removed (flow_active drives bus directly)                                       |
| I3C controller FSM         | Stub (`i3c_controller_fsm`, drives '1)                              | Replaced by `scl_generator`                                                     |
| OD/PP switching            | Hardcoded to `'0` (TODO)                                            | Phase-based: `scl_gen_driving_sda ? 1'b0 : tx_flow_sel_od_pp` (M-4)            |
| SDA MUX                    | Not present                                                         | Priority MUX: scl_gen > tx_flow > idle (M-2)                                   |
| DAT read port              | Single read port                                                    | Single muxed port shared between `flow_active` and `entdaa_controller`          |
| `daa_restart_pending_q`    | Not present                                                         | Added to extend 1-cycle pulse from `entdaa_controller` for `scl_generator` (M-7)|
| IBI queue ports            | Full IBI FIFO interface                                             | Removed                                                                         |
| DCT interface              | Full DCT read/write ports                                           | Removed                                                                         |
| Arbitration lost detection | Compared SDA driven vs read                                         | Removed — master reads bus as-is during ENTDAA                                  |
| Line count                 | 292 lines                                                           | ~330 lines                                                                      |

## 8. Error Handling

No error logic at this level. Errors are detected by sub-modules (`flow_active`, `bus_monitor`, `entdaa_controller`) and reported through the RESP FIFO.

## 9. Test Plan

### Scenarios

1. **Integration: I3C Private Write:** End-to-end write transaction; verify SCL/SDA waveforms
2. **Integration: I3C Private Read:** End-to-end read transaction; verify correct data flow
3. **Integration: I2C Write:** Legacy I2C write; verify open-drain-only signaling
4. **Integration: ENTDAA:** Full DAA sequence with simulated target; verify address assignment
5. **OD/PP switching:** Verify OD during address phase, PP during data phase of I3C transfer (M-4)
6. **SDA MUX priority:** Verify `scl_generator` wins SDA during START/STOP/Sr vs `bus_tx_flow` (M-2)
7. **`daa_restart_pending_q`:** Verify 1-cycle pulse is held until `scl_generator` acknowledges (M-7)
8. **Bus monitor distribution:** Verify `bus_state` correctly distributed to all consumers
9. **Reset:** Verify all sub-modules enter idle/safe state on reset

### UVM Test Structure

```
src/verification/uvm_i3c/
  sequences/
    i3c_entdaa_vseq.sv       # Exercises daa_restart_pending_q path
    i3c_private_write_vseq.sv
    i3c_private_read_vseq.sv
    i3c_i2c_write_vseq.sv
  tests/
    i3c_entdaa_test.sv
    i3c_private_rw_test.sv
    i3c_i2c_test.sv
```

## 10. Implementation Notes

- `controller_active` has **no FSM**. Its only sequential logic is `daa_restart_pending_q` and `scl_gen_scl_q`; everything else is combinational wiring or pass-through.
- FIFO depth parameters (`CmdFifoDepth`, `TxFifoDepth`, `RxFifoDepth`, `RespFifoDepth`) do **not** appear in `controller_active` — they are parameters of `i3c_controller_top` and `hci_queues` only.
- The `daa_active` signal is simply `flow_ccc_valid` — `flow_active` holds it high for the entire ENTDAA loop, which is sufficient to multiplex bus ownership to `entdaa_controller`.
- `bus_monitor` is connected to active `t_r` and `t_f` only. The other active timing registers are routed to `scl_generator` and `bus_tx_flow`, not to `bus_monitor`.
- `bus_tx_flow` uses local edge/stable signals derived from `scl_generator.scl_o`; `bus_rx_flow` still samples from `bus_monitor` readback.
- The single hardware DAT read port design is safe because `flow_active` reads DAT in `FetchDAT` before enabling `entdaa_controller` (via `ccc_valid_o`), and during ENTDAA rounds `flow_active` blocks in a wait state until `ccc_done_i` is asserted.
- There is no arbitration-lost detection. On the master side, the master is a passive observer during the PID transmission — it reads the bit-by-bit result of target arbitration without needing to compare drive vs readback.

## 11. Deferred RTL/Spec Cleanup Notes

The remaining known mismatches are intentionally deferred for a later cleanup pass:

- `daa_restart_pending_q` is documented as an explicit `req_restart_i` / `req_restart_ack_o` handshake with `scl_generator`, but current RTL folds DAA restart into `gen_rstart_i` and clears the pending latch using `scl_gen_done || !daa_active`.
- The ENTDAA TX/RX MUX examples show some DAA request signals forced in `controller_active`; current RTL passes the corresponding `entdaa_controller` signals through. Current behavior remains equivalent because `entdaa_fsm` ties the unused request paths low and keeps ENTDAA open-drain.
