module scl_generator #(
    parameter int CounterWidth = 20
) (
    input logic clk_i,
    input logic rst_ni,

    input logic gen_start_i,
    input logic gen_rstart_i,
    input logic gen_stop_i,
    input logic gen_clock_i,
    input logic gen_idle_i,
    input logic sel_i3c_i2c_i,  // informational; timing via CSR
    output logic done_o,
    output logic busy_o,
    output logic sda_ctrl_active_o,

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

    output logic scl_o,
    output logic sda_o
);

  typedef enum logic [3:0] {
    Idle           = 4'd0,
    GenerateStart  = 4'd1,
    SdaFall        = 4'd2,
    HoldStart      = 4'd3,
    DriveLow       = 4'd4,
    DriveHigh      = 4'd5,
    WaitCmd        = 4'd6,
    GenerateRstart = 4'd7,
    SclHigh        = 4'd8,
    RstartSdaFall  = 4'd9,
    GenerateStop   = 4'd10,
    SclHighForStop = 4'd11,
    SdaRise        = 4'd12,
    BusFree        = 4'd13
  } state_e;

  state_e state_q, state_d;

  logic [CounterWidth-1:0] tcount;
  logic                    load_tcount;
  logic [CounterWidth-1:0] tcount_load_val;
  logic [CounterWidth-1:0] active_t_low;

  logic                    tcount_expired;
  assign tcount_expired = (tcount == '0);
  assign active_t_low = scl_use_od_low_i ? t_low_od_i : t_low_i;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tcount
    if (!rst_ni) tcount <= '0;
    else if (load_tcount) tcount <= tcount_load_val;
    else if (!tcount_expired) tcount <= tcount - 1'b1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state
    if (!rst_ni) state_q <= Idle;
    else state_q <= state_d;
  end

  always_comb begin : update_tcount_load_value
    load_tcount     = 1'b0;
    tcount_load_val = '0;

    unique case (state_q)
      Idle: begin
        if (gen_start_i) begin
          load_tcount     = 1'b1;
          tcount_load_val = t_su_sta_i;
        end
      end

      GenerateRstart: begin
        if (scl_i) begin
          load_tcount     = 1'b1;
          tcount_load_val = t_su_sta_i;
        end
      end

      SdaFall, RstartSdaFall: begin
        load_tcount = 1'b1;
        tcount_load_val = t_hd_sta_i;
      end

      HoldStart: begin
        if (tcount_expired) begin
          load_tcount = 1'b1;
          tcount_load_val = active_t_low + t_f_i;
        end
      end

      WaitCmd: begin
        if (gen_stop_i || gen_clock_i) begin
          load_tcount     = 1'b1;
          tcount_load_val = active_t_low + t_f_i;
        end
      end

      DriveHigh: begin
        if (tcount_expired && (gen_stop_i || gen_clock_i)) begin
          load_tcount     = 1'b1;
          tcount_load_val = active_t_low + t_f_i;
        end
      end

      DriveLow: begin
        if (tcount_expired && gen_clock_i) begin
          load_tcount     = 1'b1;
          tcount_load_val = t_high_i + t_r_i;
        end
      end

      GenerateStop: begin
        if (tcount_expired && scl_i) begin
          load_tcount = 1'b1;
          tcount_load_val = t_su_sto_i;
        end
      end

      SdaRise: begin
        load_tcount     = 1'b1;
        tcount_load_val = t_bus_free_i;
      end

      default: ;
    endcase
  end

  always_comb begin : scl_fsm_state
    state_d = state_q;

    if (gen_idle_i) begin
      state_d = Idle;
    end else begin
      unique case (state_q)
        Idle: begin
          if (gen_start_i) begin
            state_d = GenerateStart;
          end else if (gen_rstart_i) begin
            state_d = GenerateRstart;
          end
        end

        GenerateStart: begin
          if (tcount_expired) state_d = SdaFall;
        end

        SdaFall: begin
          state_d = HoldStart;
        end

        HoldStart: begin
          if (tcount_expired) begin
            state_d = DriveLow;
          end
        end

        DriveLow: begin
          if (tcount_expired) begin
            if (gen_clock_i) begin
              state_d = DriveHigh;
            end else begin
              state_d = WaitCmd;
            end
          end
        end

        DriveHigh: begin
          if (tcount_expired) begin
            if (gen_stop_i) begin
              state_d = GenerateStop;
            end else if (gen_rstart_i) begin
              state_d = GenerateRstart;
            end else if (gen_clock_i) begin
              state_d = DriveLow;
            end else begin
              state_d = WaitCmd;
            end
          end
        end

        WaitCmd: begin
          if (gen_stop_i) begin
            state_d = GenerateStop;
          end else if (gen_rstart_i) begin
            state_d = GenerateRstart;
          end else if (gen_clock_i) begin
            state_d = DriveLow;
          end
        end

        GenerateRstart: begin
          if (scl_i) begin
            state_d = SclHigh;
          end
        end

        SclHigh: begin
          if (tcount_expired) state_d = RstartSdaFall;
        end

        RstartSdaFall: begin
          state_d = HoldStart;
        end

        GenerateStop: begin
          if (tcount_expired && scl_i) begin
            state_d = SclHighForStop;
          end
        end

        SclHighForStop: begin
          if (tcount_expired) state_d = SdaRise;
        end

        SdaRise: begin
          state_d = BusFree;
        end

        BusFree: begin
          if (tcount_expired) state_d = Idle;
        end

        default: state_d = Idle;

      endcase
    end
  end

  always_comb begin
    scl_o = 1'b1;
    sda_o = 1'b1;

    case (state_q)
      DriveLow, WaitCmd: scl_o = 1'b0;

      GenerateStop: begin
        sda_o = 1'b0;
        if (!tcount_expired) begin
          scl_o = 1'b0;
        end
      end

      SdaFall, HoldStart, RstartSdaFall, SclHighForStop: sda_o = 1'b0;

      default: ;
    endcase
  end

  assign done_o = ((state_d == DriveLow) && (state_q != DriveLow)) ||
                  ((state_q == BusFree) && (state_d == Idle));

  assign busy_o = (state_q != Idle);

  assign sda_ctrl_active_o = (state_q == GenerateStart)  |
                              (state_q == SdaFall)         |
                              (state_q == HoldStart)       |
                              (state_q == GenerateRstart)  |
                              (state_q == SclHigh)         |
                              (state_q == RstartSdaFall)   |
                              (state_q == GenerateStop)    |
                              (state_q == SclHighForStop)  |
                              (state_q == SdaRise);
endmodule
