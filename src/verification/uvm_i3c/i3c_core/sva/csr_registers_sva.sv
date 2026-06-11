module csr_registers_sva
  import controller_pkg::dat_entry_t;
#(
    parameter int unsigned DatDepth     = 16,
    parameter int unsigned AddrWidth    = 12,
    parameter int unsigned DataWidth    = 32,
    parameter int unsigned CmdDataWidth = 64,
    parameter int unsigned CounterWidth = 20,
    localparam int unsigned DatAw       = $clog2(DatDepth)
) (
    input logic clk_i,
    input logic rst_ni,

    input logic [AddrWidth-1:0] addr_i,
    input logic [DataWidth-1:0] wdata_i,
    input logic                 wen_i,
    input logic                 ren_i,
    input logic [DataWidth-1:0] rdata_o,
    input logic                 ready_o,

    input logic hc_enable_i,
    input logic sw_reset_i,
    input logic broadcast_addr_enable_i,

    input logic [DataWidth-1:0] hc_control_i,
    input logic [DataWidth-1:0] hc_status_i,
    input logic [DataWidth-1:0] queue_status_i,

    input logic                    cmd_wvalid_o,
    input logic [CmdDataWidth-1:0] cmd_wdata_o,
    input logic                    cmd_wready_i,
    input logic                    tx_wvalid_o,
    input logic [DataWidth-1:0]    tx_wdata_o,
    input logic                    tx_wready_i,
    input logic                    rx_rvalid_i,
    input logic [DataWidth-1:0]    rx_rdata_i,
    input logic                    rx_rready_o,
    input logic                    resp_rvalid_i,
    input logic [DataWidth-1:0]    resp_rdata_i,
    input logic                    resp_rready_o,

    input logic [CounterWidth-1:0] t_r_i,
    input logic [CounterWidth-1:0] t_f_i,
    input logic [CounterWidth-1:0] t_low_i,
    input logic [CounterWidth-1:0] t_low_od_i,
    input logic [CounterWidth-1:0] t_high_i,
    input logic [CounterWidth-1:0] t_su_sta_i,
    input logic [CounterWidth-1:0] t_hd_sta_i,
    input logic [CounterWidth-1:0] t_su_sto_i,
    input logic [CounterWidth-1:0] t_su_dat_i,
    input logic [CounterWidth-1:0] t_hd_dat_i,
    input logic [CounterWidth-1:0] t_bus_free_i,
    input logic [CounterWidth-1:0] i2c_t_r_i,
    input logic [CounterWidth-1:0] i2c_t_f_i,
    input logic [CounterWidth-1:0] i2c_t_low_i,
    input logic [CounterWidth-1:0] i2c_t_high_i,
    input logic [CounterWidth-1:0] i2c_t_su_sta_i,
    input logic [CounterWidth-1:0] i2c_t_hd_sta_i,
    input logic [CounterWidth-1:0] i2c_t_su_sto_i,
    input logic [CounterWidth-1:0] i2c_t_su_dat_i,
    input logic [CounterWidth-1:0] i2c_t_hd_dat_i,
    input logic [CounterWidth-1:0] i2c_t_buf_i,

    input dat_entry_t dat_mem_i[DatDepth],
    input logic                 dat_read_valid_i,
    input logic [    DatAw-1:0] dat_index_i,
    input logic [DataWidth-1:0] dat_rdata_o,

    input logic cmd_full_i,
    input logic cmd_empty_i,
    input logic tx_full_i,
    input logic tx_empty_i,
    input logic rx_full_i,
    input logic rx_empty_i,
    input logic resp_full_i,
    input logic resp_empty_i,
    input logic i3c_fsm_idle_i,

    input logic                    cmd_staging_valid_i,
    input logic [DataWidth-1:0]    cmd_dword0_i,
    input logic                    cmd_wvalid_int_i,
    input logic [CmdDataWidth-1:0] cmd_wdata_int_i,
    input logic                    tx_wvalid_int_i,
    input logic [DataWidth-1:0]    tx_wdata_int_i
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
  localparam logic [AddrWidth-1:0] ADDR_DAT_END =
      ADDR_DAT_BASE + AddrWidth'(DatDepth * 4);
  localparam int unsigned QS_CMD_FULL_BIT = 0;
  localparam int unsigned QS_CMD_EMPTY_BIT = 1;
  localparam int unsigned QS_TX_FULL_BIT = 2;
  localparam int unsigned QS_TX_EMPTY_BIT = 3;
  localparam int unsigned QS_RX_FULL_BIT = 4;
  localparam int unsigned QS_RX_EMPTY_BIT = 5;
  localparam int unsigned QS_RESP_FULL_BIT = 6;
  localparam int unsigned QS_RESP_EMPTY_BIT = 7;

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

  logic csr_written_since_reset_q;
  logic reset_default_addr_valid;
  logic [DataWidth-1:0] reset_default_rdata;
  logic timing_reset_defaults_match;
  logic status_reset_defaults_match;
  logic queue_reset_defaults_match;
  logic hc_control_write;
  logic hc_control_read;
  logic queue_status_read;
  logic csr_bus_known;
  logic cmd_queue_write;
  logic tx_data_write;
  logic cmd_queue_blocked;
  logic tx_data_blocked;
  logic rx_data_read;
  logic resp_read;
  logic repeated_sw_reset_write;
  logic [DataWidth-1:0] dat_hw_read_exp;

  always_comb begin : compute_dat_hw_read_expected
    dat_hw_read_exp = dat_mem_i[dat_index_i];
  end

  always_ff @(posedge clk_i or negedge rst_ni) begin : track_csr_write_after_reset
    if (!rst_ni) csr_written_since_reset_q <= 1'b0;
    else if (wen_i) csr_written_since_reset_q <= 1'b1;
  end

  always_comb begin : compute_reset_default_readback
    reset_default_addr_valid = 1'b1;
    reset_default_rdata      = '0;

    unique case (addr_i)
      ADDR_HC_CONTROL: reset_default_rdata = 32'h0000_0000;
      ADDR_HC_STATUS: reset_default_rdata = 32'h0000_0005;
      ADDR_T_R: reset_default_rdata = RST_T_R;
      ADDR_T_F: reset_default_rdata = RST_T_F;
      ADDR_T_LOW: reset_default_rdata = RST_T_LOW;
      ADDR_T_LOW_OD: reset_default_rdata = RST_T_LOW_OD;
      ADDR_T_HIGH: reset_default_rdata = RST_T_HIGH;
      ADDR_T_SU_STA: reset_default_rdata = RST_T_SU_STA;
      ADDR_T_HD_STA: reset_default_rdata = RST_T_HD_STA;
      ADDR_T_SU_STO: reset_default_rdata = RST_T_SU_STO;
      ADDR_T_SU_DAT: reset_default_rdata = RST_T_SU_DAT;
      ADDR_T_HD_DAT: reset_default_rdata = RST_T_HD_DAT;
      ADDR_T_BUS_FREE: reset_default_rdata = RST_T_BUS_FREE;
      ADDR_I2C_T_R: reset_default_rdata = RST_I2C_T_R;
      ADDR_I2C_T_F: reset_default_rdata = RST_I2C_T_F;
      ADDR_I2C_T_LOW: reset_default_rdata = RST_I2C_T_LOW;
      ADDR_I2C_T_HIGH: reset_default_rdata = RST_I2C_T_HIGH;
      ADDR_I2C_T_SU_STA: reset_default_rdata = RST_I2C_T_SU_STA;
      ADDR_I2C_T_HD_STA: reset_default_rdata = RST_I2C_T_HD_STA;
      ADDR_I2C_T_SU_STO: reset_default_rdata = RST_I2C_T_SU_STO;
      ADDR_I2C_T_SU_DAT: reset_default_rdata = RST_I2C_T_SU_DAT;
      ADDR_I2C_T_HD_DAT: reset_default_rdata = RST_I2C_T_HD_DAT;
      ADDR_I2C_T_BUF: reset_default_rdata = RST_I2C_T_BUF;
      ADDR_QUEUE_STATUS: reset_default_rdata = 32'h0000_00AA;
      default: begin
        if ((addr_i >= ADDR_DAT_BASE) && (addr_i <= (ADDR_DAT_END - 4))) begin
          reset_default_rdata = '0;
        end else begin
          reset_default_addr_valid = 1'b0;
        end
      end
    endcase
  end

  assign timing_reset_defaults_match =
      (t_r_i == RST_T_R) &&
      (t_f_i == RST_T_F) &&
      (t_low_i == RST_T_LOW) &&
      (t_low_od_i == RST_T_LOW_OD) &&
      (t_high_i == RST_T_HIGH) &&
      (t_su_sta_i == RST_T_SU_STA) &&
      (t_hd_sta_i == RST_T_HD_STA) &&
      (t_su_sto_i == RST_T_SU_STO) &&
      (t_su_dat_i == RST_T_SU_DAT) &&
      (t_hd_dat_i == RST_T_HD_DAT) &&
      (t_bus_free_i == RST_T_BUS_FREE) &&
      (i2c_t_r_i == RST_I2C_T_R) &&
      (i2c_t_f_i == RST_I2C_T_F) &&
      (i2c_t_low_i == RST_I2C_T_LOW) &&
      (i2c_t_high_i == RST_I2C_T_HIGH) &&
      (i2c_t_su_sta_i == RST_I2C_T_SU_STA) &&
      (i2c_t_hd_sta_i == RST_I2C_T_HD_STA) &&
      (i2c_t_su_sto_i == RST_I2C_T_SU_STO) &&
      (i2c_t_su_dat_i == RST_I2C_T_SU_DAT) &&
      (i2c_t_hd_dat_i == RST_I2C_T_HD_DAT) &&
      (i2c_t_buf_i == RST_I2C_T_BUF);

  assign status_reset_defaults_match =
      i3c_fsm_idle_i && !cmd_full_i && resp_empty_i && (hc_status_i == 32'h0000_0005);

  assign queue_reset_defaults_match =
      !cmd_full_i && cmd_empty_i &&
      !tx_full_i && tx_empty_i &&
      !rx_full_i && rx_empty_i &&
      !resp_full_i && resp_empty_i &&
      (queue_status_i == 32'h0000_00AA);

  assign hc_control_write = wen_i && (addr_i == ADDR_HC_CONTROL);
  assign hc_control_read  = ren_i && !wen_i && (addr_i == ADDR_HC_CONTROL);
  assign queue_status_read = ren_i && !wen_i && (addr_i == ADDR_QUEUE_STATUS);
  assign csr_bus_known = !$isunknown({addr_i, wen_i, ren_i});
  assign cmd_queue_write = wen_i && (addr_i == ADDR_CMD_QUEUE);
  assign tx_data_write = wen_i && (addr_i == ADDR_TX_DATA);
  assign cmd_queue_blocked = cmd_queue_write && (cmd_wvalid_int_i || sw_reset_i);
  assign tx_data_blocked = tx_data_write && (tx_wvalid_int_i || sw_reset_i);
  assign rx_data_read = ren_i && (addr_i == ADDR_RX_DATA);
  assign resp_read = ren_i && (addr_i == ADDR_RESP);
  assign repeated_sw_reset_write = hc_control_write && wdata_i[1];

  ap_ready_backpressure_only:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   ready_o == !(cmd_queue_blocked || tx_data_blocked))
  else $error("csr_registers_sva: ready_o may deassert only for blocked CMD_QUEUE/TX_DATA writes");

  cp_ready_cmd_backpressure:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  cmd_queue_blocked && !ready_o);

  cp_ready_tx_backpressure:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  tx_data_blocked && !ready_o);

  ap_hc_status_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_status_i == {29'b0, resp_empty_i, cmd_full_i, i3c_fsm_idle_i})
  else $error("csr_registers_sva: HC_STATUS mirror mismatch");

  cp_hc_status_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_status_i == {29'b0, resp_empty_i, cmd_full_i, i3c_fsm_idle_i});

  ap_queue_status_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   queue_status_i == {24'b0, resp_empty_i, resp_full_i, rx_empty_i, rx_full_i,
                                      tx_empty_i, tx_full_i, cmd_empty_i, cmd_full_i})
  else $error("csr_registers_sva: QUEUE_STATUS mirror mismatch");

  cp_queue_status_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  queue_status_i == {24'b0, resp_empty_i, resp_full_i, rx_empty_i, rx_full_i,
                                     tx_empty_i, tx_full_i, cmd_empty_i, cmd_full_i});

  cp_queue_status_cmd_empty_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !cmd_full_i && cmd_empty_i
                  ##1 (!rdata_o[QS_CMD_FULL_BIT] && rdata_o[QS_CMD_EMPTY_BIT]));

  cp_queue_status_cmd_middle_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !cmd_full_i && !cmd_empty_i
                  ##1 (!rdata_o[QS_CMD_FULL_BIT] && !rdata_o[QS_CMD_EMPTY_BIT]));

  cp_queue_status_cmd_full_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && cmd_full_i && !cmd_empty_i
                  ##1 (rdata_o[QS_CMD_FULL_BIT] && !rdata_o[QS_CMD_EMPTY_BIT]));

  cp_queue_status_tx_empty_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !tx_full_i && tx_empty_i
                  ##1 (!rdata_o[QS_TX_FULL_BIT] && rdata_o[QS_TX_EMPTY_BIT]));

  cp_queue_status_tx_middle_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !tx_full_i && !tx_empty_i
                  ##1 (!rdata_o[QS_TX_FULL_BIT] && !rdata_o[QS_TX_EMPTY_BIT]));

  cp_queue_status_tx_full_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && tx_full_i && !tx_empty_i
                  ##1 (rdata_o[QS_TX_FULL_BIT] && !rdata_o[QS_TX_EMPTY_BIT]));

  cp_queue_status_rx_empty_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !rx_full_i && rx_empty_i
                  ##1 (!rdata_o[QS_RX_FULL_BIT] && rdata_o[QS_RX_EMPTY_BIT]));

  cp_queue_status_rx_middle_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !rx_full_i && !rx_empty_i
                  ##1 (!rdata_o[QS_RX_FULL_BIT] && !rdata_o[QS_RX_EMPTY_BIT]));

  cp_queue_status_rx_full_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && rx_full_i && !rx_empty_i
                  ##1 (rdata_o[QS_RX_FULL_BIT] && !rdata_o[QS_RX_EMPTY_BIT]));

  cp_queue_status_resp_empty_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !resp_full_i && resp_empty_i
                  ##1 (!rdata_o[QS_RESP_FULL_BIT] && rdata_o[QS_RESP_EMPTY_BIT]));

  cp_queue_status_resp_middle_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && !resp_full_i && !resp_empty_i
                  ##1 (!rdata_o[QS_RESP_FULL_BIT] && !rdata_o[QS_RESP_EMPTY_BIT]));

  cp_queue_status_resp_full_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  queue_status_read && resp_full_i && !resp_empty_i
                  ##1 (rdata_o[QS_RESP_FULL_BIT] && !rdata_o[QS_RESP_EMPTY_BIT]));

  ap_hc_control_reset_defaults:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   $rose(rst_ni) |-> ((hc_control_i == 32'h0000_0000) &&
                                      !hc_enable_i && !sw_reset_i &&
                                      !broadcast_addr_enable_i))
  else $error("csr_registers_sva: HC_CONTROL reset defaults mismatch");

  cp_hc_control_reset_defaults:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  $rose(rst_ni) && (hc_control_i == 32'h0000_0000) &&
                  !hc_enable_i && !sw_reset_i && !broadcast_addr_enable_i);

  ap_hc_control_write_updates_bits:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_control_write
                   |=> ((hc_enable_i == $past(wdata_i[0])) &&
                        (sw_reset_i == $past(wdata_i[1])) &&
                        (broadcast_addr_enable_i == $past(wdata_i[2])) &&
                        (hc_control_i == {29'b0, $past(wdata_i[2]),
                                          $past(wdata_i[1]), $past(wdata_i[0])})))
  else $error("csr_registers_sva: HC_CONTROL write did not update control bits");

  cp_hc_control_write_updates_bits:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_control_write
                  ##1 ((hc_enable_i == $past(wdata_i[0])) &&
                       (sw_reset_i == $past(wdata_i[1])) &&
                       (broadcast_addr_enable_i == $past(wdata_i[2]))));

  ap_broadcast_addr_enable_does_not_enable_hc:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_control_write && wdata_i[2] && !wdata_i[0]
                   |=> (!hc_enable_i && broadcast_addr_enable_i))
  else $error("csr_registers_sva: BROADCAST_ADDR_ENABLE write must not enable HC");

  cp_broadcast_addr_enable_does_not_enable_hc:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_control_write && wdata_i[2] && !wdata_i[0]
                  ##1 (!hc_enable_i && broadcast_addr_enable_i));

  ap_hc_control_readback:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   hc_control_read |=> (rdata_o == $past(hc_control_i)))
  else $error("csr_registers_sva: HC_CONTROL readback mismatch");

  cp_hc_control_readback:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  hc_control_read ##1 (rdata_o == $past(hc_control_i)));

  ap_sw_reset_self_clear:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   sw_reset_i && !repeated_sw_reset_write |=> !sw_reset_i)
  else $error("csr_registers_sva: SW_RESET must self-clear without another reset write");

  cp_sw_reset_self_clear:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  sw_reset_i && !repeated_sw_reset_write ##1 !sw_reset_i);

  ap_cmd_wvalid_output_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   cmd_wvalid_o == cmd_wvalid_int_i)
  else $error("csr_registers_sva: cmd_wvalid_o must mirror internal cmd_wvalid");

  cp_cmd_wvalid_output_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  cmd_wvalid_o == cmd_wvalid_int_i);

  ap_cmd_wdata_output_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   cmd_wdata_o == cmd_wdata_int_i)
  else $error("csr_registers_sva: cmd_wdata_o must mirror internal cmd_wdata");

  cp_cmd_wdata_output_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  cmd_wdata_o == cmd_wdata_int_i);

  ap_tx_wvalid_output_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   tx_wvalid_o == tx_wvalid_int_i)
  else $error("csr_registers_sva: tx_wvalid_o must mirror internal tx_wvalid");

  cp_tx_wvalid_output_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  tx_wvalid_o == tx_wvalid_int_i);

  ap_tx_wdata_output_mirror:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   tx_wdata_o == tx_wdata_int_i)
  else $error("csr_registers_sva: tx_wdata_o must mirror internal tx_wdata");

  cp_tx_wdata_output_mirror:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  tx_wdata_o == tx_wdata_int_i);

  ap_cmd_first_write_stages_dword0:
  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                   cmd_queue_write && !cmd_wvalid_int_i && !cmd_staging_valid_i
                   |=> (cmd_staging_valid_i && !cmd_wvalid_int_i &&
                        (cmd_dword0_i == $past(wdata_i))))
  else $error("csr_registers_sva: first CMD_QUEUE write must stage DWORD0 only");

  cp_cmd_first_write_stages_dword0:
  cover property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                  cmd_queue_write && !cmd_wvalid_int_i && !cmd_staging_valid_i
                  ##1 (cmd_staging_valid_i && !cmd_wvalid_int_i &&
                       (cmd_dword0_i == $past(wdata_i))));

  ap_cmd_second_write_emits_command:
  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                   cmd_queue_write && !cmd_wvalid_int_i && cmd_staging_valid_i
                   |=> (!cmd_staging_valid_i && cmd_wvalid_int_i &&
                        (cmd_wdata_int_i == {$past(wdata_i), $past(cmd_dword0_i)})))
  else $error("csr_registers_sva: second CMD_QUEUE write must emit staged command");

  cp_cmd_second_write_emits_command:
  cover property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                  cmd_queue_write && !cmd_wvalid_int_i && cmd_staging_valid_i
                  ##1 (!cmd_staging_valid_i && cmd_wvalid_int_i &&
                       (cmd_wdata_int_i == {$past(wdata_i), $past(cmd_dword0_i)})));

  ap_cmd_non_cmd_write_preserves_staging:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   !sw_reset_i && cmd_staging_valid_i && !cmd_wvalid_int_i && wen_i &&
                   (addr_i != ADDR_CMD_QUEUE)
                   |=> (cmd_staging_valid_i && (cmd_dword0_i == $past(cmd_dword0_i))))
  else $error("csr_registers_sva: non-CMD writes must not disturb CMD staging");

  cp_cmd_non_cmd_write_preserves_staging:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  !sw_reset_i && cmd_staging_valid_i && !cmd_wvalid_int_i && wen_i &&
                  (addr_i != ADDR_CMD_QUEUE)
                  ##1 (cmd_staging_valid_i && (cmd_dword0_i == $past(cmd_dword0_i))));

  ap_cmd_wdata_stable_until_ready:
  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   cmd_wvalid_int_i && !cmd_wready_i
                   |=> (cmd_wvalid_int_i && (cmd_wdata_int_i == $past(cmd_wdata_int_i))))
  else $error("csr_registers_sva: CMD write data changed before ready");

  cp_cmd_wdata_stable_until_ready:
  cover property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                  cmd_wvalid_int_i && !cmd_wready_i
                  ##1 (cmd_wvalid_int_i && (cmd_wdata_int_i == $past(cmd_wdata_int_i))));

  ap_sw_reset_clears_cmd_staging:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sw_reset_i |=> (!cmd_staging_valid_i && !cmd_wvalid_int_i))
  else $error("csr_registers_sva: SW_RESET must clear CMD staging and valid");

  cp_sw_reset_clears_cmd_staging:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  sw_reset_i ##1 (!cmd_staging_valid_i && !cmd_wvalid_int_i));

  ap_sw_reset_clears_tx_pending:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   sw_reset_i |=> (!tx_wvalid_int_i && (tx_wdata_int_i == '0)))
  else $error("csr_registers_sva: SW_RESET must clear pending TX write");

  cp_sw_reset_clears_tx_pending:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  sw_reset_i ##1 (!tx_wvalid_int_i && (tx_wdata_int_i == '0)));

  ap_tx_data_write_captures_data:
  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                   tx_data_write && !tx_wvalid_int_i
                   |=> (tx_wvalid_int_i && (tx_wdata_int_i == $past(wdata_i))))
  else $error("csr_registers_sva: TX_DATA write must raise tx_wvalid with written data");

  cp_tx_data_write_captures_data:
  cover property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i || !csr_bus_known)
                  tx_data_write && !tx_wvalid_int_i
                  ##1 (tx_wvalid_int_i && (tx_wdata_int_i == $past(wdata_i))));

  ap_tx_wdata_stable_until_ready:
  assert property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                   tx_wvalid_int_i && !tx_wready_i
                   |=> (tx_wvalid_int_i && (tx_wdata_int_i == $past(tx_wdata_int_i))))
  else $error("csr_registers_sva: TX write data changed before ready");

  cp_tx_wdata_stable_until_ready:
  cover property (@(posedge clk_i) disable iff (!rst_ni || sw_reset_i)
                  tx_wvalid_int_i && !tx_wready_i
                  ##1 (tx_wvalid_int_i && (tx_wdata_int_i == $past(tx_wdata_int_i))));

  ap_tx_valid_clears_on_ready:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   tx_wvalid_int_i && tx_wready_i |=> !tx_wvalid_int_i)
  else $error("csr_registers_sva: tx_wvalid must clear when TX accepts data");

  cp_tx_valid_clears_on_ready:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  tx_wvalid_int_i && tx_wready_i ##1 !tx_wvalid_int_i);

  ap_rx_rready_only_rx_read:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   rx_rready_o == rx_data_read)
  else $error("csr_registers_sva: rx_rready_o must pulse only for RX_DATA reads");

  cp_rx_rready_only_rx_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  rx_rready_o == rx_data_read);

  ap_resp_rready_only_resp_read:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   resp_rready_o == resp_read)
  else $error("csr_registers_sva: resp_rready_o must pulse only for RESP reads");

  cp_resp_rready_only_resp_read:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  resp_rready_o == resp_read);

  ap_rx_read_returns_fifo_data:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   rx_data_read && rx_rvalid_i |=> (rdata_o == $past(rx_rdata_i)))
  else $error("csr_registers_sva: RX_DATA read must return RX FIFO data");

  cp_rx_read_returns_fifo_data:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  rx_data_read && rx_rvalid_i ##1 (rdata_o == $past(rx_rdata_i)));

  ap_rx_empty_read_returns_zero:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   rx_data_read && !rx_rvalid_i |=> (rdata_o == '0))
  else $error("csr_registers_sva: empty RX_DATA read must return zero");

  cp_rx_empty_read_returns_zero:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  rx_data_read && !rx_rvalid_i ##1 (rdata_o == '0));

  ap_resp_read_returns_fifo_data:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   resp_read && resp_rvalid_i |=> (rdata_o == $past(resp_rdata_i)))
  else $error("csr_registers_sva: RESP read must return RESP FIFO data");

  cp_resp_read_returns_fifo_data:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  resp_read && resp_rvalid_i ##1 (rdata_o == $past(resp_rdata_i)));

  ap_resp_empty_read_returns_zero:
  assert property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                   resp_read && !resp_rvalid_i |=> (rdata_o == '0))
  else $error("csr_registers_sva: empty RESP read must return zero");

  cp_resp_empty_read_returns_zero:
  cover property (@(posedge clk_i) disable iff (!rst_ni || !csr_bus_known)
                  resp_read && !resp_rvalid_i ##1 (rdata_o == '0));

  ap_timing_reset_defaults:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   $rose(rst_ni) |-> timing_reset_defaults_match)
  else $error("csr_registers_sva: timing register reset defaults mismatch");

  cp_timing_reset_defaults:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  $rose(rst_ni) && timing_reset_defaults_match);

  ap_status_reset_defaults:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   $rose(rst_ni) |-> status_reset_defaults_match)
  else $error("csr_registers_sva: HC_STATUS reset defaults mismatch");

  cp_status_reset_defaults:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  $rose(rst_ni) && status_reset_defaults_match);

  ap_queue_reset_defaults:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   $rose(rst_ni) |-> queue_reset_defaults_match)
  else $error("csr_registers_sva: QUEUE_STATUS reset defaults mismatch");

  cp_queue_reset_defaults:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  $rose(rst_ni) && queue_reset_defaults_match);

  ap_reset_default_readback:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   ren_i && !wen_i && !csr_written_since_reset_q && reset_default_addr_valid
                   |=> (rdata_o == $past(reset_default_rdata)))
  else $error("csr_registers_sva: reset-default CSR readback mismatch");

  cp_reset_default_readback:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  ren_i && !wen_i && !csr_written_since_reset_q && reset_default_addr_valid
                  ##1 (rdata_o == $past(reset_default_rdata)));

  ap_dat_hw_read_latency:
  assert property (@(posedge clk_i) disable iff (!rst_ni)
                   dat_read_valid_i |=> (dat_rdata_o == $past(dat_hw_read_exp)))
  else $error("csr_registers_sva: DAT hardware read latency/data mismatch");

  cp_dat_hw_read_latency:
  cover property (@(posedge clk_i) disable iff (!rst_ni)
                  dat_read_valid_i ##1 (dat_rdata_o == $past(dat_hw_read_exp)));

  for (genvar i = 0; i < DatDepth; i++) begin : gen_dat_reserved_zero
    ap_dat_reserved_fields_zero:
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                     (dat_mem_i[i].reserved_15_7 == '0) &&
                     (dat_mem_i[i].reserved_30_23 == '0))
    else $error("csr_registers_sva: DAT[%0d] reserved fields are not zero", i);

    cp_dat_reserved_fields_zero:
    cover property (@(posedge clk_i) disable iff (!rst_ni)
                    (dat_mem_i[i].reserved_15_7 == '0) &&
                    (dat_mem_i[i].reserved_30_23 == '0));
  end

  for (genvar i = 0; i < DatDepth; i++) begin : gen_dat_reset_defaults
    ap_dat_reset_default:
    assert property (@(posedge clk_i) disable iff (!rst_ni)
                     $rose(rst_ni) |-> (dat_mem_i[i] == dat_entry_t'('0)))
    else $error("csr_registers_sva: DAT[%0d] reset default mismatch", i);

    cp_dat_reset_default:
    cover property (@(posedge clk_i) disable iff (!rst_ni)
                    $rose(rst_ni) && (dat_mem_i[i] == dat_entry_t'('0)));
  end

endmodule

bind csr_registers csr_registers_sva #(
    .DatDepth(DatDepth),
    .AddrWidth(AddrWidth),
    .DataWidth(DataWidth),
    .CmdDataWidth(CmdDataWidth),
    .CounterWidth(CounterWidth)
) u_csr_registers_sva (
    .clk_i,
    .rst_ni,
    .addr_i,
    .wdata_i,
    .wen_i,
    .ren_i,
    .rdata_o,
    .ready_o,
    .hc_enable_i(hc_enable),
    .sw_reset_i(sw_reset),
    .broadcast_addr_enable_i(broadcast_addr_enable),
    .hc_control_i(hc_control),
    .hc_status_i(hc_status),
    .queue_status_i(queue_status),
    .cmd_wvalid_o,
    .cmd_wdata_o,
    .cmd_wready_i,
    .tx_wvalid_o,
    .tx_wdata_o,
    .tx_wready_i,
    .rx_rvalid_i,
    .rx_rdata_i,
    .rx_rready_o,
    .resp_rvalid_i,
    .resp_rdata_i,
    .resp_rready_o,
    .t_r_i(t_r),
    .t_f_i(t_f),
    .t_low_i(t_low),
    .t_low_od_i(t_low_od),
    .t_high_i(t_high),
    .t_su_sta_i(t_su_sta),
    .t_hd_sta_i(t_hd_sta),
    .t_su_sto_i(t_su_sto),
    .t_su_dat_i(t_su_dat),
    .t_hd_dat_i(t_hd_dat),
    .t_bus_free_i(t_bus_free),
    .i2c_t_r_i(i2c_t_r),
    .i2c_t_f_i(i2c_t_f),
    .i2c_t_low_i(i2c_t_low),
    .i2c_t_high_i(i2c_t_high),
    .i2c_t_su_sta_i(i2c_t_su_sta),
    .i2c_t_hd_sta_i(i2c_t_hd_sta),
    .i2c_t_su_sto_i(i2c_t_su_sto),
    .i2c_t_su_dat_i(i2c_t_su_dat),
    .i2c_t_hd_dat_i(i2c_t_hd_dat),
    .i2c_t_buf_i(i2c_t_buf),
    .dat_mem_i(dat_mem),
    .dat_read_valid_i,
    .dat_index_i,
    .dat_rdata_o,
    .cmd_full_i,
    .cmd_empty_i,
    .tx_full_i,
    .tx_empty_i,
    .rx_full_i,
    .rx_empty_i,
    .resp_full_i,
    .resp_empty_i,
    .i3c_fsm_idle_i,
    .cmd_staging_valid_i(cmd_staging_valid),
    .cmd_dword0_i(cmd_dword0),
    .cmd_wvalid_int_i(cmd_wvalid),
    .cmd_wdata_int_i(cmd_wdata),
    .tx_wvalid_int_i(tx_wvalid),
    .tx_wdata_int_i(tx_wdata)
);
