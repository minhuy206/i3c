package controller_pkg;

  // Transfer direction
  typedef enum logic {
    Write = 1'b0,
    Read  = 1'b1
  } cmd_transfer_dir_e;

  typedef enum logic [7:0] {
    ACK  = 8'h00,
    NACK = 8'h01
  } ack_nack_bit_e;

  // flow_active command-flow FSM states. Shared with flow_active_sva (property
  // checking) and DV vseqs (HDL backdoor state polling) so the encoding lives
  // in exactly one place.
  typedef enum logic [3:0] {
    Idle              = 4'd0,
    WaitForCmd        = 4'd1,
    FetchDAT          = 4'd2,
    WaitDAT           = 4'd3,
    I3CBcastHeader    = 4'd4,
    IssueImmediateCcc = 4'd5,
    FetchTxData       = 4'd6,
    InitWrite         = 4'd7,
    InitRead          = 4'd8,
    IssueDAA          = 4'd9,
    IssueI3CWrite     = 4'd10,
    IssueI2CWrite     = 4'd11,
    IssueI3CRead      = 4'd12,
    IssueI2CRead      = 4'd13,
    WriteResp         = 4'd14
  } flow_fsm_state_e;

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
