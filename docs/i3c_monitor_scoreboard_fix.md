# I3C Monitor Scoreboard Fix

## Summary

`i3c_read_vseq` previously completed the register-side read response, but the scoreboard still failed with:

```text
UVM_ERROR uvm_i3c/i3c_core/i3c_scoreboard.sv(193) ... 1 expected command(s) never observed on I3C bus
```

The DUT returned the expected RX data:

```text
RD addr=0x108 rdata=0xbebafeca
```

So the issue was not that the command failed on the controller side. The I3C bus monitor was missing or delaying the observed read transaction, which left the scoreboard with a queued expected command and no matching observed bus item.

## Root Cause

The failing path was the target-to-host I3C read data path in:

```text
src/verification/uvm_i3c/dv_i3c/i3c_monitor.sv
```

The monitor used `cfg.vif.get_bit_data()` for every bit, including the I3C read T-bit. That helper samples on `posedge scl_i` and then waits for `negedge scl_i`.

For the final target-to-host byte, the target drives the T-bit and the controller can generate STOP/RSTART immediately after the T-bit high phase. There may be no next SCL falling edge before the STOP condition. As a result, the monitor could capture the final byte value but block or lose the end-of-transfer condition before publishing the completed `i3c_item` through `analysis_port`.

The scoreboard then reported the command as "never observed" even though the bus transaction happened.

## Fix

The monitor now has a dedicated `device_to_host` path in `i3c_data()`:

1. Data bits `[8:1]` are still sampled with `get_bit_data()`.
2. The T-bit `[0]` is sampled directly on `posedge cfg.vif.scl_i` without waiting for another SCL falling edge.
3. STOP/RSTART detection runs in parallel using no-delay stop detection for this read end condition.
4. Once the read ends, the monitor sets `transaction.stop` or `transaction.rstart`, returns the completed item, and the main monitor thread publishes it to the scoreboard.

Relevant fixed code:

```systemverilog
if (device_to_host) begin
  remaining_count = count;
  fork : read_stop_or_rstart_watch
    begin
      fork
        cfg.vif.wait_for_host_stop(0, read_stop);
        cfg.vif.wait_for_host_rstart(read_rstart);
      join_any
      disable fork;
      read_end_seen = 1'b1;
    end
  join_none

  forever begin
    for (i = 8; i > 0; i--) begin
      cfg.vif.get_bit_data("device", mon_data[i]);
    end

    @(posedge cfg.vif.scl_i);
    mon_data[0] = cfg.vif.sda_i;

    transaction.data_q.push_back(mon_data[8:1]);
    transaction.data_ack_q.push_back(mon_data[0]);
    transaction.num_data++;

    if (read_end_seen || !mon_data[0] || (count > 0 && remaining_count == 0)) begin
      transaction.rstart = read_rstart;
      transaction.stop = read_stop;
      break;
    end

    @(negedge cfg.vif.scl_i);
  end
end
```

## Related Read-Sequence Fix

The read vseq also needed the target response sequence to know that the transaction is a read. `i3c_device_response_seq` now exposes a `dir` field and assigns it into `req.dir`. `i3c_read_vseq` sets:

```systemverilog
dev_seq.dir = 1'b1;
```

Without this, the target model could behave like a write target instead of driving read data.

## Verification

Ran from `src/verification/`:

```sh
source ~/EDA/cadence/xcelium/XCELIUM1803.sh
make sim SEQ=i3c_read_vseq VERBOSITY=UVM_HIGH
make regression
```

Read-sequence result after the monitor fix:

```text
monitor, sent full transaction to scb
data_q[0] = 0xca
data_q[1] = 0xfe
data_q[2] = 0xba
data_q[3] = 0xbe
RD addr=0x108 rdata=0xbebafeca
Scoreboard: pass=2 fail=0
UVM_ERROR : 0
UVM_FATAL : 0
```

Regression result:

```text
i3c_smoke_vseq: UVM_ERROR : 0, UVM_FATAL : 0
i3c_write_vseq: UVM_ERROR : 0, UVM_FATAL : 0
i3c_read_vseq : UVM_ERROR : 0, UVM_FATAL : 0
```
