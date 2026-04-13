module ccc_entdaa
  import controller_pkg::*;
  import i3c_pkg::*;
(
  input logic clk_i,  
  input logic rst_ni, 

  input logic start_daa_i,
  input logic [6:0] daa_addr_i,
  output logic done_daa_o,
  output logic addr_valid_o,
  output logic no_device_o,

  output logic [47:0] pid_o,
  output logic [7:0] bcr_o,
  output logic [7:0] dcr_o,

  // Bus RX interface
  input logic [7:0] bus_rx_data_i,
  input logic bus_rx_done_i,
  output logic bus_rx_req_bit_o,
  output logic bus_rx_req_byte_o,

  // Bus TX interface
  input logic bus_tx_done_i,
  output logic bus_tx_req_byte_o,
  output logic bus_tx_req_bit_o,
  output logic [7:0] bus_tx_req_value_o,
  output logic bus_tx_sel_od_pp_o,

  // Bus Monitor interface
  input logic bus_stop_det_i,
);
  typedef enum logic [2:0] {
    Idle           = 3'd0,
    SendRsvdByte   = 3'd1,
    ReadRsvdAck    = 3'd2,
    ReceiveIDBit   = 3'd3,
    SendAddr       = 3'd4,
    ReadAddrAck    = 3'd5,
    Done           = 3'd6,
    NoDev          = 3'd7
  } state_e;

  state_e state_q, state_d;
  logic [63:0] id_shift_q, id_shift_d;
  logic [5:0] bit_cnt_q, bit_cnt_d;
  logic bus_tx_req_byte_q;
  logic bus_tx_sel_od_pp_q;
  logic [7:0] bus_tx_req_value_q;
  logic bus_rx_req_bit_q;
  logic parity;
  logic addr_valid_q, addr_valid_d;
  logic done_daa_q;
  logic no_device_q;
  logic [47:0] pid_q;
  logic [7:0]  bcr_q;
  logic [7:0]  dcr_q;

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
      bit_cnt_q <= '0;
    end else begin
      id_shift_q <= id_shift_d;
      bit_cnt_q <= bit_cnt_d;
    end 
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_addr_valid
    if (!rst_ni) begin
      addr_valid_q <= '0;
    end else begin
      addr_valid_q <= addr_valid_d;
    end 
  end


  always_comb begin : fsm_output
    bus_tx_req_byte_q = '0;
    bus_tx_sel_od_pp_q = '0;
    bus_tx_req_value_q = '0;
    bus_rx_req_bit_q = '0;
    parity = 1'b0;
    done_daa_q = '0;
    no_device_q = '0;
    pid_q = '0;
    bcr_q = '0;
    dcr_q = '0;
    id_shift_d   = id_shift_q;
    bit_cnt_d    = bit_cnt_q;
    addr_valid_d = addr_valid_q;

    unique case (state_q)
      Idle: begin
        if (start_daa_i) begin
          id_shift_d = 64'b0;
          bit_cnt_d = 6'd63;
          addr_valid_d = 1'b0;
        end
      end

      SendRsvdByte: begin
        bus_tx_req_value_q = {7'h7E, 1'b1};
        bus_tx_req_byte_q = 1;
        bus_tx_sel_od_pp_q = 1'b0;
      end

      ReadRsvdAck: begin
        bus_rx_req_bit_q = 1'b1;
      end

      ReceiveIDBit: begin
        bus_rx_req_bit_q = 1'b1;
        if (bus_rx_done_i) begin
          id_shift_d = {id_shift_q[62:0], bus_rx_data_i[0]};
          bit_cnt_d = bit_cnt_q - 1;
        end
      end

      SendAddr: begin
        parity = ~^daa_addr_i;
        bus_tx_req_byte_q  = 1'b1;
        bus_tx_req_value_q = {daa_addr_i, parity};
        bus_tx_sel_od_pp_q = 1'b0;
      end

      ReadAddrAck: begin
        bus_rx_req_bit_q = 1'b1;
        if (bus_rx_done_i) begin
          addr_valid_d = ~bus_rx_data_i[0];
        end 
      end

      Done: begin
        done_daa_q = 1'b1;
        no_device_q = 1'b0;
        addr_valid_d = addr_valid_q;
        pid_q = id_shift_q[63:16];
        bcr_q = id_shift_q[15:8];
        dcr_q = id_shift_q[7:0];

      end

      NoDev: begin
        done_daa_q = 1'b1;
        no_device_q = 1'b1;
        // TODO(discuss): addr_valid_q is still stale (possibly 1) when done_daa_o fires this
        // cycle; it clears to 0 only on the next cycle (Idle). Relies on parent sampling
        // results one cycle after done_daa_o — confirm this 1-cycle delay contract is acceptable.
        addr_valid_d = 1'b0;
      end
      default: ;
    endcase
  end

  always_comb begin : update_fsm_state
    state_d = state_q;
    if (bus_stop_det_i && state_q != Idle) begin
      state_d = NoDev;
    end else begin
      unique case (state_q)
        Idle: begin
          if (start_daa_i) begin
            state_d = SendRsvdByte;
          end
        end

        SendRsvdByte: begin
          if (bus_tx_done_i) begin
            state_d = ReadRsvdAck;
          end
        end

        ReadRsvdAck: begin
          if (bus_rx_done_i) begin
            if (bus_rx_data_i[0]) begin
              state_d = NoDev;
            end else begin
              state_d = ReceiveIDBit;
            end
          end
        end

        ReceiveIDBit: begin
          if (bus_rx_done_i) begin
            if (bit_cnt_q == 0)
              state_d = SendAddr;
            else if (bit_cnt_q > 0) begin
              state_d = ReceiveIDBit;
            end
          end
        end

        SendAddr: begin
          if (bus_tx_done_i) begin
            state_d = ReadAddrAck;
          end
        end

        ReadAddrAck: begin
          if (bus_rx_done_i) begin
            state_d = Done;
          end
        end

        Done, NoDev: begin
          state_d = Idle;
        end
        default: ;
      endcase
    end
  end

  assign done_daa_o = done_daa_q;
  assign addr_valid_o = addr_valid_q;
  assign no_device_o = no_device_q;

  assign pid_o = pid_q;
  assign bcr_o = bcr_q;
  assign dcr_o = dcr_q;

  assign bus_tx_req_byte_o = bus_tx_req_byte_q;
  assign bus_tx_req_value_o = bus_tx_req_value_q;
  assign bus_tx_sel_od_pp_o = bus_tx_sel_od_pp_q;

  assign bus_rx_req_bit_o = bus_rx_req_bit_q;
  assign bus_rx_req_byte_o = 1'b0;
  assign bus_tx_req_bit_o = 1'b0;

endmodule