class i3c_base_vseq extends uvm_sequence;
  `uvm_object_utils(i3c_base_vseq)
  `uvm_declare_p_sequencer(i3c_virtual_sequencer)

  function new(string name = "i3c_base_vseq");
    super.new(name);
  endfunction

  virtual task body();
  endtask

  virtual task reg_write(bit [11:0] addr, bit [31:0] data);
    reg_seq_item req;
    req          = reg_seq_item::type_id::create("req");
    req.addr     = addr;
    req.wdata    = data;
    req.is_write = 1'b1;
    start_item(req, -1, p_sequencer.m_reg_sequencer);
    finish_item(req);
  endtask

  virtual task reg_read(bit [11:0] addr, output bit [31:0] data);
    reg_seq_item req;
    req          = reg_seq_item::type_id::create("req");
    req.addr     = addr;
    req.is_write = 1'b0;
    start_item(req, -1, p_sequencer.m_reg_sequencer);
    finish_item(req);
    data = req.rdata;
  endtask

  virtual task configure_dut();
    reg_write(ADDR_HC_CONTROL, 32'h0000_0001);
  endtask

  virtual task write_dat_entry(int index, bit [6:0] static_addr,
                               bit [6:0] dynamic_addr, bit is_i2c);
    bit [31:0] dat_val;
    dat_val        = '0;
    dat_val[6:0]   = static_addr;
    dat_val[22:16] = dynamic_addr;
    dat_val[31]    = is_i2c;
    reg_write(dat_addr(index), dat_val);
  endtask

  virtual task write_cmd(bit [31:0] dword0, bit [31:0] dword1);
    reg_write(ADDR_CMD_QUEUE, dword0);
    reg_write(ADDR_CMD_QUEUE, dword1);
  endtask

  virtual task write_tx_data(bit [31:0] data);
    reg_write(ADDR_TX_DATA, data);
  endtask

  virtual task read_rx_data(output bit [31:0] data);
    reg_read(ADDR_RX_DATA, data);
  endtask

  virtual task read_response(output bit [31:0] data);
    reg_read(ADDR_RESP, data);
  endtask

  virtual task poll_idle(int timeout = 10000);
    bit [31:0] status;
    for (int i = 0; i < timeout; i++) begin
      reg_read(ADDR_HC_STATUS, status);
      if (status[HC_STS_FSM_IDLE_BIT]) return;
      repeat(10) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end
    `uvm_fatal("POLL_IDLE", "Timeout waiting for FSM idle")
  endtask

endclass
