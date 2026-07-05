class i3c_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(i3c_scoreboard)

  i3c_env_cfg                              cfg;

  uvm_tlm_analysis_fifo #(reg_seq_item)    reg_fifo;
  uvm_tlm_analysis_fifo #(i3c_item)        i3c_fifo;
  uvm_analysis_port #(i3c_correlated_item) correlated_ap;

  typedef struct {
    i3c_cmd_attr_e  cmd_attr;
    bit             cmd_present;
    bit [7:0]       cmd_code;
    bit [6:0]       addr;
    bit             rnw;
    bit             toc;
    bit             wroc;
    bit             sre;
    bit             uses_tx_queue;
    int             data_length;
    bit [3:0]       tid;
    bit [4:0]       dat_idx;
    bit             is_ccc;
    bit [6:0]       ccc_target_addr;
    bit [7:0]       event_byte;
    bit [4:0]       daa_dev_idx;
    bit [3:0]       daa_dev_count;
    bit [15:0]      daa_addr_valid;
    bit [15:0][6:0] daa_assigned_addr;
    bit [7:0]       imm_data_byte[4];
    bit             target_is_i3c;
    bit             broadcast_header_eligible;
    bit             updates_private_transfer;
    bit             start_with_broadcast_header;
  } exp_txn_t;

  typedef struct {
    bit       valid;
    bit       device;
    bit [6:0] static_address;
    bit [6:0] dynamic_address;
  } dat_model_entry_t;

  typedef struct {
    bit            known;
    int            read_id;
    bit [3:0]      tid;
    int            data_length;
    int            word_idx;
    bit [31:0]     data;
    bit            integrity_candidate;
    bit            integrity_protocol;
    data_pattern_e integrity_pattern;
  } exp_rx_data_t;

  typedef struct {
    bit                   rnw;
    bit [3:0]             tid;
    int                   data_length;
    int                   requested_length;
    i3c_resp_err_status_e resp_status;
    i3c_resp_cmd_class_e  response_cmd_class;
    bit                   wroc;
    bit                   address_response_valid;
    bit                   address_phase_broadcast;
    bit                   address_acked;
    bit                   is_ccc;
    i3c_ccc_e             ccc_opcode;
    bit                   ccc_direct;
    bit                   daa_dat_valid;
    bit [4:0]             daa_start_index;
    bit [3:0]             daa_requested_count;
    bit                   daa_response_valid;
    i3c_daa_result_e      daa_result;
    bit                   abort_response_valid;
    abort_cause_e         abort_cause;
    abort_point_e         abort_point;
    abort_byte_boundary_e abort_byte_boundary;
    bit                   recovery_valid;
    recovery_source_e     recovery_source;
    reset_point_e         reset_point;
    i3c_resp_cmd_class_e  interrupted_cmd_class;
    bit                   stall_recovery_valid;
    stall_type_e          stall_type;
    i3c_resp_cmd_class_e  stall_cmd_class;
  } exp_resp_t;

  typedef struct {
    bit                   rnw;
    bit [3:0]             tid;
    int                   data_length;
    i3c_resp_err_status_e resp_status;
    bit                   is_ccc;
    i3c_ccc_e             ccc_opcode;
    bit                   ccc_direct;
    bit                   daa_dat_valid;
    bit [4:0]             daa_start_index;
    bit [3:0]             daa_requested_count;
    bit                   daa_response_valid;
    i3c_daa_result_e      daa_result;
    i3c_resp_cmd_class_e  response_cmd_class;
    int                   requested_length;
    bit                   wroc;
    bit                   address_response_valid;
    bit                   address_phase_broadcast;
    bit                   address_acked;
  } exp_resp_seed_t;

  typedef struct {
    int        devices_joined_local;
    bit        terminating_nack_seen;
    bit        address_rejected_once;
    bit        address_reject_error;
    bit        hc_abort_seen;
    bit [47:0] rejected_pid;
    bit [7:0]  rejected_bcr;
    bit [7:0]  rejected_dcr;
    bit [6:0]  rejected_addr;
  } daa_scan_state_t;

  localparam int unsigned RxFifoDepth = 8;
  localparam string I3C_FSM_IDLE_PATH = "tb_i3c_top.dut.i3c_fsm_idle";
  localparam string RESP_FULL_PATH = "tb_i3c_top.dut.resp_full";

  exp_txn_t                    exp_txn_queue                [        $];
  bit                   [31:0] tx_data_queue                [        $];
  exp_rx_data_t                exp_rx_data_queue            [        $];
  exp_resp_t                   exp_resp_queue               [        $];
  dat_model_entry_t            dat_model                    [DAT_DEPTH];

  int unsigned                 unknown_resp_fifo_words;
  bit                          read_integrity_pass[int];

  bit                          pending_abort_response_valid;
  abort_cause_e                pending_abort_cause;
  abort_point_e                pending_abort_point;
  abort_byte_boundary_e        pending_abort_byte_boundary;
  bit                          recovery_pending;
  recovery_source_e            recovery_source;
  reset_point_e                recovery_reset_point;
  i3c_resp_cmd_class_e         interrupted_command_class;
  bit                          stall_recovery_pending;
  stall_type_e                 pending_stall_type;
  i3c_resp_cmd_class_e         pending_stall_cmd_class;
  bit                          command_history_valid;
  i3c_resp_cmd_class_e         previous_command_class;
  command_boundary_e           previous_command_boundary;
  bit                          reset_history_valid;
  i3c_resp_cmd_class_e         reset_history_class;

  bit                          got_dw0;
  bit                   [31:0] cmd_dw0;
  bit                          broadcast_header_enable;
  bit                          hc_abort_active;
  bit                          pending_private_transfer;
  int                          next_read_id;

  // --------------------------------------------------------------------------
  // UVM lifecycle and input dispatch
  // --------------------------------------------------------------------------

  function new(string name = "", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    reg_fifo = new("reg_fifo", this);
    i3c_fifo = new("i3c_fifo", this);
    correlated_ap = new("correlated_ap", this);
  endfunction

  task run_phase(uvm_phase phase);
    fork
      process_req_items();
      process_i3c_items();
      process_hard_reset();
    join
  endtask

  task process_req_items();
    reg_seq_item item;
    forever begin
      reg_fifo.get(item);
      if (item.is_write) begin
        if ((item.addr >= ADDR_DAT_BASE) && (item.addr < ADDR_DAT_END)) begin
          handle_dat_write(item.addr, item.wdata);
        end else begin
          case (item.addr)
            ADDR_HC_CONTROL: handle_hc_control_write(item.wdata);
            ADDR_RESET_CONTROL: handle_reset_control_write(item.wdata);
            ADDR_CMD_QUEUE: handle_cmd_dword(item.wdata);
            ADDR_PIO_DATA_PORT: tx_data_queue.push_back(item.wdata);
            default: ;
          endcase
        end
      end else begin
        case (item.addr)
          ADDR_RESP: begin
            if (item.resp_valid) check_resp(item.rdata);
          end
          ADDR_PIO_DATA_PORT: check_rx_data(item.rdata);
          default: ;
        endcase
      end
    end
  endtask

  task process_i3c_items();
    i3c_item item;
    forever begin
      i3c_fifo.get(item);
      if (item.start_with_broadcast_header && !item.broadcast_header_nack && !item.CCC_valid &&
          (item.addr == I3C_RSVD_ADDR) && item.stop) begin
        `uvm_error(`gfn, "Monitor emitted an empty broadcast header instead of a full transaction")
        continue;
      end
      check_i3c_txn(item);
    end
  endtask

  task process_hard_reset();
    forever begin
      @(negedge cfg.m_i3c_agent_cfg.vif.rst_ni);
      reg_fifo.flush();
      i3c_fifo.flush();
      handle_hard_reset();
    end
  endtask

  function void check_phase(uvm_phase phase);
    int unobserved_count;

    unobserved_count = 0;
    foreach (exp_txn_queue[i]) begin
      unobserved_count++;
    end
    if (unobserved_count > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected command(s) never observed on I3C bus", unobserved_count))
    if (tx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf("%0d TX data word(s) unconsumed", tx_data_queue.size()))
    if (exp_resp_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected response model item(s) were not observed", exp_resp_queue.size()))
    if (exp_rx_data_queue.size() > 0)
      `uvm_error(`gfn, $sformatf(
                 "%0d expected RX data word(s) were not observed", exp_rx_data_queue.size()))
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(reg_seq_item, reg_fifo)
    `DV_EOT_PRINT_TLM_FIFO_CONTENTS(i3c_item, i3c_fifo)
  endfunction

  // --------------------------------------------------------------------------
  // Extern method table of contents
  // --------------------------------------------------------------------------

  // Reference model
  extern function void handle_hc_control_write(bit [31:0] wdata);
  extern function void handle_reset_control_write(bit [31:0] wdata);
  extern function bit controller_idle_for_sw_reset();
  extern function bit response_fifo_is_full();
  extern function void clear_transaction_model();
  extern function void handle_sw_reset();
  extern function void handle_hard_reset();
  extern function void capture_reset_recovery_context();
  extern function void handle_dat_write(bit [11:0] addr, bit [31:0] wdata);
  extern function bit invalid_cmd_descriptor(bit [63:0] raw_desc);
  extern function void handle_cmd_dword(bit [31:0] wdata);
  extern function bit [6:0] get_device_addr(bit [4:0] dev_idx);
  extern function bit is_i3c_device(bit [4:0] dev_idx);
  extern function bit is_enec_disec_ccc(bit [7:0] cmd);

  // Bus transaction checking
  extern function void check_i3c_txn(i3c_item item);
  extern function bit exp_matches_item(exp_txn_t exp, i3c_item item, int word_offset);
  extern function void report_i3c_txn_mismatch(i3c_item item, exp_txn_t exp);
  extern function int find_matching_exp_idx(i3c_item item);
  extern function void sample_command_boundary_on_start(exp_txn_t exp);
  extern function void record_command_history(exp_txn_t exp, i3c_item item, bit txn_aborted = 1'b0);
  extern function void advance_private_transfer(exp_txn_t exp, bit aborted = 1'b0);
  extern function void check_read_txn(i3c_item item, exp_txn_t exp, output bit expected_rstart,
                                      output bit expected_stop, output bit txn_aborted);
  extern function void check_read_ack_or_t_bits(i3c_item item, exp_txn_t exp);
  extern function void handle_read_end(
      i3c_item item, exp_txn_t exp, ref i3c_resp_err_status_e resp_status,
      output bit expected_rstart, output bit expected_stop, output bit txn_aborted);
  extern function bit read_final_t_bit(i3c_item item);
  extern function bit is_read_terminated_by_final_bit(bit target_is_i3c, i3c_item item);
  extern function bit is_read_takeover_bit(bit target_is_i3c, i3c_item item);
  extern function bit expected_rx_ack_or_t_bit(bit target_is_i3c, i3c_item item, int byte_idx);
  extern function string rx_ack_or_t_bit_label(bit target_is_i3c);
  extern function bit enqueue_rx_word_expectations(i3c_item item, exp_txn_t exp, int read_id);
  extern function void build_rx_data_expectation(i3c_item item, exp_txn_t exp, int read_id,
                                                 int unsigned word_idx,
                                                 output exp_rx_data_t rx_exp);
  extern function bit check_write_txn(i3c_item item, exp_txn_t exp);
  extern function bit check_immediate_write_txn(i3c_item item, exp_txn_t exp);
  extern function void check_tx_data_bytes(i3c_item item, exp_txn_t exp, int data_length,
                                           string ctxt, bit allow_i2c_final_data_nack = 1'b0);
  extern function void check_short_write_tx_data(i3c_item item, exp_txn_t exp, string cause,
                                                 bit allow_i2c_final_data_nack = 1'b0);
  extern function bit write_payload_matches(i3c_item item, int data_length);
  extern function bit data_nack_q_has_nack(i3c_item item);
  extern function int tx_fifo_available_bytes();
  extern function bit get_expected_tx_byte(int byte_idx, output bit [7:0] data_byte);
  extern function void collect_expected_tx_bytes(int data_length, output bit [7:0] bytes[$]);
  extern function bit expected_tx_ack_or_t_bit(bit target_is_i3c, bit [7:0] data_byte,
                                               bit i2c_data_nack_byte = 1'b0);
  extern function string tx_ack_or_t_bit_label(bit target_is_i3c);
  extern function void collect_expected_tx_ack_or_t_bits(
      int data_length, bit target_is_i3c, output bit t_bits[$],
      input bit allow_i2c_final_data_nack = 1'b0);
  extern function void consume_tx_data_words(int data_len);
  extern function bit tx_data_matches_at(i3c_item item, int word_offset);
  extern function int tx_words_for_len(int data_len);

  // CCC and ENTDAA checking
  extern function void check_ccc_txn(i3c_item item, exp_txn_t exp);
  extern function bit check_ccc_bcast_header_nack(i3c_item item, exp_txn_t exp,
                                                  i3c_resp_cmd_class_e cmd_class);
  extern function void check_ccc_opcode(i3c_item item, exp_txn_t exp);
  extern function void check_ccc_direct_phase(
      i3c_item item, exp_txn_t exp, ref i3c_resp_err_status_e resp_status, ref int resp_len,
      output int direct_idx, output i3c_item direct_item);
  extern function void check_ccc_broadcast_payload(i3c_item item, exp_txn_t exp);
  extern function void check_ccc_entdaa(
      i3c_item item, exp_txn_t exp, ref i3c_resp_err_status_e resp_status, ref int resp_len,
      ref bit daa_response_valid, ref i3c_daa_result_e daa_result);
  extern function void check_ccc_entdaa_round(
      i3c_item item, exp_txn_t exp, int i, ref daa_scan_state_t st,
      ref i3c_resp_err_status_e resp_status, ref int resp_len);
  extern function i3c_daa_result_e resolve_daa_result(exp_txn_t exp, daa_scan_state_t st,
                                                      i3c_resp_err_status_e resp_status);
  extern function void log_ccc_direct_data(i3c_item item, exp_txn_t exp, int direct_idx,
                                           i3c_item direct_item, i3c_resp_err_status_e resp_status,
                                           int resp_len);
  extern function void log_ccc_entdaa_data(i3c_item item, exp_txn_t exp,
                                           i3c_resp_err_status_e resp_status, int resp_len);
  extern function void log_ccc_broadcast_data(i3c_item item, exp_txn_t exp,
                                              i3c_resp_err_status_e resp_status, int resp_len);

  // RX/response and recovery modeling
  extern function bit enqueue_rx_word_expectation(bit [3:0] tid, int data_length, int word_idx,
                                                  bit [31:0] data, string ctxt);
  extern function void check_rx_data(bit [31:0] rdata);
  extern function void set_rx_fifo_level_unknown(int unsigned count, string ctxt = "");
  extern function void check_resp(bit [31:0] rdata);
  extern function void record_exp_resp(exp_resp_seed_t seed);
  extern function void check_exp_resp(bit [31:0] rdata);
  extern function void set_resp_fifo_level_unknown(int unsigned count, string ctxt);
  extern function bit response_expected(bit wroc, i3c_resp_err_status_e resp_status);
  extern function i3c_resp_cmd_class_e classify_response_cmd(i3c_cmd_attr_e cmd_attr, bit is_ccc);
  extern function bit response_length_applicable(i3c_resp_cmd_class_e cmd_class);
  extern function i3c_resp_len_relation_e classify_response_length(exp_resp_t exp_resp,
                                                                   i3c_response_desc_t resp);
  extern function abort_byte_boundary_e classify_abort_byte_boundary(int unsigned byte_count);
  extern function void publish_abort_observation(abort_cause_e cause, abort_point_e point,
                                                 int unsigned byte_count);
  extern function void prepare_abort_response(abort_cause_e cause, abort_point_e point,
                                              int unsigned byte_count);
  extern function void start_recovery_context(
      recovery_source_e source, i3c_resp_cmd_class_e cmd_class,
      reset_point_e reset_point = RESET_POINT_ACTIVE_UNKNOWN);
  extern function void start_stall_recovery(stall_type_e stall_type,
                                            i3c_resp_cmd_class_e cmd_class);

  // Correlated coverage
  extern function length_outcome_e classify_length_outcome(
      int unsigned requested_length, int unsigned actual_length, bit final_t_bit);
  extern function int find_first_nack_idx(i3c_item item);
  extern function nack_position_e classify_nack_position(
      int first_nack_idx, int unsigned requested_length, int unsigned actual_length);
  extern function short_boundary_e classify_short_boundary(int unsigned actual_length);
  extern function data_pattern_e classify_data_pattern(bit [7:0] bytes[$]);
  extern function i3c_daa_dat_span_e classify_daa_dat_span(int unsigned start_index,
                                                           int unsigned requested_count);
  extern function void publish_correlated_item(i3c_item item, exp_txn_t exp);
  extern function void publish_integrity_coverage(bit rnw, bit target_is_i3c,
                                                  data_pattern_e pattern);
  extern function void publish_command_boundary(i3c_resp_cmd_class_e previous_class,
                                                i3c_resp_cmd_class_e next_class,
                                                command_boundary_e boundary);
  extern function void publish_daa_correlated_item(
      exp_txn_t exp, int unsigned joined_count, int unsigned rstart_count, i3c_daa_result_e result,
      i3c_resp_err_status_e resp_status);
  extern function void publish_abort_response_coverage(exp_resp_t exp_resp,
                                                       i3c_response_desc_t resp);
  extern function void publish_recovery_coverage(exp_resp_t exp_resp, bit pass);
  extern function void publish_stall_recovery_coverage(exp_resp_t exp_resp, bit pass);
  extern function void publish_completion_policy_coverage(exp_resp_t exp_resp,
                                                          bit response_present);
  extern function void publish_daa_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  extern function void publish_ccc_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  extern function void publish_daa_dat_coverage(
      int unsigned start_index, int unsigned requested_count, i3c_resp_err_status_e resp_status);
  extern function void publish_response_coverage(exp_resp_t exp_resp, i3c_response_desc_t resp);
  extern function void publish_response_descriptor_coverage(exp_resp_t exp_resp,
                                                            i3c_response_desc_t resp);
  extern function void publish_address_response_coverage(exp_resp_t exp_resp,
                                                         i3c_response_desc_t resp);

  // Diagnostic formatting
  extern function string resp_status_to_string(i3c_resp_err_status_e status);
  extern function string ack_to_string(bit ack);
  extern function string optional_ack_to_string(bit present, bit ack);
  extern function string start_source_to_string(bit start_from_rstart);
  extern function void print_i3c_address(i3c_item item, exp_txn_t exp);
  extern function void print_i3c_end(i3c_item item, exp_txn_t exp, bit expected_rstart,
                                     bit expected_stop);
  extern function void print_ccc_end(i3c_item item, exp_txn_t exp, bit expected_rstart,
                                     bit expected_stop);
  extern function string format_token_list(string tokens[$], int data_length, string missing_token);
  extern function string format_byte_list(bit [7:0] bytes[$], int data_length);
  extern function string format_bit_list(bit bits[$], int data_length);
  extern function string format_ack_list(bit acks[$], int data_length);
  extern function string format_ack_or_t_bit_list(bit target_is_i3c, bit bits[$], int data_length);
  extern function string format_observed_bytes(bit [7:0] bytes[$], int data_length);
  extern function string format_expected_tx_bytes(int data_length);
  extern function string format_observed_t_bits(bit t_bits[$], int data_length);
  extern function string format_observed_ack_or_t_bits(bit target_is_i3c, bit t_bits[$],
                                                       int data_length);
  extern function string format_optional_byte(bit present, bit [7:0] value);
  extern function string format_optional_addr(bit present, bit [6:0] value);
  extern function string format_optional_bit(bit present, bit value);
  extern function string format_expected_tx_ack_or_t_bits(int data_length, bit target_is_i3c,
                                                          bit allow_i2c_final_data_nack = 1'b0);
  extern function string format_expected_rx_ack_or_t_bits(i3c_item item, exp_txn_t exp);
  extern function string format_expected_imm_bytes(exp_txn_t exp, int data_length);
  extern function string format_expected_imm_t_bits(exp_txn_t exp, int data_length);

endclass : i3c_scoreboard

`include "i3c_scoreboard_refmodel.svh"
`include "i3c_scoreboard_bus.svh"
`include "i3c_scoreboard_ccc.svh"
`include "i3c_scoreboard_resp.svh"
`include "i3c_scoreboard_cov.svh"
`include "i3c_scoreboard_fmt.svh"
