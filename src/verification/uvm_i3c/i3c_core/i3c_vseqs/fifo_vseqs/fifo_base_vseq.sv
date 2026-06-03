class fifo_base_vseq extends i3c_base_vseq;
  `uvm_object_utils(fifo_base_vseq)

  localparam int unsigned QueueDepth = 8;

  function new(string name = "fifo_base_vseq");
    super.new(name);
  endfunction

  virtual function bit [63:0] make_cmd_entry(int unsigned index);
    regular_trans_desc_t cmd;

    cmd             = '0;
    cmd.attr        = RegularTransfer;
    cmd.tid         = index[3:0];
    cmd.rnw         = 1'b1;
    cmd.mode        = sdr0;
    cmd.toc         = 1'b1;
    cmd.wroc        = 1'b1;
    cmd.dev_idx     = 5'd0;
    cmd.data_length = 16'(index + 1);
    return cmd;
  endfunction

  virtual function bit [31:0] make_tx_entry(int unsigned index);
    return 32'hA5A5_1000 | index[31:0];
  endfunction

  virtual function bit [31:0] make_rx_entry(int unsigned index);
    return 32'h5A5A_2000 | index[31:0];
  endfunction

  virtual function bit [31:0] make_resp_entry(int unsigned index);
    return {4'h0, index[3:0], 8'h00, 16'(index + 4)};
  endfunction

  virtual function uvm_hdl_data_t make_queue_entry(queue_hdl_paths_t paths, int unsigned index);
    case (paths.name)
      "CMD":  return make_cmd_entry(index);
      "TX":   return make_tx_entry(index);
      "RX":   return make_rx_entry(index);
      "RESP": return make_resp_entry(index);
      default: begin
        `uvm_fatal(`gfn, $sformatf("%s: unsupported queue %s", get_type_name(), paths.name))
      end
    endcase
  endfunction

  virtual task wait_hdl_bit(string path, bit exp, string ctxt, int unsigned timeout = 20);
    for (int unsigned i = 0; i < timeout; i++) begin
      if (hdl_read_bit(path) == exp) return;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end
    `uvm_fatal(`gfn, $sformatf("%s: timeout waiting for %s == %0b %s", get_type_name(), path, exp,
                               ctxt))
  endtask

  virtual function bit queue_uses_csr_read(queue_hdl_paths_t paths);
    return (paths.name == "RX") || (paths.name == "RESP");
  endfunction

  virtual function string flush_path(queue_hdl_paths_t paths);
    return "tb_i3c_top.dut.sw_reset";
  endfunction

  virtual task csr_read_queue(queue_hdl_paths_t paths);
    bit [31:0] unused;

    if (paths.name == "RX") begin
      read_rx_data(unused);
    end else if (paths.name == "RESP") begin
      read_response(unused);
    end else begin
      `uvm_fatal(`gfn, $sformatf("%s: %s does not use CSR read path", get_type_name(),
                                 paths.name))
    end
  endtask

  virtual task fill_queue(queue_hdl_paths_t paths, int unsigned count, int unsigned base_index,
                          string ctxt);
    uvm_hdl_data_t entry;

    for (int unsigned i = 0; i < count; i++) begin
      entry = make_queue_entry(paths, base_index + i);
      wait_hdl_bit(paths.write_ready_path, 1'b1, $sformatf("%s before push %0d", ctxt, i));
      force_fifo_write_one_cycle(paths, entry);
    end
  endtask

  virtual task force_one_cycle(string valid_path);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(valid_path, 1'b1);
    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(valid_path);
    settle_cycles(1);
  endtask

  virtual task force_fifo_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t data);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(paths.write_data_path, data);
    hdl_force_checked(paths.write_valid_path, 1'b1);
    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(paths.write_valid_path);
    hdl_release_checked(paths.write_data_path);
    settle_cycles(1);
  endtask

  virtual task force_fifo_read_one_cycle(queue_hdl_paths_t paths);
    force_one_cycle(paths.read_ready_path);
  endtask

  virtual task pop_fifo_one_entry(queue_hdl_paths_t paths);
    if (queue_uses_csr_read(paths)) begin
      csr_read_queue(paths);
    end else begin
      wait_hdl_bit(paths.read_valid_path, 1'b1, $sformatf("before %s pop", paths.name));
      force_fifo_read_one_cycle(paths);
    end
  endtask

  virtual task attempt_empty_read(queue_hdl_paths_t paths);
    if (queue_uses_csr_read(paths)) begin
      csr_read_queue(paths);
    end else begin
      force_fifo_read_one_cycle(paths);
    end
  endtask

  virtual task force_direct_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                                 bit with_flush = 1'b0);
    string flush_i_path;

    flush_i_path = flush_path(paths);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(paths.write_data_path, wr_data);
    hdl_force_checked(paths.write_valid_path, 1'b1);
    hdl_force_checked(paths.read_ready_path, 1'b1);
    if (with_flush) hdl_force_checked(flush_i_path, 1'b1);

    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    if (with_flush) hdl_release_checked(flush_i_path);
    hdl_release_checked(paths.read_ready_path);
    hdl_release_checked(paths.write_valid_path);
    hdl_release_checked(paths.write_data_path);
    settle_cycles(1);
  endtask

  virtual task force_write_during_csr_read(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                           bit with_flush = 1'b0);
    string flush_i_path;

    flush_i_path = flush_path(paths);
    fork
      begin
        csr_read_queue(paths);
      end
      begin
        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        hdl_force_checked(paths.write_data_path, wr_data);
        hdl_force_checked(paths.write_valid_path, 1'b1);
        if (with_flush) hdl_force_checked(flush_i_path, 1'b1);

        @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
        if (with_flush) hdl_release_checked(flush_i_path);
        hdl_release_checked(paths.write_valid_path);
        hdl_release_checked(paths.write_data_path);
      end
    join
    settle_cycles(1);
  endtask

  virtual task drive_fifo_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data);
    if (queue_uses_csr_read(paths)) begin
      force_write_during_csr_read(paths, wr_data);
    end else begin
      force_direct_read_write_one_cycle(paths, wr_data);
    end
  endtask

  virtual task drive_fifo_flush_read_write_one_cycle(queue_hdl_paths_t paths,
                                                     uvm_hdl_data_t wr_data);
    if (queue_uses_csr_read(paths)) begin
      force_write_during_csr_read(paths, wr_data, 1'b1);
    end else begin
      force_direct_read_write_one_cycle(paths, wr_data, 1'b1);
    end
  endtask

endclass
