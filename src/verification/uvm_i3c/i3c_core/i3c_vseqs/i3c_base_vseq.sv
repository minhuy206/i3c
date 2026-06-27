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

  localparam int unsigned BASE_CLK_PERIOD_NS = 3;
  localparam int unsigned FIFO_DEPTH_W = 7;

  // HDL path to flow_active FSM state register — update here if hierarchy changes.
  localparam string FLOW_FSM_STATE_PATH = "tb_i3c_top.dut.u_ctrl.u_flow_fsm.state_q";

  typedef bit [7:0] byte_queue_t[$];
  typedef bit [31:0] word_queue_t[$];

  typedef struct {
    string       ctxt;
    string       seq_name;
    bit [3:0]    tid;
    bit [4:0]    dev_idx;
    bit [6:0]    target_addr;
    bit          is_i3c;
    bit          ack_address;
    bit          ack_data;
    bit          tx_before_cmd;
    bit          wait_device_done;
    bit          start_with_broadcast_header;
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
    cmd_paths.name              = "CMD";
    cmd_paths.fifo_path         = "tb_i3c_top.dut.u_queues.cmd_fifo";
    cmd_paths.mem_path_fmt      = "tb_i3c_top.dut.u_queues.cmd_fifo.mem[%0d]";
    cmd_paths.rptr_path         = "tb_i3c_top.dut.u_queues.cmd_fifo.rptr_q";
    cmd_paths.wptr_path         = "tb_i3c_top.dut.u_queues.cmd_fifo.wptr_q";
    cmd_paths.depth_path        = "tb_i3c_top.dut.u_queues.cmd_fifo.depth_o";
    cmd_paths.write_valid_path  = "tb_i3c_top.dut.cmd_csr_wvalid";
    cmd_paths.write_ready_path  = "tb_i3c_top.dut.cmd_csr_wready";
    cmd_paths.write_data_path   = "tb_i3c_top.dut.cmd_csr_wdata";
    cmd_paths.read_valid_path   = "tb_i3c_top.dut.cmd_hw_rvalid";
    cmd_paths.read_ready_path   = "tb_i3c_top.dut.cmd_hw_rready";
    cmd_paths.read_data_path    = "tb_i3c_top.dut.cmd_hw_rdata";
    cmd_paths.full_bit          = QS_CMD_FULL_BIT;
    cmd_paths.empty_bit         = QS_CMD_EMPTY_BIT;
    cmd_paths.data_width        = 64;

    tx_paths.name               = "TX";
    tx_paths.fifo_path          = "tb_i3c_top.dut.u_queues.tx_fifo";
    tx_paths.mem_path_fmt       = "tb_i3c_top.dut.u_queues.tx_fifo.mem[%0d]";
    tx_paths.rptr_path          = "tb_i3c_top.dut.u_queues.tx_fifo.rptr_q";
    tx_paths.wptr_path          = "tb_i3c_top.dut.u_queues.tx_fifo.wptr_q";
    tx_paths.depth_path         = "tb_i3c_top.dut.u_queues.tx_fifo.depth_o";
    tx_paths.write_valid_path   = "tb_i3c_top.dut.tx_csr_wvalid";
    tx_paths.write_ready_path   = "tb_i3c_top.dut.tx_csr_wready";
    tx_paths.write_data_path    = "tb_i3c_top.dut.tx_csr_wdata";
    tx_paths.read_valid_path    = "tb_i3c_top.dut.tx_hw_rvalid";
    tx_paths.read_ready_path    = "tb_i3c_top.dut.tx_hw_rready";
    tx_paths.read_data_path     = "tb_i3c_top.dut.tx_hw_rdata";
    tx_paths.full_bit           = QS_TX_FULL_BIT;
    tx_paths.empty_bit          = QS_TX_EMPTY_BIT;
    tx_paths.data_width         = 32;

    rx_paths.name               = "RX";
    rx_paths.fifo_path          = "tb_i3c_top.dut.u_queues.rx_fifo";
    rx_paths.mem_path_fmt       = "tb_i3c_top.dut.u_queues.rx_fifo.mem[%0d]";
    rx_paths.rptr_path          = "tb_i3c_top.dut.u_queues.rx_fifo.rptr_q";
    rx_paths.wptr_path          = "tb_i3c_top.dut.u_queues.rx_fifo.wptr_q";
    rx_paths.depth_path         = "tb_i3c_top.dut.u_queues.rx_fifo.depth_o";
    rx_paths.write_valid_path   = "tb_i3c_top.dut.rx_hw_wvalid";
    rx_paths.write_ready_path   = "tb_i3c_top.dut.rx_hw_wready";
    rx_paths.write_data_path    = "tb_i3c_top.dut.rx_hw_wdata";
    rx_paths.read_valid_path    = "tb_i3c_top.dut.rx_csr_rvalid";
    rx_paths.read_ready_path    = "tb_i3c_top.dut.rx_csr_rready";
    rx_paths.read_data_path     = "tb_i3c_top.dut.rx_csr_rdata";
    rx_paths.full_bit           = QS_RX_FULL_BIT;
    rx_paths.empty_bit          = QS_RX_EMPTY_BIT;
    rx_paths.data_width         = 32;

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

  virtual function transfer_stimulus_cfg_t make_transfer_cfg(
      string ctxt, string seq_name, bit [3:0] tid, bit [4:0] dev_idx, bit [6:0] target_addr,
      bit is_i3c, bit ack_address = 1'b1, bit ack_data = 1'b1, bit tx_before_cmd = 1'b1,
      bit wait_device_done = 1'b1, bit start_with_broadcast_header = 1'b0,
      int unsigned data_length = 0, int unsigned settle_before_cmd = 0,
      int unsigned timeout_cycles = 0);
    transfer_stimulus_cfg_t cfg;

    cfg.ctxt                        = ctxt;
    cfg.seq_name                    = seq_name;
    cfg.tid                         = tid;
    cfg.dev_idx                     = dev_idx;
    cfg.target_addr                 = target_addr;
    cfg.is_i3c                      = is_i3c;
    cfg.ack_address                 = ack_address;
    cfg.ack_data                    = ack_data;
    cfg.tx_before_cmd               = tx_before_cmd;
    cfg.wait_device_done            = wait_device_done;
    cfg.start_with_broadcast_header = start_with_broadcast_header && is_i3c;
    cfg.data_length                 = data_length;
    cfg.settle_before_cmd           = settle_before_cmd;
    cfg.timeout_cycles              = timeout_cycles;
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

    bit_count = 9 + (9 * data_bytes);
    bit_period_cycles = ns_to_cycles(i2c_400.tClockLow + i2c_400.tClockPulse);
    framing_cycles = ns_to_cycles(
        i2c_400.tSetupStart + i2c_400.tHoldStart + i2c_400.tSetupStop + i2c_400.tHoldStop);
    return framing_cycles + (bit_count * bit_period_cycles) + 512;
  endfunction

  virtual function int unsigned i3c_device_done_timeout_cycles(transfer_stimulus_cfg_t cfg);
    int unsigned od_bit_count;
    int unsigned pp_bit_count;
    int unsigned od_bit_period_cycles;
    int unsigned pp_bit_period_cycles;
    int unsigned framing_cycles;

    od_bit_count = 9;
    if (cfg.start_with_broadcast_header) od_bit_count += 9;
    pp_bit_count = 9 * cfg.data_length;
    od_bit_period_cycles = ns_to_cycles(i3c_sdr.tClockLowOD + i3c_sdr.tClockPulse);
    pp_bit_period_cycles = ns_to_cycles(i3c_sdr.tClockLowPP + i3c_sdr.tClockPulse);
    framing_cycles = ns_to_cycles(
        i3c_sdr.tSetupStart + i3c_sdr.tHoldStart + i3c_sdr.tSetupStop + i3c_sdr.tHoldStop);
    return framing_cycles + (od_bit_count * od_bit_period_cycles) +
           (pp_bit_count * pp_bit_period_cycles) + 1024;
  endfunction

  virtual function int unsigned device_done_timeout_cycles(transfer_stimulus_cfg_t cfg);
    if (cfg.timeout_cycles != 0) return cfg.timeout_cycles;
    if (!cfg.is_i3c) return i2c_device_done_timeout_cycles(cfg.data_length);
    return i3c_device_done_timeout_cycles(cfg);
  endfunction

  virtual function regular_trans_desc_t build_regular_transfer_cmd(transfer_stimulus_cfg_t cfg,
                                                                   bit rnw, bit toc = 1'b1);
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


  virtual function void pack_payload_words(byte_queue_t exp_data, ref word_queue_t words);
    bit [31:0] word;

    words.delete();
    for (int unsigned word_idx = 0; word_idx < ((exp_data.size() + 3) / 4); word_idx++) begin
      word = '0;
      for (int unsigned byte_idx = 0; byte_idx < 4; byte_idx++) begin
        int unsigned data_idx;

        data_idx = (word_idx * 4) + byte_idx;
        if (data_idx < exp_data.size()) begin
          word[(byte_idx*8)+:8] = exp_data[data_idx];
        end
      end
      words.push_back(word);
    end
  endfunction

  virtual task configure_i3c_dat_target(int index, bit [6:0] static_addr, bit [6:0] dynamic_addr);
    if (index == 0) begin
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.static_addr = static_addr;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.static_addr_valid = 1'b1;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr = dynamic_addr;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid = 1'b1;
    end else if (index == 1) begin
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.static_addr = static_addr;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.static_addr_valid = 1'b1;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr = dynamic_addr;
      p_sequencer.cfg.m_i3c_agent_cfg.i3c_target1.dynamic_addr_valid = 1'b1;
    end
    write_dat_entry(index, static_addr, dynamic_addr, 1'b0);
  endtask

  virtual function i3c_seq_item randomize_transfer_item(
      string name = "transfer_item", int unsigned payload_len = 0,
      bit [6:0] avoid_static_addr = 7'h7e, bit [6:0] avoid_dynamic_addr = 7'h7e);
    i3c_seq_item item;

    item = i3c_seq_item::type_id::create(name);
    item.static_addr_constraint_en = 1'b1;
    item.dynamic_addr_constraint_en = 1'b1;
    item.payload_constraint_en = 1'b1;
    item.payload_len = payload_len;
    item.avoid_static_addr = avoid_static_addr;
    item.avoid_dynamic_addr = avoid_dynamic_addr;
    `DV_CHECK_RANDOMIZE_FATAL(item, $sformatf("%s randomization failed", name))
    return item;
  endfunction

  virtual task randomize_i3c_dat_target(
      int index, output bit [6:0] static_addr, output bit [6:0] dynamic_addr,
      input bit [6:0] avoid_static_addr = 7'h7e, input bit [6:0] avoid_dynamic_addr = 7'h7e);
    i3c_seq_item item;

    item = randomize_transfer_item($sformatf("dat_target_%0d_item", index), 0,
                                   avoid_static_addr, avoid_dynamic_addr);
    static_addr = item.static_addr;
    dynamic_addr = item.addr;
    configure_i3c_dat_target(index, static_addr, dynamic_addr);
  endtask

  virtual function void build_random_payload(int unsigned data_length, ref byte_queue_t data);
    i3c_seq_item item;

    item = randomize_transfer_item("payload_item", data_length);
    data = item.data;
  endfunction

  virtual function void build_random_tx_words(int unsigned data_length, ref byte_queue_t exp_data,
                                              ref word_queue_t tx_words);
    build_random_payload(data_length, exp_data);
    pack_payload_words(exp_data, tx_words);
  endfunction

  virtual function void build_sdr_data_pattern_payload(int unsigned pattern_idx,
                                                       ref byte_queue_t data);
    bit [7:0] fixed_random[16] = '{
        8'h3C,
        8'hA7,
        8'h19,
        8'hE2,
        8'h5D,
        8'h80,
        8'h0F,
        8'hB4,
        8'hC1,
        8'h26,
        8'h7A,
        8'h93,
        8'h48,
        8'hDE,
        8'h04,
        8'hF0
    };

    data.delete();

    case (pattern_idx)
      0: begin
        repeat (8) data.push_back(8'h00);
      end
      1: begin
        repeat (8) data.push_back(8'hFF);
      end
      2: begin
        for (int unsigned i = 0; i < 8; i++) begin
          data.push_back(8'(8'h01 << i));
        end
      end
      3: begin
        for (int unsigned i = 0; i < 8; i++) begin
          data.push_back(i[0] ? 8'h55 : 8'hAA);
        end
      end
      4: begin
        foreach (fixed_random[i]) begin
          data.push_back(fixed_random[i]);
        end
      end
      default: begin
        `uvm_fatal(`gfn, $sformatf("Unsupported SDR data pattern index %0d", pattern_idx))
      end
    endcase
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

  virtual task wait_for_flow_fsm_state(bit [3:0] target_state, string ctxt,
                                       int unsigned timeout_cycles = 500);
    uvm_hdl_data_t state_val;
    for (int i = 0; i < timeout_cycles; i++) begin
      @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
      if (!uvm_hdl_read(FLOW_FSM_STATE_PATH, state_val))
        `uvm_fatal(`gfn, $sformatf("%s: uvm_hdl_read failed for %s", ctxt, FLOW_FSM_STATE_PATH))
      if (state_val[3:0] == target_state) return;
    end
    `uvm_error(`gfn, $sformatf("%s: FSM did not reach state 4'd%0d within %0d cycles", ctxt,
                               target_state, timeout_cycles))
  endtask

  virtual task start_device_response(transfer_stimulus_cfg_t cfg, bit dir, byte_queue_t read_data,
                                     output i3c_device_response_seq dev_seq);
    dev_seq                             = i3c_device_response_seq::type_id::create(cfg.seq_name);
    dev_seq.target_addr                 = cfg.target_addr;
    dev_seq.ack_address                 = cfg.ack_address;
    dev_seq.ack_data                    = cfg.ack_data;
    dev_seq.is_i3c                      = cfg.is_i3c;
    dev_seq.dir                         = dir;
    dev_seq.start_with_broadcast_header = cfg.start_with_broadcast_header;
    dev_seq.read_data_cnt               = cfg.data_length;
    dev_seq.read_data                   = read_data;

    fork
      dev_seq.start(p_sequencer.m_i3c_sequencer);
    join_none
  endtask

  virtual task start_ordered_device_responses(
      input transfer_stimulus_cfg_t cfg0, input bit dir0, input byte_queue_t read_data0,
      output i3c_device_response_seq dev_seq0, input transfer_stimulus_cfg_t cfg1, input bit dir1,
      input byte_queue_t read_data1, output i3c_device_response_seq dev_seq1);
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

  virtual task write_write_cmd(input transfer_stimulus_cfg_t cfg, input bit toc = 1'b1);
    regular_trans_desc_t wr_cmd;

    wr_cmd = build_regular_transfer_cmd(cfg, 1'b0, toc);
    `uvm_info(`gfn, $sformatf(
                        "%s: write CMD dw0=0x%08h dw1=0x%08h tid=0x%0h dev_idx=%0d len=%0d toc=%0d",
                        cfg.ctxt, wr_cmd[31:0], wr_cmd[63:32], wr_cmd.tid, wr_cmd.dev_idx,
                        wr_cmd.data_length, wr_cmd.toc), UVM_LOW)
    write_cmd(wr_cmd[31:0], wr_cmd[63:32]);
  endtask

  virtual task write_read_cmd(input transfer_stimulus_cfg_t cfg, input bit toc = 1'b1);
    regular_trans_desc_t rd_cmd;

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, toc);
    `uvm_info(`gfn, $sformatf(
                        "%s: read CMD dw0=0x%08h dw1=0x%08h tid=0x%0h dev_idx=%0d len=%0d toc=%0d",
                        cfg.ctxt, rd_cmd[31:0], rd_cmd[63:32], rd_cmd.tid, rd_cmd.dev_idx,
                        rd_cmd.data_length, rd_cmd.toc), UVM_LOW)
    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
  endtask

  virtual task run_write_stimulus(transfer_stimulus_cfg_t cfg, word_queue_t tx_words,
                                  output bit [31:0] resp, output i3c_device_response_seq dev_seq);
    byte_queue_t no_read_data;

    start_device_response(cfg, 1'b0, no_read_data, dev_seq);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    if (cfg.tx_before_cmd) begin
      write_tx_words(tx_words);
      write_write_cmd(cfg);
    end else begin
      write_write_cmd(cfg);
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

  virtual task run_read_stimulus_words_with_actual_len(
      transfer_stimulus_cfg_t cfg, byte_queue_t read_data, int unsigned actual_data_length,
      output word_queue_t rx_words, output bit [31:0] resp, output i3c_device_response_seq dev_seq,
      input bit final_t_bit = 1'b0);
    regular_trans_desc_t rd_cmd;

    rd_cmd = build_regular_transfer_cmd(cfg, 1'b1, 1'b1);
    start_device_response(cfg, 1'b1, read_data, dev_seq);
    if (cfg.settle_before_cmd != 0) settle_cycles(cfg.settle_before_cmd);

    write_cmd(rd_cmd[31:0], rd_cmd[63:32]);
    poll_idle();
    if (cfg.wait_device_done) begin
      wait_for_device_done(dev_seq, cfg.ctxt, device_done_timeout_cycles(cfg));
    end
    read_rx_words(actual_data_length, rx_words);
    read_response(resp);
  endtask

  virtual task run_toc_zero_write_stimulus(
      transfer_stimulus_cfg_t cfg0, transfer_stimulus_cfg_t cfg1, word_queue_t tx_words,
      output bit [31:0] resp0, output bit [31:0] resp1, output int rstart_count,
      output i3c_device_response_seq dev_seq0, output i3c_device_response_seq dev_seq1);
    regular_trans_desc_t wr_cmd0;
    regular_trans_desc_t wr_cmd1;
    byte_queue_t         no_read_data;
    word_queue_t         tx_words0;
    word_queue_t         tx_words1;
    int unsigned         cfg0_word_count;

    wr_cmd0 = build_regular_transfer_cmd(cfg0, 1'b0, 1'b0);
    wr_cmd1 = build_regular_transfer_cmd(cfg1, 1'b0, 1'b1);
    cfg0_word_count = (cfg0.data_length + 3) / 4;
    foreach (tx_words[i]) begin
      if (i < cfg0_word_count) begin
        tx_words0.push_back(tx_words[i]);
      end else begin
        tx_words1.push_back(tx_words[i]);
      end
    end

    start_ordered_device_responses(cfg0, 1'b0, no_read_data, dev_seq0, cfg1, 1'b0, no_read_data,
                                   dev_seq1);
    if (cfg0.settle_before_cmd != 0) settle_cycles(cfg0.settle_before_cmd);

    if (cfg0.tx_before_cmd) write_tx_words(tx_words0);
    write_cmd(wr_cmd0[31:0], wr_cmd0[63:32]);
    if (!cfg0.tx_before_cmd) write_tx_words(tx_words0);
    if (cfg1.tx_before_cmd) write_tx_words(tx_words1);
    write_cmd(wr_cmd1[31:0], wr_cmd1[63:32]);
    if (!cfg1.tx_before_cmd) write_tx_words(tx_words1);

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);

    read_response(resp0);
    read_response(resp1);
  endtask

  virtual task run_toc_zero_read_stimulus(
      transfer_stimulus_cfg_t cfg0, transfer_stimulus_cfg_t cfg1, byte_queue_t read_data0,
      byte_queue_t read_data1, output word_queue_t rx_words0, output word_queue_t rx_words1,
      output bit [31:0] resp0, output bit [31:0] resp1, output int rstart_count,
      output i3c_device_response_seq dev_seq0, output i3c_device_response_seq dev_seq1);
    regular_trans_desc_t rd_cmd0;
    regular_trans_desc_t rd_cmd1;

    rd_cmd0 = build_regular_transfer_cmd(cfg0, 1'b1, 1'b0);
    rd_cmd1 = build_regular_transfer_cmd(cfg1, 1'b1, 1'b1);

    start_ordered_device_responses(cfg0, 1'b1, read_data0, dev_seq0, cfg1, 1'b1, read_data1,
                                   dev_seq1);
    if (cfg0.settle_before_cmd != 0) settle_cycles(cfg0.settle_before_cmd);

    write_cmd(rd_cmd0[31:0], rd_cmd0[63:32]);
    write_cmd(rd_cmd1[31:0], rd_cmd1[63:32]);

    poll_idle();
    wait_for_device_done(dev_seq0, cfg0.ctxt, device_done_timeout_cycles(cfg0));
    wait_for_device_done(dev_seq1, cfg1.ctxt, device_done_timeout_cycles(cfg1));
    rstart_count = int'(dev_seq0.observed_rstart) + int'(dev_seq1.observed_rstart);

    read_rx_words(cfg0.data_length, rx_words0);
    read_rx_words(cfg1.data_length, rx_words1);
    read_response(resp0);
    read_response(resp1);
  endtask

  virtual task run_toc_zero_read_write_stimulus(
      transfer_stimulus_cfg_t rd_cfg, transfer_stimulus_cfg_t wr_cfg, byte_queue_t read_data,
      word_queue_t tx_words, output bit [31:0] rx, output bit [31:0] resp0, output bit [31:0] resp1,
      output int rstart_count, output i3c_device_response_seq dev_seq0,
      output i3c_device_response_seq dev_seq1);
    regular_trans_desc_t rd_cmd0;
    regular_trans_desc_t wr_cmd1;
    byte_queue_t         no_read_data;

    rd_cmd0 = build_regular_transfer_cmd(rd_cfg, 1'b1, 1'b0);
    wr_cmd1 = build_regular_transfer_cmd(wr_cfg, 1'b0, 1'b1);

    start_ordered_device_responses(rd_cfg, 1'b1, read_data, dev_seq0, wr_cfg, 1'b0, no_read_data,
                                   dev_seq1);
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

  virtual function int unsigned hdl_read_uint_lsb(string path, int unsigned width);
    uvm_hdl_data_t raw;
    int unsigned   value;

    if ((width == 0) || (width > $bits(value))) begin
      `uvm_fatal(`gfn, $sformatf("%s: invalid hdl_read_uint_lsb width %0d for %s", get_type_name(),
                                 width, path))
    end

    raw   = hdl_read_checked(path);
    value = '0;
    for (int unsigned i = 0; i < width; i++) begin
      value[i] = raw[i];
    end
    return value;
  endfunction

  virtual function int unsigned hdl_read_fifo_depth(string path);
    return hdl_read_uint_lsb(path, FIFO_DEPTH_W);
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
    if (paths.name == "RX") begin
      uvm_component  comp;
      i3c_scoreboard scb;

      comp = uvm_top.find("uvm_test_top.env.m_scoreboard");
      if (!$cast(scb, comp)) begin
        `uvm_fatal(`gfn, $sformatf("%s: could not find i3c_scoreboard", get_type_name()))
      end
      scb.set_rx_fifo_level_unknown(count, get_type_name());
    end
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

  virtual task enable_dut(bit broadcast_header_enable = 1'b0);
    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(1'b1), .iba_include(broadcast_header_enable)));
  endtask

  virtual task disable_dut();
    reg_write(ADDR_HC_CONTROL, hc_control_value());
  endtask

  virtual task request_sw_reset(bit keep_enabled = 1'b0);
    bit [31:0] data;
    bit        keep_broadcast_header_enable;

    poll_idle();
    reg_read(ADDR_HC_CONTROL, data);
    keep_broadcast_header_enable = data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
    reg_write(ADDR_HC_CONTROL, hc_control_value(
              .bus_enable(keep_enabled), .iba_include(keep_broadcast_header_enable)));
    reg_write(ADDR_RESET_CONTROL, 32'h1 << RESET_CTRL_SOFT_RST_BIT);
    settle_cycles();

    reg_read(ADDR_HC_CONTROL, data);
    `DV_CHECK_EQ(data[HC_CTRL_ENABLE_BIT], keep_enabled,
                 $sformatf("%s: SW_RESET should preserve requested enable state", get_type_name()))
    `DV_CHECK_EQ(data[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT], keep_broadcast_header_enable,
                 $sformatf("%s: SW_RESET should preserve BROADCAST_HEADER_ENABLE config",
                           get_type_name()))
    reg_read(ADDR_RESET_CONTROL, data);
    `DV_CHECK_EQ(data[RESET_CTRL_SOFT_RST_BIT], 1'b0, $sformatf("%s: SOFT_RST should self-clear",
                                                                get_type_name()))
  endtask

  virtual function string private_addr_mode_name(bit broadcast_header_enable);
    return broadcast_header_enable ? "broadcast" : "private";
  endfunction

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
    reg_write(ADDR_PIO_DATA_PORT, data);
  endtask

  virtual task read_rx_data(output bit [31:0] data);
    reg_read(ADDR_PIO_DATA_PORT, data);
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
