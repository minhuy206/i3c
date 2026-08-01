package i3c_agent_pkg;
  import i3c_pkg::I3C_RSVD_ADDR;
  import i3c_pkg::i3c_ccc_e;
  import i3c_pkg::ENEC;
  import i3c_pkg::DISEC;
  import i3c_pkg::ENTDAA;
  import i3c_pkg::DIR_ENEC;
  import i3c_pkg::DIR_DISEC;
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

  // Raw ACK/NACK bit stored in i3c_seq_item.data_nack_q for legacy I2C reads.
  typedef enum bit {
    SampledAck  = 1'b0,
    SampledNack = 1'b1
  } sampled_ack_nack_e;

  typedef enum int {
    DrvIdle,
    DrvAddr,
    DrvAddrPushPull,
    DrvAck,
    DrvSelectNext,
    DrvWr,
    DrvWrPushPull,
    DrvRd,
    DrvRdPushPull,
    DrvEntdaa,
    DrvStop,
    DrvBcastDispatch,
    DrvCccData
  } i3c_drv_phase_e;

  typedef enum int {
    ProtoCtxNone,
    ProtoCtxEntdaa,
    ProtoCtxDirectCcc,
    ProtoCtxBroadcastCcc
  } i3c_proto_ctx_e;

  typedef uvm_enum_wrapper#(i3c_ccc_e) i3c_ccc_wrapper;

  function string ccc_to_string(bit [7:0] ccc_raw);
    i3c_ccc_e ccc;
    string    ccc_name;

    ccc = i3c_ccc_e'(ccc_raw);
    ccc_name = ccc.name();
    return (ccc_name != "") ? ccc_name : $sformatf("0x%02h", ccc_raw);
  endfunction : ccc_to_string

  bit [1:0] defining_byte_for_CCC[logic [7:0]] = '{
      // {optional defining byte, required defining byte}
      ENEC :
      2'b00,
      DISEC : 2'b00,
      ENTDAA : 2'b00,
      DIR_ENEC : 2'b00,
      DIR_DISEC : 2'b00
  };

  bit [1:0] data_for_CCC[logic [7:0]] = '{
      // {optional data, required data}
      ENEC :
      2'b01,
      DISEC : 2'b01,
      ENTDAA : 2'b00,
      DIR_ENEC : 2'b01,
      DIR_DISEC : 2'b01
  };

  bit [1:0] subcmd_byte_for_CCC[logic [7:0]] = '{
      // {optional sub-command, required sub-command}
      ENEC :
      2'b00,
      DISEC : 2'b00,
      ENTDAA : 2'b00,
      DIR_ENEC : 2'b00,
      DIR_DISEC : 2'b00
  };

  bit data_direction_for_CCC[logic [7:0]] = '{
      // 0 - host to device, 1 - device to host
      ENEC :
      1'b0,
      DISEC : 1'b0,
      ENTDAA : 1'b0,
      DIR_ENEC : 1'b0,
      DIR_DISEC : 1'b0
  };

  typedef i3c_timing_pkg::i2c_timing_t i2c_timing_t;
  typedef i3c_timing_pkg::i3c_timing_t i3c_timing_t;
  typedef i3c_timing_pkg::bus_timing_t bus_timing_t;

  i2c_timing_t i2c_400 = i3c_timing_pkg::I2C_400;
  i3c_timing_t i3c_sdr = i3c_timing_pkg::I3C_SDR;

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
