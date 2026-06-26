package controller_pkg;

  // Transfer direction
  typedef enum logic {
    Write = 1'b0,
    Read  = 1'b1
  } cmd_transfer_dir_e;

  // Raw ACK/NACK bit value driven through bus_tx_req_value on an ACK slot.
  typedef enum logic [7:0] {
    ACK  = 8'h00,
    NACK = 8'h01
  } ack_nack_bit_e;

  // Simplified DAT entry (32-bit, down from 64-bit in reference)
  typedef struct packed {
    logic       device;           // [31]    1 = I2C legacy device
    logic [7:0] reserved_30_23;   // [30:23] Reserved
    logic [6:0] dynamic_address;  // [22:16] I3C dynamic address
    logic [8:0] reserved_15_7;    // [15:7]  Reserved
    logic [6:0] static_address;   // [6:0]   I2C static address
  } dat_entry_t;

  typedef struct packed {
    logic full;
    logic empty;
  } fifo_status_t;

  typedef struct packed {
    logic ctrl_enable;
    logic i3c_fsm_en;
    logic sw_reset;
    logic broadcast_header_enable;
    logic abort;
  } hc_control_cfg_t;
endpackage
