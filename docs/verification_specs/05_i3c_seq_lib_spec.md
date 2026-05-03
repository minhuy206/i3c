# Component: I3C Sequence Library (dv_i3c/seq_lib/)

> Status: Adapt from reference + New
> Location: `verification/uvm_i3c/dv_i3c/seq_lib/`
> Reference: `i3c-core/verification/uvm_i3c/dv_i3c/seq_lib/` (8 sequences)
> Estimated LoC: ~200 lines (2 files)

## 1. Purpose

Reusable I3C bus-level sequences that run on the `i3c_sequencer`. These sequences construct `i3c_seq_item` transactions to instruct the I3C driver how to behave during bus transfers.

For Phase 1, only one sequence is needed: `i3c_device_response_seq` — a generic device responder that ACKs addresses and handles read/write data.

## 2. Dependencies

### Packages

- `i3c_agent_pkg` (parent package)

### Used By

- Virtual sequences (`i3c_smoke_vseq`, `i3c_write_vseq`, `i3c_read_vseq`) start this on the I3C sequencer
- Runs concurrently with the DUT's bus activity initiated by register agent sequences

---

## 3. File: i3c_seq_lib.sv

### 3.1. Purpose

Include file that aggregates all sequence source files.

### 3.2. Contents

```systemverilog
`include "i3c_device_response_seq.sv"
// Phase 2:
// `include "i3c_device_daa_response_seq.sv"
// `include "i3c_device_ccc_response_seq.sv"
```

---

## 4. File: i3c_device_response_seq.sv

### 4.1. Purpose

A device-mode sequence that responds to a single I3C/I2C transaction initiated by the host (DUT). The sequence:

1. Waits for the DUT to issue a START and drive address bits
2. ACKs the address if it matches the configured target address
3. For **write transfers**: receives data bytes from host, ACKs each byte
4. For **read transfers**: sends data bytes to host
5. Handles STOP or RSTART to end the transaction

### 4.2. Class Hierarchy

```
uvm_sequence#(i3c_seq_item) → i3c_device_response_seq
```

### 4.3. Configurable Fields

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `target_addr` | `bit [6:0]` | `7'h08` | Address to match and ACK |
| `is_i3c` | `bit` | `1` | I3C (1) or I2C (0) mode |
| `read_data` | `bit [7:0] [$]` | `{}` | Data to return on reads |
| `ack_address` | `bit` | `1` | Whether to ACK matched address |
| `ack_data` | `bit` | `1` | Whether to ACK received data bytes |
| `read_data_cnt` | `int` | `4` | Number of bytes to return on read |

### 4.4. Sequence Body

```systemverilog
task body();
  i3c_seq_item req;
  req = i3c_seq_item::type_id::create("req");

  // Configure the seq_item for device response
  req.i3c        = is_i3c;
  req.addr       = target_addr;
  req.dir        = 0;           // Will be overwritten by driver sampling
  req.dev_ack    = ack_address;
  req.is_daa     = 0;
  req.end_with_rstart = 0;

  // For write transfers: device just ACKs each byte
  // For read transfers: populate data to send to host
  if (read_data.size() > 0) begin
    req.data     = read_data;
    req.data_cnt = read_data.size();
  end else begin
    // Generate default read data
    for (int i = 0; i < read_data_cnt; i++) begin
      req.data.push_back(8'hA0 + i);
    end
    req.data_cnt = read_data_cnt;
  end

  // Set T-bits: ACK all bytes for write; continue for read
  req.T_bit.delete();
  for (int i = 0; i < req.data_cnt; i++) begin
    if (i < req.data_cnt - 1)
      req.T_bit.push_back(ack_data);  // ACK or continue
    else
      req.T_bit.push_back(1'b0);       // Last byte: end
  end

  start_item(req);
  finish_item(req);

  // Get response from driver
  get_response(rsp);
endtask
```

### 4.5. Usage in Virtual Sequences

```systemverilog
// In i3c_write_vseq:
i3c_device_response_seq dev_seq;
dev_seq = i3c_device_response_seq::type_id::create("dev_seq");
dev_seq.target_addr = 7'h08;
dev_seq.is_i3c = 1;
dev_seq.ack_address = 1;
fork
  dev_seq.start(p_sequencer.m_i3c_sequencer);
join_none
```

### 4.6. Write vs Read Behavior

**Write transfer (DUT writes to device):**
- Driver is in Device mode, `DrvWrPushPull` or `DrvWr` state
- Driver samples 8 bits from bus per byte
- Driver sends ACK/NACK per `T_bit[]` settings
- After transfer, driver waits for STOP

**Read transfer (DUT reads from device):**
- Driver is in Device mode, `DrvRdPushPull` or `DrvRd` state
- Driver drives `req.data[]` bits onto SDA
- For I3C PP: drives T-bit after each byte
- For I2C: waits for host ACK/NACK
- After transfer, driver waits for STOP

### 4.7. Error Injection (Phase 2)

Future sequences will extend this to support:
- NACK on specific bytes
- Data corruption
- Unexpected STOP
- IBI during transfer

---

## 5. Phase 2 Sequences (Future)

| Sequence | Description |
|----------|-------------|
| `i3c_device_daa_response_seq` | Respond to ENTDAA with PID+BCR+DCR, accept assigned address |
| `i3c_device_ccc_response_seq` | Respond to specific CCCs (GETPID, GETBCR, etc.) |
| `i3c_device_ibi_seq` | Initiate In-Band Interrupt |
| `i3c_device_nack_seq` | NACK address for error testing |

## 6. Implementation Notes

- The sequence runs once per bus transaction — the virtual sequence is responsible for starting it repeatedly if multiple transactions are expected
- The `req.end_with_rstart` field is filled by the driver based on bus observation (STOP vs RSTART detection), not by the sequence
- The sequence must be started BEFORE the DUT initiates the bus transaction (it waits for START condition)
- For back-to-back transactions, the virtual sequence should start a new `i3c_device_response_seq` in a loop
