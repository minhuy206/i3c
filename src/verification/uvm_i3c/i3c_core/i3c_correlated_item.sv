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

class i3c_correlated_item extends uvm_sequence_item;
  `uvm_object_utils(i3c_correlated_item)

  i3c_cmd_attr_e       cmd_attr;
  bit                  cmd_present;
  bit            [7:0] cmd_code;
  bit                  target_is_i3c;
  bit                  rnw;
  bit                  toc;
  bit                  wroc;
  bit            [3:0] tid;
  int unsigned         requested_len;
  bit                  addr_nack;
  bit                  data_nack;
  bit                  response_valid;
  i3c_resp_cmd_class_e response_cmd_class;
  bit                  response_length_valid;
  int unsigned         actual_bus_len;
  int unsigned         response_len;
  i3c_resp_len_relation_e response_len_relation;
  bit                  ccc_response_valid;
  i3c_ccc_e            ccc_opcode;
  bit                  ccc_direct;
  i3c_resp_err_status_e resp_status;
  bit                  daa_valid;
  int unsigned         daa_requested_count;
  int unsigned         daa_joined_count;
  int unsigned         daa_rstart_count;
  i3c_daa_result_e     daa_result;
  bit                  daa_response_valid;
  bit                  daa_dat_valid;
  int unsigned         daa_start_index;
  i3c_daa_dat_span_e   daa_dat_span;

  function new(string name = "i3c_correlated_item");
    super.new(name);
  endfunction
endclass
