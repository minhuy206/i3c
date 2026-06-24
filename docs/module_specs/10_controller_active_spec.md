# Module: controller_active

> Status: Complete
> Reference: `i3c-core/src/ctrl/controller_active.sv` (292 lines)
> Estimated LoC: ~330 lines

## 1. Purpose

The `controller_active` module is the structural wrapper that instantiates and interconnects all controller core sub-modules. It is primarily a wiring module — its behavioral additions over a pure pass-through are:

1. **`daa_rstart_pending_q` latch** — extends the 1-cycle `req_rstart_o` pulse from `entdaa_controller` so `scl_generator` sees it, folded into `gen_rstart` (M-7 fix)
2. **TX/RX bus MUX** — selects between `flow_active` and `entdaa_controller` as the active bus source, including the bit-level handoff request
3. **DAT read MUX** — selects between `flow_active` and `entdaa_controller` on the single hardware DAT read port
4. **Low-bit handoff/takeover** — master actively drives SDA low during ENTDAA address-bit arbitration when it observes the bus already pulled low
5. **SDA priority MUX** — `scl_generator` > handoff takeover > `bus_tx_flow`, in that priority order (M-2 fix)
6. **OD/PP assignment** — forced open-drain when `scl_generator` drives SDA or takeover is active; otherwise follows `bus_tx_flow` (M-4 fix)

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
                 │       │  │(daa_rstart_pending_q)                     │
                 │       │  ◄── u_daa_ctrl ──────────┐                  │
                 │       │                           │                  │
                 │       └──► u_scl_gen ─────────────┼──► SCL          │
                 │                    └──► SDA (prio) ┘                 │
                 │       u_bus_mon ◄── SCL/SDA        │                 │
 Timing Regs ────┤──────────────────────────────────► │                 │
 DAT ────────────┤──── (MUX: flow / daa_ctrl) ───────►│                 │
                 └──────────────────────────────────────────────────────┘
```

### 5.2. `daa_rstart_pending_q` Latch and DAA Stop/NACK Routing

`entdaa_controller` asserts `req_rstart_o` for exactly one clock cycle when a per-device ENTDAA round ends and another device may respond. `scl_generator`'s `gen_rstart_i` is sampled combinationally, so a single-cycle pulse can be missed if `scl_generator` is not ready to act on it in that same cycle. `controller_active` latches the request and holds it until `scl_generator` finishes the current operation or ENTDAA ends:

```systemverilog
always_ff @(posedge clk_i or negedge rst_ni) begin : update_daa_rstart_pending
  if (!rst_ni) daa_rstart_pending_q <= 1'b0;
  else daa_rstart_pending_q <= daa_rstart_pending_d;
end

always_comb begin : compute_daa_rstart_pending_d
  daa_rstart_pending_d = daa_rstart_pending_q;
  if (daa_req_rstart) daa_rstart_pending_d = 1'b1;
  else if (scl_gen_done || !daa_active) daa_rstart_pending_d = 1'b0;
end
```

There is no dedicated `req_rstart_ack_o` port on `scl_generator` — the pending flag is cleared implicitly when `scl_gen_done` fires (the requested operation, including the restart, has completed) or when ENTDAA is no longer active. The latched output folds directly into the repeated-START request driven into `scl_generator`, combined with the normal `flow_active` restart request:

```systemverilog
assign gen_rstart = flow_gen_rstart | daa_req_rstart | daa_rstart_pending_q;
```

**DAA stop / NACK-error routing.** `flow_active` and `entdaa_controller` also exchange stop and error-termination signals directly (no intermediate latching in `controller_active`):

```systemverilog
// flow_active -> entdaa_controller
.daa_valid_i  (flow_ccc_valid),
.stop_i       (flow_daa_stop),     // from flow_active.daa_stop_o

// entdaa_controller -> flow_active
.ccc_done_i       (daa_done),
.daa_stop_req_i   (daa_req_stop),    // entdaa_controller.req_stop_o
.daa_stopped_i    (daa_stopped),     // entdaa_controller.stopped_o
.daa_nack_error_i (daa_nack_error),  // entdaa_controller.nack_error_o
```

`flow_active` asserts `daa_stop_o` to request that the current ENTDAA round terminate (e.g. device-count exhausted or host abort); `entdaa_controller` acknowledges with `req_stop_o`/`stopped_o` and separately reports `nack_error_o` when a target NACKs during DAA so `flow_active` can route the resulting STOP/error status to the RESP FIFO.

**OD-low timing during ENTDAA.** While `daa_active` is asserted, `controller_active` forces open-drain-LOW timing for `scl_generator` regardless of what `flow_active` requests, since ENTDAA arbitration is always open-drain:

```systemverilog
assign active_scl_use_od_low = flow_use_i2c_timing ? 1'b0 :
                               daa_active ? 1'b1 : flow_scl_use_od_low;
```

I2C legacy timing (`flow_use_i2c_timing`) always wins over both ENTDAA and the `flow_active`-requested OD-low mode, since I2C has no OD/PP switching.

### 5.3. TX/RX Bus MUX

When `entdaa_controller` is active (`daa_active = flow_ccc_valid`), it takes exclusive control of `bus_tx_flow` and `bus_rx_flow`. The mux passes each source's request signals straight through — including the bit-level handoff signal used during ENTDAA address-bit arbitration (see §5.9):

```systemverilog
assign daa_active = flow_ccc_valid;

always_comb begin : mux_bus_tx_rx
  if (daa_active) begin
    // entdaa_controller drives the bus
    mux_tx_req_byte = daa_tx_req_byte;
    mux_tx_req_bit = daa_tx_req_bit;
    mux_tx_req_value = daa_tx_req_value;
    mux_tx_sel_od_pp = daa_tx_sel_od_pp;
    mux_rx_req_byte = daa_rx_req_byte;
    mux_rx_req_bit = daa_rx_req_bit;
    mux_rx_req_bit_handoff = daa_rx_req_bit_handoff;
  end else begin
    // flow_active drives the bus
    mux_tx_req_byte = flow_tx_req_byte;
    mux_tx_req_bit = flow_tx_req_bit;
    mux_tx_req_value = flow_tx_req_value;
    mux_tx_sel_od_pp = flow_sel_od_pp;
    mux_rx_req_byte = flow_rx_req_byte;
    mux_rx_req_bit = flow_rx_req_bit;
    mux_rx_req_bit_handoff = flow_rx_req_bit_handoff;
  end
end
```

Unlike an earlier design that forced `mux_tx_req_bit`, `mux_rx_req_byte`, and `mux_tx_sel_od_pp` to fixed values during ENTDAA, the current RTL relies on `entdaa_controller` (and `entdaa_fsm`) to drive each of its own request signals to the correct value (e.g. always open-drain, bit-level RX) — `controller_active` performs no additional forcing.

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
```

`dat_rdata_hw_i` itself is not muxed or buffered through an intermediate signal — both `flow_active` and `entdaa_controller` are wired directly to the shared `dat_rdata_hw_i` input port and read whichever data the single hardware DAT port returns, relying on the mutual-exclusion guarantee above.

### 5.5. SDA Priority MUX (M-2 Fix) and Low-Bit Takeover

SDA is driven from three prioritized sources: `scl_generator` (START/STOP/Sr), the low-bit handoff/takeover mechanism (see §5.9), and `bus_tx_flow` (normal byte/bit transmission):

```systemverilog
assign ctrl_sda_o = scl_gen_driving_sda ? scl_gen_sda :
    handoff_takeover_q ? 1'b0 : tx_flow_sda_drive ? tx_flow_sda : 1'b1;
```

Where `scl_gen_driving_sda` is `u_scl_gen.sda_ctrl_active_o`. Priority order is: (1) `scl_generator` wins outright during START/STOP/Sr; (2) if the master has taken over low-bit arbitration (`handoff_takeover_q`), it drives SDA low; (3) otherwise `bus_tx_flow` drives its bit value only while actively driving (`tx_flow_sda_drive`); (4) idle default is `1'b1` (released/high). The reference design had a race condition where `scl_generator` and `bus_tx_flow` could simultaneously drive SDA at START/STOP boundaries — this priority chain resolves it.

`ctrl_sda_oe_o` (output-enable) follows the same three-way priority, but expresses *whether* to drive rather than *what value* to drive:

```systemverilog
assign ctrl_sda_oe_o = scl_gen_driving_sda ? ~scl_gen_sda
    : handoff_takeover_q ? 1'b1
    : tx_flow_sda_drive ? (tx_flow_sel_od_pp | ~tx_flow_sda) : 1'b0;
```

- While `scl_generator` drives SDA, output-enable is asserted only when `scl_gen_sda` is low (open-drain semantics: only the low level is actively driven, high is released).
- During low-bit takeover, output-enable is forced high (actively driving low, per `ctrl_sda_o` above).
- While `bus_tx_flow` is driving, output-enable is asserted either unconditionally in push-pull mode (`tx_flow_sel_od_pp`) or only when the bit value is low in open-drain mode (`~tx_flow_sda`) — matching open-drain semantics for the OD case while always enabling in PP mode.
- Otherwise (idle), output-enable is deasserted (`1'b0`), releasing the bus.

### 5.6. OD/PP Assignment (M-4 Fix)

```systemverilog
assign sel_od_pp_o = (scl_gen_driving_sda || handoff_takeover_q) ? 1'b0 : tx_flow_sel_od_pp;
```

When `scl_generator` controls SDA (START/STOP/Sr) or the master is in low-bit takeover, the bus is forced open-drain. Otherwise, `bus_tx_flow` determines the mode based on the transaction phase.

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

### 5.9. Low-Bit Handoff / Takeover (ENTDAA Address-Bit Arbitration)

During ENTDAA, multiple unassigned targets drive the bus open-drain simultaneously while transmitting their 48-bit PID, BCR, and DCR. Per the I3C spec, on each address bit a target with a `0` wins arbitration over a target driving `1`; losing targets drop out, and the *master itself* must also actively drive the bus low for the duration of any bit period in which the wired-AND result is `0`, so that any target which initially drove `1` but observes the bus has already been pulled low can correctly sample a `0` and withdraw. The `mux_rx_req_bit_handoff` signal — sourced from `entdaa_controller.bus_rx_req_bit_handoff_o` while ENTDAA is active — marks each bit period that requires this master-side takeover behavior, and is ORed directly into `bus_rx_flow`'s sampling request:

```systemverilog
.rx_req_bit_i (mux_rx_req_bit | mux_rx_req_bit_handoff),
```

`controller_active` tracks the handoff/takeover state with a 2-bit FSM-like pair of registers:

```systemverilog
logic handoff_sampled_q;
logic handoff_takeover_q;

always_ff @(posedge clk_i or negedge rst_ni) begin : update_low_bit_handoff
  if (!rst_ni) begin
    handoff_sampled_q  <= 1'b0;
    handoff_takeover_q <= 1'b0;
  end else begin
    if (!mux_rx_req_bit_handoff) begin
      handoff_sampled_q <= 1'b0;
    end

    if (handoff_takeover_q && (scl_tx_negedge || scl_gen_driving_sda)) begin
      handoff_takeover_q <= 1'b0;
    end

    if (mux_rx_req_bit_handoff && !handoff_sampled_q && scl_tx_posedge) begin
      handoff_sampled_q  <= 1'b1;
      handoff_takeover_q <= ~ctrl_sda_i;
    end
  end
end
```

Behavior:

- **Sampling.** On the SCL rising edge (`scl_tx_posedge`) of a handoff-marked bit period, if the bit has not already been sampled this period, `handoff_sampled_q` latches high and `handoff_takeover_q` captures the inverted current bus value (`~ctrl_sda_i`) — i.e. takeover is armed exactly when the wired-AND result on the bus is `0`.
- **Takeover drive.** While `handoff_takeover_q` is set, the master actively drives SDA low and open-drain (see §5.5/§5.6 `ctrl_sda_o`/`ctrl_sda_oe_o`/`sel_od_pp_o` equations), reinforcing the bus-low result for any remaining bit time regardless of what the contending targets are doing.
- **Release.** `handoff_takeover_q` clears on the next SCL falling edge (`scl_tx_negedge`) or as soon as `scl_generator` takes over SDA (`scl_gen_driving_sda`) — whichever comes first ends the master's forced-low drive for that bit.
- **Re-arming.** `handoff_sampled_q` clears whenever the handoff request is not asserted (`!mux_rx_req_bit_handoff`), so the next handoff-marked bit period can sample and arm takeover again.

This mechanism is fully decoupled from the normal RX byte/bit request path (`mux_rx_req_bit`) and from the TX path — `bus_tx_flow`/`entdaa_controller`'s TX requests are unaffected by handoff/takeover; only SDA drive priority (§5.5) and OD/PP mode (§5.6) are altered while `handoff_takeover_q` is set.

## 6. Timing Requirements

No additional timing constraints beyond those of sub-modules. Behavioral sequential logic in this wrapper is limited to `daa_rstart_pending_q`, `handoff_sampled_q`/`handoff_takeover_q`, and the one-cycle `scl_gen_scl_q` register used to derive local TX edge/stable signals.

## 7. Changes from Reference Design

| Aspect                     | Reference                                                           | This Design                                                                     |
| -------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Parameters                 | `DatDepth`, `CmdFifoDepth`, `TxFifoDepth`, `RxFifoDepth`, `RespFifoDepth` | `DatDepth` only — FIFO depths owned by `i3c_controller_top`            |
| Bus instances              | Dual bus (`ctrl_bus_i[2]`, `ctrl_scl_o[2]`)                         | Single bus                                                                      |
| I2C controller FSM         | Full `i2c_controller_fsm` instance                                  | Removed (flow_active drives bus directly)                                       |
| I3C controller FSM         | Stub (`i3c_controller_fsm`, drives '1)                              | Replaced by `scl_generator`                                                     |
| OD/PP switching            | Hardcoded to `'0` (TODO)                                            | Phase-based, with handoff override: `(scl_gen_driving_sda \|\| handoff_takeover_q) ? 1'b0 : tx_flow_sel_od_pp` (M-4) |
| SDA MUX                    | Not present                                                         | Priority MUX: scl_gen > handoff takeover > tx_flow > idle (M-2)                |
| `ctrl_sda_oe_o`            | Not present                                                         | Added — explicit output-enable derivation mirroring the SDA priority MUX        |
| DAT read port              | Single read port                                                    | Single muxed port shared between `flow_active` and `entdaa_controller`          |
| `daa_rstart_pending_q`     | Not present                                                         | Added to extend 1-cycle pulse from `entdaa_controller` for `scl_generator` (M-7)|
| Low-bit handoff/takeover   | Not present                                                         | Added — master drives SDA low during ENTDAA address-bit arbitration when it observes the bus already pulled low |
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
7. **`daa_rstart_pending_q`:** Verify the latched restart request is held until `scl_gen_done` (or ENTDAA ends) and correctly drives `gen_rstart`(M-7)
8. **Low-bit handoff/takeover:** Verify the master correctly samples the bus on `scl_tx_posedge` during handoff-marked ENTDAA bit periods and drives SDA low for the remainder of the bit when takeover is armed
9. **DAA stop/NACK routing:** Verify `flow_active` correctly observes `daa_req_stop`/`daa_stopped`/`daa_nack_error` from `entdaa_controller` and terminates/reports accordingly
10. **Bus monitor distribution:** Verify `bus_state` correctly distributed to all consumers
11. **Reset:** Verify all sub-modules enter idle/safe state on reset

### UVM Test Structure

```
src/verification/uvm_i3c/
  sequences/
    i3c_entdaa_vseq.sv       # Exercises daa_rstart_pending_q and low-bit handoff/takeover paths
    i3c_private_write_vseq.sv
    i3c_private_read_vseq.sv
    i3c_i2c_write_vseq.sv
  tests/
    i3c_entdaa_test.sv
    i3c_private_rw_test.sv
    i3c_i2c_test.sv
```

## 10. Implementation Notes

- `controller_active` has **no FSM**. Its sequential logic is limited to `daa_rstart_pending_q`, `handoff_sampled_q`/`handoff_takeover_q`, and `scl_gen_scl_q`; everything else is combinational wiring or pass-through.
- FIFO depth parameters (`CmdFifoDepth`, `TxFifoDepth`, `RxFifoDepth`, `RespFifoDepth`) do **not** appear in `controller_active` — they are parameters of `i3c_controller_top` and `hci_queues` only.
- The `daa_active` signal is simply `flow_ccc_valid` — `flow_active` holds it high for the entire ENTDAA loop, which is sufficient to multiplex bus ownership to `entdaa_controller`.
- `bus_monitor` is connected to active `t_r` and `t_f` only. The other active timing registers are routed to `scl_generator` and `bus_tx_flow`, not to `bus_monitor`.
- `bus_tx_flow` uses local edge/stable signals derived from `scl_generator.scl_o`; `bus_rx_flow` still samples from `bus_monitor` readback.
- The single hardware DAT read port design is safe because `flow_active` reads DAT in `FetchDAT` before enabling `entdaa_controller` (via `ccc_valid_o`), and during ENTDAA rounds `flow_active` blocks in a wait state until `ccc_done_i` is asserted. Both consumers read `dat_rdata_hw_i` directly; there is no intermediate latching signal.
- There is no arbitration-lost detection in the byte-level sense. On the master side, the master is a passive observer during PID transmission for bits *without* a handoff marker — it reads the bit-by-bit result of target arbitration without needing to compare drive vs readback. For bits *with* a handoff marker, the master actively reinforces a `0` result via the low-bit takeover mechanism (§5.9) so that slower-sampling targets still observe a valid wired-AND low.
