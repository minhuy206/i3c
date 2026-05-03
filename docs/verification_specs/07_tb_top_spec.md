# Component: Testbench Top Module

> Status: New
> Location: `verification/uvm_i3c/i3c_core/tb_i3c_top.sv`
> Reference: `i3c-core/verification/uvm_i3c/i3c_core/tb_i3c_core.sv` (52 lines)
> Estimated LoC: ~120 lines

## 1. Purpose

Top-level SystemVerilog module that instantiates the DUT, connects interfaces, generates clock and reset, sets up `uvm_config_db` entries, and launches the UVM test.

## 2. Dependencies

- `uvm_pkg`, `i3c_test_pkg`
- Instantiates: `i3c_controller_top` (DUT), `reg_if`, `i3c_if`

## 3. Clock & Reset

- **Clock**: 10ns period (100 MHz), `logic clk`, toggled in initial block
- **Reset**: Assert low for 100 cycles, then release high

## 4. Register Interface

```systemverilog
reg_if reg_bus(.clk_i(clk), .rst_ni(rst_n));
```

Connected to DUT's `reg_addr_i`, `reg_wdata_i`, `reg_wen_i`, `reg_ren_i`, `reg_rdata_o`, `reg_ready_o`.

## 5. Open-Drain Bus Model

```systemverilog
wire scl_bus, sda_bus;
// DUT open-drain: LOW pulls bus, HIGH releases
assign scl_bus = (scl_out === 1'b0) ? 1'b0 : 1'bz;
assign sda_bus = (sda_out === 1'b0) ? 1'b0 : 1'bz;
pullup (weak1) pu_scl (scl_bus);
pullup (weak1) pu_sda (sda_bus);
assign scl_in = scl_bus;
assign sda_in = sda_bus;

i3c_if i3c_bus(.clk_i(clk), .rst_ni(rst_n), .scl_io(scl_bus), .sda_io(sda_bus));
```

Both DUT and agent pull low to drive LOW; release for HIGH via pull-up. DUT's 2FF synchronizer adds 2-cycle latency.

## 6. DUT Parameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| `CmdFifoDepth` | 8 | Reduced from 64 for sim speed |
| `TxFifoDepth` | 8 | Reduced for sim |
| `RxFifoDepth` | 8 | Reduced for sim |
| `RespFifoDepth` | 8 | Reduced for sim |
| `DatDepth` | 16 | Default |

## 7. UVM Config DB

```systemverilog
initial begin
  uvm_config_db#(virtual reg_if)::set(null, "*.env.m_reg_agent", "vif", reg_bus);
  uvm_config_db#(virtual i3c_if)::set(null, "*.env.m_i3c_agent", "vif", i3c_bus);
  $timeformat(-9, 0, " ns", 12);
  run_test();
end
```

## 8. Waveform Dumping (Xcelium)

```systemverilog
initial begin
  if ($test$plusargs("DUMP_WAVES")) begin
    $shm_open("waves.shm");
    $shm_probe(tb_i3c_top, "ACMTF");
  end
end
```

## 9. Timeout Watchdog

```systemverilog
initial begin
  #100ms;
  `uvm_fatal("TIMEOUT", "Simulation timeout (100ms)")
end
```

## 10. Implementation Notes

- Module name: `tb_i3c_top`
- `pullup` construct is Verilog-standard, supported by Xcelium
- `sel_od_pp_o` from DUT is unconnected — bus model is always open-drain; PP handled inside `i3c_if`
- `run_test()` with no arg → test selected via `+UVM_TESTNAME=` plusarg
