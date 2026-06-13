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
  bit start_with_broadcast_header;
  int read_data_cnt = 4;
  bit observed_rstart;
  bit observed_broadcast_header;
  bit observed_broadcast_rstart;
  bit done;
  bit request_issued;
  bit [6:0] sampled_addr;
  bit sampled_dir;
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
    sampled_data.delete();
    sampled_t_bit.delete();

    req.i3c = is_i3c;
    req.addr = target_addr;
    req.dir = dir;
    req.dev_ack = ack_address;
    req.is_daa = 0;
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
      if (!is_i3c && !dir) begin
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
      sampled_data = rsp_item.data;
      sampled_t_bit = rsp_item.T_bit;
    end
    done = 1'b1;
  endtask
endclass
