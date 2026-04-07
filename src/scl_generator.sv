module scl_generator
  import i3c_pkg::*;
#(
  parameter int CounterWidth = 20
) (
  input  logic                        clk_i,
  input  logic                        rst_ni,

  input  logic                        gen_start_i,
  input  logic                        gen_rstart_i,
  input  logic                        gen_stop_i,
  input  logic                        gen_clock_i,
  input  logic                        gen_idle_i,
  input  logic                        sel_i3c_i2c_i,  // informational; timing via CSR
  output logic                        done_o,
  output logic                        busy_o,

  input  logic [CounterWidth-1:0]     t_low_i,
  input  logic [CounterWidth-1:0]     t_high_i,
  input  logic [CounterWidth-1:0]     t_su_sta_i,
  input  logic [CounterWidth-1:0]     t_hd_sta_i,
  input  logic [CounterWidth-1:0]     t_su_sto_i,
  input  logic [CounterWidth-1:0]     t_r_i,
  input  logic [CounterWidth-1:0]     t_f_i,

  input  logic                        scl_i,

  output logic                        scl_o,
  output logic                        sda_o
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
    SdaRise        = 4'd12
  } state_e;

  state_e state, next_state;

  logic [CounterWidth-1:0] tcount;
  logic                    load_tcount;
  logic [CounterWidth-1:0] tcount_load_val;

  wire tcount_expired = (tcount == '0);

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni)
      tcount <= '0;
    else if (load_tcount)
      tcount <= tcount_load_val;
    else if (!tcount_expired)
      tcount <= tcount - 1'b1;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) state <= Idle;
    else         state <= next_state;
  end

  always_comb begin
    next_state      = state;
    load_tcount     = 1'b0;
    tcount_load_val = '0;

    // gen_idle_i is a priority override from any state
    if (gen_idle_i) begin
      next_state = Idle;
    end else begin
      case (state)

        // -----------------------------------------------------------------
        Idle: begin
          if (gen_start_i) begin
            next_state      = GenerateStart;
            load_tcount     = 1'b1;
            tcount_load_val = t_su_sta_i;
          end else if (gen_rstart_i) begin
            // Rstart directly from idle (abnormal but handled)
            next_state = GenerateRstart;
          end
        end

        // Wait t_su_sta with SCL/SDA HIGH, then fall SDA
        GenerateStart: begin
          if (tcount_expired)
            next_state = SdaFall;
        end

        // 1-cycle state: SDA is now LOW — immediately load t_hd_sta
        SdaFall: begin
          next_state      = HoldStart;
          load_tcount     = 1'b1;
          tcount_load_val = t_hd_sta_i;
        end

        // Hold SDA LOW for t_hd_sta, then begin clocking
        HoldStart: begin
          if (tcount_expired) begin
            next_state      = DriveLow;
            load_tcount     = 1'b1;
            tcount_load_val = t_low_i + t_f_i;
          end
        end

        // SCL LOW for t_low + t_f
        DriveLow: begin
          if (tcount_expired) begin
            if (gen_clock_i) begin
              next_state      = DriveHigh;
              load_tcount     = 1'b1;
              tcount_load_val = t_high_i + t_r_i;
            end else begin
              next_state = WaitCmd;
            end
          end
        end

        // SCL HIGH for t_high + t_r; gen_stop/gen_rstart checked at expiry
        DriveHigh: begin
          if (tcount_expired) begin
            if (gen_stop_i) begin
              next_state = GenerateStop;
            end else if (gen_rstart_i) begin
              next_state = GenerateRstart;
            end else if (gen_clock_i) begin
              next_state      = DriveLow;
              load_tcount     = 1'b1;
              tcount_load_val = t_low_i + t_f_i;
            end else begin
              // No command ready — hold SCL LOW until flow_active responds
              next_state = WaitCmd;
            end
          end
        end

        // SCL held LOW; wait for the next command
        WaitCmd: begin
          if (gen_stop_i) begin
            next_state = GenerateStop;
          end else if (gen_clock_i) begin
            next_state      = DriveLow;
            load_tcount     = 1'b1;
            tcount_load_val = t_low_i + t_f_i;
          end
        end

        // Release SDA+SCL HIGH; wait for SCL to be confirmed HIGH on bus
        GenerateRstart: begin
          if (scl_i) begin
            next_state      = SclHigh;
            load_tcount     = 1'b1;
            tcount_load_val = t_su_sta_i;
          end
        end

        // Wait t_su_sta with SCL/SDA HIGH before pulling SDA LOW for Sr
        SclHigh: begin
          if (tcount_expired)
            next_state = RstartSdaFall;
        end

        // 1-cycle state: SDA falls for Sr — load t_hd_sta
        RstartSdaFall: begin
          next_state      = HoldStart;
          load_tcount     = 1'b1;
          tcount_load_val = t_hd_sta_i;
        end

        // SDA LOW, release SCL; wait for SCL confirmed HIGH on bus
        GenerateStop: begin
          if (scl_i) begin
            next_state      = SclHighForStop;
            load_tcount     = 1'b1;
            tcount_load_val = t_su_sto_i;
          end
        end

        // SCL HIGH, SDA LOW; hold for t_su_sto then rise SDA
        SclHighForStop: begin
          if (tcount_expired)
            next_state = SdaRise;
        end

        // 1-cycle state: SDA released HIGH (STOP complete) → back to Idle
        SdaRise: begin
          next_state = Idle;
        end

        default: next_state = Idle;

      endcase
    end
  end

  always_comb begin
    scl_o = 1'b1;  // default: release HIGH (open-drain)
    sda_o = 1'b1;  // default: release HIGH

    case (state)
      DriveLow, WaitCmd:
        scl_o = 1'b0;

      SdaFall, HoldStart, RstartSdaFall,
      GenerateStop, SclHighForStop:
        sda_o = 1'b0;

      default: ;
    endcase
  end

  assign done_o = ((next_state == DriveLow) && (state != DriveLow)) ||
                  ((state == SdaRise) && (next_state == Idle));

  assign busy_o = (state != Idle);

endmodule
