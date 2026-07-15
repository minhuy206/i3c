module entdaa_fsm
  import controller_pkg::Read, i3c_pkg::I3C_RSVD_ADDR;
(
    input logic clk_i,
    input logic rst_ni,

    input logic start_i,
    input logic [6:0] addr_i,
    output logic done_o,
    output logic addr_valid_o,
    output logic no_device_o,
    output logic req_stop_o,
    input logic stop_pending_i,
    output logic stopped_o,

    output logic [47:0] pid_o,
    output logic [ 7:0] bcr_o,
    output logic [ 7:0] dcr_o,

    // Bus RX interface
    input logic [7:0] bus_rx_data_i,
    input logic bus_rx_done_i,
    output logic bus_rx_req_bit_o,
    output logic bus_rx_req_bit_handoff_o,
    output logic bus_rx_req_byte_o,

    // Bus TX interface
    input logic bus_tx_done_i,
    output logic bus_tx_req_byte_o,
    output logic bus_tx_req_bit_o,
    output logic [7:0] bus_tx_req_value_o,
    output logic bus_tx_sel_od_pp_o,

    // Bus Monitor interface
  input logic bus_stop_det_i
);
  typedef enum logic [2:0] {
    Idle             = 3'd0,
    SendDAAHeader    = 3'd1,
    ReceiveHeaderACK = 3'd2,
    ReceiveID        = 3'd3,
    SendDynamicAddr  = 3'd4,
    ReceiveAddrACK   = 3'd5,
    WaitStop         = 3'd6,
    Done             = 3'd7
  } state_e;

  state_e state_q, state_d;
  logic [63:0] id_shift_q, id_shift_d;
  logic [5:0] bit_cnt_q, bit_cnt_d;
  logic bus_tx_req_byte;
  logic bus_tx_sel_od_pp;
  logic [7:0] bus_tx_req_value;
  logic bus_rx_req_bit;
  logic bus_rx_req_bit_handoff;
  logic parity;
  logic addr_valid_q, addr_valid_d;
  logic no_device_q, no_device_d;
  logic stopped_q, stopped_d;
  logic done_daa;
  logic no_device;
  logic req_stop;
  logic stopped;
  logic [47:0] pid;
  logic [7:0] bcr;
  logic [7:0] dcr;

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_state
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_bit
    if (!rst_ni) begin
      id_shift_q <= '0;
      bit_cnt_q  <= '0;
    end else begin
      id_shift_q <= id_shift_d;
      bit_cnt_q  <= bit_cnt_d;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_result
    if (!rst_ni) begin
      addr_valid_q <= 1'b0;
      no_device_q  <= 1'b0;
      stopped_q    <= 1'b0;
    end else begin
      addr_valid_q <= addr_valid_d;
      no_device_q  <= no_device_d;
      stopped_q    <= stopped_d;
    end
  end


  always_comb begin : drive_data_and_outputs
    bus_tx_req_byte = '0;
    bus_tx_sel_od_pp = '0;
    bus_tx_req_value = '0;
    bus_rx_req_bit = '0;
    bus_rx_req_bit_handoff = '0;
    parity = 1'b0;
    done_daa = '0;
    no_device = '0;
    req_stop = '0;
    stopped = '0;
    pid = '0;
    bcr = '0;
    dcr = '0;
    id_shift_d   = id_shift_q;
    bit_cnt_d    = bit_cnt_q;
    addr_valid_d = addr_valid_q;
    no_device_d  = no_device_q;
    stopped_d    = stopped_q;

    unique case (state_q)
      Idle: begin
        if (start_i) begin
          id_shift_d   = 64'b0;
          bit_cnt_d    = 6'd63;
          addr_valid_d = 1'b0;
          no_device_d  = 1'b0;
          stopped_d    = 1'b0;
        end
      end

      SendDAAHeader: begin
        bus_tx_req_value = {I3C_RSVD_ADDR, Read};
        bus_tx_req_byte  = 1;
        bus_tx_sel_od_pp = 1'b0;
      end

      ReceiveHeaderACK: begin
        bus_rx_req_bit = 1'b1;
        if (bus_rx_done_i) begin
          no_device_d = bus_rx_data_i[0];
        end
      end

      ReceiveID: begin
        bus_rx_req_bit = 1'b1;
        if (bus_rx_done_i) begin
          id_shift_d = {id_shift_q[62:0], bus_rx_data_i[0]};
          if (bit_cnt_q != 0) bit_cnt_d = bit_cnt_q - 1;
        end
      end

      SendDynamicAddr: begin
        parity = ~^addr_i;
        bus_tx_req_byte = 1'b1;
        bus_tx_req_value = {addr_i, parity};
        bus_tx_sel_od_pp = 1'b0;
      end

      ReceiveAddrACK: begin
        bus_rx_req_bit_handoff = 1'b1;
        if (bus_rx_done_i) begin
          addr_valid_d = ~bus_rx_data_i[0];
        end
      end

      Done: begin
        done_daa     = 1'b1;
        no_device    = no_device_q;
        stopped      = stopped_q;
        addr_valid_d = addr_valid_q;
        pid          = id_shift_q[63:16];
        bcr          = id_shift_q[15:8];
        dcr          = id_shift_q[7:0];
      end

      WaitStop: begin
        req_stop = 1'b1;
      end

      default: ;
    endcase

    if (bus_stop_det_i && state_q != Idle && state_q != Done) begin
      stopped_d = 1'b1;
    end
  end

  always_comb begin : compute_next_state
    state_d = state_q;
    if (bus_stop_det_i && state_q != Idle && state_q != Done) begin
      state_d = Done;
    end else begin
      unique case (state_q)
        Idle: begin
          if (start_i) begin
            state_d = SendDAAHeader;
          end
        end

        SendDAAHeader: begin
          if (bus_tx_done_i) begin
            state_d = ReceiveHeaderACK;
          end
        end

        ReceiveHeaderACK: begin
          if (bus_rx_done_i) begin
            if (bus_rx_data_i[0]) begin
              state_d = Done;
            end else begin
              state_d = ReceiveID;
            end
          end
        end

        ReceiveID: begin
          if (bus_rx_done_i) begin
            if (bit_cnt_q == 0) begin
              state_d = stop_pending_i ? WaitStop : SendDynamicAddr;
            end else if (bit_cnt_q > 0) begin
              state_d = ReceiveID;
            end
          end
        end

        SendDynamicAddr: begin
          if (bus_tx_done_i) begin
            state_d = ReceiveAddrACK;
          end
        end

        ReceiveAddrACK: begin
          if (bus_rx_done_i) begin
            state_d = stop_pending_i ? WaitStop : Done;
          end
        end

        Done: begin
          state_d = Idle;
        end
        default: ;
      endcase
    end
  end

  assign done_o = done_daa;
  assign addr_valid_o = addr_valid_q;
  assign no_device_o = no_device;
  assign req_stop_o = req_stop;
  assign stopped_o = stopped;

  assign pid_o = pid;
  assign bcr_o = bcr;
  assign dcr_o = dcr;

  assign bus_tx_req_byte_o = bus_tx_req_byte;
  assign bus_tx_req_value_o = bus_tx_req_value;
  assign bus_tx_sel_od_pp_o = bus_tx_sel_od_pp;

  assign bus_rx_req_bit_o = bus_rx_req_bit;
  assign bus_rx_req_bit_handoff_o = bus_rx_req_bit_handoff;
  assign bus_rx_req_byte_o = 1'b0;
  assign bus_tx_req_bit_o = 1'b0;
endmodule
