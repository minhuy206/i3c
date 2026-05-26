# UVM_FATAL POLL_IDLE Fix

## Summary

`make smoke` previously failed with:

```text
UVM_FATAL [POLL_IDLE] Timeout waiting for FSM idle
```

The failure was caused by `HC_STATUS[FSM_IDLE]` being exposed as a one-cycle pulse after a command completed. The UVM virtual sequence polls `HC_STATUS` periodically, so it could miss that pulse and timeout even though the transaction had already completed.

## Root Cause

After a response was written, `flow_active` transitioned:

```text
WriteResp -> Idle -> WaitForCmd
```

Because `i3c_fsm_en_i` remained asserted, the FSM left `Idle` after one clock and entered `WaitForCmd`. The original implementation only asserted `i3c_fsm_idle_o` in `Idle`, so software observed idle for only one cycle.

`WaitForCmd` with an empty CMD FIFO is not an active transfer. It is the enabled controller waiting for work, so it should also be reported as idle.

## Fix

In `src/rtl/ctrl/flow_active.sv`, `WaitForCmd` now asserts idle status when no command is pending:

```systemverilog
WaitForCmd: begin
  i3c_fsm_idle = cmd_queue_empty_i;
  gen_idle = cmd_queue_empty_i;
  cmd_queue_rready = 1'b1;
  transfer_cnt_d = 8'h0;
  issue_phase_d = 8'h0;
end
```

This makes `HC_STATUS[FSM_IDLE]` a stable status while the controller is enabled but has no command to execute.

## Secondary Bug Found

The I3C immediate-write path used `transfer_cnt_q` to select immediate data bytes, but this path advances with `issue_phase_q`. As a result, the smoke command sent `0xAA, 0xAA` instead of `0xAA, 0xBB`.

The fix derives the immediate data phase from `issue_phase_q` in `I3CWriteImmediate`, and from `transfer_cnt_q` for the non-I3C immediate path.

## Verification

Ran from `src/verification/`:

```sh
source ~/EDA/cadence/xcelium/XCELIUM1803.sh
make smoke
```

Result:

```text
Device sampled data[0]=170
Device sampled data[1]=187
RESP OK: tid=0x0 data_length=2
Scoreboard: pass=2 fail=0
UVM_ERROR : 0
UVM_FATAL : 0
```
