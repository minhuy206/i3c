module scl_generator_timing_sva #(
    parameter int CounterWidth = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic gen_start_i,
    input logic gen_rstart_i,
    input logic gen_stop_i,
    input logic gen_clock_i,
    input logic gen_idle_i,
    input logic done_o,
    input logic busy_o,
    input logic sda_ctrl_active_o,

    input logic [CounterWidth-1:0] t_low_i,
    input logic [CounterWidth-1:0] t_low_od_i,
    input logic [CounterWidth-1:0] t_high_i,
    input logic [CounterWidth-1:0] t_su_sta_i,
    input logic [CounterWidth-1:0] t_hd_sta_i,
    input logic [CounterWidth-1:0] t_su_sto_i,
    input logic [CounterWidth-1:0] t_bus_free_i,
    input logic [CounterWidth-1:0] t_r_i,
    input logic [CounterWidth-1:0] t_f_i,
    input logic                    scl_use_od_low_i,

    input logic scl_i,
    input logic scl_o,
    input logic sda_o,

    input logic [3:0]              state_q,
    input logic [3:0]              state_d,
    input logic [CounterWidth-1:0] tcount,
    input logic                    load_tcount,
    input logic [CounterWidth-1:0] tcount_load_val
);

  localparam logic [3:0] Idle           = 4'd0;
  localparam logic [3:0] GenerateStart  = 4'd1;
  localparam logic [3:0] SdaFall        = 4'd2;
  localparam logic [3:0] HoldStart      = 4'd3;
  localparam logic [3:0] DriveLow       = 4'd4;
  localparam logic [3:0] DriveHigh      = 4'd5;
  localparam logic [3:0] WaitCmd        = 4'd6;
  localparam logic [3:0] GenerateRstart = 4'd7;
  localparam logic [3:0] SclHigh        = 4'd8;
  localparam logic [3:0] RstartSdaFall  = 4'd9;
  localparam logic [3:0] GenerateStop   = 4'd10;
  localparam logic [3:0] SclHighForStop = 4'd11;
  localparam logic [3:0] SdaRise        = 4'd12;
  localparam logic [3:0] BusFree        = 4'd13;

  logic past_valid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) past_valid_q <= 1'b0;
    else past_valid_q <= 1'b1;
  end

  function automatic logic [CounterWidth-1:0] counter_sum(
      input logic [CounterWidth-1:0] lhs,
      input logic [CounterWidth-1:0] rhs
  );
    counter_sum = lhs + rhs;
  endfunction

  function automatic logic [CounterWidth-1:0] selected_t_low();
    selected_t_low = scl_use_od_low_i ? t_low_od_i : t_low_i;
  endfunction

  function automatic logic state_is_valid(input logic [3:0] state);
    unique case (state)
      Idle, GenerateStart, SdaFall, HoldStart, DriveLow, DriveHigh, WaitCmd,
      GenerateRstart, SclHigh, RstartSdaFall, GenerateStop, SclHighForStop,
      SdaRise, BusFree: state_is_valid = 1'b1;
      default: state_is_valid = 1'b0;
    endcase
  endfunction

  function automatic logic expected_scl(input logic [3:0]              state,
                                        input logic [CounterWidth-1:0] count);
    expected_scl = !((state == DriveLow) || (state == WaitCmd) ||
                     ((state == GenerateStop) && (count != '0)));
  endfunction

  function automatic logic expected_sda(input logic [3:0] state);
    expected_sda = !((state == SdaFall) || (state == HoldStart) ||
                     (state == RstartSdaFall) || (state == GenerateStop) ||
                     (state == SclHighForStop));
  endfunction

  function automatic logic expected_sda_ctrl_active(input logic [3:0] state);
    expected_sda_ctrl_active = (state == GenerateStart)  ||
                               (state == SdaFall)        ||
                               (state == HoldStart)      ||
                               (state == GenerateRstart) ||
                               (state == SclHigh)        ||
                               (state == RstartSdaFall)  ||
                               (state == GenerateStop)   ||
                               (state == SclHighForStop) ||
                               (state == SdaRise);
  endfunction

  assert property (@(posedge clk_i) disable iff (!rst_ni) state_is_valid(state_q))
  else $error("scl_generator_timing_sva: state_q has invalid encoding in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   scl_o === expected_scl(state_q, tcount))
  else $error("scl_generator_timing_sva: scl_o decode mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni) sda_o === expected_sda(state_q))
  else $error("scl_generator_timing_sva: sda_o decode mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sda_ctrl_active_o === expected_sda_ctrl_active(state_q))
  else $error("scl_generator_timing_sva: sda_ctrl_active_o decode mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni) busy_o === (state_q != Idle))
  else $error("scl_generator_timing_sva: busy_o decode mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   done_o === (((state_d == DriveLow) && (state_q != DriveLow)) ||
                               ((state_q == BusFree) && (state_d == Idle))))
  else $error("scl_generator_timing_sva: done_o decode mismatch in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == Idle && gen_start_i)
                   |-> (load_tcount && (tcount_load_val == t_su_sta_i)))
  else $error("scl_generator_timing_sva: START must load t_su_sta_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == GenerateRstart && scl_i)
                   |-> (load_tcount && (tcount_load_val == t_su_sta_i)))
  else $error("scl_generator_timing_sva: repeated START high phase must load t_su_sta_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   ((state_q == SdaFall) || (state_q == RstartSdaFall))
                   |-> (load_tcount && (tcount_load_val == t_hd_sta_i)))
  else $error("scl_generator_timing_sva: START hold phase must load t_hd_sta_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == HoldStart && (tcount == '0))
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(selected_t_low(), t_f_i))))
  else $error("scl_generator_timing_sva: HoldStart expiry must load selected low+t_f_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == WaitCmd && gen_clock_i)
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(selected_t_low(), t_f_i))))
  else $error("scl_generator_timing_sva: WaitCmd resume must load selected low+t_f_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == WaitCmd && gen_stop_i)
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(selected_t_low(), t_f_i))))
  else $error("scl_generator_timing_sva: WaitCmd STOP must load selected low+t_f_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == DriveHigh && (tcount == '0) && gen_clock_i)
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(selected_t_low(), t_f_i))))
  else $error("scl_generator_timing_sva: DriveHigh expiry must load selected low+t_f_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == DriveHigh && (tcount == '0) && gen_stop_i)
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(selected_t_low(), t_f_i))))
  else $error("scl_generator_timing_sva: DriveHigh STOP must load selected low+t_f_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == DriveLow && (tcount == '0) && gen_clock_i)
                   |-> (load_tcount &&
                        (tcount_load_val == counter_sum(t_high_i, t_r_i))))
  else $error("scl_generator_timing_sva: DriveLow expiry must load t_high_i+t_r_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == GenerateStop && (tcount == '0) && scl_i)
                   |-> (load_tcount && (tcount_load_val == t_su_sto_i)))
  else $error("scl_generator_timing_sva: STOP high phase must load t_su_sto_i in %m");

  ap_stop_release_loads_bus_free :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == SdaRise)
                   |-> (load_tcount && (tcount_load_val == t_bus_free_i)))
  else $error("scl_generator_timing_sva: STOP release must load t_bus_free_i in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   $past(load_tcount) |-> (tcount == $past(tcount_load_val)))
  else $error("scl_generator_timing_sva: tcount must take loaded value in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni || !past_valid_q)
                   (!$past(load_tcount) && ($past(tcount) != '0))
                   |-> (tcount == ($past(tcount) - 1'b1)))
  else $error("scl_generator_timing_sva: tcount must decrement while nonzero in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   gen_idle_i |=> (state_q == Idle))
  else $error("scl_generator_timing_sva: gen_idle_i must return FSM to Idle in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == Idle) && gen_start_i)
                   |=> (gen_idle_i || (state_q == GenerateStart)))
  else $error("scl_generator_timing_sva: START request must enter GenerateStart in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == Idle) && !gen_start_i && gen_rstart_i)
                   |=> (gen_idle_i || (state_q == GenerateRstart)))
  else $error("scl_generator_timing_sva: repeated START request must enter GenerateRstart in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateStart) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == GenerateStart)))
  else $error("scl_generator_timing_sva: GenerateStart must wait for t_su_sta_i expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateStart) && (tcount == '0))
                   |=> (gen_idle_i || (state_q == SdaFall)))
  else $error("scl_generator_timing_sva: t_su_sta_i expiry must pull SDA low for START in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SdaFall))
                   |=> (gen_idle_i || (state_q == HoldStart)))
  else $error("scl_generator_timing_sva: SdaFall must enter HoldStart in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == HoldStart) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == HoldStart)))
  else $error("scl_generator_timing_sva: HoldStart must wait for t_hd_sta_i expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == HoldStart) && (tcount == '0))
                   |=> (gen_idle_i || (state_q == DriveLow)))
  else $error("scl_generator_timing_sva: START hold expiry must drive SCL low in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveLow) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == DriveLow)))
  else $error("scl_generator_timing_sva: DriveLow must wait for t_low_i+t_f_i expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveLow) && (tcount == '0) && gen_clock_i)
                   |=> (gen_idle_i || (state_q == DriveHigh)))
  else $error("scl_generator_timing_sva: DriveLow expiry must enter DriveHigh when clocking in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveLow) && (tcount == '0) && !gen_clock_i)
                   |=> (gen_idle_i || (state_q == WaitCmd)))
  else $error("scl_generator_timing_sva: DriveLow expiry must enter WaitCmd without clock request in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveHigh) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == DriveHigh)))
  else $error("scl_generator_timing_sva: DriveHigh must wait for t_high_i+t_r_i expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveHigh) && (tcount == '0) && gen_stop_i)
                   |=> (gen_idle_i || (state_q == GenerateStop)))
  else $error("scl_generator_timing_sva: DriveHigh expiry must service STOP before other requests in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveHigh) && (tcount == '0) && !gen_stop_i &&
                    gen_rstart_i)
                   |=> (gen_idle_i || (state_q == GenerateRstart)))
  else $error("scl_generator_timing_sva: DriveHigh expiry must service repeated START in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveHigh) && (tcount == '0) && !gen_stop_i &&
                    !gen_rstart_i && gen_clock_i)
                   |=> (gen_idle_i || (state_q == DriveLow)))
  else $error("scl_generator_timing_sva: DriveHigh expiry must continue clocking in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == DriveHigh) && (tcount == '0) && !gen_stop_i &&
                    !gen_rstart_i && !gen_clock_i)
                   |=> (gen_idle_i || (state_q == WaitCmd)))
  else $error("scl_generator_timing_sva: DriveHigh expiry must enter WaitCmd without request in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == WaitCmd) && gen_stop_i)
                   |=> (gen_idle_i || (state_q == GenerateStop)))
  else $error("scl_generator_timing_sva: WaitCmd must service STOP in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == WaitCmd) && !gen_stop_i && gen_rstart_i)
                   |=> (gen_idle_i || (state_q == GenerateRstart)))
  else $error("scl_generator_timing_sva: WaitCmd must service repeated START in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == WaitCmd) && !gen_stop_i && !gen_rstart_i &&
                    gen_clock_i)
                   |=> (gen_idle_i || (state_q == DriveLow)))
  else $error("scl_generator_timing_sva: WaitCmd must resume DriveLow when clocking in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == WaitCmd) && !gen_stop_i && !gen_rstart_i &&
                    !gen_clock_i)
                   |=> (gen_idle_i || (state_q == WaitCmd)))
  else $error("scl_generator_timing_sva: WaitCmd must hold SCL low without request in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateRstart) && !scl_i)
                   |=> (gen_idle_i || (state_q == GenerateRstart)))
  else $error("scl_generator_timing_sva: GenerateRstart must wait for SCL high feedback in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateRstart) && scl_i)
                   |=> (gen_idle_i || (state_q == SclHigh)))
  else $error("scl_generator_timing_sva: repeated START must enter SclHigh after SCL feedback in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SclHigh) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == SclHigh)))
  else $error("scl_generator_timing_sva: SclHigh must wait for repeated START setup expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SclHigh) && (tcount == '0))
                   |=> (gen_idle_i || (state_q == RstartSdaFall)))
  else $error("scl_generator_timing_sva: repeated START setup expiry must pull SDA low in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == RstartSdaFall))
                   |=> (gen_idle_i || (state_q == HoldStart)))
  else $error("scl_generator_timing_sva: RstartSdaFall must enter HoldStart in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateStop) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == GenerateStop)))
  else $error("scl_generator_timing_sva: GenerateStop must hold SCL low for STOP prep in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateStop) && (tcount == '0) && !scl_i)
                   |=> (gen_idle_i || (state_q == GenerateStop)))
  else $error("scl_generator_timing_sva: GenerateStop must wait for SCL high feedback in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == GenerateStop) && (tcount == '0) && scl_i)
                   |=> (gen_idle_i || (state_q == SclHighForStop)))
  else $error("scl_generator_timing_sva: STOP must enter SclHighForStop after SCL feedback in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SclHighForStop) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == SclHighForStop)))
  else $error("scl_generator_timing_sva: SclHighForStop must wait for t_su_sto_i expiry in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SclHighForStop) && (tcount == '0))
                   |=> (gen_idle_i || (state_q == SdaRise)))
  else $error("scl_generator_timing_sva: STOP setup expiry must release SDA high in %m");

  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == SdaRise))
                   |=> (gen_idle_i || (state_q == BusFree)))
  else $error("scl_generator_timing_sva: SdaRise must enter BusFree in %m");

  ap_bus_free_holds_until_expiry :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == BusFree) && (tcount != '0))
                   |=> (gen_idle_i || (state_q == BusFree)))
  else $error("scl_generator_timing_sva: BusFree must wait for t_bus_free_i expiry in %m");

  ap_bus_free_expires_to_idle :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == BusFree) && (tcount == '0))
                   |=> (gen_idle_i || (state_q == Idle)))
  else $error("scl_generator_timing_sva: BusFree expiry must return to Idle in %m");

  ap_no_start_rstart_during_bus_free :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (!gen_idle_i && (state_q == BusFree) && (tcount != '0) &&
                    (gen_start_i || gen_rstart_i))
                   |-> (state_d == BusFree))
  else $error("scl_generator_timing_sva: START/RSTART must not be accepted during BusFree in %m");

  cp_stop_release_loads_nonzero_bus_free :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == SdaRise) &&
                  load_tcount &&
                  (tcount_load_val == t_bus_free_i) &&
                  (t_bus_free_i != '0));

  cp_stop_bus_free_wait_to_idle :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == SdaRise) ##1
                  (state_q == BusFree) ##[1:$]
                  (state_q == Idle));

  cp_start_request_seen_during_bus_free_blocked :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (!gen_idle_i && (state_q == BusFree) && (tcount != '0) &&
                   (gen_start_i || gen_rstart_i) && (state_d == BusFree)));

endmodule
