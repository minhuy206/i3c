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

  virtual function string fifo_read_valid_path(queue_hdl_paths_t paths);
    return {paths.fifo_path, ".rvalid_o"};
  endfunction

  virtual function string fifo_read_ready_path(queue_hdl_paths_t paths);
    return {paths.fifo_path, ".rready_i"};
  endfunction

  virtual function string fifo_read_data_path(queue_hdl_paths_t paths);
    return {paths.fifo_path, ".rdata_o"};
  endfunction

  virtual task csr_read_queue(queue_hdl_paths_t paths);
    uvm_hdl_data_t unused;

    csr_read_queue_data(paths, unused);
  endtask

  virtual task csr_read_queue_data(queue_hdl_paths_t paths, output uvm_hdl_data_t data);
    bit [31:0] csr_data;

    data = '0;
    if (paths.name == "RX") begin
      read_rx_data(csr_data);
    end else if (paths.name == "RESP") begin
      read_response(csr_data);
    end else begin
      `uvm_fatal(`gfn, $sformatf("%s: %s does not use CSR read path", get_type_name(),
                                 paths.name))
    end
    data[31:0] = csr_data;
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
    force_one_cycle(fifo_read_ready_path(paths));
  endtask

  virtual task pop_fifo_one_entry(queue_hdl_paths_t paths);
    uvm_hdl_data_t unused;

    read_fifo_one_entry(paths, unused);
  endtask

  virtual task read_fifo_one_entry(queue_hdl_paths_t paths, output uvm_hdl_data_t data);
    data = '0;
    if (queue_uses_csr_read(paths)) begin
      csr_read_queue_data(paths, data);
    end else begin
      wait_hdl_bit(fifo_read_valid_path(paths), 1'b1, $sformatf("before %s pop", paths.name));
      data = hdl_read_checked(fifo_read_data_path(paths));
      force_fifo_read_one_cycle(paths);
    end
  endtask

  virtual function uvm_hdl_data_t queue_data_lsb(queue_hdl_paths_t paths, uvm_hdl_data_t raw);
    uvm_hdl_data_t data;

    data = '0;
    for (int unsigned i = 0; i < paths.data_width; i++) begin
      data[i] = raw[i];
    end
    return data;
  endfunction

  virtual task expect_fifo_pop(queue_hdl_paths_t paths, uvm_hdl_data_t exp, string ctxt);
    uvm_hdl_data_t got;

    read_fifo_one_entry(paths, got);
    `DV_CHECK_EQ(queue_data_lsb(paths, got), queue_data_lsb(paths, exp),
                 $sformatf("%s: %s FIFO pop data mismatch %s", get_type_name(), paths.name, ctxt))
  endtask

  virtual task check_fifo_state(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit exp_full;
    bit exp_empty;

    exp_full  = (exp_depth == QueueDepth);
    exp_empty = (exp_depth == 0);

    settle_cycles();
    `DV_CHECK_EQ(hdl_read_fifo_depth(paths.depth_path), exp_depth,
                 $sformatf("%s: %s FIFO depth mismatch %s", get_type_name(), paths.name, ctxt))
    check_queue_flags(paths.name, paths.full_bit, paths.empty_bit, exp_full, exp_empty, ctxt);
  endtask

  virtual task attempt_empty_read(queue_hdl_paths_t paths);
    if (queue_uses_csr_read(paths)) begin
      csr_read_queue(paths);
    end else begin
      force_fifo_read_one_cycle(paths);
    end
  endtask

  virtual task force_direct_read_write_one_cycle_data(queue_hdl_paths_t paths,
                                                      uvm_hdl_data_t wr_data,
                                                      output uvm_hdl_data_t rd_data,
                                                      input bit with_flush = 1'b0);
    string flush_i_path;

    rd_data      = '0;
    flush_i_path = flush_path(paths);
    wait_hdl_bit(fifo_read_valid_path(paths), 1'b1,
                 $sformatf("before %s simultaneous read/write", paths.name));
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(paths.write_data_path, wr_data);
    hdl_force_checked(paths.write_valid_path, 1'b1);
    hdl_force_checked(fifo_read_ready_path(paths), 1'b1);
    if (with_flush) hdl_force_checked(flush_i_path, 1'b1);
    rd_data = hdl_read_checked(fifo_read_data_path(paths));

    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    if (with_flush) hdl_release_checked(flush_i_path);
    hdl_release_checked(fifo_read_ready_path(paths));
    hdl_release_checked(paths.write_valid_path);
    hdl_release_checked(paths.write_data_path);
    settle_cycles(1);
  endtask

  virtual task force_direct_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                                 bit with_flush = 1'b0);
    uvm_hdl_data_t unused;

    force_direct_read_write_one_cycle_data(paths, wr_data, unused, with_flush);
  endtask

  virtual task force_write_during_csr_read_data(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                                output uvm_hdl_data_t rd_data,
                                                input bit with_flush = 1'b0);
    string flush_i_path;

    rd_data      = '0;
    flush_i_path = flush_path(paths);
    fork
      begin
        csr_read_queue_data(paths, rd_data);
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

  virtual task force_write_during_csr_read(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data,
                                           bit with_flush = 1'b0);
    uvm_hdl_data_t unused;

    force_write_during_csr_read_data(paths, wr_data, unused, with_flush);
  endtask

  virtual task drive_fifo_read_write_one_cycle_data(queue_hdl_paths_t paths,
                                                    uvm_hdl_data_t wr_data,
                                                    output uvm_hdl_data_t rd_data);
    if (queue_uses_csr_read(paths)) begin
      force_write_during_csr_read_data(paths, wr_data, rd_data);
    end else begin
      force_direct_read_write_one_cycle_data(paths, wr_data, rd_data);
    end
  endtask

  virtual task drive_fifo_read_write_one_cycle(queue_hdl_paths_t paths, uvm_hdl_data_t wr_data);
    uvm_hdl_data_t unused;

    drive_fifo_read_write_one_cycle_data(paths, wr_data, unused);
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
