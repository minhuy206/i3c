// Control and Status Registers (CSR) + Device Address Table (DAT).
// Hand-written register file; replaces 14,342-line auto-generated PeakRDL output.
// Provides: HC_CONTROL, HC_STATUS, 9 timing registers, queue port registers,
//           QUEUE_STATUS, and 16-entry DAT.
// Spec: docs/module_specs/07_csr_registers_spec.md

module csr_registers
  import controller_pkg::*;
#(
  parameter int unsigned DatDepth  = 16,
  parameter int unsigned AddrWidth = 12,
  parameter int unsigned DataWidth = 32,
  parameter int unsigned CounterWidth = 20;
  parameter int unsigned CmdDataWidth = 64;
  localparam int unsigned DatAw    = $clog2(DatDepth)
) (
  input  logic clk_i,
  input  logic rst_ni,

  input  logic [AddrWidth-1:0] addr_i,
  input  logic [DataWidth-1:0] wdata_i,
  input  logic                 wen_i,
  input  logic                 ren_i,
  output logic [DataWidth-1:0] rdata_o,
  output logic                 ready_o,  

  output logic ctrl_enable_o, 
  output logic i3c_fsm_en_o,  
  output logic sw_reset_o,    

  output logic [CounterWidth-1:0] t_r_o,       
  output logic [CounterWidth-1:0] t_f_o,       
  output logic [CounterWidth-1:0] t_low_o,     
  output logic [CounterWidth-1:0] t_high_o,    
  output logic [CounterWidth-1:0] t_su_sta_o,  
  output logic [CounterWidth-1:0] t_hd_sta_o,  
  output logic [CounterWidth-1:0] t_su_sto_o,  
  output logic [CounterWidth-1:0] t_su_dat_o,  
  output logic [CounterWidth-1:0] t_hd_dat_o,  

  input  logic             dat_read_valid_i,
  input  logic [DatAw-1:0] dat_index_i,
  output logic [DataWidth-1:0]            dat_rdata_o,

  output logic        cmd_wvalid_o,
  output logic [CmdDataWidth-1:0] cmd_wdata_o,
  input  logic        cmd_wready_i,

  output logic        tx_wvalid_o,
  output logic [DataWidth-1:0] tx_wdata_o,
  input  logic        tx_wready_i,

  input  logic        rx_rvalid_i,
  input  logic [DataWidth-1:0] rx_rdata_i,
  output logic        rx_rready_o,

  input  logic        resp_rvalid_i,
  input  logic [DataWidth-1:0] resp_rdata_i,
  output logic        resp_rready_o,

  input  logic cmd_full_i,
  input  logic cmd_empty_i,
  input  logic tx_full_i,
  input  logic tx_empty_i,
  input  logic rx_full_i,
  input  logic rx_empty_i,
  input  logic resp_full_i,
  input  logic resp_empty_i,

  input  logic i3c_fsm_idle_i
);

  localparam logic [AddrWidth-1:0] ADDR_HC_CONTROL   = 12'h000;
  localparam logic [AddrWidth-1:0] ADDR_HC_STATUS    = 12'h004;
  localparam logic [AddrWidth-1:0] ADDR_T_R          = 12'h010;
  localparam logic [AddrWidth-1:0] ADDR_T_F          = 12'h014;
  localparam logic [AddrWidth-1:0] ADDR_T_LOW        = 12'h018;
  localparam logic [AddrWidth-1:0] ADDR_T_HIGH       = 12'h01C;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_STA     = 12'h020;
  localparam logic [AddrWidth-1:0] ADDR_T_HD_STA     = 12'h024;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_STO     = 12'h028;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_DAT     = 12'h02C;
  localparam logic [AddrWidth-1:0] ADDR_T_HD_DAT     = 12'h030;
  localparam logic [AddrWidth-1:0] ADDR_CMD_QUEUE    = 12'h100;
  localparam logic [AddrWidth-1:0] ADDR_TX_DATA      = 12'h104;
  localparam logic [AddrWidth-1:0] ADDR_RX_DATA      = 12'h108;
  localparam logic [AddrWidth-1:0] ADDR_RESP         = 12'h10C;
  localparam logic [AddrWidth-1:0] ADDR_QUEUE_STATUS = 12'h110;
  localparam logic [AddrWidth-1:0] ADDR_DAT_BASE     = 12'h200;
  localparam logic [AddrWidth-1:0] ADDR_DAT_END      = 12'h240;

  localparam logic [CounterWidth-1:0] RST_T_R      = 20'd4;   
  localparam logic [CounterWidth-1:0] RST_T_F      = 20'd4;
  localparam logic [CounterWidth-1:0] RST_T_LOW    = 20'd13;  
  localparam logic [CounterWidth-1:0] RST_T_HIGH   = 20'd13;
  localparam logic [CounterWidth-1:0] RST_T_SU_STA = 20'd13;
  localparam logic [CounterWidth-1:0] RST_T_HD_STA = 20'd13;
  localparam logic [CounterWidth-1:0] RST_T_SU_STO = 20'd13;
  localparam logic [CounterWidth-1:0] RST_T_SU_DAT = 20'd1;
  localparam logic [CounterWidth-1:0] RST_T_HD_DAT = 20'd4;

  logic hc_enable_q;  
  logic sw_reset_q;   

  logic [CounterWidth-1:0] t_r_q, t_f_q, t_low_q, t_high_q;
  logic [CounterWidth-1:0] t_su_sta_q, t_hd_sta_q, t_su_sto_q, t_su_dat_q, t_hd_dat_q;

  dat_entry_t dat_mem [DatDepth];

  logic cmd_staging_valid_q;
  logic cmd_wvalid_q;
  logic [DataWidth-1:0] cmd_dword0_q;
  logic [CmdDataWidth-1:0] cmd_wdata_q;

  logic [DataWidth-1:0] tx_wdata_q;
  logic tx_wvalid_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_write
    if (!rst_ni) begin
      hc_enable_q <= '0;
      sw_reset_q <= '0;
      t_r_q <= RST_T_R;
      t_f_q <= RST_T_F;
      t_low_q <= RST_T_LOW;
      t_high_q <= RST_T_HIGH;
      t_su_sta_q <= RST_T_SU_STA;
      t_hd_sta_q <= RST_T_HD_STA;
      t_su_sto_q <= RST_T_SU_STO;
      t_su_dat_q <= RST_T_SU_DAT;
      t_hd_dat_q <= RST_T_HD_DAT;
      for (int i = 0; i < DatDepth; i++) begin
        dat_mem[i] <= '0;
      end
    end else begin
      sw_reset_q <= 0;
      if (wen_i) begin
        unique case (addr_i)
          ADDR_HC_CONTROL: begin
            hc_enable_q <= wdata_i[0];
            sw_reset_q <= wdata_i[1];
          end
          ADDR_T_R: t_r_q <= wdata_i[19:0];
          ADDR_T_F: t_f_q <= wdata_i[19:0];
          ADDR_T_LOW: t_low_q <= wdata_i[19:0];
          ADDR_T_HIGH: t_high_q <= wdata_i[19:0];
          ADDR_T_SU_STA: t_su_sta_q <= wdata_i[19:0];
          ADDR_T_HD_STA: t_hd_sta_q <= wdata_i[19:0];
          ADDR_T_SU_STO: t_su_sto_q <= wdata_i[19:0];
          ADDR_T_SU_DAT: t_su_dat_q <= wdata_i[19:0];
          ADDR_T_HD_DAT: t_hd_dat_q <= wdata_i[19:0];
          default: begin
            if (addr_i >= ADDR_DAT_BASE && addr_i <= (ADDR_DAT_END - 4)) begin
              dat_mem[(addr_i-ADDR_DAT_BASE) >> 2] <= dat_entry_t'(wdata_i);
            end
          end
        endcase
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : cmd_write
    if (!rst_ni) begin
      cmd_staging_valid_q <= 1'b0;
      cmd_wvalid_q <= '0;
      cmd_dword0_q <= '0;
      cmd_wdata_q <= '0;
    end else if (sw_reset_q || (cmd_wvalid_q && cmd_wready_i)) begin
      cmd_wvalid_q <= '0;
    end else if (wen_i && (addr_i == ADDR_CMD_QUEUE) && !cmd_wvalid_q) begin
      if (!cmd_staging_valid_q) begin
        cmd_dword0_q <= wdata_i;
        cmd_staging_valid_q <= 1'b1;
      end else begin
        cmd_wdata_q <= {wdata_i, cmd_dword0_q};
        cmd_wvalid_q <= 1'b1;
        cmd_staging_valid_q <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : tx_write
    if (!rst_ni) begin
      tx_wdata_q <= '0;
      tx_wvalid_q <= '0;
    end else if (tx_wvalid_q && tx_wready_i) begin
      tx_wvalid_q <= '0; 
    end else if (wen_i && (addr_i == ADDR_TX_DATA) && !tx_wvalid_q) begin
      tx_wdata_q <= wdata_i;
      tx_wvalid_q <= 1'b1;
    end
  end

  assign ctrl_enable_o = hc_enable_q;
  assign i3c_fsm_en_o  = hc_enable_q; 
  assign sw_reset_o    = sw_reset_q;

  assign t_r_o      = t_r_q;
  assign t_f_o      = t_f_q;
  assign t_low_o    = t_low_q;
  assign t_high_o   = t_high_q;
  assign t_su_sta_o = t_su_sta_q;
  assign t_hd_sta_o = t_hd_sta_q;
  assign t_su_sto_o = t_su_sto_q;
  assign t_su_dat_o = t_su_dat_q;
  assign t_hd_dat_o = t_hd_dat_q;

  assign ready_o = 1'b1;

  assign cmd_wvalid_o = cmd_wvalid_q;
  assign cmd_wdata_o = cmd_wdata_q;

  assign tx_wvalid_o = tx_wvalid_q;
  assign tx_wdata_o  = tx_wdata_q;

  logic [DataWidth-1:0] hc_control =  {30'b0, sw_reset_q, hc_enable_q};
  logic [DataWidth-1:0] hc_status = {29'b0, resp_empty_i, cmd_full_i, i3c_fsm_idle_i};
  logic [DataWidth-1:0] queue_status = {24'b0, resp_empty_i, resp_full_i, rx_empty_i, rx_full_i, tx_empty_i, tx_full_i, cmd_empty_i, cmd_full_i};

  always_comb begin : reg_read
    rdata_o = '0;
    resp_rready_o = 1'b0;
    rx_rready_o = 1'b0;
    if (ren_i) begin
      unique case (addr_i)
        ADDR_HC_CONTROL: rdata_o = hc_control;
        ADDR_HC_STATUS: rdata_o = hc_status;
        ADDR_T_R: rdata_o = {12'b0, t_r_q};
        ADDR_T_F: rdata_o = {12'b0, t_f_q};
        ADDR_T_LOW: rdata_o = {12'b0, t_low_q};
        ADDR_T_HIGH: rdata_o = {12'b0, t_high_q};
        ADDR_T_SU_STA: rdata_o = {12'b0, t_su_sta_q};
        ADDR_T_HD_STA: rdata_o = {12'b0, t_hd_sta_q};
        ADDR_T_SU_STO: rdata_o = {12'b0, t_su_sto_q};
        ADDR_T_SU_DAT: rdata_o = {12'b0, t_su_dat_q};
        ADDR_T_HD_DAT: rdata_o = {12'b0, t_hd_dat_q};
        ADDR_RX_DATA: begin
          rx_rready_o = ren_i;
          if (rx_rvalid_i) begin
            rdata_o = rx_rdata_i;
          end
        end
        ADDR_RESP: begin
          if (resp_rvalid_i) begin
            rdata_o = resp_rdata_i;
          end
          resp_rready_o = ren_i;
        end
        ADDR_QUEUE_STATUS: rdata_o = queue_status; 
        default: begin
          if (addr_i >= ADDR_DAT_BASE && addr_i <= (ADDR_DAT_END - 4)) begin
            rdata_o = dat_mem[(addr_i-ADDR_DAT_BASE) >> 2]; 
          end
        end
      endcase    
    end
  end

  always_ff @(posedge clk_i) begin
    if (dat_read_valid_i)
      dat_rdata_o <= dat_mem[dat_index_i];
  end
endmodule
