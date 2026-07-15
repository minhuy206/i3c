class i3c_coverage extends uvm_subscriber #(i3c_item);
  `uvm_component_utils(i3c_coverage)

  typedef enum bit [1:0] {
    ADDR_BROADCAST,
    ADDR_I3C_DYNAMIC,
    ADDR_I2C_STATIC,
    ADDR_RESERVED_OTHER
  } bus_addr_class_e;

  typedef enum bit {
    START_FROM_START,
    START_FROM_RSTART
  } start_source_e;

  typedef enum bit {
    CCC_BROADCAST,
    CCC_DIRECT
  } ccc_form_e;

  typedef enum bit [2:0] {
    ACCEPTED,
    ADDR_REJECTED,
    NO_DEVICE,
    ID_INTERRUPTED,
    OTHER
  } daa_round_outcome_e;

  typedef enum bit [1:0] {
    ADDR_LOW_VALID,
    ADDR_MIDDLE_VALID,
    ADDR_HIGH_VALID,
    ADDR_RESERVED
  } daa_assigned_addr_class_e;

  bit                             protocol;
  bus_op_e                        bus_op;
  bit                       [6:0] addr;
  bus_addr_class_e                addr_class;
  bit                             addr_nack;
  start_source_e                  start_source;

  int unsigned                    actual_len;
  int unsigned                    final_remainder;
  bus_op_e                        previous_op;
  bus_op_e                        current_op;
  bit                             previous_private_valid;

  ccc_form_e                      ccc_form;
  bit                       [7:0] ccc_opcode;
  bit                             ccc_target_nack;

  daa_round_outcome_e             daa_round_outcome;
  daa_assigned_addr_class_e       daa_assigned_addr_class;

  covergroup cg_address_phase;
    option.per_instance = 1;

    cp_addr_class: coverpoint addr_class {
      bins broadcast = {ADDR_BROADCAST};
      bins i3c_dynamic = {ADDR_I3C_DYNAMIC};
      bins i2c_static = {ADDR_I2C_STATIC};
      bins reserved_other = {ADDR_RESERVED_OTHER};
    }

    cp_addr_nack: coverpoint addr_nack {bins ack = {0}; bins nack = {1};}

    cp_start_source: coverpoint start_source {
      bins start = {START_FROM_START}; bins repeated_start = {START_FROM_RSTART};
    }

    cp_i2c_static_addr_range: coverpoint addr iff (!protocol) {
      bins low = {[7'h08 : 7'h1f]}; bins mid = {[7'h20 : 7'h5f]}; bins high = {[7'h60 : 7'h77]};
    }

    cx_addr_class_nack: cross cp_addr_class, cp_addr_nack{
      ignore_bins reserved_other = binsof (cp_addr_class.reserved_other);
    }
  endgroup

  covergroup cg_bus_transfer;
    option.per_instance = 1;

    cp_protocol: coverpoint protocol {bins i2c = {0}; bins i3c = {1};}

    cp_bus_op: coverpoint bus_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cp_actual_len: coverpoint actual_len {
      bins zero = {0};
      bins one = {1};
      bins two_to_four = {[2 : 4]};
      bins multiple_dwords = {[5 : $]};
    }

    cp_final_remainder: coverpoint final_remainder iff (actual_len > 0) {
      bins full_dword = {0}; bins one_byte = {1}; bins two_bytes = {2}; bins three_bytes = {3};
    }

    cx_protocol_op_length: cross cp_protocol, cp_bus_op, cp_actual_len;
  endgroup

  covergroup cg_private_rstart_transition;
    option.per_instance = 1;

    cp_previous_op: coverpoint previous_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cp_current_op: coverpoint current_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cx_previous_next_op: cross cp_previous_op, cp_current_op;
  endgroup

  covergroup cg_ccc;
    option.per_instance = 1;

    cp_ccc_form: coverpoint ccc_form {bins broadcast = {CCC_BROADCAST}; bins direct = {CCC_DIRECT};}

    cp_ccc_opcode: coverpoint ccc_opcode {
      bins enec = {8'(ENEC)};
      bins disec = {8'(DISEC)};
      bins entdaa = {8'(ENTDAA)};
      bins direct_enec = {8'(DIR_ENEC)};
      bins direct_disec = {8'(DIR_DISEC)};
      bins unsupported = default;
    }

    cx_ccc_opcode_form: cross cp_ccc_opcode, cp_ccc_form{
      ignore_bins broadcast_opcode_as_direct =
          binsof(cp_ccc_opcode) intersect {8'(ENEC), 8'(DISEC), 8'(ENTDAA)} &&
          binsof(cp_ccc_form) intersect {
        CCC_DIRECT
      };
      ignore_bins direct_opcode_as_broadcast =
          binsof(cp_ccc_opcode) intersect {8'(DIR_ENEC), 8'(DIR_DISEC)} &&
          binsof(cp_ccc_form) intersect {
        CCC_BROADCAST
      };
    }
  endgroup

  covergroup cg_ccc_target;
    option.per_instance = 1;

    cp_ccc_opcode: coverpoint ccc_opcode {
      bins direct_enec = {8'(DIR_ENEC)};
      bins direct_disec = {8'(DIR_DISEC)};
      bins unsupported_direct = default;
    }

    cp_target_nack: coverpoint ccc_target_nack {bins ack = {0}; bins nack = {1};}

    cx_ccc_target_nack: cross cp_ccc_opcode, cp_target_nack;
  endgroup

  covergroup cg_daa_round;
    option.per_instance = 1;

    cp_round_outcome: coverpoint daa_round_outcome {
      bins accepted = {ACCEPTED};
      bins address_rejected = {ADDR_REJECTED};
      bins no_device = {NO_DEVICE};
      bins id_interrupted = {ID_INTERRUPTED};
      ignore_bins other = {OTHER};
    }

  endgroup

  covergroup cg_daa_assigned_address;
    option.per_instance = 1;

    cp_address_class: coverpoint daa_assigned_addr_class {
      bins low_valid = {ADDR_LOW_VALID};
      bins middle_valid = {ADDR_MIDDLE_VALID};
      bins high_valid = {ADDR_HIGH_VALID};
      ignore_bins reserved = {ADDR_RESERVED};
    }
  endgroup

  function new(string name = "i3c_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_address_phase = new();
    cg_bus_transfer = new();
    cg_private_rstart_transition = new();
    cg_ccc = new();
    cg_ccc_target = new();
    cg_daa_round = new();
    cg_daa_assigned_address = new();
    previous_private_valid = 1'b0;
  endfunction

  function bus_addr_class_e classify_address(bit protocol, bit [6:0] addr);
    if (addr == I3C_RSVD_ADDR) return ADDR_BROADCAST;
    if ((addr < 7'h08) || (addr > 7'h77)) return ADDR_RESERVED_OTHER;
    return protocol ? ADDR_I3C_DYNAMIC : ADDR_I2C_STATIC;
  endfunction

  function start_source_e classify_start_source(bit start_from_rstart);
    return start_from_rstart ? START_FROM_RSTART : START_FROM_START;
  endfunction

  function daa_round_outcome_e classify_daa_round(i3c_item round);
    if (round.addr_nack) return NO_DEVICE;
    if ((round.num_data == 8) && round.interrupted) return ID_INTERRUPTED;
    if ((round.num_data >= 9) && (round.data_nack_q.size() > 0)) begin
      return round.data_nack_q[0] ? ADDR_REJECTED : ACCEPTED;
    end
    return OTHER;
  endfunction

  function daa_assigned_addr_class_e classify_daa_assigned_address(bit [6:0] assigned_addr);
    if (assigned_addr inside {[7'h08 : 7'h1f]}) return ADDR_LOW_VALID;
    if (assigned_addr inside {[7'h20 : 7'h5f]}) return ADDR_MIDDLE_VALID;
    if (assigned_addr inside {[7'h60 : 7'h77]}) return ADDR_HIGH_VALID;
    return ADDR_RESERVED;
  endfunction

  function void sample_address_phase(bit protocol, bus_op_e bus_op, bit [6:0] addr,
                                     bit address_nack, bit start_from_rstart);
    this.protocol     = protocol;
    this.bus_op       = bus_op;
    this.addr         = addr;
    this.addr_class   = classify_address(protocol, addr);
    this.addr_nack    = address_nack;
    this.start_source = classify_start_source(start_from_rstart);
    cg_address_phase.sample();
  endfunction

  function void sample_transfer(i3c_item t);
    protocol = t.i3c;
    bus_op = t.bus_op;
    actual_len = t.num_data;
    final_remainder = t.num_data % 4;
    cg_bus_transfer.sample();

  endfunction

  function void sample_ccc(i3c_item t);
    ccc_form = t.i3c_direct ? CCC_DIRECT : CCC_BROADCAST;
    ccc_opcode = 8'(t.CCC);
    cg_ccc.sample();

    if (t.CCC != ENTDAA) begin
      foreach (t.CCC_direct_q[i]) begin
        ccc_target_nack = t.CCC_direct_q[i].addr_nack;
        cg_ccc_target.sample();
      end
    end
  endfunction

  function void sample_daa(i3c_item t);
    foreach (t.CCC_direct_q[i]) begin
      daa_round_outcome = classify_daa_round(t.CCC_direct_q[i]);
      cg_daa_round.sample();

      // data_q[8] is present only after the complete assigned-address byte was
      // observed. Bits [7:1] carry the address and bit [0] carries its parity.
      if ((t.CCC_direct_q[i].num_data >= 9) && (t.CCC_direct_q[i].data_q.size() >= 9)) begin
        daa_assigned_addr_class = classify_daa_assigned_address(t.CCC_direct_q[i].data_q[8][7:1]);
        cg_daa_assigned_address.sample();
      end
    end

  endfunction

  virtual function void write(i3c_item t);
    bit is_private_transfer;
    bit header_nack;

    if (t == null) return;
    if (t.tran_id == 1) previous_private_valid = 1'b0;

    is_private_transfer = !t.CCC_valid && (t.addr != I3C_RSVD_ADDR);

    if (is_private_transfer) begin
      if (t.start_with_broadcast_header) begin
        sample_address_phase(1'b1, BusOpWrite, I3C_RSVD_ADDR, t.broadcast_header_nack,
                             t.start_from_rstart);
        sample_address_phase(t.i3c, t.bus_op, t.addr, t.addr_nack, 1'b1);
      end else begin
        sample_address_phase(t.i3c, t.bus_op, t.addr, t.addr_nack, t.start_from_rstart);
      end
      sample_transfer(t);

      if (t.i3c) begin
        current_op = t.bus_op;
        if (previous_private_valid && t.start_from_rstart) cg_private_rstart_transition.sample();
        previous_op = t.bus_op;
        previous_private_valid = 1'b1;
      end else begin
        previous_private_valid = 1'b0;
      end
      return;
    end

    previous_private_valid = 1'b0;
    header_nack = t.start_with_broadcast_header ? t.broadcast_header_nack : t.addr_nack;
    sample_address_phase(1'b1, t.bus_op, I3C_RSVD_ADDR, header_nack, t.start_from_rstart);

    foreach (t.CCC_direct_q[i]) begin
      sample_address_phase(1'b1, t.CCC_direct_q[i].bus_op, t.CCC_direct_q[i].addr,
                           t.CCC_direct_q[i].addr_nack, t.CCC_direct_q[i].start_from_rstart);
    end

    if (t.CCC_valid) begin
      sample_ccc(t);
      if (t.CCC == ENTDAA) sample_daa(t);
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("I3C_COVERAGE", $sformatf(
              {
                "cg_address_phase=%0.2f%% cg_bus_transfer=%0.2f%% ",
                "cg_private_rstart_transition=%0.2f%% ",
                "cg_ccc=%0.2f%% cg_ccc_target=%0.2f%% ",
                "cg_daa_round=%0.2f%% ",
                "cg_daa_assigned_address=%0.2f%%"
              },
              cg_address_phase.get_inst_coverage(),
              cg_bus_transfer.get_inst_coverage(),
              cg_private_rstart_transition.get_inst_coverage(),
              cg_ccc.get_inst_coverage(),
              cg_ccc_target.get_inst_coverage(),
              cg_daa_round.get_inst_coverage(),
              cg_daa_assigned_address.get_inst_coverage()
              ), UVM_NONE)
  endfunction
endclass
