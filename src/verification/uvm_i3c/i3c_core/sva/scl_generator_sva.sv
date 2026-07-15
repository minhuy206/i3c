module scl_generator_sva #(
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
    input logic sda_ctrl_active_o,

    input logic scl_use_od_low_i,
    input logic [CounterWidth-1:0] t_r_i,
    input logic [CounterWidth-1:0] t_f_i,
    input logic [CounterWidth-1:0] t_low_i,
    input logic [CounterWidth-1:0] t_low_od_i,
    input logic [CounterWidth-1:0] t_high_i,
    input logic [CounterWidth-1:0] t_su_sta_i,
    input logic [CounterWidth-1:0] t_hd_sta_i,
    input logic [CounterWidth-1:0] t_su_sto_i,
    input logic [CounterWidth-1:0] t_bus_free_i,
    input logic [CounterWidth-1:0] active_t_low_i,

    input logic scl_i,
    input logic scl_o,
    input logic sda_o,

    input logic [3:0] state_q,
    input logic [3:0] state_d,
    input logic [CounterWidth-1:0] tcount_load_val,
    input logic load_tcount,
    input logic tcount_expired
);

  localparam logic [3:0] StateIdle              = 4'd0;
  localparam logic [3:0] StateGenerateStart     = 4'd1;
  localparam logic [3:0] StateSdaFall           = 4'd2;
  localparam logic [3:0] StateHoldStart         = 4'd3;
  localparam logic [3:0] StateDriveLow          = 4'd4;
  localparam logic [3:0] StateDriveHigh         = 4'd5;
  localparam logic [3:0] StateWaitCmd           = 4'd6;
  localparam logic [3:0] StateGenerateRstart    = 4'd7;
  localparam logic [3:0] StateSclHighForRstart  = 4'd8;
  localparam logic [3:0] StateGenerateStop      = 4'd9;
  localparam logic [3:0] StateSclHighForStop    = 4'd10;
  localparam logic [3:0] StateSdaRise           = 4'd11;
  localparam logic [3:0] StateBusFree           = 4'd12;

  logic [CounterWidth-1:0] low_fall_delay;
  logic [CounterWidth-1:0] high_rise_delay;
  logic                    bus006_start_req;
  logic                    bus006_waitcmd_stop_req;
  logic                    bus006_drivelow_stop_req;
  logic                    bus006_drivehigh_stop_req;
  logic                    bus006_stop_req;
  logic                    bus007_drivelow_clock_req;
  logic                    bus007_drivehigh_clock_req;
  logic                    bus008_waitcmd_no_cmd;
  logic                    bus008_waitcmd_clock_resume;
  logic                    bus009_waitcmd_rstart_req;

  assign low_fall_delay = active_t_low_i + t_f_i;
  assign high_rise_delay = t_high_i + t_r_i;
  assign bus006_start_req = (state_q == StateIdle) && gen_start_i && !gen_idle_i;
  assign bus006_waitcmd_stop_req =
      (state_q == StateWaitCmd) && gen_stop_i && !gen_rstart_i && !gen_idle_i;
  assign bus006_drivelow_stop_req =
      (state_q == StateDriveLow) && tcount_expired && gen_stop_i && !gen_idle_i;
  assign bus006_drivehigh_stop_req =
      (state_q == StateDriveHigh) && tcount_expired && gen_stop_i && !gen_rstart_i &&
      !gen_idle_i;
  assign bus006_stop_req =
      bus006_waitcmd_stop_req || bus006_drivelow_stop_req || bus006_drivehigh_stop_req;
  assign bus007_drivelow_clock_req =
      (state_q == StateDriveLow) && tcount_expired && gen_clock_i && !gen_rstart_i &&
      !gen_stop_i && !gen_idle_i;
  assign bus007_drivehigh_clock_req =
      (state_q == StateDriveHigh) && tcount_expired && gen_clock_i && !gen_rstart_i &&
      !gen_stop_i && !gen_idle_i;
  assign bus008_waitcmd_no_cmd =
      (state_q == StateWaitCmd) && !gen_clock_i && !gen_rstart_i && !gen_stop_i &&
      !gen_idle_i;
  assign bus008_waitcmd_clock_resume =
      (state_q == StateWaitCmd) && gen_clock_i && !gen_rstart_i && !gen_stop_i &&
      !gen_idle_i;
  assign bus009_waitcmd_rstart_req =
      (state_q == StateWaitCmd) && gen_rstart_i && !gen_stop_i && !gen_idle_i;

  // BUS_006: START and STOP are generated on nearly every real transaction, so
  // no dedicated force-based vseq is required. These assertions check the local
  // scl_generator sequence and counter loads whenever existing traffic exercises
  // START/STOP.
  ap_bus006_start_req_enters_generate_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus006_start_req |-> (state_d == StateGenerateStart))
  else $error("scl_generator_sva: BUS_006 START request did not enter GenerateStart in %m");

  cp_bus006_start_req_enters_generate_start :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus006_start_req ##1 (state_q == StateGenerateStart));

  ap_bus006_start_req_loads_setup_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus006_start_req
                   |-> (load_tcount && (tcount_load_val == t_su_sta_i)))
  else $error("scl_generator_sva: BUS_006 START request did not load t_su_sta_i in %m");

  cp_bus006_start_req_loads_setup_start :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus006_start_req && load_tcount && (tcount_load_val == t_su_sta_i));

  ap_bus006_generate_start_releases_scl_sda :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateStart)
                   |-> (scl_o && sda_o && sda_ctrl_active_o && !done_o))
  else $error("scl_generator_sva: BUS_006 GenerateStart did not release SCL/SDA in %m");

  cp_bus006_generate_start_releases_scl_sda :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateStart) && scl_o && sda_o &&
                  sda_ctrl_active_o && !done_o);

  ap_bus006_generate_start_expires_to_sda_fall :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateStart) && tcount_expired && !gen_idle_i
                   |-> (state_d == StateSdaFall))
  else $error("scl_generator_sva: BUS_006 GenerateStart did not transition to SdaFall in %m");

  cp_bus006_generate_start_expires_to_sda_fall :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateStart) && tcount_expired && !gen_idle_i
                  ##1 (state_q == StateSdaFall));

  ap_bus006_sda_fall_drives_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSdaFall)
                   |-> (scl_o && !sda_o && sda_ctrl_active_o && !done_o))
  else $error("scl_generator_sva: BUS_006 SdaFall did not drive START condition in %m");

  cp_bus006_sda_fall_drives_start :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSdaFall) && scl_o && !sda_o &&
                  sda_ctrl_active_o && !done_o);

  ap_bus006_sda_fall_loads_hold_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSdaFall) && !gen_idle_i
                   |-> (load_tcount && (tcount_load_val == t_hd_sta_i) &&
                        (state_d == StateHoldStart)))
  else $error("scl_generator_sva: BUS_006 SdaFall did not load t_hd_sta_i in %m");

  cp_bus006_sda_fall_loads_hold_start :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSdaFall) && !gen_idle_i && load_tcount &&
                  (tcount_load_val == t_hd_sta_i) ##1 (state_q == StateHoldStart));

  ap_bus006_hold_start_drives_start_hold :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateHoldStart)
                   |-> (scl_o && !sda_o && sda_ctrl_active_o))
  else $error("scl_generator_sva: BUS_006 HoldStart did not hold START condition in %m");

  cp_bus006_hold_start_drives_start_hold :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateHoldStart) && scl_o && !sda_o && sda_ctrl_active_o);

  ap_bus006_hold_start_expires_to_drivelow :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateHoldStart) && tcount_expired && !gen_idle_i
                   |-> (state_d == StateDriveLow && done_o && load_tcount &&
                        (tcount_load_val == low_fall_delay)))
  else $error("scl_generator_sva: BUS_006 HoldStart did not finish START with low/fall delay in %m");

  cp_bus006_hold_start_expires_to_drivelow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateHoldStart) && tcount_expired && !gen_idle_i &&
                  done_o && load_tcount && (tcount_load_val == low_fall_delay)
                  ##1 (state_q == StateDriveLow));

  ap_bus006_stop_req_enters_generate_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus006_stop_req |-> (state_d == StateGenerateStop))
  else $error("scl_generator_sva: BUS_006 STOP request did not enter GenerateStop in %m");

  cp_bus006_stop_req_enters_generate_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus006_stop_req ##1 (state_q == StateGenerateStop));

  ap_bus006_stop_req_loads_low_delay :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus006_stop_req
                   |-> (load_tcount && (tcount_load_val == low_fall_delay)))
  else $error("scl_generator_sva: BUS_006 STOP request did not load low/fall delay in %m");

  cp_bus006_stop_req_loads_low_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus006_stop_req && load_tcount && (tcount_load_val == low_fall_delay));

  ap_bus006_generate_stop_holds_sda_low :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateStop)
                   |-> (!sda_o && sda_ctrl_active_o && (tcount_expired || !scl_o)))
  else $error("scl_generator_sva: BUS_006 GenerateStop did not hold SDA low before STOP in %m");

  cp_bus006_generate_stop_holds_sda_low :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateStop) && !sda_o && sda_ctrl_active_o &&
                  (tcount_expired || !scl_o));

  ap_bus006_generate_stop_scl_high_loads_setup_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateStop) && tcount_expired && scl_i && !gen_idle_i
                   |-> (state_d == StateSclHighForStop && load_tcount &&
                        (tcount_load_val == t_su_sto_i)))
  else $error("scl_generator_sva: BUS_006 GenerateStop did not load t_su_sto_i in %m");

  cp_bus006_generate_stop_scl_high_loads_setup_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateStop) && tcount_expired && scl_i && !gen_idle_i &&
                  load_tcount && (tcount_load_val == t_su_sto_i)
                  ##1 (state_q == StateSclHighForStop));

  ap_bus006_scl_high_for_stop_holds_stop_setup :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSclHighForStop)
                   |-> (scl_o && !sda_o && sda_ctrl_active_o))
  else $error("scl_generator_sva: BUS_006 SclHighForStop did not hold STOP setup in %m");

  cp_bus006_scl_high_for_stop_holds_stop_setup :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSclHighForStop) && scl_o && !sda_o &&
                  sda_ctrl_active_o);

  ap_bus006_scl_high_for_stop_expires_to_sda_rise :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSclHighForStop) && tcount_expired && !gen_idle_i
                   |-> (state_d == StateSdaRise))
  else $error("scl_generator_sva: BUS_006 SclHighForStop did not transition to SdaRise in %m");

  cp_bus006_scl_high_for_stop_expires_to_sda_rise :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSclHighForStop) && tcount_expired && !gen_idle_i
                  ##1 (state_q == StateSdaRise));

  ap_bus006_sda_rise_drives_stop :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSdaRise) && !gen_idle_i
                   |-> (scl_o && sda_o && sda_ctrl_active_o && load_tcount &&
                        (tcount_load_val == t_bus_free_i) && (state_d == StateBusFree)))
  else $error("scl_generator_sva: BUS_006 SdaRise did not drive STOP and load bus-free delay in %m");

  cp_bus006_sda_rise_drives_stop :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSdaRise) && !gen_idle_i && scl_o && sda_o && sda_ctrl_active_o &&
                  load_tcount && (tcount_load_val == t_bus_free_i)
                  ##1 (state_q == StateBusFree));

  ap_bus006_bus_free_expires_to_idle :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateBusFree) && tcount_expired && !gen_idle_i
                   |-> (state_d == StateIdle && done_o && scl_o && sda_o &&
                        !sda_ctrl_active_o))
  else $error("scl_generator_sva: BUS_006 BusFree did not finish STOP into Idle in %m");

  cp_bus006_bus_free_expires_to_idle :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateBusFree) && tcount_expired && !gen_idle_i &&
                  done_o && scl_o && sda_o && !sda_ctrl_active_o
                  ##1 (state_q == StateIdle));

  // BUS_007: generated clock timing must use the programmed low/high timing
  // values. The vseq sweeps CSR profiles; these assertions check the
  // scl_generator counter loads that produce SCL low/high periods.
  ap_bus007_pp_low_selects_t_low :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   !scl_use_od_low_i |-> (active_t_low_i == t_low_i))
  else $error("scl_generator_sva: BUS_007 PP low mode did not select t_low_i in %m");

  cp_bus007_pp_low_selects_t_low :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  !scl_use_od_low_i && (active_t_low_i == t_low_i));

  ap_bus007_od_low_selects_t_low_od :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   scl_use_od_low_i |-> (active_t_low_i == t_low_od_i))
  else $error("scl_generator_sva: BUS_007 OD low mode did not select t_low_od_i in %m");

  cp_bus007_od_low_selects_t_low_od :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  scl_use_od_low_i && (active_t_low_i == t_low_od_i));

  ap_bus007_drivelow_clock_enters_drivehigh :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus007_drivelow_clock_req |-> (state_d == StateDriveHigh))
  else $error("scl_generator_sva: BUS_007 DriveLow clock request did not enter DriveHigh in %m");

  cp_bus007_drivelow_clock_enters_drivehigh :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus007_drivelow_clock_req ##1 (state_q == StateDriveHigh));

  ap_bus007_drivelow_clock_loads_high_delay :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus007_drivelow_clock_req
                   |-> (load_tcount && (tcount_load_val == high_rise_delay)))
  else $error("scl_generator_sva: BUS_007 DriveLow clock request did not load high/rise delay in %m");

  cp_bus007_drivelow_clock_loads_high_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus007_drivelow_clock_req && load_tcount &&
                  (tcount_load_val == high_rise_delay));

  ap_bus007_drivehigh_clock_enters_drivelow :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus007_drivehigh_clock_req |-> (state_d == StateDriveLow))
  else $error("scl_generator_sva: BUS_007 DriveHigh clock request did not enter DriveLow in %m");

  cp_bus007_drivehigh_clock_enters_drivelow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus007_drivehigh_clock_req ##1 (state_q == StateDriveLow));

  ap_bus007_drivehigh_clock_loads_low_delay :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus007_drivehigh_clock_req
                   |-> (load_tcount && (tcount_load_val == low_fall_delay)))
  else $error("scl_generator_sva: BUS_007 DriveHigh clock request did not load low/fall delay in %m");

  cp_bus007_drivehigh_clock_loads_pp_low_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus007_drivehigh_clock_req && !scl_use_od_low_i && load_tcount &&
                  (tcount_load_val == low_fall_delay));

  cp_bus007_drivehigh_clock_loads_od_low_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus007_drivehigh_clock_req && scl_use_od_low_i && load_tcount &&
                  (tcount_load_val == low_fall_delay));

  // BUS_008: with no next bus command, WaitCmd intentionally parks SCL low.
  // The generator must stay there until higher-level control requests clock,
  // STOP, repeated START, or idle.
  ap_bus008_waitcmd_no_cmd_stays_waitcmd :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus008_waitcmd_no_cmd |-> (state_d == StateWaitCmd))
  else $error("scl_generator_sva: BUS_008 WaitCmd did not hold state with no command in %m");

  cp_bus008_waitcmd_no_cmd_stays_waitcmd :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus008_waitcmd_no_cmd ##1 (state_q == StateWaitCmd));

  ap_bus008_waitcmd_no_cmd_holds_scl_low :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus008_waitcmd_no_cmd
                   |-> (!scl_o && sda_o && !sda_ctrl_active_o && !done_o))
  else $error("scl_generator_sva: BUS_008 WaitCmd did not park SCL low with SDA released in %m");

  cp_bus008_waitcmd_no_cmd_holds_scl_low :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus008_waitcmd_no_cmd && !scl_o && sda_o && !sda_ctrl_active_o &&
                  !done_o);

  ap_bus008_waitcmd_clock_resume_enters_drivelow :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus008_waitcmd_clock_resume |-> (state_d == StateDriveLow))
  else $error("scl_generator_sva: BUS_008 WaitCmd clock resume did not enter DriveLow in %m");

  cp_bus008_waitcmd_clock_resume_enters_drivelow :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus008_waitcmd_clock_resume ##1 (state_q == StateDriveLow));

  ap_bus008_waitcmd_clock_resume_loads_low_delay :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus008_waitcmd_clock_resume
                   |-> (load_tcount && (tcount_load_val == low_fall_delay)))
  else $error("scl_generator_sva: BUS_008 WaitCmd clock resume did not load the low/fall delay in %m");

  cp_bus008_waitcmd_clock_resume_loads_low_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus008_waitcmd_clock_resume && load_tcount &&
                  (tcount_load_val == low_fall_delay));

  // BUS_009: a Repeated START request while SCL is parked low in WaitCmd must
  // be serviced immediately by the restart path, not missed or treated as an
  // ordinary clock resume.
  ap_bus009_waitcmd_rstart_enters_generate_rstart :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus009_waitcmd_rstart_req |=> (state_q == StateGenerateRstart))
  else $error("scl_generator_sva: BUS_009 WaitCmd rstart request did not enter GenerateRstart in %m");

  cp_bus009_waitcmd_to_rstart :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus009_waitcmd_rstart_req ##1 (state_q == StateGenerateRstart));

  ap_bus009_waitcmd_rstart_loads_low_delay :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   bus009_waitcmd_rstart_req
                   |-> (load_tcount && (tcount_load_val == low_fall_delay)))
  else $error("scl_generator_sva: BUS_009 WaitCmd rstart did not load the low/fall delay in %m");

  cp_bus009_waitcmd_rstart_loads_low_delay :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  bus009_waitcmd_rstart_req && load_tcount &&
                  (tcount_load_val == low_fall_delay));

  ap_bus009_generate_rstart_holds_scl_low :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateRstart) && !tcount_expired
                   |-> (!scl_o && sda_o && sda_ctrl_active_o))
  else $error("scl_generator_sva: BUS_009 GenerateRstart did not hold SCL low with SDA released in %m");

  cp_bus009_generate_rstart_holds_scl_low :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateRstart) && !tcount_expired &&
                  !scl_o && sda_o && sda_ctrl_active_o);

  ap_bus009_scl_high_for_rstart_releases_scl :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSclHighForRstart)
                   |-> (scl_o && sda_o && sda_ctrl_active_o))
  else $error("scl_generator_sva: BUS_009 SclHighForRstart did not release SCL/SDA before Sr edge in %m");

  cp_bus009_scl_high_for_rstart_releases_scl :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSclHighForRstart) &&
                  scl_o && sda_o && sda_ctrl_active_o);

  ap_bus009_scl_high_for_rstart_expires_to_sda_fall :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateSclHighForRstart) && tcount_expired && !gen_idle_i
                   |-> (state_d == StateSdaFall))
  else $error("scl_generator_sva: BUS_009 SclHighForRstart did not transition to SdaFall in %m");

  cp_bus009_scl_high_for_rstart_to_sda_fall :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateSclHighForRstart) && tcount_expired && !gen_idle_i
                  ##1 (state_q == StateSdaFall) && scl_o && !sda_o &&
                  sda_ctrl_active_o);

  ap_rstart_state_sequence :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q == StateGenerateRstart && tcount_expired && scl_i)
                   |-> (state_d == StateSclHighForRstart))
  else $error("scl_generator_sva: GenerateRstart did not transition to SclHighForRstart when ready in %m");

  cp_rstart_waits_for_scl_high :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateRstart && tcount_expired && !scl_i)
                  ##1 (state_q == StateGenerateRstart));

  cp_rstart_state_sequence :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q == StateGenerateRstart && tcount_expired && scl_i)
                  ##1 (state_q == StateSclHighForRstart)
                  ##[1:$] (state_q == StateSdaFall));

  ap_rstart_state_done_only_after_hold_start :
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   (state_q inside {StateDriveLow, StateWaitCmd, StateGenerateRstart,
                                    StateSclHighForRstart, StateSdaFall})
                   |-> !done_o)
  else $error("scl_generator_sva: restart path asserted done_o before HoldStart completion in %m");

  cp_rstart_state_done_only_after_hold_start :
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  (state_q inside {StateGenerateRstart, StateSclHighForRstart,
                                   StateSdaFall}) && !done_o);

endmodule

bind scl_generator scl_generator_sva #(
    .CounterWidth(CounterWidth)
) u_scl_generator_sva (
    .clk_i,
    .rst_ni,
    .gen_start_i,
    .gen_rstart_i,
    .gen_stop_i,
    .gen_clock_i,
    .gen_idle_i,
    .done_o,
    .sda_ctrl_active_o,
    .scl_use_od_low_i,
    .t_r_i,
    .t_f_i,
    .t_low_i,
    .t_low_od_i,
    .t_high_i,
    .t_su_sta_i,
    .t_hd_sta_i,
    .t_su_sto_i,
    .t_bus_free_i,
    .active_t_low_i(active_t_low),
    .scl_i,
    .scl_o,
    .sda_o,
    .state_q,
    .state_d,
    .tcount_load_val,
    .load_tcount,
    .tcount_expired
);
