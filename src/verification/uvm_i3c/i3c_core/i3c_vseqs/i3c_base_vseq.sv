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

  localparam int unsigned BASE_CLK_PERIOD_NS = 10;

  typedef bit [7:0] byte_queue_t[$];
  typedef bit [31:0] word_queue_t[$];

  typedef struct {
    string       ctxt;
    string       seq_name;
    bit [ 3:0]  tid;
    bit [ 4:0]  dev_idx;
    bit [ 6:0]  target_addr;
    bit         is_i3c;
    bit         ack_address;
    bit         ack_data;
    bit         tx_before_cmd;
    bit         wait_device_done;
    int unsigned data_length;
    int unsigned settle_before_cmd;
    int unsigned timeout_cycles;
  } transfer_stimulus_cfg_t;

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

  virtual function transfer_stimulus_cfg_t make_transfer_cfg(string ctxt, string seq_name,
                                                             bit [3:0] tid, bit [4:0] dev_idx,
                                                             bit [6:0] target_addr,
                                                             bit is_i3c,
                                                             int unsigned data_length);
    transfer_stimulus_cfg_t cfg;

    cfg.ctxt              = ctxt;
    cfg.seq_name          = seq_name;
    cfg.tid               = tid;
    cfg.dev_idx           = dev_idx;
    cfg.target_addr       = target_addr;
    cfg.is_i3c            = is_i3c;
    cfg.ack_address       = 1'b1;
    cfg.ack_data          = 1'b1;
    cfg.tx_before_cmd     = 1'b1;
    cfg.wait_device_done  = 1'b0;
    cfg.data_length       = data_length;
    cfg.settle_before_cmd = 0;
    cfg.timeout_cycles    = 0;
    return cfg;
  endfunction

  virtual function int unsigned ns_to_cycles(int ns);
    if (ns <= 0) return 0;
    return (ns + BASE_CLK_PERIOD_NS - 1) / BASE_CLK_PERIOD_NS;
  endfunction

  virtual function int unsigned i2c_device_done_timeout_cycles(int unsigned data_bytes);
    int unsigned bit_count;
    int unsigned bit_period_cycles;
    int unsigned framing_cycles;

    bit_count         = 9 + (9 * data_bytes);
    bit_period_cycles = ns_to_cycles(i2c_400.tClockLow + i2c_400.tClockPulse);
    framing_cycles    = ns_to_cycles(i2c_400.tSetupStart + i2c_400.tHoldStart +
                                      i2c_400.tSetupStop + i2c_400.tHoldStop);
    return framing_cycles + (bit_count * bit_period_cycles) + 512;
  endfunction

  virtual function int unsigned device_done_timeout_cycles(transfer_stimulus_cfg_t cfg);
    if (cfg.timeout_cycles != 0) return cfg.timeout_cycles;
    if (!cfg.is_i3c) return i2c_device_done_timeout_cycles(cfg.data_length);
    return 1000;
  endfunction

  virtual function regular_trans_desc_t build_regular_transfer_cmd(
      transfer_stimulus_cfg_t cfg, bit rnw, bit toc = 1'b1);
    regular_trans_desc_t cmd;

    cmd             = '0;
    cmd.attr        = RegularTransfer;
    cmd.tid         = cfg.tid;
    cmd.rnw         = rnw;
    cmd.mode        = sdr0;
    cmd.toc         = toc;
    cmd.wroc        = 1'b1;
    cmd.dev_idx     = cfg.dev_idx;
    cmd.data_length = 16'(cfg.data_length);
    return cmd;
  endfunction

  virtual function bit [31:0] pack_bytes_to_word(byte_queue_t data);
    bit [31:0] word;

    word = '0;
    for (int i = 0; (i < data.size()) && (i < 4); i++) begin
      word[(i*8)+:8] = data[i];
    end
    return word;
  endfunction

  virtual task wait_for_device_done(i3c_device_response_seq dev_seq, string ctxt,
                                    int unsigned timeout_cycles = 1000);
    for (int i = 0; i < timeout_cycles; i++) begin
      if (dev_seq.done) return;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `uvm_error(`gfn, $sformatf("%s: device response did not finish", ctxt))
  endtask

  virtual task wait_for_device_request_issued(i3c_device_response_seq dev_seq, string ctxt,
                                              int unsigned timeout_cycles = 100);
    for (int i = 0; i < timeout_cycles; i++) begin
      if (dev_seq.request_issued) return;
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    end

    `uvm_error(`gfn, $sformatf("%s: device response request was not issued", ctxt))
  endtask

  virtual task start_device_response(transfer_stimulus_cfg_t cfg, bit dir,
                                     byte_queue_t read_data,
                                     output i3c_device_response_seq dev_seq);
    dev_seq               = i3c_device_response_seq::type_id::create(cfg.seq_name);
    dev_seq.target_addr   = cfg.target_addr;
    dev_seq.ack_address   = cfg.ack_address;
    dev_seq.ack_data      = cfg.ack_data;
    dev_seq.is_i3c        = cfg.is_i3c;
    dev_seq.dir           = dir;
    dev_seq.read_data_cnt = cfg.data_length;
    dev_seq.read_data     = read_data;

    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none
  endtask

  virtual task start_ordered_device_responses(input transfer_stimulus_cfg_t cfg0,
                                              input bit dir0,
                                              input byte_queue_t read_data0,
                                              output i3c_device_response_seq dev_seq0,
                                              input transfer_stimulus_cfg_t cfg1,
                                              input bit dir1,
                                              input byte_queue_t read_data1,
                                              output i3c_device_response_seq dev_seq1);
    start_device_response(cfg0, dir0, read_data0, dev_seq0);
    wait_for_device_request_issued(dev_seq0, cfg0.ctxt);
    start_device_response(cfg1, dir1, read_data1, dev_seq1);
    settle_cycles(1);
  endtask

  virtual task write_tx_words(word_queue_t tx_words);
    foreach (tx_words[i]) begin
      write_tx_data(tx_words[i]);
    end
  endtask

  virtual task run_write_stimulus(transfer_stimulus_cfg_t cfg, word_queue_t tx_words,
                                  output bit [31:0] resp,
                                  output i3c_device_response_seq dev_seq);
    regular_trans_desc_t wr_cmd;
    byte_queue_t         no_read_data;

    wr_cmd = build_regular_transfer_cmd(cfg, 1'b0, 1'b1);
    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    if (cfg.tx_before_cmd) begin
      write_tx_words(tx_words);
      write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
    end else begin
      write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
      write_tx_words(tx_words);
    end

    poll_idle();
    if (cfg.wait_device_done) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    end
    read_response(resp);
  endtask

  virtual task run_read_stimulus(transfer_stimulus_cfg_t cfg, byte_queue_t read_data,
                                 output bit [31:0] rx, output bit [31:0] resp,
                                 output i3c_device_response_seq dev_seq);
    regular_trans_desc_t rd_cmd;

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    expect_scoreboard_read_data(cfg, read_data, cfg.data_length);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();
    if (cfg.wait_device_done) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    end
    read_rx_data(rx);
    read_response(resp);
  endtask

  virtual task run_read_stimulus_words(transfer_stimulus_cfg_t cfg, byte_queue_t read_data,
                                       output word_queue_t rx_words, output bit [31:0] resp,
                                       output i3c_device_response_seq dev_seq);
    run_read_stimulus_words_with_actual_len(cfg, read_data, cfg.data_length, rx_words, resp,
                                            dev_seq);
  endtask

  virtual task run_read_stimulus_words_with_actual_len(transfer_stimulus_cfg_t cfg,
                                                       byte_queue_t read_data,
                                                       int unsigned actual_data_length,
                                                       output word_queue_t rx_words,
                                                       output bit [31:0] resp,
                                                       output i3c_device_response_seq dev_seq,
                                                       input bit final_t_bit = 1'b0);
    regular_trans_desc_t rd_cmd;

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    expect_scoreboard_read_data(cfg, read_data, actual_data_length, final_t_bit);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();
    if (cfg.wait_device_done) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    end
    read_rx_words(actual_data_length, rx_words);
    read_response(resp);
  endtask

  virtual task run_toc_zero_write_stimulus(transfer_stimulus_cfg_t cfg0,
                                           transfer_stimulus_cfg_t cfg1,
                                           word_queue_t tx_words, output bit [31:0] resp0,
                                           output bit [31:0] resp1, output int rstart_count,
                                           output i3c_device_response_seq dev_seq0,
                                           output i3c_device_response_seq dev_seq1);
    regular_trans_desc_t wr_cmd0;
    regular_trans_desc_t wr_cmd1;
    byte_queue_t         no_read_data;

    wr_cmd0 = build_regular_transfer_cmd(cfg0, 1'b0, 1'b0);
    wr_cmd1 = build_regular_transfer_cmd(cfg1, 1'b0, 1'b1);

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0,
                                   cfg1, 1'b0, no_read_data, dev_seq1);
    if (cfg0.settle_before_cmd != 0) settle_cycles(cfg0.settle_before_cmd);

    write_cmd(wr_cmd0[31:0], wr_cmd0[63:32]);
    write_cmd(wr_cmd1[31:0], wr_cmd1[63:32]);
    write_tx_words(tx_words);

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);

    read_response(resp0);
    read_response(resp1);
  endtask

  virtual task run_toc_zero_read_write_stimulus(transfer_stimulus_cfg_t rd_cfg,
                                                transfer_stimulus_cfg_t wr_cfg,
                                                byte_queue_t read_data, word_queue_t tx_words,
                                                output bit [31:0] rx, output bit [31:0] resp0,
                                                output bit [31:0] resp1,
                                                output int rstart_count,
                                                output i3c_device_response_seq dev_seq0,
                                                output i3c_device_response_seq dev_seq1);
    regular_trans_desc_t rd_cmd0;
    regular_trans_desc_t wr_cmd1;
    byte_queue_t         no_read_data;

    rd_cmd0 = build_regular_transfer_cmd(rd_cfg, 1'b1, 1'b0);
    wr_cmd1 = build_regular_transfer_cmd(wr_cfg, 1'b0, 1'b1);

    start_ordered_device_responses(rd_cfg, 1'b1, read_data, dev_seq0,
                                   wr_cfg, 1'b0, no_read_data, dev_seq1);
    if (rd_cfg.settle_before_cmd != 0) settle_cycles(rd_cfg.settle_before_cmd);

    write_cmd(rd_cmd0[31:0], rd_cmd0[63:32]);
    write_cmd(wr_cmd1[31:0], wr_cmd1[63:32]);
    write_tx_words(tx_words);

    poll_idle();
    wait_for_device_done(dev_seq0, rd_cfg.ctxt, device_done_timeout_cycles(rd_cfg));
    wait_for_device_done(dev_seq1, wr_cfg.ctxt, device_done_timeout_cycles(wr_cfg));
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);

    read_rx_data(rx);
    read_response(resp0);
    read_response(resp1);
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

  virtual function void expect_scoreboard_resp_error(bit [3:0] err_status, bit [3:0] tid,
                                                     bit [15:0] data_length, string ctxt);
    uvm_component comp;
    i3c_scoreboard scb;

    comp = uvm_top.find("uvm_test_top.env.m_scoreboard");
    if (!$cast(scb, comp)) begin
      `uvm_fatal(`gfn, $sformatf("%s: could not find i3c_scoreboard", ctxt))
    end
    scb.expect_resp_error(err_status, tid, data_length);
  endfunction

  virtual function void expect_scoreboard_read_data(transfer_stimulus_cfg_t cfg,
                                                    byte_queue_t read_data,
                                                    int unsigned actual_data_length,
                                                    bit final_t_bit = 1'b0);
    uvm_component comp;
    i3c_scoreboard scb;
    byte_queue_t exp_read_data;

    comp = uvm_top.find("uvm_test_top.env.m_scoreboard");
    if (!$cast(scb, comp)) begin
      `uvm_fatal(`gfn, $sformatf("%s: could not find i3c_scoreboard", cfg.ctxt))
    end

    exp_read_data.delete();
    for (int unsigned i = 0; (i < actual_data_length) && (i < read_data.size()); i++) begin
      exp_read_data.push_back(read_data[i]);
    end

    scb.expect_read_data(cfg.target_addr, cfg.tid, cfg.data_length, actual_data_length,
                         exp_read_data, cfg.ack_data, final_t_bit);
  endfunction

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

  virtual task read_rx_words(int unsigned data_length, output word_queue_t rx_words);
    bit [31:0] data;

    rx_words.delete();
    for (int unsigned i = 0; i < ((data_length + 3) / 4); i++) begin
      read_rx_data(data);
      rx_words.push_back(data);
    end
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
