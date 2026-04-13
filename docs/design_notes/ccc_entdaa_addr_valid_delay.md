# Design Note: `addr_valid_o` 1-Cycle Delay in `ccc_entdaa`

**Module:** `src/ctrl/ccc_entdaa.sv`  
**Signal:** `addr_valid_o` (and implicitly `pid_o`, `bcr_o`, `dcr_o`)  
**Status:** TODO — confirm 1-cycle delay contract with parent `ccc` module

---

## Root Cause

`addr_valid_q` is a **flip-flop output**. Its value on any cycle is the value driven into `addr_valid_d` **one clock edge earlier**. This is just how FFs work:

```
addr_valid_d  ──[FF]──►  addr_valid_q  ──►  addr_valid_o
               (1 clk)
```

---

## Tracing the NoDev Path

```
Cycle N-1:  state_q = ReadRsvdAck
            bus_rx_done_i = 1, received NACK (no target responded)
            addr_valid_d = addr_valid_q  ← default, NOT cleared
            state_d = NoDev

Cycle N:    state_q = NoDev
            ┌──────────────────────────────────────────────────────┐
            │ done_daa_o  = 1   ← parent sees "round complete"    │
            │ no_device_o = 1   ← parent sees "no device"         │
            │ addr_valid_o = addr_valid_q = ???                    │
            │   If previous round succeeded: addr_valid_q = 1  ← STALE
            │   If this is the first round:  addr_valid_q = 0  ✓  │
            └──────────────────────────────────────────────────────┘
            addr_valid_d = 1'b0  ← being driven to 0 NOW
            state_d = Idle

Cycle N+1:  state_q = Idle
            done_daa_o  = 0  ← gone
            addr_valid_q = 0  ← NOW correct, but done is already gone
```

---

## The Consequence

When `done_daa_o` fires (Cycle N), the parent reads `addr_valid_o`. If there was a successful round before this NoDev round, `addr_valid_o = 1` simultaneously with `no_device_o = 1`. That is a **contradictory signal pair** — it says "address was acknowledged" AND "no device responded" at the same time.

If the parent uses these two signals together to decide what to do next (e.g., write to DAT only if `addr_valid_o && !no_device_o`), the stale `addr_valid_o = 1` could cause a **false DAT write** or incorrect behavior.

---

## The Contract That Makes It Safe

The 1-cycle delay is only harmless if the parent (`ccc` module) is designed to follow this exact sampling rule:

> **Do NOT read `addr_valid_o`, `pid_o`, `bcr_o`, `dcr_o` on the same cycle `done_daa_o` fires. Read them on the NEXT cycle.**

Concretely, the parent must register `done_daa_o` and act on the registered version:

```systemverilog
// In ccc module (parent):
logic done_daa_q;
always_ff @(posedge clk_i) done_daa_q <= done_daa_o;

// Sample results when the registered done fires:
if (done_daa_q) begin
  // addr_valid_o, pid_o, bcr_o, dcr_o are now valid ✓
end
```

On the cycle `done_daa_q` (registered) is high, `addr_valid_q` in `ccc_entdaa` is already `0` (cleared by the FF). Everything is consistent.

---

## Summary

| What the parent does | `addr_valid_o` on NoDev cycle | Safe? |
|---|---|---|
| Samples **same cycle** as `done_daa_o` | Stale (possibly 1) | **No** |
| Samples **one cycle after** `done_daa_o` | Correctly 0 | **Yes** |

The 1-cycle delay is only a "bug" if the parent samples on the same cycle. If the parent is written to sample one cycle later, it is a valid design — but that contract **must be explicit and enforced** in the `ccc` module.
