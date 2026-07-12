# Component: I3C Sequence Library (dv_i3c/seq_lib/)

> Status: Adapt from reference + New
> Location: `src/verification/uvm_i3c/dv_i3c/seq_lib/`
> Reference: `i3c-core/verification/uvm_i3c/dv_i3c/seq_lib/` (8 sequences)
> Estimated LoC: ~200 lines (2 files)

## 1. Purpose

Reusable I3C bus-level sequences that run on the `i3c_sequencer`. These sequences construct `i3c_seq_item` transactions to instruct the I3C driver how to behave during bus transfers.

For Phase 1, only one sequence is needed: `i3c_device_response_seq` — a generic device responder that ACKs addresses and handles read/write data.

## 2. Dependencies

### Packages

- `i3c_agent_pkg` (parent package)

### Used By

- Virtual sequences (`i3c_imm_vseq`, `i3c_write_vseq`, `i3c_read_vseq`) start this on the I3C sequencer
- Runs concurrently with the DUT's bus activity initiated by register agent sequences

---

## 3. File: i3c_seq_lib.sv

### 3.1. Purpose

Include file that aggregates all sequence source files.

### 3.2. Contents

```systemverilog
`include "i3c_device_response_seq.sv"
```

CCC/ENTDAA responses are handled by `i3c_device_response_seq` itself (§4.7), not by separate sequence files.

---

## 4. File: i3c_device_response_seq.sv

### 4.1. Purpose

A device-mode sequence that responds to a single I3C/I2C transaction initiated by the host (DUT). The sequence:

1. Waits for the DUT to issue a START and drive address bits
2. ACKs the address if it matches the configured target address
3. For **write transfers**: receives data bytes from the host; for I2C it drives the configured per-byte ACK/NACK, while for I3C it samples the controller-driven T-bit
4. For **read transfers**: sends data bytes to host
5. Handles STOP or RSTART to end the transaction

### 4.2. Class Hierarchy

```
uvm_sequence#(i3c_seq_item) → i3c_device_response_seq
```

### 4.3. Configurable Fields (inputs, set before `start()`)

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `target_addr` | `bit [6:0]` | `7'h08` | Address to match and ACK (`req.addr`) |
| `is_i3c` | `bit` | `1` | I3C (1) or I2C (0) mode |
| `dir` | `bit` | `0` | Direction control (`req.dir`): `i3c_driver::next_state_after_ack()` uses it directly to pick the post-ACK FSM state (`DrvRdPushPull`/`DrvRd` vs `DrvWrPushPull`/`DrvWr`), so it must be set to match the direction the host will actually drive on the bus, not left as a hint |
| `read_data` | `bit [7:0] [$]` | `{}` | Explicit data to return on reads; when empty, `read_data_cnt` random bytes are generated instead via `req.payload_constraint_en`/`payload_len` |
| `addr_nack` | `bit` | `0` | NACK the matched private address (`req.addr_nack`). It does not NACK an expected `0x7E` broadcast header, which `get_addr_ack()` always ACKs |
| `data_nack` | `bit` | `0` | Default per-byte I2C NACK value when `data_nack_pattern_q` doesn't cover an index |
| `data_nack_pattern_q` | `bit [$]` | `{}` | Explicit per-byte I2C NACK pattern (I2C write only) |
| `start_with_broadcast_header` | `bit` | `0` | Sequence expects/handles a `0x7E` broadcast-header frame (`req.start_with_broadcast_header`) |
| `entdaa_join` | `bit` | `0` | This device joins the current ENTDAA round (`req.entdaa_join`) |
| `daa_id_bytes` | `bit [7:0] [$]` | `{}` | 8-byte PID/BCR/DCR identity for ENTDAA (`req.daa_id_bytes`) |
| `daa_accept_addr` | `bit` | `1` | ACK (1) or NACK (0) the controller-assigned dynamic address during ENTDAA |
| `ccc_target_addr` | `bit [6:0]` | `0` | Expected target address for a direct CCC (`req.ccc_target_addr`) |
| `ccc_target_addr_valid` | `bit` | `0` | Whether `ccc_target_addr` should be matched (`req.ccc_target_addr_valid`) |
| `read_data_cnt` | `int` | `4` | Random-payload length when `read_data` is empty |

### 4.4. Sequence Body

```systemverilog
task body();
  i3c_seq_item req;
  i3c_seq_item rsp_item;
  req = i3c_seq_item::type_id::create("req");

  if (read_data.size() > 0) begin
    req.data = read_data;
  end else begin
    req.payload_constraint_en = 1'b1;
    req.payload_len = read_data_cnt;
    `DV_CHECK_RANDOMIZE_FATAL(req, "Device-response payload randomization failed")
  end

  // Protocol controls applied after payload randomization so only data is random.
  req.i3c                         = is_i3c;
  req.addr                        = target_addr;
  req.dir                         = dir;
  req.addr_nack                   = addr_nack;
  req.entdaa_join                 = entdaa_join;
  req.daa_id_bytes                = daa_id_bytes;
  req.daa_accept_addr             = daa_accept_addr;
  req.ccc_target_addr             = ccc_target_addr;
  req.ccc_target_addr_valid       = ccc_target_addr_valid;
  req.end_with_rstart             = 0;
  req.start_with_broadcast_header = start_with_broadcast_header;

  // I2C write: per-byte NACK pattern (data_nack_pattern_q, else data_nack).
  // I3C read: T-bit continues (1) on every byte but the last (0 = end).
  req.data_nack_q.delete();
  req.t_bit_q.delete();
  if (!is_i3c && !dir) begin
    for (int i = 0; i < req.data.size(); i++) begin
      req.data_nack_q.push_back(
          i < data_nack_pattern_q.size() ? data_nack_pattern_q[i] : data_nack);
    end
  end else if (is_i3c && dir) begin
    for (int i = 0; i < req.data.size(); i++) begin
      req.t_bit_q.push_back(i < req.data.size() - 1);
    end
  end

  start_item(req);
  request_issued = 1'b1;
  finish_item(req);

  get_response(rsp_item);
  if (rsp_item != null) begin
    observed_rstart           = rsp_item.end_with_rstart;
    observed_broadcast_header = rsp_item.start_with_broadcast_header;
    observed_broadcast_rstart = rsp_item.observed_broadcast_rstart;
    sampled_addr              = rsp_item.addr;
    sampled_data_q             = rsp_item.data;
    sampled_data_nack_q        = rsp_item.data_nack_q;
  end
  done = 1'b1;
endtask
```

### 4.4.1. Driver → Sequence Handshake (`rsp_item` fields, exposed via `sampled_*`/`observed_*`)

When the driver finishes the transaction it calls `seq_item_port.item_done(rsp)` (`i3c_driver::get_and_drive()`, `04_i3c_agent_spec.md` §8.6), and the sequence consumes it via `get_response(rsp_item)`. `body()` copies the following observed fields out to sequence-level state so a caller can read them after `start()` returns:

| `rsp_item` field | Copied to (sequence field) | Meaning |
|-------------|-----------------------|---------|
| `rsp_item.addr` | `sampled_addr` | Address actually sampled off the bus |
| `rsp_item.data` | `sampled_data_q` | Bytes the driver *sampled* during a write (`do_i2c_write`/`do_i3c_write` push into `rsp.data`). **Not populated for a private I3C read** (`do_i3c_read()` drives `req.data[]` onto SDA but never writes `rsp.data`); for a private I2C read it stays empty too — only the write-direction tasks populate it |
| `rsp_item.data_nack_q` | `sampled_data_nack_q` | For an I2C **write**, per-byte host ACK/NACK as driven by the device (mirrors `req.data_nack_q`/`data_nack_pattern_q`). For an I2C **read**, the *controller's* ACK/NACK of each byte the device sent (`do_i2c_read()`: `rsp.data_nack_q.push_back(!ack)` where `ack` is the sampled host ACK) — i.e. on a read this field reports what the host did, not a device-side NACK pattern |
| `rsp_item.t_bit_q` | *(not copied by `body()`; read `rsp_item` directly)* | For a private I3C **write**, the T-bits the driver observed on the bus (`do_i3c_write()`: `rsp.t_bit_q.push_back(t_bit)`) |
| `rsp_item.end_with_rstart` | `observed_rstart` | `0` if the frame ended with STOP, `1` if RSTART |
| `rsp_item.start_with_broadcast_header` | `observed_broadcast_header` | Whether the driver recognized this as a broadcast-header frame |
| `rsp_item.observed_broadcast_rstart` | `observed_broadcast_rstart` | Set when a broadcast-header/CCC frame was followed by Sr into a private/direct sub-frame (`i3c_driver::handle_broadcast_dispatch()`) |

There is no `rsp_item.dev_ack` — that field does not exist on `i3c_seq_item` (`04_i3c_agent_spec.md` §6.2); address/data ACK behavior is driven from `req.addr_nack`/`req.data_nack_q` and, for reads, echoed back via `rsp_item.data_nack_q` as described above.

### 4.5. Usage in Virtual Sequences

```systemverilog
// In a write vseq:
i3c_device_response_seq dev_seq;
dev_seq = i3c_device_response_seq::type_id::create("dev_seq");
dev_seq.target_addr = 7'h08;
dev_seq.is_i3c = 1;
fork
  dev_seq.start(p_sequencer.m_i3c_sequencer);
join_none
```

### 4.6. Write vs Read Behavior

**Write transfer (DUT writes to device):**
- Driver is in Device mode, `DrvWrPushPull` or `DrvWr` state (`04_i3c_agent_spec.md` §8.5)
- Driver samples 8 bits from bus per byte
- For I2C, ACK/NACK is driven per `req.data_nack_q` (`data_nack_pattern_q`/`data_nack`); for I3C PP, the host drives its own T-bit which the driver only observes
- After transfer, driver waits for STOP/RSTART

**Read transfer (DUT reads from device):**
- Driver is in Device mode, `DrvRdPushPull` or `DrvRd` state
- Driver drives `req.data[]` bits onto SDA (`rsp.data` is left empty — the driver does not echo the driven bytes back)
- For I3C PP: drives `req.t_bit_q[i]` as the T-bit after each byte (not echoed to `rsp.t_bit_q`)
- For I2C: waits for host ACK/NACK, recording each into `rsp.data_nack_q` (the *controller's* ACK/NACK of the byte, not a device-side pattern)
- After transfer, driver waits for STOP/RSTART

### 4.7. CCC / ENTDAA Response

`i3c_device_response_seq` already covers broadcast-header, direct-CCC, and ENTDAA responses through `start_with_broadcast_header`, `ccc_target_addr[_valid]`, and `entdaa_join`/`daa_id_bytes`/`daa_accept_addr` (§4.3) — this is not deferred future work. See `i3c_driver::handle_broadcast_dispatch()`/`do_entdaa_round()`/`do_ccc_payload()` (`04_i3c_agent_spec.md` §8.5) for how the driver interprets these fields. Not yet supported: per-byte data corruption and unexpected/injected STOP mid-transfer.

---

## 5. Related Sequences

| Sequence | Description |
|----------|-------------|
| `i3c_device_response_seq` | Generic device responder: address ACK/NACK, I2C/I3C read/write, broadcast-header/direct-CCC/ENTDAA response (§4) |

A dedicated NACK-only or corruption-injection sequence has not been split out; `addr_nack`/`data_nack`/`data_nack_pattern_q` on `i3c_device_response_seq` already cover the common NACK-injection cases (§4.3). The reference `i3c_seq_list.sv` is not used — our include set is `i3c_seq_lib.sv` (§3).

## 6. Implementation Notes

- The sequence runs once per bus transaction — the virtual sequence is responsible for starting it repeatedly if multiple transactions are expected
- The `rsp.end_with_rstart` field is filled by the driver based on bus observation (STOP vs RSTART detection), not by the sequence (`i3c_driver::get_and_drive()` sets `rsp.end_with_rstart` after the fork-based STOP/RSTART wait; §4.4.1)
- The sequence must be started BEFORE the DUT initiates the bus transaction (it waits for START condition)
- For back-to-back transactions, the virtual sequence should start a new `i3c_device_response_seq` in a loop
