module csr_registers
  import controller_pkg::dat_entry_t;
#(
    parameter int unsigned DatDepth  = 16,
    parameter int unsigned AddrWidth = 12,
    parameter int unsigned DataWidth = 32,
    parameter int unsigned CounterWidth = 20,
    parameter int unsigned CmdDataWidth = 64,
    localparam int unsigned DatAw    = $clog2(DatDepth)
) (
    input logic clk_i,
    input logic rst_ni,

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
    output logic [CounterWidth-1:0] t_low_od_o,
    output logic [CounterWidth-1:0] t_high_o,
    output logic [CounterWidth-1:0] t_su_sta_o,
    output logic [CounterWidth-1:0] t_hd_sta_o,
    output logic [CounterWidth-1:0] t_su_sto_o,
    output logic [CounterWidth-1:0] t_su_dat_o,
    output logic [CounterWidth-1:0] t_hd_dat_o,
    output logic [CounterWidth-1:0] t_bus_free_o,
    output logic [CounterWidth-1:0] i2c_t_r_o,
    output logic [CounterWidth-1:0] i2c_t_f_o,
    output logic [CounterWidth-1:0] i2c_t_low_o,
    output logic [CounterWidth-1:0] i2c_t_high_o,
    output logic [CounterWidth-1:0] i2c_t_su_sta_o,
    output logic [CounterWidth-1:0] i2c_t_hd_sta_o,
    output logic [CounterWidth-1:0] i2c_t_su_sto_o,
    output logic [CounterWidth-1:0] i2c_t_su_dat_o,
    output logic [CounterWidth-1:0] i2c_t_hd_dat_o,
    output logic [CounterWidth-1:0] i2c_t_buf_o,

    input  logic                 dat_read_valid_i,
    input  logic [    DatAw-1:0] dat_index_i,
    output logic [DataWidth-1:0] dat_rdata_o,

    output logic                    cmd_wvalid_o,
    output logic [CmdDataWidth-1:0] cmd_wdata_o,
    input  logic                    cmd_wready_i,

    output logic                 tx_wvalid_o,
    output logic [DataWidth-1:0] tx_wdata_o,
    input  logic                 tx_wready_i,

    input  logic                 rx_rvalid_i,
    input  logic [DataWidth-1:0] rx_rdata_i,
    output logic                 rx_rready_o,

    input  logic                 resp_rvalid_i,
    input  logic [DataWidth-1:0] resp_rdata_i,
    output logic                 resp_rready_o,

    input logic cmd_full_i,
    input logic cmd_empty_i,
    input logic tx_full_i,
    input logic tx_empty_i,
    input logic rx_full_i,
    input logic rx_empty_i,
    input logic resp_full_i,
    input logic resp_empty_i,

    input logic i3c_fsm_idle_i
);

  localparam logic [AddrWidth-1:0] ADDR_HC_CONTROL = 12'h000;
  localparam logic [AddrWidth-1:0] ADDR_HC_STATUS = 12'h004;
  localparam logic [AddrWidth-1:0] ADDR_T_R = 12'h010;
  localparam logic [AddrWidth-1:0] ADDR_T_F = 12'h014;
  localparam logic [AddrWidth-1:0] ADDR_T_LOW = 12'h018;
  localparam logic [AddrWidth-1:0] ADDR_T_LOW_OD = 12'h01C;
  localparam logic [AddrWidth-1:0] ADDR_T_HIGH = 12'h020;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_STA = 12'h024;
  localparam logic [AddrWidth-1:0] ADDR_T_HD_STA = 12'h028;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_STO = 12'h02C;
  localparam logic [AddrWidth-1:0] ADDR_T_SU_DAT = 12'h030;
  localparam logic [AddrWidth-1:0] ADDR_T_HD_DAT = 12'h034;
  localparam logic [AddrWidth-1:0] ADDR_T_BUS_FREE = 12'h038;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_R = 12'h040;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_F = 12'h044;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_LOW = 12'h048;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_HIGH = 12'h04C;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_SU_STA = 12'h050;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_HD_STA = 12'h054;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_SU_STO = 12'h058;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_SU_DAT = 12'h05C;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_HD_DAT = 12'h060;
  localparam logic [AddrWidth-1:0] ADDR_I2C_T_BUF = 12'h064;
  localparam logic [AddrWidth-1:0] ADDR_CMD_QUEUE = 12'h100;
  localparam logic [AddrWidth-1:0] ADDR_TX_DATA = 12'h104;
  localparam logic [AddrWidth-1:0] ADDR_RX_DATA = 12'h108;
  localparam logic [AddrWidth-1:0] ADDR_RESP = 12'h10C;
  localparam logic [AddrWidth-1:0] ADDR_QUEUE_STATUS = 12'h110;
  localparam logic [AddrWidth-1:0] ADDR_DAT_BASE = 12'h200;
  localparam logic [AddrWidth-1:0] ADDR_DAT_END = 12'h240;

  localparam logic [CounterWidth-1:0] RST_T_R = 20'd4;
  localparam logic [CounterWidth-1:0] RST_T_F = 20'd4;
  localparam logic [CounterWidth-1:0] RST_T_LOW = 20'd8;
  localparam logic [CounterWidth-1:0] RST_T_LOW_OD = 20'd20;
  localparam logic [CounterWidth-1:0] RST_T_HIGH = 20'd8;
  localparam logic [CounterWidth-1:0] RST_T_SU_STA = 20'd8;
  localparam logic [CounterWidth-1:0] RST_T_HD_STA = 20'd8;
  localparam logic [CounterWidth-1:0] RST_T_SU_STO = 20'd4;
  localparam logic [CounterWidth-1:0] RST_T_SU_DAT = 20'd1;
  localparam logic [CounterWidth-1:0] RST_T_HD_DAT = 20'd4;
  localparam logic [CounterWidth-1:0] RST_T_BUS_FREE = 20'd4;
  localparam logic [CounterWidth-1:0] RST_I2C_T_R = 20'd4;
  localparam logic [CounterWidth-1:0] RST_I2C_T_F = 20'd4;
  localparam logic [CounterWidth-1:0] RST_I2C_T_LOW = 20'd160;
  localparam logic [CounterWidth-1:0] RST_I2C_T_HIGH = 20'd90;
  localparam logic [CounterWidth-1:0] RST_I2C_T_SU_STA = 20'd60;
  localparam logic [CounterWidth-1:0] RST_I2C_T_HD_STA = 20'd60;
  localparam logic [CounterWidth-1:0] RST_I2C_T_SU_STO = 20'd130;
  localparam logic [CounterWidth-1:0] RST_I2C_T_SU_DAT = 20'd10;
  localparam logic [CounterWidth-1:0] RST_I2C_T_HD_DAT = 20'd0;
  localparam logic [CounterWidth-1:0] RST_I2C_T_BUF = 20'd130;

  logic [DataWidth-1:0] hc_control, hc_status, queue_status;
  logic [CounterWidth-1:0] t_r, t_f, t_low, t_low_od, t_high;
  logic [CounterWidth-1:0] t_su_sta, t_hd_sta, t_su_sto, t_su_dat, t_hd_dat, t_bus_free;
  logic [CounterWidth-1:0] i2c_t_r, i2c_t_f, i2c_t_low, i2c_t_high;
  logic [CounterWidth-1:0] i2c_t_su_sta, i2c_t_hd_sta, i2c_t_su_sto, i2c_t_su_dat;
  logic [CounterWidth-1:0] i2c_t_hd_dat, i2c_t_buf;

  dat_entry_t dat_mem[DatDepth];
  dat_entry_t dat_rdata;

  logic cmd_staging_valid;
  logic cmd_wvalid;
  logic [DataWidth-1:0] cmd_dword0;
  logic [CmdDataWidth-1:0] cmd_wdata;

  logic [DataWidth-1:0] tx_wdata;
  logic tx_wvalid;

  logic [DataWidth-1:0] rdata_d, rdata_q;

  logic hc_enable;
  logic sw_reset;
  logic resp_rready;
  logic rx_rready;

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_write
    if (!rst_ni) begin
      hc_enable <= '0;
      sw_reset <= '0;
      t_r <= RST_T_R;
      t_f <= RST_T_F;
      t_low <= RST_T_LOW;
      t_low_od <= RST_T_LOW_OD;
      t_high <= RST_T_HIGH;
      t_su_sta <= RST_T_SU_STA;
      t_hd_sta <= RST_T_HD_STA;
      t_su_sto <= RST_T_SU_STO;
      t_su_dat <= RST_T_SU_DAT;
      t_hd_dat <= RST_T_HD_DAT;
      t_bus_free <= RST_T_BUS_FREE;
      i2c_t_r <= RST_I2C_T_R;
      i2c_t_f <= RST_I2C_T_F;
      i2c_t_low <= RST_I2C_T_LOW;
      i2c_t_high <= RST_I2C_T_HIGH;
      i2c_t_su_sta <= RST_I2C_T_SU_STA;
      i2c_t_hd_sta <= RST_I2C_T_HD_STA;
      i2c_t_su_sto <= RST_I2C_T_SU_STO;
      i2c_t_su_dat <= RST_I2C_T_SU_DAT;
      i2c_t_hd_dat <= RST_I2C_T_HD_DAT;
      i2c_t_buf <= RST_I2C_T_BUF;
      for (int i = 0; i < DatDepth; i++) begin
        dat_mem[i] <= '0;
      end
    end else begin
      sw_reset <= 0;
      if (wen_i) begin
        unique case (addr_i)
          ADDR_HC_CONTROL: begin
            hc_enable <= wdata_i[0];
            // SW_RESET only safe when HC_STATUS[FSM_IDLE]=1; see spec §HC_CONTROL[1]
            sw_reset  <= wdata_i[1];
          end
          ADDR_T_R: t_r <= wdata_i[19:0];
          ADDR_T_F: t_f <= wdata_i[19:0];
          ADDR_T_LOW: t_low <= wdata_i[19:0];
          ADDR_T_LOW_OD: t_low_od <= wdata_i[19:0];
          ADDR_T_HIGH: t_high <= wdata_i[19:0];
          ADDR_T_SU_STA: t_su_sta <= wdata_i[19:0];
          ADDR_T_HD_STA: t_hd_sta <= wdata_i[19:0];
          ADDR_T_SU_STO: t_su_sto <= wdata_i[19:0];
          ADDR_T_SU_DAT: t_su_dat <= wdata_i[19:0];
          ADDR_T_HD_DAT: t_hd_dat <= wdata_i[19:0];
          ADDR_T_BUS_FREE: t_bus_free <= wdata_i[19:0];
          ADDR_I2C_T_R: i2c_t_r <= wdata_i[19:0];
          ADDR_I2C_T_F: i2c_t_f <= wdata_i[19:0];
          ADDR_I2C_T_LOW: i2c_t_low <= wdata_i[19:0];
          ADDR_I2C_T_HIGH: i2c_t_high <= wdata_i[19:0];
          ADDR_I2C_T_SU_STA: i2c_t_su_sta <= wdata_i[19:0];
          ADDR_I2C_T_HD_STA: i2c_t_hd_sta <= wdata_i[19:0];
          ADDR_I2C_T_SU_STO: i2c_t_su_sto <= wdata_i[19:0];
          ADDR_I2C_T_SU_DAT: i2c_t_su_dat <= wdata_i[19:0];
          ADDR_I2C_T_HD_DAT: i2c_t_hd_dat <= wdata_i[19:0];
          ADDR_I2C_T_BUF: i2c_t_buf <= wdata_i[19:0];
          default: begin
            if (addr_i >= ADDR_DAT_BASE && addr_i <= (ADDR_DAT_END - 4)) begin
              dat_mem[(addr_i-ADDR_DAT_BASE)>>2] <= dat_entry_t'(wdata_i);
            end
          end
        endcase
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : cmd_write
    if (!rst_ni) begin
      cmd_staging_valid <= 1'b0;
      cmd_wvalid <= '0;
      cmd_dword0 <= '0;
      cmd_wdata <= '0;
    end else if (sw_reset || (cmd_wvalid && cmd_wready_i)) begin
      cmd_staging_valid <= 1'b0;
      cmd_wvalid <= '0;
    end else if (wen_i && (addr_i == ADDR_CMD_QUEUE) && !cmd_wvalid) begin
      if (!cmd_staging_valid) begin
        cmd_dword0 <= wdata_i;
        cmd_staging_valid <= 1'b1;
      end else begin
        cmd_wdata <= {wdata_i, cmd_dword0};
        cmd_wvalid <= 1'b1;
        cmd_staging_valid <= '0;
      end
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : tx_write
    if (!rst_ni) begin
      tx_wdata  <= '0;
      tx_wvalid <= '0;
    end else if (tx_wvalid && tx_wready_i) begin
      tx_wvalid <= '0;
    end else if (wen_i && (addr_i == ADDR_TX_DATA) && !tx_wvalid) begin
      tx_wdata  <= wdata_i;
      tx_wvalid <= 1'b1;
    end
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : reg_read_reg
    if (!rst_ni) rdata_q <= '0;
    else rdata_q <= rdata_d;
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) dat_rdata <= '0;
    else if (dat_read_valid_i) dat_rdata <= dat_mem[dat_index_i];
  end

  always_comb begin : reg_read_mux
    rdata_d    = '0;
    resp_rready = 1'b0;
    rx_rready   = 1'b0;
    if (ren_i) begin
      unique case (addr_i)
        ADDR_HC_CONTROL:   rdata_d = hc_control;
        ADDR_HC_STATUS:    rdata_d = hc_status;
        ADDR_T_R:          rdata_d = {12'b0, t_r};
        ADDR_T_F:          rdata_d = {12'b0, t_f};
        ADDR_T_LOW:        rdata_d = {12'b0, t_low};
        ADDR_T_LOW_OD:     rdata_d = {12'b0, t_low_od};
        ADDR_T_HIGH:       rdata_d = {12'b0, t_high};
        ADDR_T_SU_STA:     rdata_d = {12'b0, t_su_sta};
        ADDR_T_HD_STA:     rdata_d = {12'b0, t_hd_sta};
        ADDR_T_SU_STO:     rdata_d = {12'b0, t_su_sto};
        ADDR_T_SU_DAT:     rdata_d = {12'b0, t_su_dat};
        ADDR_T_HD_DAT:     rdata_d = {12'b0, t_hd_dat};
        ADDR_T_BUS_FREE:   rdata_d = {12'b0, t_bus_free};
        ADDR_I2C_T_R:      rdata_d = {12'b0, i2c_t_r};
        ADDR_I2C_T_F:      rdata_d = {12'b0, i2c_t_f};
        ADDR_I2C_T_LOW:    rdata_d = {12'b0, i2c_t_low};
        ADDR_I2C_T_HIGH:   rdata_d = {12'b0, i2c_t_high};
        ADDR_I2C_T_SU_STA: rdata_d = {12'b0, i2c_t_su_sta};
        ADDR_I2C_T_HD_STA: rdata_d = {12'b0, i2c_t_hd_sta};
        ADDR_I2C_T_SU_STO: rdata_d = {12'b0, i2c_t_su_sto};
        ADDR_I2C_T_SU_DAT: rdata_d = {12'b0, i2c_t_su_dat};
        ADDR_I2C_T_HD_DAT: rdata_d = {12'b0, i2c_t_hd_dat};
        ADDR_I2C_T_BUF:    rdata_d = {12'b0, i2c_t_buf};
        ADDR_RX_DATA: begin
          rx_rready = ren_i;
          if (rx_rvalid_i) rdata_d = rx_rdata_i;
        end
        ADDR_RESP: begin
          if (resp_rvalid_i) rdata_d = resp_rdata_i;
          resp_rready = ren_i;
        end
        ADDR_QUEUE_STATUS: rdata_d = queue_status;
        default: begin
          if (addr_i >= ADDR_DAT_BASE && addr_i <= (ADDR_DAT_END - 4))
            rdata_d = dat_mem[(addr_i-ADDR_DAT_BASE)>>2];
        end
      endcase
    end
  end

  assign ctrl_enable_o = hc_enable;
  assign i3c_fsm_en_o = hc_enable;
  assign sw_reset_o = sw_reset;
  assign rdata_o = rdata_q;
  assign dat_rdata_o = dat_rdata;
  assign rx_rready_o = rx_rready;
  assign resp_rready_o = resp_rready;

  assign t_r_o = t_r;
  assign t_f_o = t_f;
  assign t_low_o = t_low;
  assign t_low_od_o = t_low_od;
  assign t_high_o = t_high;
  assign t_su_sta_o = t_su_sta;
  assign t_hd_sta_o = t_hd_sta;
  assign t_su_sto_o = t_su_sto;
  assign t_su_dat_o = t_su_dat;
  assign t_hd_dat_o = t_hd_dat;
  assign t_bus_free_o = t_bus_free;
  assign i2c_t_r_o = i2c_t_r;
  assign i2c_t_f_o = i2c_t_f;
  assign i2c_t_low_o = i2c_t_low;
  assign i2c_t_high_o = i2c_t_high;
  assign i2c_t_su_sta_o = i2c_t_su_sta;
  assign i2c_t_hd_sta_o = i2c_t_hd_sta;
  assign i2c_t_su_sto_o = i2c_t_su_sto;
  assign i2c_t_su_dat_o = i2c_t_su_dat;
  assign i2c_t_hd_dat_o = i2c_t_hd_dat;
  assign i2c_t_buf_o = i2c_t_buf;

  assign ready_o = 1'b1;

  assign cmd_wvalid_o = cmd_wvalid;
  assign cmd_wdata_o = cmd_wdata;

  assign tx_wvalid_o = tx_wvalid;
  assign tx_wdata_o = tx_wdata;

  assign hc_control = {30'b0, sw_reset, hc_enable};
  assign hc_status = {29'b0, resp_empty_i, cmd_full_i, i3c_fsm_idle_i};
  assign queue_status = {
    24'b0,
    resp_empty_i,
    resp_full_i,
    rx_empty_i,
    rx_full_i,
    tx_empty_i,
    tx_full_i,
    cmd_empty_i,
    cmd_full_i
  };

endmodule
