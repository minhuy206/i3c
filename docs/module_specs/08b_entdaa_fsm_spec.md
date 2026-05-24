# Module: entdaa_fsm (Per-Device ENTDAA Round)

> Status: Complete
> Reference: `i3c-core/src/ctrl/ccc_entdaa.sv` (238 lines, target-side) — replaced by master-side design from scratch
> Estimated LoC: ~150 lines

## 1. Purpose

The `entdaa_fsm` module executes a single ENTDAA device round from the master's perspective:

1. Send the reserved byte `0x7E+R` (broadcast address with read bit)
2. Read the ACK slot — NACK means no target responded
3. Receive 64 raw bits (PID[47:0] + BCR[7:0] + DCR[7:0]) bit-by-bit via `bus_rx_req_bit`
4. Send the dynamic address with odd parity (`Addr+P`)
5. Read the ACK slot — ACK means the target accepted the address

`entdaa_fsm` is instantiated by `entdaa_controller`, which manages the multi-device loop. Each invocation (`start_daa_i` pulse) handles one device.

## 2. Dependencies

### Sub-modules

- None

### Parent modules

- `entdaa_controller` (instantiates this module as `u_daa_fsm`)

### Packages

- `i3c_pkg` — `I3C_RSVD_ADDR` (7'h7E), `I3C_RSVD_BYTE` (8'hFC)

## 3. Parameters

None.

## 4. Ports / Interfaces

### Clock and Reset

| Signal   | Direction | Width | Description            |
| -------- | --------- | ----- | ---------------------- |
| `clk_i`  | Input     | 1     | System clock           |
| `rst_ni` | Input     | 1     | Active-low async reset |

### DAA Control (from entdaa_controller)

| Signal         | Direction | Width | Description                                                    |
| -------------- | --------- | ----- | -------------------------------------------------------------- |
| `start_daa_i`  | Input     | 1     | Pulse: start one ENTDAA device round                           |
| `daa_addr_i`   | Input     | 7     | Dynamic address to assign, from DAT entry                      |
| `done_daa_o`   | Output    | 1     | Pulse: round complete (check `addr_valid_o` or `no_device_o`)  |
| `addr_valid_o` | Output    | 1     | High with `done_daa_o`: address was accepted (ACK)             |
| `no_device_o`  | Output    | 1     | High with `done_daa_o`: no target responded (NACK on `0x7E+R`) |

### Received Device Information (to entdaa_controller)

| Signal  | Direction | Width | Description                           |
| ------- | --------- | ----- | ------------------------------------- |
| `pid_o` | Output    | 48    | Provisioned ID shifted in (MSB first) |
| `bcr_o` | Output    | 8     | Bus Characteristics Register          |
| `dcr_o` | Output    | 8     | Device Characteristics Register       |

### Bus TX Interface

| Signal               | Direction | Width | Description                  |
| -------------------- | --------- | ----- | ---------------------------- |
| `bus_tx_done_i`      | Input     | 1     | TX completed current request |
| `bus_tx_req_byte_o`  | Output    | 1     | Request byte transmission    |
| `bus_tx_req_bit_o`   | Output    | 1     | Always `0` (unused)          |
| `bus_tx_req_value_o` | Output    | 8     | Byte value to transmit       |
| `bus_tx_sel_od_pp_o` | Output    | 1     | Always `0` (Open-Drain)      |

### Bus RX Interface

| Signal              | Direction | Width | Description                  |
| ------------------- | --------- | ----- | ---------------------------- |
| `bus_rx_data_i`     | Input     | 8     | `[0]` = single received bit  |
| `bus_rx_done_i`     | Input     | 1     | RX completed                 |
| `bus_rx_req_bit_o`  | Output    | 1     | Request single-bit reception |
| `bus_rx_req_byte_o` | Output    | 1     | Always `0` (unused)          |

### Bus Monitor Interface

| Signal           | Direction | Width | Description           |
| ---------------- | --------- | ----- | --------------------- |
| `bus_stop_det_i` | Input     | 1     | STOP detected (abort) |

## 5. Functional Description

### 5.1. FSM — 8 States

```systemverilog
typedef enum logic [2:0] {
  Idle           = 3'd0,
  SendRsvdByte   = 3'd1,
  ReadRsvdAck    = 3'd2,
  ReceiveIDBit   = 3'd3,
  SendAddr       = 3'd4,
  ReadAddrAck    = 3'd5,
  Done           = 3'd6,
  NoDev          = 3'd7
} entdaa_state_e;
```

```mermaid
stateDiagram-v2
    [*] --> Idle

    Idle --> SendRsvdByte: start_daa_i

    SendRsvdByte --> ReadRsvdAck: bus_tx_done_i

    ReadRsvdAck --> ReceiveIDBit: ack==0 (target responded)
    ReadRsvdAck --> NoDev: ack==1 (no target)

    ReceiveIDBit --> ReceiveIDBit: bus_rx_done_i && bit_cnt_q > 0
    ReceiveIDBit --> SendAddr: bus_rx_done_i && bit_cnt_q == 0

    SendAddr --> ReadAddrAck: bus_tx_done_i

    ReadAddrAck --> Done: ack==0 (accepted)
    ReadAddrAck --> Done: ack==1 (rejected, addr_valid=0)

    Done --> Idle: (next cycle)
    NoDev --> Idle: (next cycle)
```

### 5.2. State Descriptions

#### Idle (State 0)

Wait for `start_daa_i`. On entry, reset `bit_cnt_q` to 63 and clear `id_shift_q`.

#### SendRsvdByte (State 1)

Transmit the reserved address with read bit:

```systemverilog
bus_tx_req_byte_o  = 1'b1;
bus_tx_req_value_o = {I3C_RSVD_ADDR, 1'b1};  // 8'hFD
bus_tx_sel_od_pp_o = 1'b0;                    // Open-Drain
```

Advance to `ReadRsvdAck` when `bus_tx_done_i`.

#### ReadRsvdAck (State 2)

Request one bit read (`bus_rx_req_bit_o = 1`). When `bus_rx_done_i`:

- `bus_rx_data_i[0] == 0` (ACK) → at least one target responded → `ReceiveIDBit`
- `bus_rx_data_i[0] == 1` (NACK) → no target on bus → `NoDev`

#### ReceiveIDBit (State 3)

Read one bit per invocation (`bus_rx_req_bit_o = 1`). Shift into `id_shift_q`:

```systemverilog
id_shift_q <= {id_shift_q[62:0], bus_rx_data_i[0]};
bit_cnt_q  <= bit_cnt_q - 1;
```

When `bit_cnt_q` reaches 0, all 64 bits are captured:
- `pid_o = id_shift_q[63:16]` (PID[47:0])
- `bcr_o = id_shift_q[15:8]`
- `dcr_o = id_shift_q[7:0]`

Advance to `SendAddr`.

#### SendAddr (State 4)

Compute odd parity over 7 address bits and transmit:

```systemverilog
parity = ~^daa_addr_i;   // odd parity: XOR-reduce then invert
bus_tx_req_byte_o  = 1'b1;
bus_tx_req_value_o = {daa_addr_i, parity};
bus_tx_sel_od_pp_o = 1'b0;
```

Advance to `ReadAddrAck` when `bus_tx_done_i`.

#### ReadAddrAck (State 5)

Read one bit (`bus_rx_req_bit_o = 1`). When `bus_rx_done_i`:

- `bus_rx_data_i[0] == 0` → target accepted address → `Done` with `addr_valid = 1`
- `bus_rx_data_i[0] == 1` → target rejected address → `Done` with `addr_valid = 0`

#### Done (State 6)

Outputs are valid for one cycle:

```systemverilog
done_daa_o   = 1'b1;
addr_valid_o = addr_valid_q;
no_device_o  = 1'b0;
pid_o        = id_shift_q[63:16];
bcr_o        = id_shift_q[15:8];
dcr_o        = id_shift_q[7:0];
```

Return to `Idle` next cycle.

#### NoDev (State 7)

No target responded:

```systemverilog
done_daa_o   = 1'b1;
no_device_o  = 1'b1;
addr_valid_o = 1'b0;
```

Return to `Idle` next cycle.

On `bus_stop_det_i` in any non-Idle state: synchronous override → `NoDev` (cleanly terminates the current round).

## 6. Timing Requirements

| Aspect              | Requirement                                                                              |
| ------------------- | ---------------------------------------------------------------------------------------- |
| Per-device round    | 2 bytes TX + 65 RX bits (ACK + 64 ID bits) = ~74 SCL cycles minimum                     |
| Address parity      | Computed combinationally (`~^daa_addr_i`) in `SendAddr`; no extra cycles                |
| No-device detection | NACK detected on the ACK bit after `0x7E+R` = 1 RX bit cycle                            |

## 7. Changes from Reference Design

| Aspect                           | Reference (`ccc_entdaa.sv`, target-side)                                                             | This Design (master-side)                                     |
| -------------------------------- | ---------------------------------------------------------------------------------------------------- | ------------------------------------------------------------- |
| Perspective                      | Target sends its own PID, receives assigned address from master                                      | Master receives PID/BCR/DCR, sends the address               |
| States                           | 13 (Idle, WaitStart, ReceiveRsvdByte, AckRsvdByte, SendNack, SendID, PrepareIDBit, SendIDBit, LostArbitration, ReceiveAddr, AckAddr, Done, Error) | 8 (Idle, SendRsvdByte, ReadRsvdAck, ReceiveIDBit, SendAddr, ReadAddrAck, Done, NoDev) |
| `id_i/bcr_i/dcr_i`              | Inputs: target's own identity to send to master                                                      | Removed (master does not send its identity)                  |
| `arbitration_lost_i`             | Target detects arbitration loss on SDA during PID transmission                                       | Removed (master reads bus as-is; arbitration is among targets)|
| `process_virtual_i`              | Caliptra virtual device support                                                                      | Removed                                                      |
| `address_o`                      | Output: address received FROM master                                                                 | Replaced by `daa_addr_i` (input: address TO assign)          |
| `bus_tx_req_bit_o`               | Used for bit-level ACK                                                                               | Always `0` (unused)                                          |
| `bus_rx_req_byte_o`              | Used for byte-level reception                                                                        | Always `0` (unused)                                          |

## 8. Error Handling

| Error                   | Detection                                     | Action                          |
| ----------------------- | --------------------------------------------- | ------------------------------- |
| No target on bus        | NACK after `0x7E+R` (`bus_rx_data_i[0] == 1`) | `NoDev` state, `no_device_o` pulse |
| Target rejects address  | NACK after `Addr+P` (`bus_rx_data_i[0] == 1`) | `Done` with `addr_valid_o = 0`  |
| Unexpected STOP         | `bus_stop_det_i` in any non-Idle state        | Forced → `NoDev`                |

## 9. Test Plan

### Scenarios

1. **Successful round:** 1 target; verify full state sequence Idle→Done; check `pid_o`, `bcr_o`, `dcr_o`, `addr_valid_o`
2. **No device:** NACK on `0x7E+R`; verify Idle→SendRsvdByte→ReadRsvdAck→NoDev
3. **Address NACK:** Target ACKs `0x7E+R` but NACKs `Addr+P`; verify Done with `addr_valid_o=0`
4. **64-bit reception:** Drive 64 specific bits; verify `id_shift_q` captures correctly (MSB first)
5. **Odd parity:** Test address 7'h08 (parity=0), 7'h09 (parity=1); verify `bus_tx_req_value_o[0]`
6. **STOP during ReceiveIDBit:** Assert `bus_stop_det_i` mid-PID; verify forced → `NoDev`
7. **STOP during SendAddr:** Assert `bus_stop_det_i`; verify forced → `NoDev`

### UVM Test Structure

```
src/verification/uvm_i3c/
  sequences/
    i3c_entdaa_vseq.sv    # Simulates target: ACK on 0x7E+R, drive PID/BCR/DCR bits, ACK/NACK address
  tests/
    i3c_entdaa_test.sv
```

## 10. Implementation Notes

- **64-bit reception is bit-serial:** `ReceiveIDBit` loops 64 times using `bus_rx_req_bit_o`. The `id_shift_q` register is 64 bits wide; bits arrive MSB first per I3C spec.
- **Arbitration transparency:** The master reads whatever bit combination the wired-AND of all competing targets produces. The target that loses arbitration (drives `1` but sees `0`) stops participating in subsequent bits. The master reads the arbitration result naturally without any special handling.
- **`bus_tx_req_bit_o = 1'b0` always:** ACK reception uses `bus_rx_req_bit_o`, not bit-level TX. The `bus_tx_req_bit_o` port is present for interface compatibility with the MUX in `entdaa_controller` but is permanently deasserted.
- **`bus_rx_req_byte_o = 1'b0` always:** All reception in ENTDAA is single-bit. The port exists for interface compatibility but is permanently deasserted.
- **Open-Drain throughout:** `bus_tx_sel_od_pp_o = 1'b0` in all states. Push-Pull is never used in `entdaa_fsm` because targets drive ACK and PID bits simultaneously.
- **Address parity:** I3C requires odd parity — the parity bit is set such that the total number of `1`s in all 8 bits is odd. In SystemVerilog: `parity = ~^daa_addr_i` (XOR-reduce over 7 bits, then invert gives odd parity).
