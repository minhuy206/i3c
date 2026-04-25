module flow_active
  import controller_pkg::*
  import i3c_pkg::*
#(
  parameter int HciCmdDataWidth = 64;
  parameter int HciTxDataWidth = 32;
  parameter int HciRxDataWidth = 32;
  parameter int HciRespDataWidth = 32;
  parameter int DatDepth = 32;
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
  input  logic [31:0]       dat_rdata_hw_i,    // Simplified 32-bit DAT entry

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

  output logic gen_start_o,    // Request START condition
  output logic gen_rstart_o,   // Request Repeated START
  output logic gen_stop_o,     // Request STOP condition
  output logic gen_clock_o,    // Enable SCL clock generation
  output logic gen_idle_o,     // Force SCL generator to Idle (abort)
  output logic sel_i3c_i2c_o,  // 0=I2C FM timing, 1=I3C SDR timing
  input  logic scl_gen_done_i, // SCL generator operation complete
  input  logic scl_gen_busy_i, // SCL generator is busy

  output logic       ccc_valid_o,     // Start CCC execution
  output logic [7:0] ccc_code_o,      // CCC command code
  output logic [7:0] ccc_def_byte_o,  // Defining byte (ENEC/DISEC)
  output logic [6:0] ccc_dev_addr_o,  // Target address (direct CCC)
  output logic [3:0] ccc_dev_count_o, // Device count (ENTDAA)
  input  logic       ccc_done_i,      // CCC execution complete
  input  logic       ccc_invalid_i,   // Unsupported CCC received

  input  logic [6:0]  daa_address_i,       // Assigned dynamic address
  input  logic        daa_address_valid_i,  // Address assignment valid pulse
  input  logic [47:0] daa_pid_i,            // Provisioned ID
  input  logic [7:0]  daa_bcr_i,           // Bus Characteristics Register
  input  logic [7:0]  daa_dcr_i,           // Device Characteristics Register

  output logic sel_od_pp_o, // 0=Open-Drain, 1=Push-Pull

  input  logic i3c_fsm_en_i,   // FSM enable (from CSR HC_CONTROL)
  output logic i3c_fsm_idle_o  // FSM is idle  input logic clk_i,
)

  typedef enum logic [3:0] {
    Idle             = 4'd0,   // Wait for FSM enable
    WaitForCmd       = 4'd1,   // Fetch command from CMD FIFO
    FetchDAT         = 4'd2,   // Look up target in DAT
    I3CWriteImmediate= 4'd3,   // Immediate write to I3C device (CCC or short data)
    I2CWriteImmediate= 4'd4,   // Immediate write to I2C legacy device
    FetchTxData      = 4'd5,   // Fetch DWORD from TX FIFO
    FetchRxData      = 4'd6,   // Write received data to RX FIFO
    InitI2CWrite     = 4'd7,   // Initialize I2C write transaction
    InitI2CRead      = 4'd8,   // Initialize I2C read transaction
    StallWrite       = 4'd9,   // Wait for TX FIFO data (underflow prevention)
    StallRead        = 4'd10,  // Wait for RX FIFO space (overflow prevention)
    IssueCmd         = 4'd11,  // Drive command bytes on bus
    WriteResp        = 4'd12   // Generate and write response descriptor
  } flow_fsm_state_e;

  flow_fsm_state_e state_d, state_q;
  cmd_transfer_dir_e cmd_dir;
  dat_entry_t dat_entry;
  
  logic i3c_fsm_idle_q;
  logic cmd_queue_rready_q;
  logic [HciCmdDataWidth-1:0] cmd_desc;
  logic [2:0] cmd_attr;
  logic dat_read_valid_hw_d, dat_read_valid_hw_q;
  logic i2c_cmd;
  logic [DatAw-1:0] dat_index_hw_q;
  logic [DatAw-1:0] dev_index
  logic [3:0] transfer_cnt;
  

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_dat_read_valid_hw_d 
    if (!rst_ni) begin
      dat_read_valid_hw_d <= 0;
    end else begin
      dat_read_valid_hw_d <= dat_read_valid_hw_q;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : capture_dat_rdata_hw_i_into_dat_entry
    if (!rst_ni) begin
      dat_entry <= '0;
    end else begin
      if (dat_read_valid_hw_d) begin
        dat_entry <= dat_entry_t'(dat_rdata_hw_i);
      end
    end
  end


  always_ff @(posedge clk_i or negedge rst_ni) begin : update_fsm_state_q
    if (!rst_ni) begin
      state_q <= Idle;
    end
    else begin
      state_q <= state_d;
    end
  end 

  always_ff @(posedge clk_i or negedge rst_ni) begin : latch_cmd_queue_rdata_i_into_cmd_desc
    if (!rst_ni) begin
      cmd_desc <= '0;
    end else begin
      if (cmd_queue_rready_q && cmd_queue_rvalid_i) begin
        cmd_desc <= cmd_queue_rdata_i; 
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : update_transfer_count
    if (!rst_ni) begin
      transfer_cnt <= '0;
    end else begin
      unique case (transfer_cnt)
        0: begin
          
        end
      endcase
    end
  end

  always_comb begin : update_fsm_state_d
    state_d = Idle;

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
        if (dat_entry) begin
          if (cmd_attr == i3c_cmd_attr_e.ImmediateDataTransfer && dat_entry.device) begin
            state_d = dat_entry.device ? I2CWriteImmediate : I3CWriteImmediate;
          end else if (cmd_attr == i3c_cmd_attr_e.AddressAssignment) begin
            state_d = IssueCmd;
          end else if (cmd_dir == Write) begin
            state_d = FetchTxData;
          end else if (cmd_dir == Read) begin
            state_d = IssueCmd;
          end
        end
      end

      I2CWriteImmediate: begin
        
      end
    endcase


    
  end

  always_comb begin : update_fsm_output
    i3c_fsm_idle_q = '0;
    cmd_queue_rready_q = '0;

    unique case (state_q)
      Idle: begin
        i3c_fsm_idle_q = 1'b1;
      end

      WaitForCmd: begin
        cmd_queue_rready_q = 1'b1;
      end

      FetchDAT: begin
        dat_read_valid_hw_q = 1'b1;
        dat_index_hw_q = dev_index;
      end

      I2CWriteImmediate: begin
        
      end
    endcase

  end

endmodule