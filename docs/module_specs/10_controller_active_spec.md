# Module: controller_active

> Status: Simplify
> Reference: `i3c-core/src/ctrl/controller_active.sv` (292 lines)
> Estimated LoC: ~200 lines

## 1. Purpose

The `controller_active` module is the structural wrapper that instantiates and interconnects all controller core sub-modules. It is primarily a wiring module with minimal logic — its main added-value logic is the **OD/PP switching control** (which was a TODO in the reference) and **bus signal multiplexing**.

## 2. Dependencies

### Sub-modules

| Module          | Instance   | Role                                |
| --------------- | ---------- | ----------------------------------- |
| `flow_active`   | `flow_fsm` | Command flow FSM                    |
| `bus_tx_flow`   | `tx_flow`  | TX serializer                       |
| `bus_rx_flow`   | `rx_flow`  | RX deserializer                     |
| `bus_monitor`   | `bus_mon`  | START/STOP/Sr detection             |
| `scl_generator` | `scl_gen`  | SCL clock generation                |
| `ccc`           | `ccc_proc` | CCC processor (includes ccc_entdaa) |

### Parent modules

- `i3c_controller_top` (top-level integration)

### Packages

- `i3c_pkg` — For `bus_state_t`
- `controller_pkg` — For `dat_entry_t`

## 3. Parameters

| Parameter       | Type | Default | Description     |
| --------------- | ---- | ------- | --------------- |
| `DatDepth`      | int  | 16      | DAT table depth |
| `CmdFifoDepth`  | int  | 64      | CMD FIFO depth  |
| `TxFifoDepth`   | int  | 64      | TX FIFO depth   |
| `RxFifoDepth`   | int  | 64      | RX FIFO depth   |
| `RespFifoDepth` | int  | 64      | RESP FIFO depth |

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
| `sel_od_pp_o` | Output    | 1     | OD/PP mode select to PHY  |

### HCI Queue Interfaces

Same as `flow_active` FIFO interfaces (CMD, TX, RX, RESP) — passed through.

### DAT Interface

Same as `flow_active` DAT interface — passed through.

### Timing Configuration (from CSR)

| Signal       | Direction | Width | Description      |
| ------------ | --------- | ----- | ---------------- |
| `t_r_i`      | Input     | 20    | Rise time        |
| `t_f_i`      | Input     | 20    | Fall time        |
| `t_low_i`    | Input     | 20    | SCL LOW period   |
| `t_high_i`   | Input     | 20    | SCL HIGH period  |
| `t_su_sta_i` | Input     | 20    | START setup time |
| `t_hd_sta_i` | Input     | 20    | START hold time  |
| `t_su_sto_i` | Input     | 20    | STOP setup time  |
| `t_su_dat_i` | Input     | 20    | Data setup time  |
| `t_hd_dat_i` | Input     | 20    | Data hold time   |

### Control / Status

| Signal           | Direction | Width | Description                                |
| ---------------- | --------- | ----- | ------------------------------------------ |
| `ctrl_enable_i`  | Input     | 1     | Controller enable (from CSR HC_CONTROL[0]) |
| `i3c_fsm_en_i`   | Input     | 1     | FSM enable (from CSR)                      |
| `i3c_fsm_idle_o` | Output    | 1     | FSM idle status                            |

## 5. Functional Description

### 5.1. Signal Routing

The module primarily routes signals between sub-modules. The key connections:

```
                    ┌─────────────────────────────────────────────┐
                    │             controller_active               │
                    │                                             │
  HCI Queues ──────┤──► flow_active ──► bus_tx_flow ──┬──► SDA   │
                    │       │                          │          │
                    │       │  ◄── bus_rx_flow ◄───────┤◄── SDA   │
                    │       │                          │          │
                    │       ├──► scl_generator ────────┼──► SCL   │
                    │       │                          │          │
                    │       ├──► ccc ──────────────────┤          │
                    │       │                          │          │
  DAT ─────────────┤───────┘  bus_monitor ◄───────────┤◄── SCL   │
                    │                                  │◄── SDA   │
  Timing Regs ─────┤──────────────────────────────────►│          │
                    └─────────────────────────────────────────────┘
```

### 5.2. Bus Monitor Connection

The bus monitor receives synchronized SCL/SDA from the PHY and produces `bus_state_t`:

```systemverilog
bus_monitor bus_mon (
  .clk_i, .rst_ni,
  .enable_i(1'b1),
  .scl_i(ctrl_scl_i),
  .sda_i(ctrl_sda_i),
  .t_hd_dat_i, .t_r_i, .t_f_i,
  .state_o(bus_state)
);
```

The `bus_state` signals are distributed to sub-modules by unpacking the `bus_state_t` struct fields:

```systemverilog
// bus_state_t struct → individual wires for sub-modules
// bus_tx_flow connections:
.scl_negedge_i   (bus_state.scl.neg_edge),
.scl_posedge_i   (bus_state.scl.pos_edge),
.scl_stable_low_i(bus_state.scl.stable_low),

// bus_rx_flow connections:
.scl_posedge_i    (bus_state.scl.pos_edge),
.scl_stable_high_i(bus_state.scl.stable_high),
.sda_i            (bus_state.sda.value),

// scl_generator connections:
.scl_i            (bus_state.scl.value),

// flow_active connections (bus events):
// (routed via internal signals for START/STOP/Sr detection)

// ccc connections:
.bus_start_det_i (bus_state.start_det),
.bus_rstart_det_i(bus_state.rstart_det),
.bus_stop_det_i  (bus_state.stop_det),
```

### 5.3. SDA Output Multiplexing

SDA is driven by multiple sources depending on the current phase:

```systemverilog
always_comb begin
  if (scl_gen_driving_sda) begin
    // SCL generator drives SDA for START/STOP/Sr conditions
    ctrl_sda_o = scl_gen_sda;
  end else if (tx_flow_active) begin
    // TX flow drives SDA for data/ACK transmission
    ctrl_sda_o = tx_flow_sda;
  end else begin
    // Default: release SDA HIGH (idle)
    ctrl_sda_o = 1'b1;
  end
end
```

### 5.4. SCL Output

SCL is always driven by the SCL generator:

```systemverilog
assign ctrl_scl_o = scl_gen_scl;
```

### 5.5. OD/PP Switching Logic (NEW — was TODO in reference)

The OD/PP mode is determined by `flow_active` based on the current bus phase:

```systemverilog
// flow_active provides sel_od_pp based on transaction phase
// This replaces the hardcoded '0 from the reference
assign sel_od_pp_o = flow_sel_od_pp;
```

The reference had:

```systemverilog
// TODO: Handle driver switching in the active controller mode
assign phy_sel_od_pp_o[0] = '0;  // Always open-drain
assign phy_sel_od_pp_o[1] = '0;  // Always open-drain
```

### 5.6. Bus TX/RX Multiplexing for CCC

When the CCC module is active, it takes over bus_tx/bus_rx control:

```systemverilog
always_comb begin
  if (ccc_active) begin
    tx_req_byte  = ccc_tx_req_byte;
    tx_req_bit   = ccc_tx_req_bit;
    tx_req_value = ccc_tx_req_value;
    rx_req_byte  = ccc_rx_req_byte;
    rx_req_bit   = ccc_rx_req_bit;
  end else begin
    tx_req_byte  = flow_tx_req_byte;
    tx_req_bit   = flow_tx_req_bit;
    tx_req_value = flow_tx_req_value;
    rx_req_byte  = flow_rx_req_byte;
    rx_req_bit   = flow_rx_req_bit;
  end
end
```

### 5.7. DAA Results Routing

The CCC module produces DAA results that flow_active consumes to store address assignments:

```systemverilog
// ccc → flow_active (via controller_active wiring)
.daa_address_i     (ccc_daa_address),
.daa_address_valid_i(ccc_daa_address_valid),
.daa_pid_i         (ccc_daa_pid),
.daa_bcr_i         (ccc_daa_bcr),
.daa_dcr_i         (ccc_daa_dcr),
```

`flow_active` uses these to write the assigned address back to the DAT (via `dat_write_valid_hw_o`) and optionally report PID/BCR/DCR to software via the response or RX FIFO.

### 5.8. Arbitration Lost Detection

For ENTDAA, the controller must detect when it loses arbitration on SDA:

```systemverilog
// Compare driven SDA with readback from bus
assign arbitration_lost = tx_flow_sda & ~bus_state.sda.value;
// (Master drives HIGH but reads LOW → another device is driving)
```

This signal feeds into `ccc_entdaa.arbitration_lost_i`.

### 5.9. I3C/I2C Mode Selection

`flow_active` drives `sel_i3c_i2c_o` based on the current command's DAT entry:

```systemverilog
// flow_active → scl_generator
.sel_i3c_i2c_i(flow_sel_i3c_i2c),  // 0 = I2C FM, 1 = I3C SDR
```

### 5.10. Controller Enable

The CSR `ctrl_enable_o` signal gates the bus monitor enable and can be used to gate the PHY:

```systemverilog
assign bus_mon_enable = ctrl_enable_i;  // From CSR HC_CONTROL[0]
```

The `i3c_fsm_en_i` (also from CSR) separately controls the flow_active FSM. Both must be asserted for the controller to operate.

## 6. Timing Requirements

No additional timing constraints beyond those of sub-modules. All connections are same-cycle (combinational wiring or registered within sub-modules).

## 7. Changes from Reference Design

| Aspect             | Reference                                   | This Design                               |
| ------------------ | ------------------------------------------- | ----------------------------------------- |
| Bus instances      | Dual bus (`ctrl_bus_i[2]`, `ctrl_scl_o[2]`) | Single bus                                |
| I2C controller FSM | Full `i2c_controller_fsm` instance          | Removed (flow_active drives bus directly) |
| I3C controller FSM | Stub (`i3c_controller_fsm`, drives '1)      | Replaced by `scl_generator`               |
| OD/PP switching    | Hardcoded to `'0` (TODO)                    | Proper phase-based switching              |
| IBI queue ports    | Full IBI FIFO interface                     | Removed                                   |
| DCT interface      | Full DCT read/write ports                   | Removed                                   |
| I2C event signals  | 8 `unused_*` signals                        | Removed                                   |
| `phy_mux_select_i` | 2-bit MUX for dual bus                      | Removed (single bus)                      |
| I2C timing         | Hardcoded `16'd1` / `16'd10`                | CSR-driven via timing registers           |
| Line count         | 292 lines                                   | ~200 lines                                |

## 8. Error Handling

No additional error logic. Errors are detected by sub-modules (`flow_active`, `bus_monitor`, `ccc`) and reported through the response FIFO.

## 9. Test Plan

### Scenarios

1. **Integration: I3C Private Write:** End-to-end write transaction; verify SCL/SDA waveforms match I3C protocol
2. **Integration: I3C Private Read:** End-to-end read transaction; verify correct data flow
3. **Integration: I2C Write:** Legacy I2C write; verify open-drain-only signaling
4. **Integration: ENTDAA:** Full DAA sequence with simulated target; verify address assignment
5. **OD/PP switching:** Verify OD during address phase, PP during data phase of I3C transfer
6. **SDA MUX:** Verify correct SDA source selection during START (scl_gen) vs data (tx_flow)
7. **SCL generation:** Verify SCL frequency matches CSR timing values
8. **Bus monitor feedback:** Verify bus_state correctly distributed to all consumers
9. **Reset:** Verify all sub-modules enter idle/safe state on reset

### cocotb Test Structure

```
tests/
  test_controller_active/
    test_integration.py      # Full transaction tests
    test_odpp_switching.py   # OD/PP mode verification
    test_signal_routing.py   # Signal connectivity tests
    Makefile
```

## 10. Implementation Notes

- The reference design uses a dual-bus architecture (`ctrl_bus_i[2]`, `ctrl_scl_o[2]`) with separate I2C and I3C bus instances multiplexed by `phy_mux_select_i`. This design uses a **single bus** — the same SCL/SDA lines carry both I2C and I3C traffic, distinguished by timing and OD/PP mode.
- The removal of `i2c_controller_fsm` is a significant simplification. In the reference, I2C transactions went through a separate FSM with its own `fmt_fifo_*` interface. In this design, `flow_active` handles I2C directly by sending bytes through `bus_tx_flow` and reading through `bus_rx_flow` — the only difference from I3C is the timing (400 kHz vs 12.5 MHz) and always-OD mode.
- The `ccc_active` signal (for TX/RX MUX) is derived from `flow_active` — when it dispatches a CCC, it signals that the CCC module should control the bus.
- Arbitration lost detection (for ENTDAA): compare `sda_o` driven value with `sda_i` readback. If the master drives HIGH but reads LOW, another device is winning arbitration. This comparison happens in this module and feeds into `ccc_entdaa.arbitration_lost_i`.
