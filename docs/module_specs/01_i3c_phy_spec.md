# Module: i3c_phy

> Status: Reuse
> Reference: `i3c-core/src/phy/i3c_phy.sv` (63 lines)
> Estimated LoC: ~50 lines

## 1. Purpose

The PHY (Physical Layer) module provides the electrical interface between the I3C controller logic and the physical SCL/SDA bus lines. It performs two critical functions:

1. **Input synchronization:** Double flip-flop (2FF) metastability protection for asynchronous SCL and SDA inputs, bringing them into the system clock domain.
2. **Output driving:** Routes controller-generated SCL and SDA signals to the bus, supporting both Open-Drain (OD) and Push-Pull (PP) signaling modes via the `sel_od_pp` control signal.

## 2. Dependencies

### Sub-modules

- None (the reference uses `caliptra_prim_flop_2sync`, which will be replaced with inline 2FF logic)

### Parent modules

- `i3c_controller_top` (top-level integration)

### Packages

- None

## 3. Parameters

| Parameter    | Type | Default | Description                                           |
| ------------ | ---- | ------- | ----------------------------------------------------- |
| `ResetValue` | bit  | 1'b1    | Reset value for synchronized outputs (bus idles HIGH) |

## 4. Ports / Interfaces

### Clock and Reset

| Signal   | Direction | Width | Description                   |
| -------- | --------- | ----- | ----------------------------- |
| `clk_i`  | Input     | 1     | System clock (min 333 MHz)    |
| `rst_ni` | Input     | 1     | Active-low asynchronous reset |

### Physical Bus Pins (External)

| Signal  | Direction | Width | Description                               |
| ------- | --------- | ----- | ----------------------------------------- |
| `scl_i` | Input     | 1     | SCL bus input (asynchronous)              |
| `scl_o` | Output    | 1     | SCL bus output (directly from controller) |
| `sda_i` | Input     | 1     | SDA bus input (asynchronous)              |
| `sda_o` | Output    | 1     | SDA bus output (directly from controller) |

### Controller-Side (Internal)

| Signal       | Direction | Width | Description                              |
| ------------ | --------- | ----- | ---------------------------------------- |
| `ctrl_scl_i` | Input     | 1     | SCL value from controller (to drive bus) |
| `ctrl_sda_i` | Input     | 1     | SDA value from controller (to drive bus) |
| `ctrl_scl_o` | Output    | 1     | Synchronized SCL for controller logic    |
| `ctrl_sda_o` | Output    | 1     | Synchronized SDA for controller logic    |

### Mode Control

| Signal        | Direction | Width | Description                               |
| ------------- | --------- | ----- | ----------------------------------------- |
| `sel_od_pp_i` | Input     | 1     | 0 = Open-Drain, 1 = Push-Pull             |
| `sel_od_pp_o` | Output    | 1     | Pass-through of mode select to bus driver |

## 5. Functional Description

### 5.1. Input Synchronization (2FF)

Both SCL and SDA inputs are asynchronous relative to the system clock. To prevent metastability, each input passes through a double flip-flop synchronizer:

```
scl_i -> [FF1] -> [FF2] -> ctrl_scl_o
sda_i -> [FF1] -> [FF2] -> ctrl_sda_o
```

- Both FFs are clocked on `posedge clk_i`
- Both FFs are reset to `ResetValue` (1'b1) on `negedge rst_ni`
- The reset value of 1'b1 represents the idle bus state (both lines HIGH)
- This introduces a 2-cycle latency for input sampling

**Implementation (replacing `caliptra_prim_flop_2sync`):**

```systemverilog
logic scl_ff1, scl_ff2;
always_ff @(posedge clk_i or negedge rst_ni) begin
  if (!rst_ni) begin
    scl_ff1 <= 1'b1;
    scl_ff2 <= 1'b1;
  end else begin
    scl_ff1 <= scl_i;
    scl_ff2 <= scl_ff1;
  end
end
assign ctrl_scl_o = scl_ff2;
```

Same pattern for SDA.

### 5.2. Output Driving

The output path is purely combinational — no additional latency:

```systemverilog
assign scl_o = ctrl_scl_i;
assign sda_o = ctrl_sda_i;
assign sel_od_pp_o = sel_od_pp_i;
```

The actual OD/PP behavior is determined by the external bus driver (pad cell or FPGA tri-state buffer):

- **Open-Drain (sel_od_pp = 0):** Output can only pull LOW or release to high-impedance. The bus pull-up resistor drives HIGH.
- **Push-Pull (sel_od_pp = 1):** Output actively drives both HIGH and LOW.

> **Note:** The OD/PP mode switching happens at the pad level, not inside this module. This module only passes the mode selection signal through. The `controller_active` module is responsible for setting `sel_od_pp_i` correctly based on the current bus phase.

## 6. Timing Requirements

| Aspect                | Requirement                                             |
| --------------------- | ------------------------------------------------------- |
| Input synchronization | 2 clock cycle latency (part of tSCO budget)             |
| Output path           | Combinational (0 cycle latency)                         |
| System clock minimum  | 333 MHz (to meet tSCO = 12 ns with 4-cycle budget)      |
| Reset recovery        | After reset de-assertion, outputs stable after 2 clocks |

## 7. Changes from Reference Design

| Aspect                   | Reference                                       | This Design                         |
| ------------------------ | ----------------------------------------------- | ----------------------------------- |
| 2FF synchronizer         | `caliptra_prim_flop_2sync` (Caliptra primitive) | Inline 2FF (no external dependency) |
| `ifdef DISABLE_INPUT_FF` | Conditional compile for simulation              | Removed; always use 2FF             |
| OD/PP logic              | Pass-through (no logic)                         | Same (pass-through)                 |

## 8. Error Handling

- No explicit error detection in this module
- Metastability is handled by the 2FF synchronizer (statistical guarantee, not deterministic)
- Bus-level errors (stuck LOW, etc.) are detected by `bus_monitor`

## 9. Test Plan

### Scenarios

1. **Reset behavior:** Verify `ctrl_scl_o` and `ctrl_sda_o` are HIGH after reset
2. **Input synchronization latency:** Apply a transition on `scl_i`/`sda_i` and verify it appears on `ctrl_scl_o`/`ctrl_sda_o` exactly 2 clock cycles later
3. **Output pass-through:** Verify `scl_o == ctrl_scl_i` and `sda_o == ctrl_sda_i` at all times (combinational)
4. **OD/PP pass-through:** Verify `sel_od_pp_o == sel_od_pp_i` at all times
5. **Glitch filtering:** Apply a pulse shorter than 1 clock cycle on `sda_i` and verify it is filtered by the 2FF (may or may not propagate — this tests metastability tolerance)

### cocotb Test Structure

```
tests/
  test_i3c_phy/
    test_i3c_phy.py       # Main test file
    Makefile              # cocotb makefile
```

## 10. Implementation Notes

- This is the simplest module in the design — essentially just wires and flip-flops
- The 2FF synchronizer does NOT guarantee that SCL and SDA are sampled at the same instant. The bus_monitor module handles this by using edge detectors with timing-aware delays.
- For FPGA prototyping, the OD/PP behavior must be implemented in the top-level I/O constraints (e.g., using IOBUF primitives on Xilinx)
