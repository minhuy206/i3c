interface i3c_if (
    input clk_i,
    input rst_ni,
    inout scl_io,
    inout sda_io
);
  logic scl_i;
  logic scl_o = 1'b1;
  logic scl_pp_en = 1'b0;
  logic sda_i;
  logic device_sda_o = 1'b1;
  logic device_sda_pp_en = 1'b1;

  assign scl_i = scl_io;
  assign sda_i = sda_io;

  assign scl_io = scl_pp_en ? scl_o : (scl_o ? 1'bz : scl_o);
  assign (highz0, weak1) scl_io = 1'b1;

  assign sda_io = device_sda_pp_en ? device_sda_o : (device_sda_o ? 1'bz : device_sda_o);

  assign (highz0, weak1) sda_io = 1'b1;

  string msg_id = "i3c_if";

  int scl_spinwait_timeout_ns = 10_000_000;

  clocking cb @(posedge clk_i);
    input scl_i;
    input sda_i;
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

  bit i2c_devices_present = 0;
  task automatic mixed_bus();
    i2c_devices_present = 1;
  endtask

  task automatic i3c_only_bus();
    i2c_devices_present = 0;
  endtask

  task automatic p_edge_scl();
    wait (cb.scl_i == 0);
    wait (cb.scl_i == 1);
  endtask

  task automatic sample_target_data(output bit data);
    p_edge_scl();
    data = cb.sda_i;
  endtask

  task automatic get_bit_data(input string src = "host", output bit bit_o);
    @(posedge scl_i);
    bit_o = sda_i;
    `uvm_info(msg_id, $sformatf("get bit data %d from %s", bit_o, src), UVM_DEBUG)
    @(negedge scl_i);
  endtask : get_bit_data

  task automatic wait_for_host_start();
    forever begin
      @(negedge sda_i);
      if (!scl_i) continue;
      break;
    end
  endtask : wait_for_host_start

  task automatic wait_for_host_rstart(output bit rstart);
    rstart = 1'b0;
    forever begin
      @(posedge scl_i && sda_i);
      @(negedge sda_i);
      if (scl_i) begin
        rstart = 1'b1;
        break;
      end
    end
  endtask : wait_for_host_rstart

  task automatic wait_for_host_stop(input int wait_delay, output bit stop);
    stop = 1'b0;
    forever begin
      if (scl_i == 0) @(posedge scl_i);
      @(posedge sda_i);
      if (scl_i) begin
        stop = 1'b1;
        break;
      end
    end
    #(wait_delay * 1ns);
  endtask : wait_for_host_stop

  task automatic wait_for_i2c_host_stop_or_rstart(ref i2c_timing_t tc, output bit rstart,
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

  task automatic wait_for_i3c_host_stop_or_rstart(ref i3c_timing_t tc, output bit rstart,
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

  task automatic wait_for_host_ack();
    `uvm_info(msg_id, "Wait for host ack::Begin", UVM_DEBUG)
    forever begin
      @(posedge scl_i);
      if (!sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host ack::Ack received", UVM_DEBUG)
  endtask : wait_for_host_ack

  task automatic wait_for_host_nack();
    `uvm_info(msg_id, "Wait for host nack::Begin", UVM_DEBUG)
    forever begin
      @(posedge scl_i);
      if (sda_i) begin
        break;
      end
    end
    `uvm_info(msg_id, "Wait for host nack::Nack received", UVM_DEBUG)
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

  task automatic time_check(input int delay, input bit exp_value, ref check_wire, input string msg);
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

  task automatic device_i3c_start(ref i3c_timing_t tc);
    `DV_WAIT(scl_i === 1'b1,, scl_spinwait_timeout_ns, "host_start");
    #(tc.tSetupStart * 1ns);
    device_sda_o = 1'b0;
    #(tc.tHoldStart * 1ns);
    scl_o = 1'b0;
  endtask : device_i3c_start

  task automatic device_i2c_send_bit(ref i2c_timing_t tc, input bit bit_i);
    device_sda_pp_en = 0;
    device_sda_o = 1'b1;
    wait (!scl_i);
    `uvm_info(msg_id, "device_send_bit::Drive bit", UVM_DEBUG)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I2C device bit setup");
    `uvm_info(msg_id, "device_send_bit::Value sampled", UVM_DEBUG)

    time_check(tc.tClockPulse, 1'b0, scl_i, "I2C device bit clock high pulse width");

    #(tc.tHoldBit * 1ns);
    device_sda_o = 1'b1;
  endtask : device_i2c_send_bit

  task automatic device_i2c_send_ack(ref i2c_timing_t tc);
    device_i2c_send_bit(tc, 1'b0);
  endtask : device_i2c_send_ack

  task automatic device_i2c_send_nack(ref i2c_timing_t tc);
    device_i2c_send_bit(tc, 1'b1);
  endtask : device_i2c_send_nack

  task automatic device_i3c_od_send_bit(ref i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 0;
    `uvm_info(msg_id, "device_send_bit::Drive bit", UVM_DEBUG)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_send_bit::Value sampled", UVM_DEBUG)
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C device bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    device_sda_o = 1;
  endtask : device_i3c_od_send_bit

  task automatic device_i3c_send_bit(ref i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 1;
    `uvm_info(msg_id, "device_send_bit::Drive bit", UVM_DEBUG)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_send_bit::Value sampled", UVM_DEBUG)
    time_check(tc.tClockPulse, 1'b0, scl_i, "I3C device bit clock high pulse width");
    #(tc.tHoldBit * 1ns);
    device_sda_pp_en = 0;
    device_sda_o = 1;
  endtask : device_i3c_send_bit

  task automatic device_send_T_bit(ref i3c_timing_t tc, input bit bit_i);
    wait (!scl_i);
    device_sda_pp_en = 1;
    `uvm_info(msg_id, "device_send_bit::Drive bit", UVM_DEBUG)
    device_sda_o = bit_i;
    time_check(tc.tSetupBit, 1'b1, scl_i, "I3C device bit setup");
    `uvm_info(msg_id, "device_send_bit::Value sampled", UVM_DEBUG)
    #(12 * 1ns);
    device_sda_pp_en = 0;
    time_check(tc.tClockPulse - 12, 1'b0, scl_i, "I3C device bit clock high pulse width");
    device_sda_o = 1;
  endtask : device_send_T_bit
endinterface
