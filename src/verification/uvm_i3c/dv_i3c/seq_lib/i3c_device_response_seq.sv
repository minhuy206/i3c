class i3c_device_response_seq extends uvm_sequence #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_item)
);
  bit [6:0] target_addr = 7'h08;
  bit is_i3c = 1;
  bit dir = 0;
  bit [7:0] read_data[$];
  bit ack_address = 1;
  bit ack_data = 1;
  bit data_ack_pattern[$];
  bit start_with_broadcast_header;
  bit is_daa;
  bit entdaa_join;
  bit [7:0] daa_id_bytes[$];
  bit daa_accept_addr = 1'b1;
  int unsigned daa_target_count;
  i3c_daa_arb_target_t daa_targets[I3C_DAA_ARB_MAX_TARGETS];
  bit [6:0] ccc_target_addr;
  bit ccc_target_addr_valid;
  int read_data_cnt = 4;
  bit observed_rstart;
  bit observed_broadcast_header;
  bit observed_broadcast_rstart;
  bit done;
  bit request_issued;
  bit [6:0] sampled_addr;
  bit sampled_dir;
  bit [6:0] sampled_addr_q[$];
  bit sampled_dir_q[$];
  bit [7:0] sampled_data[$];
  bit sampled_t_bit[$];

  `uvm_object_utils(i3c_device_response_seq)

  function new(string name = "");
    super.new(name);
  endfunction

  task body();
    i3c_seq_item req;
    i3c_seq_item rsp_item;
    req = i3c_seq_item::type_id::create("req");
    observed_rstart = 1'b0;
    observed_broadcast_header = 1'b0;
    observed_broadcast_rstart = 1'b0;
    done = 1'b0;
    request_issued = 1'b0;
    sampled_addr = '0;
    sampled_dir = 1'b0;
    sampled_addr_q.delete();
    sampled_dir_q.delete();
    sampled_data.delete();
    sampled_t_bit.delete();

    req.i3c = is_i3c;
    req.addr = target_addr;
    req.dir = dir;
    req.dev_ack = ack_address;
    req.is_daa = is_daa;
    req.entdaa_join = entdaa_join;
    req.daa_id_bytes = daa_id_bytes;
    req.daa_accept_addr = daa_accept_addr;
    req.daa_target_count = daa_target_count;
    req.daa_targets = daa_targets;
    req.ccc_target_addr = ccc_target_addr;
    req.ccc_target_addr_valid = ccc_target_addr_valid;
    req.end_with_rstart = 0;
    req.start_with_broadcast_header = start_with_broadcast_header;

    if (read_data.size() > 0) begin
      req.data = read_data;
      req.data_cnt = read_data.size();
    end else begin
      for (int i = 0; i < read_data_cnt; i++) begin
        req.data.push_back(8'hA0 + i);
      end
      req.data_cnt = read_data_cnt;
    end

    req.T_bit.delete();
    for (int i = 0; i < req.data_cnt; i++) begin
      if (i < data_ack_pattern.size()) begin
        req.T_bit.push_back(data_ack_pattern[i]);
      end else if (!is_i3c && !dir) begin
        req.T_bit.push_back(ack_data);
      end else if (i < req.data_cnt - 1) begin
        req.T_bit.push_back(ack_data);
      end else begin
        req.T_bit.push_back(1'b0);
      end
    end

    start_item(req);
    request_issued = 1'b1;
    finish_item(req);

    get_response(rsp_item);
    if (rsp_item != null) begin
      observed_rstart = rsp_item.end_with_rstart;
      observed_broadcast_header = rsp_item.observed_broadcast_header;
      observed_broadcast_rstart = rsp_item.observed_broadcast_rstart;
      sampled_addr = rsp_item.addr;
      sampled_dir = rsp_item.dir;
      sampled_addr_q = rsp_item.sampled_addr_q;
      sampled_dir_q = rsp_item.sampled_dir_q;
      sampled_data = rsp_item.data;
      sampled_t_bit = rsp_item.T_bit;
    end
    done = 1'b1;
  endtask
endclass
