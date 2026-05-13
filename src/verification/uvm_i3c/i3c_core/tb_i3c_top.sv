`timescale 1ns / 1ps

module tb_i3c_top;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  import i3c_test_pkg::*;

  logic clk;
  logic rst_n;

  initial clk = 1'b0;
  always #5 clk = ~clk;  // 10 ns period → 100 MHz

  initial begin
    rst_n = 1'b0;
    repeat (100) @(posedge clk);
    rst_n = 1'b1;
  end

  wire scl_bus, sda_bus;
  logic scl_out, sda_out;
  logic scl_in, sda_in;

  assign scl_bus = (scl_out === 1'b0) ? 1'b0 : 1'bz;
  assign sda_bus = (sda_out === 1'b0) ? 1'b0 : 1'bz;

  pullup (weak1) pu_scl (scl_bus);
  pullup (weak1) pu_sda (sda_bus);

  assign scl_in = scl_bus;
  assign sda_in = sda_bus;

  reg_if reg_bus (
      .clk_i (clk),
      .rst_ni(rst_n)
  );

  i3c_if i3c_bus (
      .clk_i (clk),
      .rst_ni(rst_n),
      .scl_io(scl_bus),
      .sda_io(sda_bus)
  );

  i3c_controller_top #(
      .DatDepth     (16),
      .CmdFifoDepth (8),
      .TxFifoDepth  (8),
      .RxFifoDepth  (8),
      .RespFifoDepth(8)
  ) dut (
      .clk_i (clk),
      .rst_ni(rst_n),

      .reg_addr_i (reg_bus.addr),
      .reg_wdata_i(reg_bus.wdata),
      .reg_wen_i  (reg_bus.wen),
      .reg_ren_i  (reg_bus.ren),
      .reg_rdata_o(reg_bus.rdata),
      .reg_ready_o(reg_bus.ready),

      .scl_i      (scl_in),
      .scl_o      (scl_out),
      .sda_i      (sda_in),
      .sda_o      (sda_out),
      .sel_od_pp_o()          // unconnected — bus model is always open-drain
  );

  initial begin
    uvm_config_db#(virtual reg_if)::set(null, "*.env.m_reg_agent*", "vif", reg_bus);
    uvm_config_db#(virtual i3c_if)::set(null, "*.env.m_i3c_agent", "vif", i3c_bus);
    $timeformat(-9, 0, " ns", 12);
    run_test();  // test selected via +UVM_TESTNAME=
  end

  initial begin
    if ($test$plusargs("DUMP_WAVES")) begin
      $shm_open("waves.shm");
      $shm_probe(tb_i3c_top, "ACMTF");
    end
  end

  initial begin
    #100ms;
    `uvm_fatal("TIMEOUT", "Simulation timeout (100ms)")
  end

endmodule
