module ccc
  import i3c_pkg::*;  
  import controller_pkg::*;
#(
) (
  input logic clk_i,
  input logic rst_ni,

  input logic [7:0] ccc_i,
  input logic ccc_valid_i,
  input logic [7:0] def_byte_i,
  input logic [6:0] dev_addr_i,
  input logic [3:0] dev_count_i,
  output logic done_o,
  output logic invalid_ccc_o,

  input logic bus_tx_done_i,
  input logic bus_tx_idle_i,
  output logic bus_tx_req_byte_o,
  output logic bus_tx_req_bit_o,
  output logic [7:0] bus_tx_req_value_o
  output logic bus_tx_sel_od_pp_o,

  input logic [7:0] bus_rx_data_i,
  input logic bus_rx_done_i,
  output logic bus_rx_req_bit_o,
  output logic bus_rx_req_byte_o,

  input logic bus_start_det_i,
  input logic bus_rstart_det_i,
  input logic bus_stop_det_i,

  output logic [6:0] daa_address_o,
  output logic daa_address_valid_o,
  output logic [47:0] daa_pid_o,
  output logic [7:0] daa_bcr_o,
  output logic [7:0] daa_dcr_o,
);
  
endmodule