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

  task automatic sample_bit_data(input string src = "host", output bit bit_o);
    @(posedge scl_i);
    bit_o = sda_i;
    `uvm_info(msg_id, $sformatf("sample bit data %d from %s", bit_o, src), UVM_DEBUG)
    @(negedge scl_i);
  endtask : sample_bit_data

  task automatic sample_t_bit_data(input string src = "host", output bit bit_o);
    @(posedge scl_i);
    bit_o = sda_i;
    `uvm_info(msg_id, $sformatf("sample T-bit data %d from %s", bit_o, src), UVM_DEBUG)
  endtask : sample_t_bit_data

  task automatic sample_addr(input string msg, output bit [6:0] addr, output bit dir);
    addr = '0;
    dir  = 1'b0;

    for (int i = 6; i >= 0; i--) begin
      sample_bit_data("host", addr[i]);
      `uvm_info(msg_id, $sformatf("sampled %s[%0d]=%0b", msg, i, addr[i]), UVM_DEBUG)
    end
    sample_bit_data("host", dir);
    `uvm_info(msg_id, $sformatf("sampled %s=0x%0h dir=%0b", msg, addr, dir), UVM_HIGH)
  endtask : sample_addr

  task automatic sample_i3c_data_byte(input string msg, output bit [7:0] data, output bit t_bit);
    data  = '0;
    t_bit = 1'b0;

    for (int i = 7; i >= 0; i--) begin
      sample_target_data(data[i]);
      `uvm_info(msg_id, $sformatf("sampled %s bit[%0d]=%0b", msg, i, data[i]), UVM_DEBUG)
    end
    sample_target_data(t_bit);
    `uvm_info(msg_id, $sformatf("sampled %s=0x%02h T-bit=%0b", msg, data, t_bit), UVM_HIGH)
  endtask : sample_i3c_data_byte

  task automatic wait_for_host_start(input i3c_timing_t tc);
    bit  start_seen;
    bit  hold_done;
    bit  hold_violated;
    time idle_high_time;
    time sda_fall_time;
    time setup_actual_time;

    forever begin
      wait (scl_i === 1'b1 && sda_i === 1'b1);
      idle_high_time = $time;

      start_seen = 1'b0;
      fork
        begin
          @(negedge sda_i iff scl_i);
          start_seen = 1'b1;
          sda_fall_time = $time;
        end
        begin
          @(negedge scl_i);
        end
      join_any
      disable fork;

      if (!start_seen || scl_i !== 1'b1 || sda_i !== 1'b0) continue;

      setup_actual_time = sda_fall_time - idle_high_time;
      if (setup_actual_time < (tc.tSetupStart * 1ns)) begin
        `uvm_error(msg_id,
                   $sformatf(
                       "Host START setup time check failed: expected time %0t vs actual time %0t",
                       tc.tSetupStart * 1ns, setup_actual_time))
      end

      hold_done = 1'b0;
      hold_violated = 1'b0;
      fork
        begin
          #(tc.tHoldStart * 1ns);
          hold_done = 1'b1;
        end
        begin
          @(negedge scl_i);
          if (!hold_done) hold_violated = 1'b1;
        end
      join_any
      disable fork;

      if (hold_violated) begin
        `uvm_error(msg_id, "Host START hold time check failed")
      end

      break;
    end
  endtask : wait_for_host_start

  task automatic wait_for_host_rstart(input i3c_timing_t tc, output bit rstart);
    bit  setup_check_valid;
    bit  sda_high_seen;
    bit  rstart_seen;
    bit  hold_done;
    bit  hold_violated;
    time scl_high_time;
    time sda_fall_time;
    time setup_actual_time;

    rstart = 1'b0;

    forever begin
      setup_check_valid = 1'b0;
      sda_high_seen = 1'b0;
      rstart_seen = 1'b0;

      if (scl_i !== 1'b1) begin
        @(posedge scl_i);
        setup_check_valid = 1'b1;
        scl_high_time = $time;
      end

      if (sda_i !== 1'b1) begin
        fork
          begin
            @(posedge sda_i);
            sda_high_seen = 1'b1;
          end
          begin
            @(negedge scl_i);
          end
        join_any
        disable fork;
        if (!sda_high_seen || scl_i !== 1'b1) continue;
      end

      fork
        begin
          @(negedge sda_i iff scl_i);
          rstart_seen   = 1'b1;
          sda_fall_time = $time;
        end
        begin
          @(negedge scl_i);
        end
      join_any
      disable fork;

      if (!rstart_seen || scl_i !== 1'b1 || sda_i !== 1'b0) continue;

      if (setup_check_valid) begin
        setup_actual_time = sda_fall_time - scl_high_time;
        if (setup_actual_time < (tc.tSetupStart * 1ns)) begin
          `uvm_error(
              msg_id,
              $sformatf("Host RSTART setup time check failed: expected time %0t vs actual time %0t",
                        tc.tSetupStart * 1ns, setup_actual_time))
        end
      end

      hold_done = 1'b0;
      hold_violated = 1'b0;
      fork
        begin
          #(tc.tHoldRStart * 1ns);
          hold_done = 1'b1;
        end
        begin
          @(negedge scl_i);
          if (!hold_done) hold_violated = 1'b1;
        end
      join_any
      disable fork;

      if (hold_violated) begin
        `uvm_error(msg_id, "Host RSTART hold time check failed")
      end

      rstart = 1'b1;
      break;
    end
  endtask : wait_for_host_rstart

  task automatic wait_for_host_stop(input i3c_timing_t tc, output bit stop);
    bit stop_setup_done;
    bit bus_free_done;
    bit bus_free_violated;

    stop = 1'b0;
    forever begin
      wait (scl_i === 1'b0 && sda_i === 1'b0);
      @(posedge scl_i or posedge sda_i);
      if (!(scl_i === 1'b1 && sda_i === 1'b0)) continue;

      stop_setup_done = 1'b0;
      fork
        begin
          time_check(tc.tSetupStop, 1'b1, sda_i, "Host STOP setup");
          stop_setup_done = 1'b1;
        end
        begin
          @(negedge scl_i);
        end
      join_any
      disable fork;
      if (!stop_setup_done || scl_i !== 1'b1 || sda_i !== 1'b1) continue;

      bus_free_done = 1'b0;
      bus_free_violated = 1'b0;
      fork
        begin
          #(tc.tHoldStop * 1ns);
          bus_free_done = 1'b1;
        end
        begin
          @(negedge scl_i or negedge sda_i);
          if (!bus_free_done) bus_free_violated = 1'b1;
        end
      join_any
      disable fork;

      if (bus_free_violated) begin
        `uvm_error(msg_id, "Host STOP bus free time check failed")
      end else if (scl_i === 1'b1 && sda_i === 1'b1) begin
        stop = 1'b1;
        break;
      end
    end
  endtask : wait_for_host_stop

  task automatic wait_for_i2c_host_stop_or_rstart(input i2c_timing_t tc, output bit rstart,
                                                  output bit stop);
    i3c_timing_t host_tc;

    host_tc.tSetupStart = tc.tSetupStart;
    host_tc.tHoldStart  = tc.tHoldStart;
    host_tc.tHoldRStart = tc.tHoldStart;
    host_tc.tSetupStop  = tc.tSetupStop;
    host_tc.tHoldStop   = tc.tHoldStop;

    fork
      begin : iso_fork
        fork
          wait_for_host_stop(.tc(host_tc), .stop(stop));
          wait_for_host_rstart(.tc(host_tc), .rstart(rstart));
        join_any
        disable fork;
      end : iso_fork
    join
  endtask : wait_for_i2c_host_stop_or_rstart

  task automatic wait_for_i3c_host_stop_or_rstart(input i3c_timing_t tc, output bit rstart,
                                                  output bit stop);
    fork
      begin : iso_fork
        fork
          wait_for_host_stop(.tc(tc), .stop(stop));
          wait_for_host_rstart(.tc(tc), .rstart(rstart));
        join_any
        disable fork;
      end : iso_fork
    join
  endtask : wait_for_i3c_host_stop_or_rstart

  task automatic sample_i3c_next_addr_or_stop(
      input i3c_timing_t tc, input string msg, output bit got_addr, output bit rstart,
      output bit stop, output bit [6:0] addr, output bit dir);
    got_addr = 1'b0;
    rstart   = 1'b0;
    stop     = 1'b0;
    addr     = '0;
    dir      = 1'b0;

    wait_for_i3c_host_stop_or_rstart(tc, rstart, stop);
    if (!rstart) begin
      `uvm_info(msg_id, $sformatf("%s not followed by RSTART", msg), UVM_HIGH)
      return;
    end

    sample_addr(msg, addr, dir);
    got_addr = 1'b1;
  endtask : sample_i3c_next_addr_or_stop

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
    ack_r = ack && !nack;
  endtask : wait_for_host_ack_or_nack

  task automatic wait_for_device_ack_or_nack(output bit ack_r);
    bit data;
    @(posedge scl_i);
    data  = sda_i;
    ack_r = !data;
    `uvm_info(msg_id, $sformatf("sample device %s", ack_r ? "ACK" : "NACK"), UVM_HIGH)
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
      `uvm_error(msg_id, $sformatf(
                 "%s time check failed: expected time %d vs actual time %d",
                 msg,
                 valid_time,
                 exp_value_time
                 ))
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
      `uvm_error(msg_id, "I2C device bit clock high pulse width time check failed")
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

  task automatic wait_for_i3c_target_sda_handoff(input string phase, output bit ok,
                                                 input bit pp_phase = 1'b0);
    bit handoff_seen;

    ok = 1'b0;
    wait (!scl_i);
    device_sda_pp_en = 1'b0;
    device_sda_o = 1'b1;

    handoff_seen = 1'b0;
    fork
      begin
        if (pp_phase) wait (dut_sda_oe === 1'b0 && dut_sel_od_pp === 1'b1);
        else wait (dut_sda_oe === 1'b0);
        handoff_seen = 1'b1;
      end
      begin
        @(posedge scl_i);
      end
    join_any
    disable fork;

    if (!handoff_seen) begin
      if (pp_phase && dut_sel_od_pp === 1'b0) begin
        `uvm_info(msg_id, $sformatf("Controller framing STOP/Rstart before %s; target releases SDA",
                                    phase), UVM_HIGH)
        device_sda_pp_en = 1'b0;
        device_sda_o = 1'b1;
        return;
      end
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
    `uvm_info(msg_id, "device_i3c_raw_od_send_bit::Value", UVM_HIGH)
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C device bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    `uvm_info(msg_id, "device_i3c_raw_od_send_bit::Released SDA", UVM_HIGH)
    device_sda_o = 1;
  endtask : device_i3c_raw_od_send_bit

  task automatic device_i3c_send_addr_ack_handoff(input i3c_timing_t tc, input bit ack);
    bit handoff_ok;

    wait_for_i3c_target_sda_handoff("I3C address ACK/NACK slot", handoff_ok);
    if (!handoff_ok) return;

    `uvm_info(msg_id, $sformatf("device_i3c_send_addr_ack_handoff::Drive %s", ack ? "ACK" : "NACK"),
              UVM_HIGH)

    wait (!scl_i);
    device_sda_pp_en = 0;
    device_sda_o = ack ? 1'b0 : 1'b1;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C address ACK setup");
    `uvm_info(msg_id, "device_i3c_send_addr_ack_handoff::ACK", UVM_HIGH)

    #(tc.tSCO * 1ns);
    device_sda_o = 1'b1;
    `uvm_info(msg_id, "device_i3c_send_addr_ack_handoff::Released SDA after ACK handoff", UVM_HIGH)
  endtask : device_i3c_send_addr_ack_handoff

  task automatic device_i3c_send_addr_ack_no_handoff(input i3c_timing_t tc, input bit ack);
    bit handoff_ok;

    wait_for_i3c_target_sda_handoff("I3C address ACK/NACK slot without handoff", handoff_ok);
    if (!handoff_ok) return;

    `uvm_info(msg_id, $sformatf("device_i3c_send_addr_ack_no_handoff::Drive %s",
                                ack ? "ACK" : "NACK"), UVM_HIGH)

    wait (!scl_i);
    device_sda_pp_en = 1'b0;
    device_sda_o = ack ? 1'b0 : 1'b1;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C address ACK setup without handoff");

    `uvm_info(msg_id, "device_i3c_send_addr_ack_no_handoff::Hold SDA for following Target data",
              UVM_HIGH)
  endtask : device_i3c_send_addr_ack_no_handoff

  task automatic device_i3c_raw_pp_send_bit(input i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 1;
    `uvm_info(msg_id, "device_i3c_raw_pp_send_bit::Drive bit", UVM_HIGH)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_i3c_raw_pp_send_bit::Value", UVM_HIGH)
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
    `uvm_info(msg_id, "device_i3c_raw_pp_send_t_bit::Value", UVM_HIGH)
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    #(tc.tSCO * 1ns);

    {device_sda_pp_en, device_sda_o} = 2'b01;

    time_check(tc.tClockPulse - tc.tSCO, 1'b0, scl_i, "I3C device bit clock high pulse width");
    `uvm_info(msg_id, "device_i3c_raw_pp_send_t_bit::Released SDA after T-bit", UVM_HIGH)
  endtask : device_i3c_raw_pp_send_t_bit

  task automatic device_i3c_send_bit(input i3c_timing_t tc, input bit bit_i);
    bit handoff_ok;
    bit rstart;
    bit stop;

    wait_for_i3c_target_sda_handoff("I3C read data bit", handoff_ok, 1'b1);
    if (!handoff_ok) return;

    device_i3c_raw_pp_send_bit(tc, bit_i);
  endtask : device_i3c_send_bit

  task automatic device_i3c_send_t_bit(input i3c_timing_t tc, input bit bit_i);
    bit handoff_ok;
    bit rstart;
    bit stop;

    wait_for_i3c_target_sda_handoff("I3C read T-bit", handoff_ok, 1'b1);
    if (!handoff_ok) return;

    device_i3c_raw_pp_send_t_bit(tc, bit_i);
  endtask : device_i3c_send_t_bit

  task automatic device_i3c_send_daa_bit(input i3c_timing_t tc, input bit bit_i);
    bit handoff_ok;

    wait_for_i3c_target_sda_handoff("I3C DAA bit", handoff_ok);
    if (!handoff_ok) return;

    device_i3c_raw_od_send_bit(tc, bit_i);
  endtask : device_i3c_send_daa_bit
endinterface
