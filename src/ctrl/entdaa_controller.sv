module entdaa_controller
  import i3c_pkg::*;
  import controller_pkg::*;
#(
  parameter int DatDepth = 16,
  localparam int unsigned DatAw = $clog2(DatDepth)
) (
  input logic clk_i,
  input logic rst_ni,

  input logic ccc_valid_i,
  input logic [3:0] dev_count_i,
  input logic [4:0] dev_idx_i,
  output logic done_o,

  output logic req_restart_o,

  input logic bus_tx_done_i,
  input logic bus_tx_idle_i,
  output logic bus_tx_req_byte_o,
  output logic bus_tx_req_bit_o,
  output logic [7:0] bus_tx_req_value_o,
  output logic bus_tx_sel_od_pp_o,

  input logic [7:0] bus_rx_data_i,
  input logic bus_rx_done_i,
  output logic bus_rx_req_bit_o,
  output logic bus_rx_req_byte_o,

  input logic bus_start_det_i,
  input logic bus_rstart_det_i,
  input logic bus_stop_det_i,

  output logic dat_read_valid_o,
  output logic [DatAw-1:0] dat_index_o,
  input logic [31:0] dat_rdata_i,

  output logic [6:0] daa_address_o,
  output logic daa_address_valid_o,
  output logic [47:0] daa_pid_o,
  output logic [7:0] daa_bcr_o,
  output logic [7:0] daa_dcr_o
);

  typedef enum logic [2:0] {
    Idle           = 3'd0,
    StartLoop      = 3'd1,
    RequestRestart = 3'd2,
    WaitRestart    = 3'd3,
    ReadDAT        = 3'd4,
    RunEntdaa      = 3'd5,
    Done           = 3'd6
  } state_e;

  state_e state_q, state_d;
  logic [3:0] dev_round_q, dev_round_d;
  logic [6:0] daa_addr_q, daa_addr_d;

  logic start_daa;
  logic done_daa;
  logic addr_valid;
  logic no_device;
  logic [47:0] pid;
  logic [7:0] bcr;
  logic [7:0] dcr;

  logic entdaa_tx_req_byte;
  logic entdaa_tx_req_bit;
  logic [7:0] entdaa_tx_req_value;
  logic entdaa_tx_sel_od_pp;
  logic entdaa_rx_req_bit;
  logic entdaa_rx_req_byte;

  entdaa_fsm u_entdaa_fsm (
    .clk_i,
    .rst_ni,
    .start_daa_i     (start_daa),
    .daa_addr_i      (daa_addr_q),
    .done_daa_o      (done_daa),
    .addr_valid_o    (addr_valid),
    .no_device_o     (no_device),
    .pid_o           (pid),
    .bcr_o           (bcr),
    .dcr_o           (dcr),
    .bus_rx_data_i,
    .bus_rx_done_i,
    .bus_rx_req_bit_o  (entdaa_rx_req_bit),
    .bus_rx_req_byte_o (entdaa_rx_req_byte),
    .bus_tx_done_i,
    .bus_tx_req_byte_o (entdaa_tx_req_byte),
    .bus_tx_req_bit_o  (entdaa_tx_req_bit),
    .bus_tx_req_value_o(entdaa_tx_req_value),
    .bus_tx_sel_od_pp_o(entdaa_tx_sel_od_pp),
    .bus_stop_det_i
  );

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      state_q <= Idle;
      dev_round_q <= 4'h0;
      daa_addr_q <= 7'h0;
    end else begin
      state_q <= state_d;
      dev_round_q <= dev_round_d;
      daa_addr_q <= daa_addr_d;
    end
  end

  always_comb begin
    state_d = state_q;
    dev_round_d = dev_round_q;
    daa_addr_d = daa_addr_q;

    if (bus_stop_det_i && state_q != Idle && state_q != Done) begin
      state_d = Done;
    end else begin
      unique case (state_q)
        Idle: begin
          if (ccc_valid_i) begin
            dev_round_d = 4'h0;
            state_d = StartLoop;
          end
        end

        StartLoop: begin
          if (dev_round_q < dev_count_i) begin
            state_d = RequestRestart;
          end else begin
            state_d = Done;
          end
        end

        RequestRestart: begin
          state_d = WaitRestart;
        end

        WaitRestart: begin
          if (bus_rstart_det_i) begin
            state_d = ReadDAT;
          end
        end

        ReadDAT: begin
          state_d = RunEntdaa;
        end

        RunEntdaa: begin
          if (done_daa) begin
            if (addr_valid) begin
              dev_round_d = dev_round_q + 1'b1;
              state_d = StartLoop;
            end else if (no_device) begin
              state_d = Done;
            end
          end
        end

        Done: begin
          state_d = Idle;
        end

        default: ;
      endcase
    end
  end

  always_comb begin
    dat_read_valid_o = 1'b0;
    dat_index_o = '0;
    req_restart_o = 1'b0;
    start_daa = 1'b0;
    done_o = 1'b0;
    daa_address_o = 7'h0;
    daa_address_valid_o = 1'b0;
    daa_pid_o = 48'h0;
    daa_bcr_o = 8'h0;
    daa_dcr_o = 8'h0;

    unique case (state_q)
      Idle: begin
      end

      StartLoop: begin
      end

      RequestRestart: begin
        req_restart_o = 1'b1;
      end

      WaitRestart: begin
        dat_read_valid_o = 1'b1;
        if ((dev_idx_i + dev_round_q) >= DatDepth) begin
          dat_index_o = DatDepth - 1;
        end else begin
          dat_index_o = dev_idx_i[DatAw-1:0] + dev_round_q[DatAw-1:0];
        end
      end

      ReadDAT: begin
        dat_entry_t entry;
        entry = dat_entry_t'(dat_rdata_i);
        daa_addr_d = entry.dynamic_address;
      end

      RunEntdaa: begin
        start_daa = 1'b1;
        if (done_daa && addr_valid) begin
          daa_address_valid_o = 1'b1;
          daa_address_o = daa_addr_q;
          daa_pid_o = pid;
          daa_bcr_o = bcr;
          daa_dcr_o = dcr;
        end
      end

      Done: begin
        done_o = 1'b1;
      end

      default: ;
    endcase
  end

  always_comb begin
    if (state_q == RunEntdaa) begin
      bus_tx_req_byte_o  = entdaa_tx_req_byte;
      bus_tx_req_bit_o   = entdaa_tx_req_bit;
      bus_tx_req_value_o = entdaa_tx_req_value;
      bus_tx_sel_od_pp_o = entdaa_tx_sel_od_pp;
      bus_rx_req_bit_o   = entdaa_rx_req_bit;
      bus_rx_req_byte_o  = entdaa_rx_req_byte;
    end else begin
      bus_tx_req_byte_o  = 1'b0;
      bus_tx_req_bit_o   = 1'b0;
      bus_tx_req_value_o = 8'h00;
      bus_tx_sel_od_pp_o = 1'b0;
      bus_rx_req_bit_o   = 1'b0;
      bus_rx_req_byte_o  = 1'b0;
    end
  end

endmodule
