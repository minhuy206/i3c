package i3c_agent_pkg;
  import uvm_pkg::*;

  `include "uvm_macros.svh"
  `include "dv_macros.svh"

  typedef enum bit {
    Host,
    Device
  } if_mode_e;

  typedef enum bit {
    BusOpWrite = 1'b0,
    BusOpRead  = 1'b1
  } bus_op_e;

  typedef enum int {
    DrvIdle,
    DrvAddr,
    DrvAddrArbit,
    DrvAddrPushPull,
    DrvAck,
    DrvSelectNext,
    DrvWr,
    DrvWrPushPull,
    DrvRd,
    DrvRdPushPull,
    DrvStop,
    DrvStopPushPull,
    DrvDAA
  } i3c_drv_phase_e;

  typedef enum logic [7:0] {
    // Broadcast CCCs (Phase 1 scope)
    ENEC      = 8'h00,
    DISEC     = 8'h01,
    ENTDAA    = 8'h07,
    // Direct CCCs (Phase 1 scope)
    DIR_ENEC  = 8'h80,
    DIR_DISEC = 8'h81
  } i3c_ccc_e;

  typedef uvm_enum_wrapper#(i3c_ccc_e) i3c_ccc_wrapper;

  bit [1:0] defining_byte_for_CCC[logic [7:0]] = '{
      // {optional defining byte, required defining byte}
      8'h00 :
      2'b00,  // ENEC
      8'h01 : 2'b00,  // DISEC
      8'h07 : 2'b00,  // ENTDAA
      8'h80 : 2'b00,  // DIR_ENEC
      8'h81 : 2'b00  // DIR_DISEC
  };

  bit [1:0] data_for_CCC[logic [7:0]] = '{
      // {optional data, required data}
      8'h00 :
      2'b01,  // ENEC
      8'h01 : 2'b01,  // DISEC
      8'h07 : 2'b00,  // ENTDAA
      8'h80 : 2'b01,  // DIR_ENEC
      8'h81 : 2'b01  // DIR_DISEC
  };

  bit [1:0] subcmd_byte_for_CCC[logic [7:0]] = '{
      // {optional sub-command, required sub-command}
      8'h00 :
      2'b00,  // ENEC
      8'h01 : 2'b00,  // DISEC
      8'h07 : 2'b00,  // ENTDAA
      8'h80 : 2'b00,  // DIR_ENEC
      8'h81 : 2'b00  // DIR_DISEC
  };

  bit data_direction_for_CCC[logic [7:0]] = '{
      // 0 - host to device, 1 - device to host
      8'h00 :
      1'b0,  // ENEC
      8'h01 : 1'b0,  // DISEC
      8'h07 : 1'b0,  // ENTDAA
      8'h80 : 1'b0,  // DIR_ENEC
      8'h81 : 1'b0  // DIR_DISEC
  };

  typedef struct {
    int tHoldStop   = 1_300; // 1.3 us
    int tHoldStart  = 600;
    int tSetupStart = 600;
    int tSetupBit   = 100;
    int tHoldBit    = 0;
    int tClockPulse = 900;
    int tClockLow   = 1_600;
    int tSetupStop  = 1_300;
  } i2c_timing_t;

  i2c_timing_t i2c_400 = '{
      tHoldStop   : 1_300,  // 1.3 us
      tHoldStart  : 600,
      tSetupStart : 600,
      tSetupBit   : 100,
      tHoldBit    : 0,
      tClockPulse : 900,
      tClockLow   : 1_600,
      tSetupStop  : 1_300
  };

  typedef struct {
    int tHoldStop   = 1_300; // 1.3 us
    int tHoldStart  = 39;
    int tSetupStart = 20;
    int tHoldRStart = 20;
    int tSetupBit   = 3;
    int tHoldBit    = 0;
    int tClockPulse = 32;
    int tClockLowOD = 200;
    int tClockLowPP = 48;
    int tSetupStop  = 20;
  } i3c_timing_t;

  typedef struct {
    i2c_timing_t i2c_tc;
    i3c_timing_t i3c_tc;
  } bus_timing_t;

  typedef struct {
    bit [6:0] static_addr;
    bit       static_addr_valid;
    bit [6:0] dynamic_addr;
    bit       dynamic_addr_valid;

    bit [7:0]  bcr;
    bit [7:0]  dcr;
    bit [47:0] pid;
    bit [15:0] device_read_limit;
    bit [15:0] max_read_length;
    bit [15:0] device_write_limit;
    bit [15:0] max_write_length;
    bit [15:0] status;
  } I3C_device;

  typedef class i3c_item;
  typedef class i3c_seq_item;
  typedef class i3c_agent_cfg;

  `include "i3c_item.sv"
  `include "i3c_seq_item.sv"
  `include "i3c_agent_cfg.sv"
  `include "i3c_monitor.sv"
  `include "i3c_driver.sv"
  `include "i3c_sequencer.sv"
  `include "i3c_agent.sv"
  `include "seq_lib/i3c_seq_lib.sv"

endpackage : i3c_agent_pkg

