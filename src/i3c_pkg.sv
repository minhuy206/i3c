// SPDX-License-Identifier: Apache-2.0
// Adapted from CHIPS Alliance i3c-core for simplified I3C Master Controller

package i3c_pkg;

  // Constants
  localparam logic [6:0] I3C_RSVD_ADDR = 7'h7E;
  localparam logic [7:0] I3C_RSVD_BYTE = 8'hFC;

  // DAT configuration
  localparam int unsigned DatDepth = 16;
  localparam int unsigned DatAw = $clog2(DatDepth);

  // Response error ID width
  localparam int unsigned RespErrIdWidth = 4;

  // ---------------------------------------------------------------------------
  // Bus Signal Types
  // ---------------------------------------------------------------------------

  // Individual signal state from bus_monitor
  typedef struct packed {
    logic value;
    logic pos_edge;
    logic neg_edge;
    logic stable_high;
    logic stable_low;
  } signal_state_t;

  // Composite bus state
  typedef struct packed {
    signal_state_t sda;
    signal_state_t scl;
    logic start_det;
    logic rstart_det;
    logic stop_det;
  } bus_state_t;

  // ---------------------------------------------------------------------------
  // Response Descriptor
  // ---------------------------------------------------------------------------

  // Response error status (See TCRI 7.1.3 Table 11 field ERR_STATUS)
  typedef enum logic [RespErrIdWidth-1:0] {
    Success                    = 4'b0000,
    Crc                        = 4'b0001,
    Parity                     = 4'b0010,
    Frame                      = 4'b0011,
    AddrHeader                 = 4'b0100,
    Nack                       = 4'b0101,
    Ovl                        = 4'b0110,
    I3cShortReadErr            = 4'b0111,
    HcAborted                  = 4'b1000,
    I2cDataNackOrI3cBusAborted = 4'b1001,
    NotSupported               = 4'b1010
  } i3c_resp_err_status_e;

  // Response descriptor (See TCRI 7.1.3 Table 11)
  typedef struct packed {
    i3c_resp_err_status_e err_status;  // [31:28]
    logic [3:0]           tid;         // [27:24]
    logic [7:0]           __rsvd23_16; // [23:16]
    logic [15:0]          data_length; // [15:0]
  } i3c_response_desc_t;

  // ---------------------------------------------------------------------------
  // Command Descriptor Types
  // ---------------------------------------------------------------------------

  // Command attribute types (See TCRI 7.1.2 Table 6)
  typedef enum logic [2:0] {
    RegularTransfer       = 3'b000,
    ImmediateDataTransfer = 3'b001,
    AddressAssignment     = 3'b010,
    ComboTransfer         = 3'b011
  } i3c_cmd_attr_e;

  // Data transfer speed and mode (See TCRI 7.1.1.1)
  typedef enum logic [2:0] {
    sdr0     = 3'b000,  // Standard SDR speed (up to 12.5 MHz)
    sdr1     = 3'b001,
    sdr2     = 3'b010,
    sdr3     = 3'b011,
    sdr4     = 3'b100,
    hdr_tsx  = 3'b101,
    hdr_ddr  = 3'b110,
    reserved = 3'b111
  } i3c_trans_mode_e;

  // Immediate transfer command descriptor (See TCRI 7.1.2.1)
  typedef struct packed {
    // DWORD 1
    logic [7:0] data_byte4;
    logic [7:0] data_byte3;
    logic [7:0] data_byte2;
    logic [7:0] def_or_data_byte1;

    // DWORD 0
    logic                toc;           // Terminate on completion
    logic                wroc;          // Response on completion
    logic                rnw;           // Direction (write-only for immediate)
    i3c_trans_mode_e     mode;
    logic [2:0]          dtt;           // Number of valid data bytes
    logic [1:0]          __rsvd22_21;
    logic [4:0]          dev_idx;
    logic                cp;            // Command present
    logic [7:0]          cmd;           // CCC / HDR command code
    logic [3:0]          tid;           // Transaction ID
    i3c_cmd_attr_e       attr;
  } immediate_data_trans_desc_t;

  // Regular transfer command descriptor (See TCRI 7.1.2.2)
  typedef struct packed {
    // DWORD 1
    logic [15:0] data_length;
    logic [7:0]  __rsvd47_40;
    logic [7:0]  def_byte;

    // DWORD 0
    logic                toc;
    logic                wroc;
    logic                rnw;
    i3c_trans_mode_e     mode;
    logic                dbp;           // Defining byte present
    logic                sre;           // Short read error
    logic [2:0]          __rsvd23_21;
    logic [4:0]          dev_idx;
    logic                cp;
    logic [7:0]          cmd;
    logic [3:0]          tid;
    i3c_cmd_attr_e       attr;
  } regular_trans_desc_t;

  // Combo transfer command descriptor (See TCRI 7.1.2.3)
  typedef struct packed {
    // DWORD 1
    logic [15:0] data_length;
    logic [15:0] offset;

    // DWORD 0
    logic                toc;
    logic                wroc;
    logic                rnw;
    i3c_trans_mode_e     mode;
    logic                sub_16_off;
    logic                fpm;
    logic [1:0]          dlp;
    logic                __rsvd21;
    logic [4:0]          dev_idx;
    logic                cp;
    logic [7:0]          cmd;
    logic [3:0]          tid;
    i3c_cmd_attr_e       attr;
  } combo_trans_desc_t;

  // Address assignment command descriptor (See TCRI 7.1.2.3)
  typedef struct packed {
    // DWORD 1
    logic [31:0] __rsvd63_32;

    // DWORD 0
    logic                toc;
    logic                wroc;
    logic [3:0]          dev_count;
    logic [4:0]          __rsvd25_21;
    logic [4:0]          dev_idx;
    logic                __rsvd15;
    logic [7:0]          cmd;
    logic [3:0]          tid;
    i3c_cmd_attr_e       attr;
  } addr_assign_desc_t;

endpackage
