class i3c_base_vseq extends uvm_sequence;
  `uvm_object_utils(i3c_base_vseq)
  `uvm_declare_p_sequencer(i3c_virtual_sequencer)

  typedef struct {
    string       name;
    string       fifo_path;
    string       mem_path_fmt;
    string       rptr_path;
    string       wptr_path;
    string       depth_path;
    string       write_valid_path;
    string       write_ready_path;
    string       write_data_path;
    string       read_valid_path;
    string       read_ready_path;
    string       read_data_path;
    int          full_bit;
    int          empty_bit;
    int unsigned data_width;
  } queue_hdl_paths_t;

  queue_hdl_paths_t cmd_paths;
  queue_hdl_paths_t tx_paths;
  queue_hdl_paths_t rx_paths;
  queue_hdl_paths_t resp_paths;

  function new(string name = "i3c_base_vseq");
    super.new(name);
    init_queue_hdl_paths();
  endfunction

  virtual task body();
  endtask

  virtual function void init_queue_hdl_paths();
    cmd_paths.name             = "CMD";
    cmd_paths.fifo_path        = "tb_i3c_top.dut.u_queues.cmd_fifo";
    cmd_paths.mem_path_fmt     = "tb_i3c_top.dut.u_queues.cmd_fifo.mem[%0d]";
    cmd_paths.rptr_path        = "tb_i3c_top.dut.u_queues.cmd_fifo.rptr_q";
    cmd_paths.wptr_path        = "tb_i3c_top.dut.u_queues.cmd_fifo.wptr_q";
    cmd_paths.depth_path       = "tb_i3c_top.dut.u_queues.cmd_fifo.depth_o";
    cmd_paths.write_valid_path = "tb_i3c_top.dut.cmd_csr_wvalid";
    cmd_paths.write_ready_path = "tb_i3c_top.dut.cmd_csr_wready";
    cmd_paths.write_data_path  = "tb_i3c_top.dut.cmd_csr_wdata";
    cmd_paths.read_valid_path  = "tb_i3c_top.dut.cmd_hw_rvalid";
    cmd_paths.read_ready_path  = "tb_i3c_top.dut.cmd_hw_rready";
    cmd_paths.read_data_path   = "tb_i3c_top.dut.cmd_hw_rdata";
    cmd_paths.full_bit         = QS_CMD_FULL_BIT;
    cmd_paths.empty_bit        = QS_CMD_EMPTY_BIT;
    cmd_paths.data_width       = 64;

    tx_paths.name             = "TX";
    tx_paths.fifo_path        = "tb_i3c_top.dut.u_queues.tx_fifo";
    tx_paths.mem_path_fmt     = "tb_i3c_top.dut.u_queues.tx_fifo.mem[%0d]";
    tx_paths.rptr_path        = "tb_i3c_top.dut.u_queues.tx_fifo.rptr_q";
    tx_paths.wptr_path        = "tb_i3c_top.dut.u_queues.tx_fifo.wptr_q";
    tx_paths.depth_path       = "tb_i3c_top.dut.u_queues.tx_fifo.depth_o";
    tx_paths.write_valid_path = "tb_i3c_top.dut.tx_csr_wvalid";
    tx_paths.write_ready_path = "tb_i3c_top.dut.tx_csr_wready";
    tx_paths.write_data_path  = "tb_i3c_top.dut.tx_csr_wdata";
    tx_paths.read_valid_path  = "tb_i3c_top.dut.tx_hw_rvalid";
    tx_paths.read_ready_path  = "tb_i3c_top.dut.tx_hw_rready";
    tx_paths.read_data_path   = "tb_i3c_top.dut.tx_hw_rdata";
    tx_paths.full_bit         = QS_TX_FULL_BIT;
    tx_paths.empty_bit        = QS_TX_EMPTY_BIT;
    tx_paths.data_width       = 32;

    rx_paths.name             = "RX";
    rx_paths.fifo_path        = "tb_i3c_top.dut.u_queues.rx_fifo";
    rx_paths.mem_path_fmt     = "tb_i3c_top.dut.u_queues.rx_fifo.mem[%0d]";
    rx_paths.rptr_path        = "tb_i3c_top.dut.u_queues.rx_fifo.rptr_q";
    rx_paths.wptr_path        = "tb_i3c_top.dut.u_queues.rx_fifo.wptr_q";
    rx_paths.depth_path       = "tb_i3c_top.dut.u_queues.rx_fifo.depth_o";
    rx_paths.write_valid_path = "tb_i3c_top.dut.rx_hw_wvalid";
    rx_paths.write_ready_path = "tb_i3c_top.dut.rx_hw_wready";
    rx_paths.write_data_path  = "tb_i3c_top.dut.rx_hw_wdata";
    rx_paths.read_valid_path  = "tb_i3c_top.dut.rx_csr_rvalid";
    rx_paths.read_ready_path  = "tb_i3c_top.dut.rx_csr_rready";
    rx_paths.read_data_path   = "tb_i3c_top.dut.rx_csr_rdata";
    rx_paths.full_bit         = QS_RX_FULL_BIT;
    rx_paths.empty_bit        = QS_RX_EMPTY_BIT;
    rx_paths.data_width       = 32;

    resp_paths.name             = "RESP";
    resp_paths.fifo_path        = "tb_i3c_top.dut.u_queues.resp_fifo";
    resp_paths.mem_path_fmt     = "tb_i3c_top.dut.u_queues.resp_fifo.mem[%0d]";
    resp_paths.rptr_path        = "tb_i3c_top.dut.u_queues.resp_fifo.rptr_q";
    resp_paths.wptr_path        = "tb_i3c_top.dut.u_queues.resp_fifo.wptr_q";
    resp_paths.depth_path       = "tb_i3c_top.dut.u_queues.resp_fifo.depth_o";
    resp_paths.write_valid_path = "tb_i3c_top.dut.resp_hw_wvalid";
    resp_paths.write_ready_path = "tb_i3c_top.dut.resp_hw_wready";
    resp_paths.write_data_path  = "tb_i3c_top.dut.resp_hw_wdata";
    resp_paths.read_valid_path  = "tb_i3c_top.dut.resp_csr_rvalid";
    resp_paths.read_ready_path  = "tb_i3c_top.dut.resp_csr_rready";
    resp_paths.read_data_path   = "tb_i3c_top.dut.resp_csr_rdata";
    resp_paths.full_bit         = QS_RESP_FULL_BIT;
    resp_paths.empty_bit        = QS_RESP_EMPTY_BIT;
    resp_paths.data_width       = 32;
  endfunction

  virtual task settle_cycles(int unsigned cycles = 4);
    repeat (cycles) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
  endtask

  virtual task check_queue_flags(string queue_name, int full_bit, int empty_bit, bit exp_full,
                                 bit exp_empty, string ctxt);
    bit [31:0] status;

    reg_read(ADDR_QUEUE_STATUS, status);
    `DV_CHECK_EQ(status[full_bit], exp_full, $sformatf("%s: %s full flag mismatch %s",
                                                       get_type_name(), queue_name, ctxt))
    `DV_CHECK_EQ(status[empty_bit], exp_empty, $sformatf("%s: %s empty flag mismatch %s",
                                                         get_type_name(), queue_name, ctxt))
  endtask

  virtual task check_all_queues_empty(string ctxt);
    check_queue_flags(cmd_paths.name, cmd_paths.full_bit, cmd_paths.empty_bit, 1'b0, 1'b1, ctxt);
    check_queue_flags(tx_paths.name, tx_paths.full_bit, tx_paths.empty_bit, 1'b0, 1'b1, ctxt);
    check_queue_flags(rx_paths.name, rx_paths.full_bit, rx_paths.empty_bit, 1'b0, 1'b1, ctxt);
    check_queue_flags(resp_paths.name, resp_paths.full_bit, resp_paths.empty_bit, 1'b0, 1'b1, ctxt);
  endtask

  virtual function string fifo_mem_path(queue_hdl_paths_t paths, int unsigned index);
    return $sformatf(paths.mem_path_fmt, index);
  endfunction

  virtual function void hdl_deposit_checked(string path, uvm_hdl_data_t value);
    if (!uvm_hdl_deposit(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_deposit failed for %s", get_type_name(), path))
    end
  endfunction

  virtual function uvm_hdl_data_t hdl_read_checked(string path);
    uvm_hdl_data_t value;

    if (!uvm_hdl_read(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_read failed for %s", get_type_name(), path))
    end
    return value;
  endfunction

  virtual function bit hdl_read_bit(string path);
    uvm_hdl_data_t value;

    value = hdl_read_checked(path);
    return value[0];
  endfunction

  virtual function bit [31:0] hdl_read_word(string path);
    uvm_hdl_data_t value;

    value = hdl_read_checked(path);
    return value[31:0];
  endfunction

  virtual function bit [63:0] hdl_read_qword(string path);
    uvm_hdl_data_t value;

    value = hdl_read_checked(path);
    return value[63:0];
  endfunction

  virtual function void hdl_force_checked(string path, uvm_hdl_data_t value);
    if (!uvm_hdl_force(path, value)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_force failed for %s", get_type_name(), path))
    end
  endfunction

  virtual function void hdl_release_checked(string path);
    if (!uvm_hdl_release(path)) begin
      `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_release failed for %s", get_type_name(), path))
    end
  endfunction

  virtual task backdoor_write_fifo_entry(queue_hdl_paths_t paths, int unsigned index,
                                         uvm_hdl_data_t data);
    hdl_deposit_checked(fifo_mem_path(paths, index), data);
  endtask

  virtual task backdoor_set_fifo_level(queue_hdl_paths_t paths, int unsigned count);
    hdl_deposit_checked(paths.rptr_path, '0);
    hdl_deposit_checked(paths.wptr_path, count);
  endtask

  virtual task reg_write(bit [11:0] addr, bit [31:0] data);
    reg_seq_item reg_seq;
    reg_seq          = reg_seq_item::type_id::create("reg_seq");
    reg_seq.addr     = addr;
    reg_seq.wdata    = data;
    reg_seq.is_write = 1'b1;
    start_item(reg_seq, -1, p_sequencer.m_reg_sequencer);
    finish_item(reg_seq);
  endtask

  virtual task reg_read(bit [11:0] addr, output bit [31:0] data);
    reg_seq_item reg_seq;
    reg_seq          = reg_seq_item::type_id::create("reg_seq");
    reg_seq.addr     = addr;
    reg_seq.is_write = 1'b0;
    start_item(reg_seq, -1, p_sequencer.m_reg_sequencer);
    finish_item(reg_seq);
    data = reg_seq.rdata;
  endtask

  virtual task configure_dut();
    reg_write(ADDR_HC_CONTROL, 32'h0000_0001);
  endtask

  virtual task write_dat_entry(int index, bit [6:0] static_addr, bit [6:0] dynamic_addr,
                               bit is_i2c);
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
      repeat (10) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end
    `uvm_fatal("POLL_IDLE", "Timeout waiting for FSM idle")
  endtask

endclass
