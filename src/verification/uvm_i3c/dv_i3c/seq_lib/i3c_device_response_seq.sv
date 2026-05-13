class i3c_device_response_seq extends uvm_sequence #(
    .REQ(i3c_seq_item),
    .RSP(i3c_seq_item)
);
  bit [6:0] target_addr = 7'h08;
  bit is_i3c = 1;
  bit [7:0] read_data[$];
  bit ack_address = 1;
  bit ack_data = 1;
  int read_data_cnt = 4;

  `uvm_object_utils(i3c_device_response_seq)

  function new(string name = "");
    super.new(name);
  endfunction

  task body();
    i3c_seq_item req;
    req = i3c_seq_item::type_id::create("req");

    req.i3c = is_i3c;
    req.addr = target_addr;
    req.dir = 0;
    req.dev_ack = ack_address;
    req.is_daa = 0;
    req.end_with_rstart = 0;

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
      if (i < req.data_cnt - 1) req.T_bit.push_back(ack_data);
      else req.T_bit.push_back(1'b0);
    end

    start_item(req);
    finish_item(req);

    get_response(rsp);
  endtask
endclass
