class i3c_device_response_seq extends uvm_sequence #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_item)
);
  bit [6:0] target_addr = 7'h08;
  bit is_i3c = 1;
  bit dir = 0;
  bit [7:0] read_data[$];
  bit addr_nack;
  bit data_nack;
  bit data_nack_pattern_q[$];
  bit start_with_broadcast_header;
  bit entdaa_join;
  bit [7:0] daa_id_bytes[$];
  bit daa_accept_addr = 1'b1;
  bit [6:0] ccc_target_addr;
  bit ccc_target_addr_valid;
  int read_data_cnt = 4;
  bit observed_rstart;
  bit observed_broadcast_header;
  bit observed_broadcast_rstart;
  bit done;
  bit request_issued;
  bit [6:0] sampled_addr;
  bit [7:0] sampled_data_q[$];
  bit sampled_data_nack_q[$];

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
    sampled_data_q.delete();
    sampled_data_nack_q.delete();

    if (read_data.size() > 0) begin
      req.data = read_data;
    end else begin
      req.payload_constraint_en = 1'b1;
      req.payload_len = read_data_cnt;
      `DV_CHECK_RANDOMIZE_FATAL(req, "Device-response payload randomization failed")
    end

    // Apply protocol controls after payload randomization so only data is effectively random.
    req.i3c = is_i3c;
    req.addr = target_addr;
    req.dir = dir;
    req.addr_nack = addr_nack;
    req.entdaa_join = entdaa_join;
    req.daa_id_bytes = daa_id_bytes;
    req.daa_accept_addr = daa_accept_addr;
    req.ccc_target_addr = ccc_target_addr;
    req.ccc_target_addr_valid = ccc_target_addr_valid;
    req.end_with_rstart = 0;
    req.start_with_broadcast_header = start_with_broadcast_header;

    req.data_nack_q.delete();
    req.t_bit_q.delete();
    if (!is_i3c && !dir) begin
      for (int i = 0; i < req.data.size(); i++) begin
        if (i < data_nack_pattern_q.size()) begin
          req.data_nack_q.push_back(data_nack_pattern_q[i]);
        end else begin
          req.data_nack_q.push_back(data_nack);
        end
      end
    end else if (is_i3c && dir) begin
      for (int i = 0; i < req.data.size(); i++) begin
        req.t_bit_q.push_back(i < req.data.size() - 1);
      end
    end

    start_item(req);
    request_issued = 1'b1;
    finish_item(req);

    get_response(rsp_item);
    if (rsp_item != null) begin
      observed_rstart = rsp_item.end_with_rstart;
      observed_broadcast_header = rsp_item.start_with_broadcast_header;
      observed_broadcast_rstart = rsp_item.observed_broadcast_rstart;
      sampled_addr = rsp_item.addr;
      sampled_data_q = rsp_item.data;
      sampled_data_nack_q = rsp_item.data_nack_q;
    end
    done = 1'b1;
  endtask
endclass
