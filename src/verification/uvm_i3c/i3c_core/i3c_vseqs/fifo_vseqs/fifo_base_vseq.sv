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

  virtual task check_depth(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit [31:0] depth;

    depth = hdl_read_word(paths.depth_path);
    `DV_CHECK_EQ(depth, 32'(exp_depth), $sformatf("%s: %s depth mismatch %s", get_type_name(),
                                                  paths.name, ctxt))
  endtask

  virtual task check_fifo_state(queue_hdl_paths_t paths, int unsigned exp_depth, string ctxt);
    bit exp_full;
    bit exp_empty;

    exp_full  = (exp_depth == QueueDepth);
    exp_empty = (exp_depth == 0);
    check_depth(paths, exp_depth, ctxt);
    check_queue_flags(paths.name, paths.full_bit, paths.empty_bit, exp_full, exp_empty, ctxt);
  endtask

  virtual task check_queue_read_data(queue_hdl_paths_t paths, uvm_hdl_data_t exp, string ctxt);
    uvm_hdl_data_t got;

    got = hdl_read_checked(paths.read_data_path);
    if (paths.data_width == 64) begin
      `DV_CHECK_EQ(got[63:0], exp[63:0], $sformatf("%s: %s read data mismatch %s",
                                                   get_type_name(), paths.name, ctxt))
    end else begin
      `DV_CHECK_EQ(got[31:0], exp[31:0], $sformatf("%s: %s read data mismatch %s",
                                                   get_type_name(), paths.name, ctxt))
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
    check_fifo_state(paths, count, $sformatf("%s after fill", ctxt));
  endtask

  virtual task check_write_blocked(queue_hdl_paths_t paths, string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(paths.write_ready_path), 1'b0, $sformatf(
                                                      "%s: %s wready should deassert when full %s",
                                                      get_type_name(), paths.name, ctxt))
    check_fifo_state(paths, QueueDepth, ctxt);
  endtask

  virtual task check_read_blocked(queue_hdl_paths_t paths, string ctxt);
    `DV_CHECK_EQ(hdl_read_bit(paths.read_valid_path), 1'b0,
                 $sformatf("%s: %s rvalid should deassert when empty %s", get_type_name(),
                           paths.name, ctxt))
    check_fifo_state(paths, 0, ctxt);
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

endclass
