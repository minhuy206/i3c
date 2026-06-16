interface i3c_if (
    input clk_i,
    input rst_ni,
    input dut_sel_od_pp_i,
    input dut_sda_oe_i,
    input dut_sda_o_i,
    inout scl_io,
    inout sda_io
);
  import uvm_pkg::*;
  import i3c_timing_pkg::i2c_timing_t;
  import i3c_timing_pkg::i3c_timing_t;
  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  logic scl_i;
  logic scl_o = 1'b1;
  logic scl_pp_en = 1'b0;
  logic sda_i;
  logic device_sda_o = 1'b1;
  logic device_sda_pp_en = 1'b1;
  logic dut_sel_od_pp;
  logic dut_sda_oe;
  logic dut_sda_o;

  assign scl_i = scl_io;
  assign sda_i = sda_io;
  assign dut_sel_od_pp = dut_sel_od_pp_i;
  assign dut_sda_oe = dut_sda_oe_i;
  assign dut_sda_o = dut_sda_o_i;

  // Target-mode sequences must keep scl_pp_en=0 and scl_o=1.
  // Driving SCL is only for host-mode or directed raw bus/PHY stimulus.
  assign scl_io = scl_pp_en ? scl_o : (scl_o ? 1'bz : scl_o);
  assign (highz0, weak1) scl_io = 1'b1;

  assign sda_io = device_sda_pp_en ? device_sda_o : (device_sda_o ? 1'bz : device_sda_o);

  assign (highz0, weak1) sda_io = 1'b1;

  string msg_id = "i3c_if";

  int scl_spinwait_timeout_ns = 10_000_000;

  clocking cb @(posedge clk_i);
    input scl_i;
    input sda_i;
    input dut_sel_od_pp;
    input dut_sda_oe;
    input dut_sda_o;
    output scl_o;
    output device_sda_o;
    output scl_pp_en;
    output device_sda_pp_en;
  endclocking

  bit spike_filter = 0;

  task automatic enable_spike_filter();
    spike_filter = 1;
  endtask

  task automatic disable_spike_filter();
    spike_filter = 0;
  endtask

  int delay;
  assign delay = spike_filter ? 50 : 0;

  wire scl_delayed, scl_filtered;

  assign #(delay) scl_delayed = cb.scl_i;
  assign scl_filtered = cb.scl_i & scl_delayed;

  task automatic p_edge_scl();
    // Poll SCL on every system clock edge. NOTE: an empty `while(...) @(posedge clk_i);`
    // body gets optimized out by Xcelium in some configurations, returning in zero
    // time; the dummy `tick` increment defeats that optimization.
    int tick;
    while (scl_i !== 1'b0) begin
      @(posedge clk_i);
      tick++;
    end
    while (scl_i !== 1'b1) begin
      @(posedge clk_i);
      tick++;
    end
  endtask

  task automatic sample_target_data(output bit data);
    p_edge_scl();
    data = sda_i;
  endtask

  task automatic get_bit_data(input string src = "host", output bit bit_o);
    @(posedge scl_i);
    bit_o = sda_i;
    `uvm_info(msg_id, $sformatf("get bit data %d from %s", bit_o, src), UVM_HIGH)
    @(negedge scl_i);
  endtask : get_bit_data

  task automatic wait_for_host_start();
    @(negedge sda_i iff scl_i);
  endtask

  task automatic wait_for_host_rstart(output bit rstart);
    rstart = 1'b0;
    @(negedge sda_i iff scl_i);
    rstart = 1'b1;
  endtask

  task automatic wait_for_host_stop(input int wait_delay, output bit stop);
    stop = 1'b0;
    forever begin
      @(posedge sda_i iff scl_i);
      #(wait_delay * 1ns);
      if (scl_i === 1'b1 && sda_i === 1'b1) begin
        stop = 1'b1;
        break;
      end
    end
  endtask

  task automatic wait_for_i2c_host_stop_or_rstart(input i2c_timing_t tc, output bit rstart,
                                                  output bit stop);
    int delay = tc.tHoldStop;
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(.wait_delay(delay), .stop(stop));
          wait_for_host_rstart(.rstart(rstart));
        join_any
        disable fork;
      end : iso_fork
    join
  endtask : wait_for_i2c_host_stop_or_rstart

  task automatic wait_for_i3c_host_stop_or_rstart(input i3c_timing_t tc, output bit rstart,
                                                  output bit stop);
    int delay = tc.tHoldStop;
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(.wait_delay(delay), .stop(stop));
          wait_for_host_rstart(.rstart(rstart));
        join_any
        disable fork;
      end : iso_fork
    join
  endtask : wait_for_i3c_host_stop_or_rstart

  task automatic wait_for_i3c_host_stop_or_rstart_after_ack(input i3c_timing_t tc,
                                                            output bit rstart, output bit stop);
    int delay = tc.tHoldStop;
    rstart = 1'b0;
    stop   = 1'b0;
    fork
      begin : iso_fork
        fork
          wait_for_host_rstart(.rstart(rstart));
          begin
            if (scl_i === 1'b1) @(negedge scl_i);
            wait_for_host_stop(.wait_delay(delay), .stop(stop));
          end
        join_any
        disable fork;
      end : iso_fork
    join
  endtask : wait_for_i3c_host_stop_or_rstart_after_ack

  task automatic wait_for_host_ack();
    `uvm_info(msg_id, "Wait for host ack::Begin", UVM_HIGH)
    forever begin
      @(posedge scl_i);
      if (!sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host ack::Ack received", UVM_HIGH)
  endtask : wait_for_host_ack

  task automatic wait_for_host_nack();
    `uvm_info(msg_id, "Wait for host nack::Begin", UVM_HIGH)
    forever begin
      @(posedge scl_i);
      if (sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host nack::Nack received", UVM_HIGH)
  endtask : wait_for_host_nack

  task automatic wait_for_host_ack_or_nack(output bit ack_r);
    bit ack = 1'b0;
    bit nack = 1'b0;
    fork
      begin : iso_fork
        fork
          begin
            wait_for_host_ack();
            ack = 1'b1;
          end
          begin
            wait_for_host_nack();
            nack = 1'b1;
          end
        join_any
        disable fork;
      end : iso_fork
    join
    wait (scl_io == 0);
    ack_r = ack && !nack;
  endtask : wait_for_host_ack_or_nack

  task automatic wait_for_device_ack_or_nack(output bit ack_r);
    bit data;
    get_bit_data("device", data);
    ack_r = !data;
  endtask : wait_for_device_ack_or_nack

  task automatic time_check(input int delay, input bit exp_value, ref logic check_wire,
                            input string msg);
    time valid_time;
    time exp_value_time;
    fork
      begin
        #(delay * 1ns);
        valid_time = $time;
      end
      begin
        wait (check_wire == exp_value);
        exp_value_time = $time;
      end
    join
    if (valid_time > exp_value_time)
      `uvm_info(msg_id, $sformatf(
                "%s time check failed: expected time %d vs actual time %d",
                msg,
                valid_time,
                exp_value_time
                ), UVM_HIGH)
  endtask

  task automatic device_i2c_send_bit(input i2c_timing_t tc, input bit bit_i);
    bit min_high_done;
    bit scl_fell_early;

    device_sda_pp_en = 0;
    device_sda_o = 1'b1;
    wait (!scl_i);
    `uvm_info(msg_id, "device_i2c_send_bit::Drive bit", UVM_HIGH)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I2C device bit setup");
    `uvm_info(msg_id, "device_i2c_send_bit::Value sampled", UVM_HIGH)

    min_high_done  = 1'b0;
    scl_fell_early = 1'b0;
    fork
      begin
        #(tc.tClockPulse * 1ns);
        min_high_done = 1'b1;
      end
      begin
        @(negedge scl_i);
        if (!min_high_done) scl_fell_early = 1'b1;
      end
    join_any
    disable fork;
    if (scl_fell_early) begin
      `uvm_info(msg_id, "I2C device bit clock high pulse width time check failed", UVM_HIGH)
    end else if (scl_i) begin
      fork
        begin
          wait (!scl_i);
        end
        begin
          #(tc.tSetupStop * 1ns);
        end
      join_any
      disable fork;
    end

    #(tc.tHoldBit * 1ns);
    device_sda_o = 1'b1;
  endtask : device_i2c_send_bit

  task automatic wait_for_i3c_target_sda_handoff(input string phase, output bit ok);
    bit handoff_seen;

    ok = 1'b0;
    wait (!scl_i);
    device_sda_pp_en = 1'b0;
    device_sda_o = 1'b1;

    handoff_seen = 1'b0;
    fork
      begin
        wait (dut_sda_oe === 1'b0);
        handoff_seen = 1'b1;
      end
      begin
        @(posedge scl_i);
      end
    join_any
    disable fork;

    if (!handoff_seen) begin
      `uvm_error(msg_id, $sformatf("Controller did not release SDA before %s", phase))
      wait (!scl_i);
      device_sda_o = 1'b1;
      return;
    end

    ok = 1'b1;
  endtask : wait_for_i3c_target_sda_handoff

  task automatic device_i3c_raw_od_send_bit(input i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 0;
    `uvm_info(msg_id, "device_i3c_raw_od_send_bit::Drive bit", UVM_HIGH)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_i3c_raw_od_send_bit::Value sampled", UVM_HIGH)
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C device bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    `uvm_info(msg_id, "device_i3c_raw_od_send_bit::Released SDA", UVM_HIGH)
    device_sda_o = 1;
  endtask : device_i3c_raw_od_send_bit

  task automatic device_i3c_send_addr_ack(input i3c_timing_t tc, input bit ack,
                                          input bit wait_low_after_handoff);
    bit handoff_ok;

    wait_for_i3c_target_sda_handoff("I3C address ACK/NACK slot", handoff_ok);
    if (!handoff_ok) return;

    `uvm_info(msg_id, $sformatf("device_i3c_send_addr_ack::Drive %s", ack ? "ACK" : "NACK"),
              UVM_HIGH)

    wait (!scl_i);
    device_sda_pp_en = 0;
    device_sda_o = ack ? 1'b0 : 1'b1;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C address ACK setup");
    `uvm_info(msg_id, "device_i3c_send_addr_ack::ACK sampled", UVM_HIGH)

    #(tc.tSCO * 1ns);
    device_sda_o = 1'b1;
    `uvm_info(msg_id, "device_i3c_send_addr_ack::Released SDA after ACK handoff", UVM_HIGH)

    if (wait_low_after_handoff) wait (!scl_i);
  endtask : device_i3c_send_addr_ack

  task automatic device_i3c_raw_pp_send_bit(input i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 1;
    `uvm_info(msg_id, "device_i3c_raw_pp_send_bit::Drive bit", UVM_HIGH)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_i3c_raw_pp_send_bit::Value sampled", UVM_HIGH)
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C device bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    device_sda_pp_en = 0;
    device_sda_o = 1;
  endtask : device_i3c_raw_pp_send_bit

  task automatic device_i3c_raw_pp_send_t_bit(input i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 1;
    `uvm_info(msg_id, "device_i3c_raw_pp_send_t_bit::Drive bit", UVM_HIGH)
    device_sda_o = bit_i;
    `uvm_info(msg_id, "device_i3c_raw_pp_send_t_bit::Value sampled", UVM_HIGH)
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    #(tc.tSCO * 1ns);
    device_sda_pp_en = 0;
    time_check(tc.tClockPulse - tc.tSCO, 1'b0, scl_i, "I3C device bit clock high pulse width");
    `uvm_info(msg_id, "device_i3c_raw_pp_send_t_bit", UVM_HIGH)
    device_sda_o = 1;
  endtask : device_i3c_raw_pp_send_t_bit

  task automatic device_i3c_send_bit(input i3c_timing_t tc, input bit bit_i,
                                     output bit sent);
    bit handoff_ok;
    bit rstart;
    bit stop;

    sent = 1'b0;
    wait_for_i3c_target_sda_handoff("I3C read data bit", handoff_ok);
    if (!handoff_ok) return;

    fork
      begin
        device_i3c_raw_pp_send_bit(tc, bit_i);
        sent = 1'b1;
      end
      begin
        wait_for_i3c_host_stop_or_rstart(tc, rstart, stop);
      end
    join_any
    disable fork;

    if (!sent) begin
      device_sda_pp_en = 1'b0;
      device_sda_o = 1'b1;
    end
  endtask : device_i3c_send_bit

  task automatic device_i3c_send_t_bit(input i3c_timing_t tc, input bit bit_i,
                                       output bit sent);
    bit handoff_ok;
    bit rstart;
    bit stop;

    sent = 1'b0;
    wait_for_i3c_target_sda_handoff("I3C read T-bit", handoff_ok);
    if (!handoff_ok) return;

    fork
      begin
        device_i3c_raw_pp_send_t_bit(tc, bit_i);
        sent = 1'b1;
      end
      begin
        wait_for_i3c_host_stop_or_rstart(tc, rstart, stop);
      end
    join_any
    disable fork;

    if (!sent) begin
      device_sda_pp_en = 1'b0;
      device_sda_o = 1'b1;
    end
  endtask : device_i3c_send_t_bit

  task automatic device_i3c_send_daa_bit(input i3c_timing_t tc, input bit bit_i);
    bit handoff_ok;

    wait_for_i3c_target_sda_handoff("I3C DAA bit", handoff_ok);
    if (!handoff_ok) return;

    device_i3c_raw_od_send_bit(tc, bit_i);
  endtask : device_i3c_send_daa_bit
endinterface
