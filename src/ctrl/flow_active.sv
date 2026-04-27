module flow_active
  import controller_pkg::*;
  import i3c_pkg::*;
#(
  parameter int HciCmdDataWidth = 64,
  parameter int HciTxDataWidth = 32,
  parameter int HciRxDataWidth = 32,
  parameter int HciRespDataWidth = 32,
  parameter int DatDepth = 32
)
(
  input  logic clk_i,
  input  logic rst_ni,

  input  logic                        cmd_queue_empty_i,
  input  logic                        cmd_queue_rvalid_i,
  output logic                        cmd_queue_rready_o,
  input  logic [HciCmdDataWidth-1:0]  cmd_queue_rdata_i,

  input  logic                        tx_queue_empty_i,
  input  logic                        tx_queue_rvalid_i,
  output logic                        tx_queue_rready_o,
  input  logic [HciTxDataWidth-1:0]   tx_queue_rdata_i,

  input  logic                        rx_queue_full_i,
  output logic                        rx_queue_wvalid_o,
  input  logic                        rx_queue_wready_i,
  output logic [HciRxDataWidth-1:0]   rx_queue_wdata_o,

  input  logic                        resp_queue_full_i,
  output logic                        resp_queue_wvalid_o,
  input  logic                        resp_queue_wready_i,
  output logic [HciRespDataWidth-1:0] resp_queue_wdata_o,

  output logic              dat_read_valid_hw_o,
  output logic [DatAw-1:0]  dat_index_hw_o,
  input  logic [31:0]       dat_rdata_hw_i,

  output logic        bus_tx_req_byte_o,
  output logic        bus_tx_req_bit_o,
  output logic [7:0]  bus_tx_req_value_o,
  input  logic        bus_tx_done_i,
  input  logic        bus_tx_idle_i,

  output logic        bus_rx_req_byte_o,
  output logic        bus_rx_req_bit_o,
  input  logic [7:0]  bus_rx_data_i,
  input  logic        bus_rx_done_i,
  input  logic        bus_rx_idle_i,

  output logic gen_start_o,
  output logic gen_rstart_o,
  output logic gen_stop_o,
  output logic gen_clock_o,
  output logic gen_idle_o,
  output logic sel_i3c_i2c_o,
  input  logic scl_gen_done_i,
  input  logic scl_gen_busy_i,

  output logic       ccc_valid_o,
  output logic [7:0] ccc_code_o,
  output logic [7:0] ccc_def_byte_o,
  output logic [6:0] ccc_dev_addr_o,
  output logic [3:0] ccc_dev_count_o,
  input  logic       ccc_done_i,
  input  logic       ccc_invalid_i,

  input  logic [6:0]  daa_address_i,
  input  logic        daa_address_valid_i,
  input  logic [47:0] daa_pid_i,
  input  logic [7:0]  daa_bcr_i,
  input  logic [7:0]  daa_dcr_i,

  output logic sel_od_pp_o,

  input  logic i3c_fsm_en_i,
  output logic i3c_fsm_idle_o
);

  typedef enum logic [3:0] {
    Idle             = 4'd0,
    WaitForCmd       = 4'd1,
    FetchDAT         = 4'd2,
    I3CWriteImmediate= 4'd3,
    I2CWriteImmediate= 4'd4,
    FetchTxData      = 4'd5,
    FetchRxData      = 4'd6,
    InitI2CWrite     = 4'd7,
    InitI2CRead      = 4'd8,
    StallWrite       = 4'd9,
    StallRead        = 4'd10,
    IssueCmd         = 4'd11,
    WriteResp        = 4'd12
  } flow_fsm_state_e;

  flow_fsm_state_e state_d, state_q;
  
  logic [HciCmdDataWidth-1:0] cmd_desc;
  immediate_data_trans_desc_t imm_desc;
  regular_trans_desc_t reg_desc;
  addr_assign_desc_t aa_desc;
  dat_entry_t dat_entry;
  
  i3c_cmd_attr_e cmd_attr;
  cmd_transfer_dir_e cmd_dir;
  logic [3:0] cmd_tid;
  logic [DatAw-1:0] dev_index;
  
  logic i3c_fsm_idle_q;
  logic cmd_queue_rready_q;
  logic dat_read_valid_hw_q, dat_read_valid_hw_d;
  logic [DatAw-1:0] dat_index_hw_q;
  
  logic [7:0] transfer_cnt_d, transfer_cnt_q;
  logic [7:0] issue_phase_d, issue_phase_q;
  
  logic [31:0] tx_dword_q;
  logic [1:0] tx_byte_idx_d, tx_byte_idx_q;
  logic tx_queue_rready_q;
  
  logic [31:0] rx_dword_d, rx_dword_q;
  logic [1:0] rx_byte_idx_d, rx_byte_idx_q;
  logic rx_queue_wvalid_q;
  logic [31:0] rx_queue_wdata_q;
  
  logic [15:0] remaining_len_d, remaining_len_q;
  logic [15:0] resp_data_len_d, resp_data_len_q;
  
  i3c_resp_err_status_e resp_err_status_q;
  logic nack_detected_d, nack_detected_q;
  logic parity_error_d, parity_error_q;
  logic addr_nack_d, addr_nack_q;
  
  logic gen_start_q;
  logic gen_rstart_q;
  logic gen_stop_q;
  logic gen_clock_q;
  logic gen_idle_q;
  logic sel_i3c_i2c_q;
  logic sel_od_pp_q;
  
  logic bus_tx_req_byte_q;
  logic bus_tx_req_bit_q;
  logic [7:0] bus_tx_req_value_q;
  logic bus_rx_req_byte_q;
  logic bus_rx_req_bit_q;
  
  logic resp_queue_wvalid_q;
  logic [31:0] resp_queue_wdata_q;
  
  logic ccc_valid_q;
  logic [7:0] ccc_code_q;
  logic [7:0] ccc_def_byte_q;
  logic [6:0] ccc_dev_addr_q;
  logic [3:0] ccc_dev_count_q;
  
  logic [7:0] imm_data_byte;
  logic [2:0] data_byte_idx;
  logic [7:0] current_tx_byte;
  
  assign imm_desc = immediate_data_trans_desc_t'(cmd_desc);
  assign reg_desc = regular_trans_desc_t'(cmd_desc);
  assign aa_desc = addr_assign_desc_t'(cmd_desc);
  
  assign cmd_attr = i3c_cmd_attr_e'(cmd_desc[2:0]);
  assign cmd_dir = cmd_transfer_dir_e'(cmd_desc[29]);
  assign cmd_tid = cmd_desc[6:3];
  assign dev_index = cmd_desc[20:16];
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state_q
    if (!rst_ni) begin
      state_q <= Idle;
    end else begin
      state_q <= state_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_cmd_queue_rdata_i_into_cmd_desc
    if (!rst_ni) begin
      cmd_desc <= '0;
    end else begin
      if (cmd_queue_rready_o && cmd_queue_rvalid_i) begin
        cmd_desc <= cmd_queue_rdata_i;
      end
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_dat_read_valid_hw_q
    if (!rst_ni) begin
      dat_read_valid_hw_q <= 1'b0;
    end else begin
      dat_read_valid_hw_q <= dat_read_valid_hw_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : capture_dat_rdata_hw_i_into_dat_entry
    if (!rst_ni) begin
      dat_entry <= '0;
    end else begin
      if (dat_read_valid_hw_q) begin
        dat_entry <= dat_entry_t'(dat_rdata_hw_i);
      end
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_transfer_count
    if (!rst_ni) begin
      transfer_cnt_q <= '0;
    end else begin
      transfer_cnt_q <= transfer_cnt_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_issue_phase
    if (!rst_ni) begin
      issue_phase_q <= '0;
    end else begin
      issue_phase_q <= issue_phase_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tx_dword
    if (!rst_ni) begin
      tx_dword_q <= '0;
    end else begin
      if (tx_queue_rready_o && tx_queue_rvalid_i) begin
        tx_dword_q <= tx_queue_rdata_i;
      end
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_tx_byte_idx
    if (!rst_ni) begin
      tx_byte_idx_q <= '0;
    end else begin
      tx_byte_idx_q <= tx_byte_idx_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rx_dword
    if (!rst_ni) begin
      rx_dword_q <= '0;
    end else begin
      rx_dword_q <= rx_dword_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_rx_byte_idx
    if (!rst_ni) begin
      rx_byte_idx_q <= '0;
    end else begin
      rx_byte_idx_q <= rx_byte_idx_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_remaining_len
    if (!rst_ni) begin
      remaining_len_q <= '0;
    end else begin
      remaining_len_q <= remaining_len_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_resp_data_len
    if (!rst_ni) begin
      resp_data_len_q <= '0;
    end else begin
      resp_data_len_q <= resp_data_len_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_nack_detected
    if (!rst_ni) begin
      nack_detected_q <= 1'b0;
    end else begin
      nack_detected_q <= nack_detected_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_addr_nack
    if (!rst_ni) begin
      addr_nack_q <= 1'b0;
    end else begin
      addr_nack_q <= addr_nack_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_parity_error
    if (!rst_ni) begin
      parity_error_q <= 1'b0;
    end else begin
      parity_error_q <= parity_error_d;
    end
  end
  
  always_ff @(posedge clk_i or negedge rst_ni) begin : update_resp_err_status_q
    if (!rst_ni || i3c_fsm_idle_o) begin
      resp_err_status_q <= Success;
    end else if (addr_nack_q) begin
      resp_err_status_q <= AddrHeader;
    end else if (nack_detected_q) begin
      resp_err_status_q <= Nack;
    end else if (parity_error_q) begin
      resp_err_status_q <= Parity;
    end
  end
  
  always_comb begin : select_imm_data_byte
    data_byte_idx = (transfer_cnt_q >= 8'd3) ? (transfer_cnt_q[2:0] - 3'd3) : 3'h0;
    
    unique case (data_byte_idx)
      3'd0: imm_data_byte = imm_desc.def_or_data_byte1;
      3'd1: imm_data_byte = imm_desc.data_byte2;
      3'd2: imm_data_byte = imm_desc.data_byte3;
      3'd3: imm_data_byte = imm_desc.data_byte4;
      default: imm_data_byte = 8'h00;
    endcase
  end
  
  always_comb begin : select_tx_byte
    unique case (tx_byte_idx_q)
      2'd0: current_tx_byte = tx_dword_q[7:0];
      2'd1: current_tx_byte = tx_dword_q[15:8];
      2'd2: current_tx_byte = tx_dword_q[23:16];
      2'd3: current_tx_byte = tx_dword_q[31:24];
    endcase
  end
  
  always_comb begin : update_fsm_state_d
    state_d = state_q;
    
    unique case (state_q)
      Idle: begin
        if (i3c_fsm_en_i) begin
          state_d = WaitForCmd;
        end
      end
      
      WaitForCmd: begin
        if (!cmd_queue_empty_i && cmd_queue_rvalid_i) begin
          state_d = FetchDAT;
        end
      end
      
      FetchDAT: begin
        if (dat_read_valid_hw_q) begin
          if (cmd_attr == ImmediateDataTransfer) begin
            state_d = dat_entry.device ? I2CWriteImmediate : I3CWriteImmediate;
          end else if (cmd_attr == AddressAssignment) begin
            state_d = IssueCmd;
          end else if (cmd_dir == Write) begin
            if (dat_entry.device) begin
              state_d = InitI2CWrite;
            end else begin
              state_d = FetchTxData;
            end
          end else begin
            if (dat_entry.device) begin
              state_d = InitI2CRead;
            end else begin
              state_d = IssueCmd;
            end
          end
        end
      end
      
      I2CWriteImmediate: begin
        if (addr_nack_q && transfer_cnt_q == 8'd3) begin
          state_d = WriteResp;
        end else if (transfer_cnt_q > (8'd3 + (imm_desc.dtt << 1))) begin
          if (imm_desc.toc && scl_gen_done_i) begin
            state_d = WriteResp;
          end else if (!imm_desc.toc) begin
            state_d = WriteResp;
          end
        end
      end
      
      I3CWriteImmediate: begin
        if (addr_nack_q && issue_phase_q == 8'd2) begin
          state_d = WriteResp;
        end else if (imm_desc.cp) begin
          if (imm_desc.cmd[7]) begin
            if (issue_phase_q >= 8'd10 && (!imm_desc.toc || scl_gen_done_i)) begin
              state_d = WriteResp;
            end
          end else begin
            if (issue_phase_q >= 8'd6 && (!imm_desc.toc || scl_gen_done_i)) begin
              state_d = WriteResp;
            end
          end
        end else begin
          if (issue_phase_q >= (8'd3 + (imm_desc.dtt << 1)) && (!imm_desc.toc || scl_gen_done_i)) begin
            state_d = WriteResp;
          end
        end
      end
      
      FetchTxData: begin
        if (tx_queue_empty_i) begin
          state_d = StallWrite;
        end else if (tx_queue_rvalid_i) begin
          state_d = IssueCmd;
        end
      end
      
      FetchRxData: begin
        if (rx_queue_full_i) begin
          state_d = StallRead;
        end else if (rx_queue_wready_i) begin
          state_d = IssueCmd;
        end
      end
      
      InitI2CWrite: begin
        if (addr_nack_q && transfer_cnt_q >= 8'd2) begin
          state_d = WriteResp;
        end else if (transfer_cnt_q >= 8'd2) begin
          state_d = IssueCmd;
        end
      end
      
      InitI2CRead: begin
        if (addr_nack_q && transfer_cnt_q >= 8'd2) begin
          state_d = WriteResp;
        end else if (transfer_cnt_q >= 8'd2) begin
          state_d = IssueCmd;
        end
      end
      
      StallWrite: begin
        if (!tx_queue_empty_i) begin
          state_d = FetchTxData;
        end
      end
      
      StallRead: begin
        if (!rx_queue_full_i) begin
          state_d = FetchRxData;
        end
      end
      
      IssueCmd: begin
        if (cmd_attr == AddressAssignment) begin
          if (ccc_done_i && issue_phase_q >= 8'd5) begin
            state_d = WriteResp;
          end
        end else if (cmd_dir == Write) begin
          if (remaining_len_q == 16'h0 && issue_phase_q > 8'h0) begin
            if (reg_desc.toc && scl_gen_done_i) begin
              state_d = WriteResp;
            end else if (!reg_desc.toc) begin
              state_d = WriteResp;
            end
          end else if (tx_byte_idx_q == 2'd3 && remaining_len_q > 16'h0) begin
            state_d = FetchTxData;
          end
        end else begin
          if (remaining_len_q == 16'h0 && issue_phase_q > 8'h0) begin
            if (reg_desc.toc && scl_gen_done_i) begin
              state_d = WriteResp;
            end else if (!reg_desc.toc) begin
              state_d = WriteResp;
            end
          end else if (rx_byte_idx_q == 2'd3 && remaining_len_q > 16'h0) begin
            state_d = FetchRxData;
          end
        end
      end
      
      WriteResp: begin
        if (resp_queue_wready_i) begin
          state_d = Idle;
        end
      end
      
      default: begin
        state_d = Idle;
      end
    endcase
  end
  
  always_comb begin : compute_fsm_outputs
    transfer_cnt_d = transfer_cnt_q;
    issue_phase_d = issue_phase_q;
    i3c_fsm_idle_q = 1'b0;
    cmd_queue_rready_q = 1'b0;
    dat_read_valid_hw_d = 1'b0;
    dat_index_hw_q = '0;
    
    tx_queue_rready_q = 1'b0;
    tx_byte_idx_d = tx_byte_idx_q;
    
    rx_dword_d = rx_dword_q;
    rx_byte_idx_d = rx_byte_idx_q;
    rx_queue_wvalid_q = 1'b0;
    rx_queue_wdata_q = '0;
    
    remaining_len_d = remaining_len_q;
    resp_data_len_d = resp_data_len_q;
    
    addr_nack_d = addr_nack_q;
    nack_detected_d = nack_detected_q;
    parity_error_d = parity_error_q;
    
    gen_start_q = 1'b0;
    gen_rstart_q = 1'b0;
    gen_stop_q = 1'b0;
    gen_clock_q = 1'b0;
    gen_idle_q = 1'b0;
    sel_i3c_i2c_q = 1'b0;
    sel_od_pp_q = 1'b0;
    
    bus_tx_req_byte_q = 1'b0;
    bus_tx_req_bit_q = 1'b0;
    bus_tx_req_value_q = 8'h00;
    bus_rx_req_byte_q = 1'b0;
    bus_rx_req_bit_q = 1'b0;
    
    resp_queue_wvalid_q = 1'b0;
    resp_queue_wdata_q = '0;
    
    ccc_valid_q = 1'b0;
    ccc_code_q = 8'h00;
    ccc_def_byte_q = 8'h00;
    ccc_dev_addr_q = 7'h00;
    ccc_dev_count_q = 4'h0;
    
    unique case (state_q)
      Idle: begin
        i3c_fsm_idle_q = 1'b1;
        transfer_cnt_d = 8'h0;
        issue_phase_d = 8'h0;
        tx_byte_idx_d = 2'h0;
        rx_byte_idx_d = 2'h0;
        rx_dword_d = 32'h0;
        remaining_len_d = 16'h0;
        resp_data_len_d = 16'h0;
        addr_nack_d = 1'b0;
        nack_detected_d = 1'b0;
        parity_error_d = 1'b0;
      end
      
      WaitForCmd: begin
        cmd_queue_rready_q = 1'b1;
        transfer_cnt_d = 8'h0;
        issue_phase_d = 8'h0;
      end
      
      FetchDAT: begin
        dat_read_valid_hw_d = 1'b1;
        dat_index_hw_q = dev_index;
        if (cmd_attr == RegularTransfer || cmd_attr == ComboTransfer) begin
          remaining_len_d = reg_desc.data_length;
        end
      end
      
      I2CWriteImmediate: begin
        sel_i3c_i2c_q = 1'b0;
        sel_od_pp_q = 1'b0;
        
        unique case (transfer_cnt_q)
          8'd0: begin
            gen_start_q = 1'b1;
            if (scl_gen_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd1: begin
            bus_tx_req_byte_q = 1'b1;
            bus_tx_req_value_q = {dat_entry.static_address, Write};
            if (bus_tx_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd2: begin
            bus_rx_req_bit_q = 1'b1;
            if (bus_rx_done_i) begin
              addr_nack_d = bus_rx_data_i[0];
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          default: begin
            if (transfer_cnt_q >= 8'd3 && data_byte_idx < imm_desc.dtt) begin
              if (transfer_cnt_q[0] == 1'b1) begin
                bus_tx_req_byte_q = 1'b1;
                bus_tx_req_value_q = imm_data_byte;
                if (bus_tx_done_i) begin
                  transfer_cnt_d = transfer_cnt_q + 8'h1;
                  resp_data_len_d = resp_data_len_q + 16'h1;
                end
              end else begin
                bus_rx_req_bit_q = 1'b1;
                if (bus_rx_done_i) begin
                  nack_detected_d = bus_rx_data_i[0];
                  transfer_cnt_d = transfer_cnt_q + 8'h1;
                end
              end
            end else if (imm_desc.toc && transfer_cnt_q == (8'd3 + (imm_desc.dtt << 1))) begin
              gen_stop_q = 1'b1;
              if (scl_gen_done_i) begin
                transfer_cnt_d = transfer_cnt_q + 8'h1;
              end
            end
          end
        endcase
      end
      
      I3CWriteImmediate: begin
        sel_i3c_i2c_q = 1'b1;
        
        if (!imm_desc.cp) begin
          unique case (issue_phase_q)
            8'd0: begin
              sel_od_pp_q = 1'b0;
              gen_start_q = 1'b1;
              if (scl_gen_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd1: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = {dat_entry.dynamic_address, Write};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd2: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                addr_nack_d = bus_rx_data_i[0];
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            default: begin
              if (issue_phase_q >= 8'd3 && ((issue_phase_q - 8'd3) >> 1) < imm_desc.dtt) begin
                sel_od_pp_q = 1'b1;
                if (issue_phase_q[0] == 1'b1) begin
                  bus_tx_req_byte_q = 1'b1;
                  bus_tx_req_value_q = imm_data_byte;
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                    resp_data_len_d = resp_data_len_q + 16'h1;
                  end
                end else begin
                  bus_tx_req_bit_q = 1'b1;
                  bus_tx_req_value_q = 8'h01;
                  if (bus_tx_done_i) begin
                    issue_phase_d = issue_phase_q + 8'h1;
                  end
                end
              end else if (imm_desc.toc && issue_phase_q == (8'd3 + (imm_desc.dtt << 1))) begin
                gen_stop_q = 1'b1;
                if (scl_gen_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end
            end
          endcase
        end else if (imm_desc.cmd[7]) begin
          unique case (issue_phase_q)
            8'd0: begin
              sel_od_pp_q = 1'b0;
              gen_start_q = 1'b1;
              if (scl_gen_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd1: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = {I3C_RSVD_ADDR, Write};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd2: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd3: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = imm_desc.cmd;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd4: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd5: begin
              sel_od_pp_q = 1'b0;
              gen_rstart_q = 1'b1;
              if (scl_gen_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd6: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = {dat_entry.dynamic_address, Write};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd7: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                addr_nack_d = bus_rx_data_i[0];
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd8: begin
              sel_od_pp_q = 1'b1;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = imm_desc.def_or_data_byte1;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
            
            8'd9: begin
              sel_od_pp_q = 1'b1;
              bus_tx_req_bit_q = 1'b1;
              bus_tx_req_value_q = 8'h01;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            default: begin
              if (imm_desc.toc && issue_phase_q == 8'd10) begin
                gen_stop_q = 1'b1;
                if (scl_gen_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end
            end
          endcase
        end else begin
          unique case (issue_phase_q)
            8'd0: begin
              sel_od_pp_q = 1'b0;
              gen_start_q = 1'b1;
              if (scl_gen_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd1: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = {I3C_RSVD_ADDR, Write};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd2: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd3: begin
              sel_od_pp_q = 1'b0;
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = imm_desc.cmd;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd4: begin
              sel_od_pp_q = 1'b0;
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd5: begin
              if (imm_desc.dtt >= 3'd5) begin
                sel_od_pp_q = 1'b0;
                bus_tx_req_byte_q = 1'b1;
                bus_tx_req_value_q = imm_desc.def_or_data_byte1;
                if (bus_tx_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                  resp_data_len_d = resp_data_len_q + 16'h1;
                end
              end else begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            default: begin
              if (imm_desc.toc && issue_phase_q == 8'd6) begin
                gen_stop_q = 1'b1;
                if (scl_gen_done_i) begin
                  issue_phase_d = issue_phase_q + 8'h1;
                end
              end
            end
          endcase
        end
      end
      
      FetchTxData: begin
        tx_queue_rready_q = 1'b1;
        if (tx_queue_rvalid_i) begin
          tx_byte_idx_d = 2'h0;
        end
      end
      
      FetchRxData: begin
        if (rx_byte_idx_q == 2'h0) begin
          rx_queue_wvalid_q = 1'b1;
          rx_queue_wdata_q = rx_dword_q;
          if (rx_queue_wready_i) begin
            rx_dword_d = 32'h0;
          end
        end
      end
      
      InitI2CWrite: begin
        sel_i3c_i2c_q = 1'b0;
        sel_od_pp_q = 1'b0;
        
        unique case (transfer_cnt_q)
          8'd0: begin
            gen_start_q = 1'b1;
            if (scl_gen_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd1: begin
            bus_tx_req_byte_q = 1'b1;
            bus_tx_req_value_q = {dat_entry.static_address, Write};
            if (bus_tx_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd2: begin
            bus_rx_req_bit_q = 1'b1;
            if (bus_rx_done_i) begin
              addr_nack_d = bus_rx_data_i[0];
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
        endcase
      end
      
      InitI2CRead: begin
        sel_i3c_i2c_q = 1'b0;
        sel_od_pp_q = 1'b0;
        
        unique case (transfer_cnt_q)
          8'd0: begin
            gen_start_q = 1'b1;
            if (scl_gen_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd1: begin
            bus_tx_req_byte_q = 1'b1;
            bus_tx_req_value_q = {dat_entry.static_address, Read};
            if (bus_tx_done_i) begin
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
          
          8'd2: begin
            bus_rx_req_bit_q = 1'b1;
            if (bus_rx_done_i) begin
              addr_nack_d = bus_rx_data_i[0];
              transfer_cnt_d = transfer_cnt_q + 8'h1;
            end
          end
        endcase
      end
      
      StallWrite: begin
        gen_clock_q = 1'b0;
      end
      
      StallRead: begin
        gen_clock_q = 1'b0;
      end
      
      IssueCmd: begin
        gen_clock_q = 1'b1;
        
        if (cmd_attr == AddressAssignment) begin
          sel_i3c_i2c_q = 1'b1;
          sel_od_pp_q = 1'b0;
          
          unique case (issue_phase_q)
            8'd0: begin
              gen_start_q = 1'b1;
              if (scl_gen_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd1: begin
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = {I3C_RSVD_ADDR, Write};
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd2: begin
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd3: begin
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = 8'h07;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            8'd4: begin
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end
            
            default: begin
              ccc_valid_q = 1'b1;
              ccc_dev_count_q = aa_desc.dev_count;
              ccc_dev_addr_q = {2'b0, aa_desc.dev_idx};
              if (daa_address_valid_i) begin
                unique case (rx_byte_idx_q)
                  2'h0: rx_dword_d[7:0] = {1'b0, daa_address_i};
                  2'h1: rx_dword_d[15:8] = {1'b0, daa_address_i};
                  2'h2: rx_dword_d[23:16] = {1'b0, daa_address_i};
                  2'h3: rx_dword_d[31:24] = {1'b0, daa_address_i};
                endcase
                rx_byte_idx_d = rx_byte_idx_q + 2'h1;
                resp_data_len_d = resp_data_len_q + 16'h1;
                if (rx_byte_idx_q == 2'h3) begin
                  rx_queue_wvalid_q = 1'b1;
                  rx_queue_wdata_q = rx_dword_d;
                  rx_byte_idx_d = 2'h0;
                  rx_dword_d = 32'h0;
                end
              end
              if (ccc_done_i) begin
                gen_stop_q = 1'b1;
              end
            end
          endcase
        end else if (cmd_dir == Write) begin
          sel_i3c_i2c_q = !dat_entry.device;
          
          if (dat_entry.device) begin
            sel_od_pp_q = 1'b0;
            bus_tx_req_byte_q = 1'b1;
            bus_tx_req_value_q = current_tx_byte;
            if (bus_tx_done_i) begin
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                nack_detected_d = bus_rx_data_i[0];
                if (tx_byte_idx_q == 2'd3) begin
                  tx_byte_idx_d = 2'h0;
                end else begin
                  tx_byte_idx_d = tx_byte_idx_q + 2'h1;
                end
                if (remaining_len_q > 16'h0) begin
                  remaining_len_d = remaining_len_q - 16'h1;
                end
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
          end else begin
            sel_od_pp_q = 1'b1;
            if (issue_phase_q[0] == 1'b0) begin
              bus_tx_req_byte_q = 1'b1;
              bus_tx_req_value_q = current_tx_byte;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end else begin
              bus_tx_req_bit_q = 1'b1;
              bus_tx_req_value_q = 8'h01;
              if (bus_tx_done_i) begin
                issue_phase_d = issue_phase_q + 8'h1;
                if (tx_byte_idx_q == 2'd3) begin
                  tx_byte_idx_d = 2'h0;
                end else begin
                  tx_byte_idx_d = tx_byte_idx_q + 2'h1;
                end
                if (remaining_len_q > 16'h0) begin
                  remaining_len_d = remaining_len_q - 16'h1;
                end
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
          end
          
          if (remaining_len_q == 16'h0 && reg_desc.toc) begin
            gen_stop_q = 1'b1;
          end
        end else begin
          sel_i3c_i2c_q = !dat_entry.device;
          
          if (dat_entry.device) begin
            sel_od_pp_q = 1'b0;
            bus_rx_req_byte_q = 1'b1;
            if (bus_rx_done_i) begin
              unique case (rx_byte_idx_q)
                2'h0: rx_dword_d[7:0] = bus_rx_data_i;
                2'h1: rx_dword_d[15:8] = bus_rx_data_i;
                2'h2: rx_dword_d[23:16] = bus_rx_data_i;
                2'h3: rx_dword_d[31:24] = bus_rx_data_i;
              endcase
              
              if (remaining_len_q > 16'h1) begin
                bus_tx_req_bit_q = 1'b1;
                bus_tx_req_value_q = 8'h00;
              end else begin
                bus_tx_req_bit_q = 1'b1;
                bus_tx_req_value_q = 8'h01;
              end
              
              if (bus_tx_done_i) begin
                if (rx_byte_idx_q == 2'h3) begin
                  rx_byte_idx_d = 2'h0;
                end else begin
                  rx_byte_idx_d = rx_byte_idx_q + 2'h1;
                end
                if (remaining_len_q > 16'h0) begin
                  remaining_len_d = remaining_len_q - 16'h1;
                end
                resp_data_len_d = resp_data_len_q + 16'h1;
              end
            end
          end else begin
            sel_od_pp_q = 1'b1;
            if (issue_phase_q[0] == 1'b0) begin
              bus_rx_req_byte_q = 1'b1;
              if (bus_rx_done_i) begin
                unique case (rx_byte_idx_q)
                  2'h0: rx_dword_d[7:0] = bus_rx_data_i;
                  2'h1: rx_dword_d[15:8] = bus_rx_data_i;
                  2'h2: rx_dword_d[23:16] = bus_rx_data_i;
                  2'h3: rx_dword_d[31:24] = bus_rx_data_i;
                endcase
                issue_phase_d = issue_phase_q + 8'h1;
              end
            end else begin
              bus_rx_req_bit_q = 1'b1;
              if (bus_rx_done_i) begin
                parity_error_d = (bus_rx_data_i[0] != 1'b1);
                issue_phase_d = issue_phase_q + 8'h1;
                
                if (remaining_len_q > 16'h1) begin
                  bus_tx_req_bit_q = 1'b1;
                  bus_tx_req_value_q = 8'h00;
                end else begin
                  bus_tx_req_bit_q = 1'b1;
                  bus_tx_req_value_q = 8'h01;
                end
                
                if (bus_tx_done_i) begin
                  if (rx_byte_idx_q == 2'h3) begin
                    rx_byte_idx_d = 2'h0;
                  end else begin
                    rx_byte_idx_d = rx_byte_idx_q + 2'h1;
                  end
                  if (remaining_len_q > 16'h0) begin
                    remaining_len_d = remaining_len_q - 16'h1;
                  end
                  resp_data_len_d = resp_data_len_q + 16'h1;
                end
              end
            end
          end
          
          if (remaining_len_q == 16'h0 && reg_desc.toc) begin
            gen_stop_q = 1'b1;
          end
        end
      end
      
      WriteResp: begin
        resp_queue_wvalid_q = 1'b1;
        resp_queue_wdata_q = {resp_err_status_q, cmd_tid, 8'h00, resp_data_len_q};
      end
      
      default: begin
      end
    endcase
  end
  
  assign i3c_fsm_idle_o = i3c_fsm_idle_q;
  assign cmd_queue_rready_o = cmd_queue_rready_q;
  assign dat_read_valid_hw_o = dat_read_valid_hw_q;
  assign dat_index_hw_o = dat_index_hw_q;
  
  assign tx_queue_rready_o = tx_queue_rready_q;
  
  assign rx_queue_wvalid_o = rx_queue_wvalid_q;
  assign rx_queue_wdata_o = rx_queue_wdata_q;
  
  assign resp_queue_wvalid_o = resp_queue_wvalid_q;
  assign resp_queue_wdata_o = resp_queue_wdata_q;
  
  assign gen_start_o = gen_start_q;
  assign gen_rstart_o = gen_rstart_q;
  assign gen_stop_o = gen_stop_q;
  assign gen_clock_o = gen_clock_q;
  assign gen_idle_o = gen_idle_q;
  assign sel_i3c_i2c_o = sel_i3c_i2c_q;
  
  assign bus_tx_req_byte_o = bus_tx_req_byte_q;
  assign bus_tx_req_bit_o = bus_tx_req_bit_q;
  assign bus_tx_req_value_o = bus_tx_req_value_q;
  assign bus_rx_req_byte_o = bus_rx_req_byte_q;
  assign bus_rx_req_bit_o = bus_rx_req_bit_q;
  
  assign ccc_valid_o = ccc_valid_q;
  assign ccc_code_o = ccc_code_q;
  assign ccc_def_byte_o = ccc_def_byte_q;
  assign ccc_dev_addr_o = ccc_dev_addr_q;
  assign ccc_dev_count_o = ccc_dev_count_q;
  
  assign sel_od_pp_o = sel_od_pp_q;

endmodule
