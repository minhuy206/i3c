typedef enum bit [2:0] {
  DAA_RESULT_ASSIGNED_ALL,
  DAA_RESULT_FEWER_THAN_COUNT,
  DAA_RESULT_NO_DEVICE,
  DAA_RESULT_ADDRESS_REJECTED,
  DAA_RESULT_OVERFLOW,
  DAA_RESULT_ABORT,
  DAA_RESULT_OTHER
} i3c_daa_result_e;

typedef enum bit [1:0] {
  DAA_DAT_SPAN_WITHIN_TABLE,
  DAA_DAT_SPAN_ENDS_AT_LAST,
  DAA_DAT_SPAN_CROSSES_BOUNDARY
} i3c_daa_dat_span_e;

typedef enum bit [2:0] {
  RESP_CMD_CLASS_REGULAR,
  RESP_CMD_CLASS_IMMEDIATE,
  RESP_CMD_CLASS_CCC,
  RESP_CMD_CLASS_DAA,
  RESP_CMD_CLASS_OTHER
} i3c_resp_cmd_class_e;

typedef enum bit [2:0] {
  RESP_LEN_EXACT,
  RESP_LEN_SHORT,
  RESP_LEN_ZERO,
  RESP_LEN_PARTIAL_ABORT,
  RESP_LEN_PARTIAL_OVERFLOW,
  RESP_LEN_OTHER
} i3c_resp_len_relation_e;

typedef enum bit [1:0] {
  RESP_ADDR_PHASE_TARGET,
  RESP_ADDR_PHASE_BROADCAST_HEADER,
  RESP_ADDR_PHASE_OTHER
} i3c_resp_addr_phase_e;

typedef enum bit [1:0] {
  LEN_EXACT,
  LEN_EARLY,
  LEN_BEYOND
} length_outcome_e;

typedef enum bit [1:0] {
  NACK_FIRST,
  NACK_MIDDLE,
  NACK_LAST,
  NACK_NONE
} nack_position_e;

typedef enum bit [2:0] {
  SHORT_ONE_BYTE,
  SHORT_DWORD_BOUNDARY,
  SHORT_PARTIAL_1,
  SHORT_PARTIAL_2,
  SHORT_PARTIAL_3,
  SHORT_OTHER
} short_boundary_e;

typedef enum bit [1:0] {
  HC_ABORT,
  RESET,
  PROTOCOL_TERMINATION
} abort_cause_e;

typedef enum bit [3:0] {
  PREAMBLE,
  ADDRESS,
  TX_DATA,
  RX_DATA,
  CCC,
  DAA_ID,
  DAA_ASSIGNED_ADDRESS,
  RESPONSE
} abort_point_e;

typedef enum bit [1:0] {
  ABORT_BYTES_ZERO,
  ABORT_BYTES_ONE_TO_THREE,
  ABORT_BYTES_ONE_DWORD,
  ABORT_BYTES_MORE_THAN_ONE_DWORD
} abort_byte_boundary_e;

typedef enum bit [1:0] {
  RECOVERY_HC_ABORT,
  RECOVERY_RESET,
  RECOVERY_PROTOCOL_TERMINATION
} recovery_source_e;

typedef enum bit [1:0] {
  RESET_POINT_IDLE,
  RESET_POINT_QUEUED_COMMAND,
  RESET_POINT_ACTIVE_UNKNOWN
} reset_point_e;

typedef enum bit [2:0] {
  BOUNDARY_STOP,
  BOUNDARY_REPEATED_START,
  BOUNDARY_TOC_CONTINUATION,
  BOUNDARY_IDLE_BACK_TO_BACK,
  BOUNDARY_RESET_CLEARED
} command_boundary_e;

typedef enum bit [1:0] {
  STALL_TX_EMPTY,
  STALL_RX_FULL,
  STALL_RESP_FULL,
  STALL_WAIT_CMD
} stall_type_e;

class i3c_correlated_item extends uvm_sequence_item;
  `uvm_object_utils(i3c_correlated_item)

  i3c_cmd_attr_e                cmd_attr;
  bit                           cmd_present;
  bit                     [7:0] cmd_code;
  bit                           target_is_i3c;
  bit                           rnw;
  bit                           toc;
  bit                           wroc;
  bit                     [3:0] tid;
  int unsigned                  requested_len;
  bit                           addr_nack;
  bit                           data_nack;
  bit                           response_valid;
  i3c_resp_cmd_class_e          response_cmd_class;
  i3c_resp_err_status_e         expected_resp_status;
  i3c_resp_err_status_e         observed_resp_status;
  bit                           response_length_valid;
  int unsigned                  response_len;
  i3c_resp_len_relation_e       response_len_relation;
  i3c_resp_err_status_e         resp_status;
  bit                           daa_valid;
  int unsigned                  daa_requested_count;
  int unsigned                  daa_joined_count;
  i3c_daa_result_e              daa_result;
  bit                           daa_response_valid;
  bit                           daa_dat_valid;
  int unsigned                  daa_start_index;
  i3c_daa_dat_span_e            daa_dat_span;
  bit                           broadcast_header_enable;
  bit                           expected_broadcast_header;
  bit                           observed_broadcast_header;
  bit                           private_transfer_valid;
  bit                           address_response_valid;
  i3c_resp_addr_phase_e         response_addr_phase;
  bit                           address_acked;
  bit                           completion_policy_valid;
  bit                           response_present;
  bit                           length_t_bit_valid;
  bit                           final_t_bit;
  length_outcome_e              length_outcome;
  bit                           nack_position_valid;
  nack_position_e               nack_position;
  bit                           short_boundary_valid;
  bit                           sre;
  short_boundary_e              short_boundary;
  bit                           integrity_valid;
  bit                           abort_valid;
  abort_cause_e                 abort_cause;
  abort_point_e                 abort_point;
  abort_byte_boundary_e         abort_byte_boundary;
  bit                           recovery_valid;
  recovery_source_e             recovery_source;
  reset_point_e                 reset_point;
  i3c_resp_cmd_class_e          interrupted_cmd_class;
  i3c_resp_cmd_class_e          recovery_cmd_class;
  bit                           command_boundary_valid;
  command_boundary_e            command_boundary;
  bit                           stall_recovery_valid;
  stall_type_e                  stall_type;

  function new(string name = "i3c_correlated_item");
    super.new(name);
  endfunction
endclass
