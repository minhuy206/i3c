// SPDX-License-Identifier: Apache-2.0
// Adapted from CHIPS Alliance i3c-core for simplified I3C Master Controller

package controller_pkg;

  // Transfer direction
  typedef enum logic {
    Write = 1'b0,
    Read  = 1'b1
  } cmd_transfer_dir_e;

  // Simplified DAT entry (32-bit, down from 64-bit in reference)
  typedef struct packed {
    logic        device;           // [31]    1 = I2C legacy device
    logic [7:0]  reserved_30_23;   // [30:23] Reserved
    logic [6:0]  dynamic_address;  // [22:16] I3C dynamic address
    logic [8:0]  reserved_15_7;    // [15:7]  Reserved
    logic [6:0]  static_address;   // [6:0]   I2C static address
  } dat_entry_t;

endpackage
