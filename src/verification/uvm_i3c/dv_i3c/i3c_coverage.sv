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

  typedef enum bit [1:0] {
    END_STOP,
    END_RSTART,
    END_RSTART_STOP,
    END_INCOMPLETE
  } end_condition_e;

  typedef enum bit [2:0] {
    ACK_NO_DATA,
    ACK_ALL,
    WRITE_NACK_FIRST,
    WRITE_NACK_AFTER_PROGRESS,
    READ_NACK,
    ACK_PROFILE_OTHER
  } i2c_ack_profile_e;

  typedef enum bit {
    CCC_BROADCAST,
    CCC_DIRECT
  } ccc_form_e;

  typedef enum bit [2:0] {
    DAA_ROUND_ACCEPTED,
    DAA_ROUND_ADDR_REJECTED,
    DAA_ROUND_NO_DEVICE,
    DAA_ROUND_ID_INTERRUPTED,
    DAA_ROUND_OTHER
  } daa_round_outcome_e;

  typedef enum bit [1:0] {
    IDENTITY_ZERO,
    IDENTITY_ONES,
    IDENTITY_ALTERNATING,
    IDENTITY_OTHER
  } identity_pattern_e;

  bit                       protocol;
  bus_op_e                  bus_op;
  bit                 [6:0] addr;
  bus_addr_class_e          addr_class;
  bit                       addr_nack;
  start_source_e            start_source;

  int unsigned              actual_len;
  end_condition_e           end_condition;
  bit                       interrupted;
  bit                       private_preamble;
  int unsigned              final_remainder;
  bit                       i3c_read_has_data;
  bit                       i3c_final_t_bit;

  bit                 [7:0] payload_byte;

  bus_op_e                  previous_op;
  bus_op_e                  current_op;
  bit                       previous_private_valid;

  i2c_ack_profile_e         i2c_ack_profile;

  ccc_form_e                ccc_form;
  bit                 [7:0] ccc_opcode;
  bit                       ccc_header_nack;
  bit                       ccc_opcode_t_bit;
  bit                       ccc_event_t_bit_valid;
  bit                       ccc_event_t_bit;
  bit                       ccc_target_nack;

  int unsigned              daa_joined_count;
  daa_round_outcome_e       daa_terminal_outcome;
  daa_round_outcome_e       daa_round_outcome;
  bit                       daa_identity_valid;
  identity_pattern_e        daa_identity_pattern;

  covergroup cg_address_phase;
    option.per_instance = 1;

    cp_protocol: coverpoint protocol {bins i2c = {0}; bins i3c = {1};}

    cp_bus_op: coverpoint bus_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

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

    cx_addr_class_nack: cross cp_addr_class, cp_addr_nack;
  endgroup

  covergroup cg_bus_transfer;
    option.per_instance = 1;

    cp_protocol: coverpoint protocol {bins i2c = {0}; bins i3c = {1};}

    cp_bus_op: coverpoint bus_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cp_actual_len: coverpoint actual_len {
      bins zero = {0};
      bins one = {1};
      bins two_to_four = {[2 : 4]};
      bins five_to_eight = {[5 : 8]};
      bins nine_to_sixteen = {[9 : 16]};
      bins seventeen_to_sixty_four = {[17 : 64]};
      bins greater_than_sixty_four = {[65 : $]};
    }

    cp_end_condition: coverpoint end_condition {
      bins stop = {END_STOP};
      bins repeated_start = {END_RSTART};
      bins repeated_start_then_stop = {END_RSTART_STOP};
      bins incomplete = {END_INCOMPLETE};
    }

    cp_interrupted: coverpoint interrupted {bins normal = {0}; bins interrupted = {1};}

    cp_private_preamble: coverpoint private_preamble iff (protocol) {
      bins disabled = {0}; bins enabled = {1};
    }

    cp_final_remainder: coverpoint final_remainder iff (actual_len > 0) {
      bins full_dword = {0}; bins one_byte = {1}; bins two_bytes = {2}; bins three_bytes = {3};
    }

    cx_protocol_op_length: cross cp_protocol, cp_bus_op, cp_actual_len;
    cx_preamble_op: cross cp_private_preamble, cp_bus_op;
  endgroup

  covergroup cg_payload_byte;
    option.per_instance = 1;

    cp_data_pattern: coverpoint payload_byte {
      bins all_zero = {8'h00};
      bins all_one = {8'hff};
      bins alternating[] = {8'haa, 8'h55};
      bins walking_one[] = {8'h01, 8'h02, 8'h04, 8'h08, 8'h10, 8'h20, 8'h40, 8'h80};
      bins other = default;
    }
  endgroup

  covergroup cg_i3c_read_end;
    option.per_instance = 1;

    cp_final_t_bit: coverpoint i3c_final_t_bit iff (i3c_read_has_data) {
      bins target_end = {0}; bins controller_continue = {1};
    }

    cp_interrupted: coverpoint interrupted {bins normal = {0}; bins interrupted = {1};}

    cx_t_bit_interrupted: cross cp_final_t_bit, cp_interrupted;
  endgroup

  covergroup cg_private_transition;
    option.per_instance = 1;

    cp_previous_op: coverpoint previous_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cp_current_op: coverpoint current_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cx_previous_next_op: cross cp_previous_op, cp_current_op;
  endgroup

  covergroup cg_i2c_ack;
    option.per_instance = 1;

    cp_i2c_op: coverpoint bus_op {bins write = {BusOpWrite}; bins read = {BusOpRead};}

    cp_i2c_ack_profile: coverpoint i2c_ack_profile {
      bins no_data = {ACK_NO_DATA};
      bins all_ack = {ACK_ALL};
      bins write_nack_first = {WRITE_NACK_FIRST};
      bins write_nack_after_progress = {WRITE_NACK_AFTER_PROGRESS};
      bins read_nack = {READ_NACK};
      bins other = {ACK_PROFILE_OTHER};
    }

    cx_i2c_op_ack: cross cp_i2c_op, cp_i2c_ack_profile {
      ignore_bins read_with_write_nack_first = binsof(cp_i2c_op.read) &&
                                               binsof(cp_i2c_ack_profile.write_nack_first);
      ignore_bins read_with_write_nack_after_progress =
          binsof(cp_i2c_op.read) &&
          binsof(cp_i2c_ack_profile.write_nack_after_progress);
      ignore_bins read_without_final_nack = binsof(cp_i2c_op.read) &&
                                            binsof(cp_i2c_ack_profile.all_ack);
      ignore_bins read_with_nonfinal_nack = binsof(cp_i2c_op.read) &&
                                            binsof(cp_i2c_ack_profile.other);
      ignore_bins write_with_read_nack = binsof(cp_i2c_op.write) &&
                                         binsof(cp_i2c_ack_profile.read_nack);
      ignore_bins write_with_other = binsof(cp_i2c_op.write) &&
                                     binsof(cp_i2c_ack_profile.other);
    }
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

    cp_ccc_header_nack: coverpoint ccc_header_nack {bins ack = {0}; bins nack = {1};}

    cp_ccc_opcode_t_bit: coverpoint ccc_opcode_t_bit {bins zero = {0}; bins one = {1};}

    cp_ccc_event_t_bit: coverpoint ccc_event_t_bit iff (ccc_event_t_bit_valid) {
      bins zero = {0}; bins one = {1};
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

  covergroup cg_daa_transaction;
    option.per_instance = 1;

    cp_joined_count: coverpoint daa_joined_count {
      bins zero = {0}; bins one = {1}; bins two = {2}; bins three_or_more = {[3 : $]};
    }

    cp_terminal_outcome: coverpoint daa_terminal_outcome {
      bins accepted = {DAA_ROUND_ACCEPTED};
      bins address_rejected = {DAA_ROUND_ADDR_REJECTED};
      bins no_device = {DAA_ROUND_NO_DEVICE};
      bins id_interrupted = {DAA_ROUND_ID_INTERRUPTED};
      bins other = {DAA_ROUND_OTHER};
    }
  endgroup

  covergroup cg_daa_round;
    option.per_instance = 1;

    cp_round_outcome: coverpoint daa_round_outcome {
      bins accepted = {DAA_ROUND_ACCEPTED};
      bins address_rejected = {DAA_ROUND_ADDR_REJECTED};
      bins no_device = {DAA_ROUND_NO_DEVICE};
      bins id_interrupted = {DAA_ROUND_ID_INTERRUPTED};
      bins other = {DAA_ROUND_OTHER};
    }

    cp_identity_pattern: coverpoint daa_identity_pattern iff (daa_identity_valid) {
      bins zero = {IDENTITY_ZERO};
      bins ones = {IDENTITY_ONES};
      bins alternating = {IDENTITY_ALTERNATING};
      bins other = {IDENTITY_OTHER};
    }
  endgroup

  function new(string name = "i3c_coverage", uvm_component parent = null);
    super.new(name, parent);
    cg_address_phase = new();
    cg_bus_transfer = new();
    cg_payload_byte = new();
    cg_i3c_read_end = new();
    cg_private_transition = new();
    cg_i2c_ack = new();
    cg_ccc = new();
    cg_ccc_target = new();
    cg_daa_transaction = new();
    cg_daa_round = new();
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

  function end_condition_e classify_end_condition(i3c_item t);
    if (t.rstart && t.stop) return END_RSTART_STOP;
    if (t.rstart) return END_RSTART;
    if (t.stop) return END_STOP;
    return END_INCOMPLETE;
  endfunction

  function i2c_ack_profile_e classify_i2c_ack(i3c_item t);
    int first_nack;

    if (t.data_nack_q.size() == 0) return ACK_NO_DATA;

    first_nack = -1;
    foreach (t.data_nack_q[i]) begin
      if (t.data_nack_q[i]) begin
        first_nack = i;
        break;
      end
    end

    if (first_nack < 0) return ACK_ALL;
    if (t.bus_op == BusOpWrite) begin
      return (first_nack == 0) ? WRITE_NACK_FIRST : WRITE_NACK_AFTER_PROGRESS;
    end
    if (first_nack == (t.data_nack_q.size() - 1)) return READ_NACK;
    return ACK_PROFILE_OTHER;
  endfunction

  function daa_round_outcome_e classify_daa_round(i3c_item round);
    if (round.addr_nack) return DAA_ROUND_NO_DEVICE;
    if ((round.num_data == 8) && round.interrupted) return DAA_ROUND_ID_INTERRUPTED;
    if ((round.num_data >= 9) && (round.data_nack_q.size() > 0)) begin
      return round.data_nack_q[0] ? DAA_ROUND_ADDR_REJECTED : DAA_ROUND_ACCEPTED;
    end
    return DAA_ROUND_OTHER;
  endfunction

  function identity_pattern_e classify_identity(i3c_item round);
    bit all_zero;
    bit all_one;
    bit all_alternating;

    all_zero = 1'b1;
    all_one = 1'b1;
    all_alternating = 1'b1;
    for (int i = 0; i < 8; i++) begin
      all_zero &= (round.data_q[i] == 8'h00);
      all_one &= (round.data_q[i] == 8'hff);
      all_alternating &= (round.data_q[i] inside {8'haa, 8'h55});
    end

    if (all_zero) return IDENTITY_ZERO;
    if (all_one) return IDENTITY_ONES;
    if (all_alternating) return IDENTITY_ALTERNATING;
    return IDENTITY_OTHER;
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
    end_condition = classify_end_condition(t);
    interrupted = t.interrupted;
    private_preamble = t.start_with_broadcast_header;
    final_remainder = t.num_data % 4;
    cg_bus_transfer.sample();

    foreach (t.data_q[i]) begin
      payload_byte = t.data_q[i];
      cg_payload_byte.sample();
    end

    if (t.i3c && (t.bus_op == BusOpRead)) begin
      i3c_read_has_data = t.data_nack_q.size() > 0;
      i3c_final_t_bit   = i3c_read_has_data ? t.data_nack_q[t.data_nack_q.size()-1] : 1'b0;
      cg_i3c_read_end.sample();
    end

    if (!t.i3c) begin
      i2c_ack_profile = classify_i2c_ack(t);
      cg_i2c_ack.sample();
    end
  endfunction

  function void sample_ccc(i3c_item t);
    ccc_form = t.i3c_direct ? CCC_DIRECT : CCC_BROADCAST;
    ccc_opcode = 8'(t.CCC);
    ccc_header_nack = t.broadcast_header_nack;
    ccc_opcode_t_bit = t.ccc_t_bit;
    ccc_event_t_bit_valid = (t.CCC != ENTDAA) && (t.data_nack_q.size() > 0);
    ccc_event_t_bit = ccc_event_t_bit_valid ? t.data_nack_q[0] : 1'b0;
    if ((t.CCC != ENTDAA) && !ccc_event_t_bit_valid) begin
      foreach (t.CCC_direct[i]) begin
        if (t.CCC_direct[i].data_nack_q.size() > 0) begin
          ccc_event_t_bit_valid = 1'b1;
          ccc_event_t_bit = t.CCC_direct[i].data_nack_q[0];
          break;
        end
      end
    end
    cg_ccc.sample();

    if (t.CCC != ENTDAA) begin
      foreach (t.data_q[i]) begin
        payload_byte = t.data_q[i];
        cg_payload_byte.sample();
      end

      foreach (t.CCC_direct[i]) begin
        ccc_target_nack = t.CCC_direct[i].addr_nack;
        cg_ccc_target.sample();
        foreach (t.CCC_direct[i].data_q[j]) begin
          payload_byte = t.CCC_direct[i].data_q[j];
          cg_payload_byte.sample();
        end
      end
    end
  endfunction

  function void sample_daa(i3c_item t);
    daa_joined_count = 0;
    daa_terminal_outcome = DAA_ROUND_OTHER;

    foreach (t.CCC_direct[i]) begin
      daa_round_outcome = classify_daa_round(t.CCC_direct[i]);
      daa_terminal_outcome = daa_round_outcome;
      daa_identity_valid = t.CCC_direct[i].data_q.size() >= 8;
      daa_identity_pattern = daa_identity_valid ? classify_identity(t.CCC_direct[i]) :
          IDENTITY_OTHER;
      if (daa_round_outcome == DAA_ROUND_ACCEPTED) daa_joined_count++;
      cg_daa_round.sample();
    end

    cg_daa_transaction.sample();
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
        if (previous_private_valid) cg_private_transition.sample();
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

    foreach (t.CCC_direct[i]) begin
      sample_address_phase(1'b1, t.CCC_direct[i].bus_op, t.CCC_direct[i].addr,
                           t.CCC_direct[i].addr_nack, t.CCC_direct[i].start_from_rstart);
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
                "cg_payload_byte=%0.2f%% cg_i3c_read_end=%0.2f%% ",
                "cg_private_transition=%0.2f%% ",
                "cg_i2c_ack=%0.2f%% cg_ccc=%0.2f%% cg_ccc_target=%0.2f%% ",
                "cg_daa_transaction=%0.2f%% cg_daa_round=%0.2f%%"
              },
              cg_address_phase.get_inst_coverage(),
              cg_bus_transfer.get_inst_coverage(),
              cg_payload_byte.get_inst_coverage(),
              cg_i3c_read_end.get_inst_coverage(),
              cg_private_transition.get_inst_coverage(),
              cg_i2c_ack.get_inst_coverage(),
              cg_ccc.get_inst_coverage(),
              cg_ccc_target.get_inst_coverage(),
              cg_daa_transaction.get_inst_coverage(),
              cg_daa_round.get_inst_coverage()
              ), UVM_NONE)
  endfunction
endclass
