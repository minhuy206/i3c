class reg_coverage extends uvm_subscriber #(reg_seq_item);
  `uvm_component_utils(reg_coverage)

  typedef enum bit [1:0] {
    QUEUE_CMD_PUSH,
    QUEUE_TX_PUSH,
    QUEUE_RX_POP,
    QUEUE_RESP_POP
  } queue_sw_op_e;

  reg_seq_item                       reg_item;
  virtual reg_if                     vif;

  queue_sw_op_e                      queue_sw_op;

  bit                                dat_access;
  int unsigned                       dat_idx;
  controller_pkg::dat_entry_t        dat_entry;
  controller_pkg::dat_entry_t        dat_shadow                [DAT_DEPTH];
  bit                                dat_shadow_valid          [DAT_DEPTH];

  bit                                cmd_dw0_valid;
  bit                         [31:0] cmd_dw0;
  bit                                last_fsm_idle;

  bit                         [ 2:0] cmd_attr;
  bit                                cmd_rnw;
  bit                                cmd_toc;
  bit                                cmd_wroc;
  int unsigned                       cmd_data_len;
  int unsigned                       cmd_dtt;
  int unsigned                       cmd_dev_count;
  int unsigned                       cmd_dat_idx;
  i3c_trans_mode_e                   cmd_mode;
  bit                                cmd_present;
  bit                         [ 7:0] cmd_code;
  bit                                cmd_sre;

  // bit                                cmd_dbp; // Decoded for descriptor visibility only. Regular CCC is unsupported, so DBP is not sampled.

  bit                                cmd_has_rnw;
  bit                                cmd_has_data_len;
  bit                                cmd_has_dtt;
  bit                                cmd_has_dev_count;
  bit                                cmd_has_mode;
  bit                                cmd_has_present;
  bit                                cmd_has_sre;
  bit                                cmd_is_ccc;
  bit                                cmd_known_attr;
  bit                                cmd_dat_correlation_valid;
  bit                                cmd_device_type;

  bit                         [31:0] csr_hc_control_raw;
  bit                                csr_bus_enable;
  bit                                csr_broadcast_enable;
  bit                                csr_hc_abort;

  covergroup cg_dat_entry;
    option.per_instance = 1;

    cp_device: coverpoint dat_entry.device {bins i3c = {0}; bins legacy_i2c = {1};}
  endgroup

  covergroup cg_cmd_desc;
    option.per_instance = 1;

    cp_cmd_attr: coverpoint cmd_attr {
      bins regular = {RegularTransfer};
      bins immediate = {ImmediateDataTransfer};
      bins address_assignment = {AddressAssignment};
      bins unsupported = {[ComboTransfer : 3'd7]};
    }

    cp_cmd_rnw: coverpoint cmd_rnw iff (cmd_has_rnw) {bins write = {0}; bins read = {1};}

    cp_cmd_toc: coverpoint cmd_toc {
      bins continue_transfer = {0}; bins terminate_on_completion = {1};
    }

    cp_cmd_wroc: coverpoint cmd_wroc {bins no_response = {0}; bins response_required = {1};}

    cp_cmd_data_len: coverpoint cmd_data_len iff (cmd_has_data_len) {
      bins zero = {0};
      bins one = {1};
      bins short = {[2 : 4]};
      bins mid_size = {[5 : 8]};
      bins long = {[9 : 16]};
      bins larger = {[17 : 16'hffff]};
    }

    cp_cmd_dtt: coverpoint cmd_dtt iff (cmd_has_dtt) {
      bins valid[] = {[0 : 4]}; bins unsupported = {[5 : 7]};
    }

    cp_cmd_dev_count: coverpoint cmd_dev_count iff (cmd_has_dev_count) {
      bins zero = {0};
      bins one = {1};
      bins two = {2};
      bins three_or_more = {[3 : 15]};
    }

    cp_cmd_dat_idx: coverpoint cmd_dat_idx iff (cmd_known_attr) {
      bins first = {0};
      bins middle = {[1 : DAT_DEPTH - 2]};
      bins last = {DAT_DEPTH - 1};
    }

    cp_cmd_mode: coverpoint cmd_mode iff (cmd_has_mode) {
      bins sdr0_bin = {sdr0};
      bins unsupported = {[sdr1 : reserved]};
    }

    cp_cmd_present: coverpoint cmd_present iff (cmd_has_present) {
      bins absent = {0}; bins present = {1};
    }

    cp_cmd_code: coverpoint cmd_code iff (cmd_is_ccc) {
      bins broadcast_enec = {8'(ENEC)};
      bins broadcast_disec = {8'(DISEC)};
      bins direct_enec = {8'(DIR_ENEC)};
      bins direct_disec = {8'(DIR_DISEC)};
      bins entdaa = {8'(ENTDAA)};
      bins unsupported = default;
    }

    cp_cmd_sre: coverpoint cmd_sre iff (cmd_has_sre) {bins disabled = {0}; bins enabled = {1};}

    cx_cmd_attr_toc: cross cp_cmd_attr, cp_cmd_toc{
      ignore_bins unsupported_attr = binsof (cp_cmd_attr.unsupported);
    }

    cx_cmd_attr_present: cross cp_cmd_attr, cp_cmd_present{
      ignore_bins non_applicable_attr =
          binsof (cp_cmd_attr.address_assignment) || binsof (cp_cmd_attr.unsupported);
    }

  endgroup

  covergroup cg_cmd_dat_correlation;
    option.per_instance = 1;

    cp_cmd_corr_attr: coverpoint cmd_attr iff (cmd_dat_correlation_valid) {
      bins regular = {RegularTransfer};
      bins immediate = {ImmediateDataTransfer};
      bins address_assignment = {AddressAssignment};
      ignore_bins combo = {ComboTransfer};
      ignore_bins reserved_attr = {[3'd4 : 3'd7]};
    }

    cp_cmd_device_type: coverpoint cmd_device_type iff (cmd_dat_correlation_valid) {
      bins i3c = {0}; bins legacy_i2c = {1};
    }

    cx_cmd_attr_device: cross cp_cmd_corr_attr, cp_cmd_device_type{
      ignore_bins legacy_i2c_address_assignment =
          binsof (cp_cmd_device_type.legacy_i2c) && binsof (cp_cmd_corr_attr.address_assignment);
    }
  endgroup

  covergroup cg_hc_control;
    option.per_instance = 1;

    cp_bus_enable: coverpoint csr_bus_enable {bins disabled = {0}; bins enabled = {1};}

    cp_bus_enable_transition: coverpoint csr_bus_enable {
      bins enable_transition = (0 => 1); bins disable_transition = (1 => 0);
    }

    cp_broadcast_enable: coverpoint csr_broadcast_enable {bins disabled = {0}; bins enabled = {1};}

    cp_hc_abort: coverpoint csr_hc_abort {bins cleared = {0}; bins set = {1};}

    cp_hc_abort_transition: coverpoint csr_hc_abort {
      bins set_transition = (0 => 1); bins clear_transition = (1 => 0);
    }

    cx_bus_broadcast: cross cp_bus_enable, cp_broadcast_enable;
  endgroup

  covergroup cg_queue_sw_port;
    option.per_instance = 1;

    cp_queue_op: coverpoint queue_sw_op {
      bins cmd_push = {QUEUE_CMD_PUSH};
      bins tx_push = {QUEUE_TX_PUSH};
      bins rx_pop = {QUEUE_RX_POP};
      bins resp_pop = {QUEUE_RESP_POP};
    }
  endgroup

  function new(string name = "reg_coverage", uvm_component parent = null);
    super.new(name, parent);
    clear_hard_reset_tracking();
    cg_dat_entry = new();
    cg_cmd_desc = new();
    cg_cmd_dat_correlation = new();
    cg_hc_control = new();
    cg_queue_sw_port = new();
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual reg_if)::get(this, "", "vif", vif))
      `uvm_fatal(`gfn, "reg_coverage: failed to get reg_if")
  endfunction

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(negedge vif.rst_ni);
      clear_hard_reset_tracking();
    end
  endtask

  function void clear_command_tracking();
    cmd_dw0_valid = 1'b0;
    cmd_dw0 = '0;
  endfunction

  function void clear_hard_reset_tracking();
    clear_command_tracking();
    last_fsm_idle = 1'b1;
    foreach (dat_shadow[i]) begin
      dat_shadow[i] = '0;
      dat_shadow_valid[i] = 1'b0;
    end
  endfunction

  function void decode_reg_access(reg_seq_item item);
    dat_access = 1'b0;
    dat_idx = 0;

    if ((item.addr >= ADDR_DAT_BASE) &&
        (item.addr < ADDR_DAT_END) &&
        (item.addr[1:0] == 2'b00)) begin
      dat_access = 1'b1;
      dat_idx = (item.addr - ADDR_DAT_BASE) >> 2;
    end
  endfunction

  function void decode_cmd_desc(bit [63:0] raw_desc);
    regular_trans_desc_t        regular_desc;
    immediate_data_trans_desc_t immediate_desc;
    combo_trans_desc_t          combo_desc;
    addr_assign_desc_t          daa_desc;

    regular_desc = regular_trans_desc_t'(raw_desc);
    immediate_desc = immediate_data_trans_desc_t'(raw_desc);
    combo_desc = combo_trans_desc_t'(raw_desc);
    daa_desc = addr_assign_desc_t'(raw_desc);

    cmd_attr = raw_desc[2:0];
    cmd_toc = raw_desc[31];
    cmd_wroc = raw_desc[30];
    cmd_rnw = 1'b0;
    cmd_data_len = 0;
    cmd_dtt = 0;
    cmd_dev_count = 0;
    cmd_dat_idx = 0;
    cmd_mode = sdr0;
    cmd_present = 1'b0;
    cmd_code = raw_desc[14:7];
    cmd_sre = 1'b0;

    cmd_has_rnw = 1'b0;
    cmd_has_data_len = 1'b0;
    cmd_has_dtt = 1'b0;
    cmd_has_dev_count = 1'b0;
    cmd_has_mode = 1'b0;
    cmd_has_present = 1'b0;
    cmd_has_sre = 1'b0;
    cmd_is_ccc = 1'b0;
    cmd_known_attr = 1'b1;

    case (cmd_attr)
      RegularTransfer: begin
        cmd_rnw = regular_desc.rnw;
        cmd_data_len = regular_desc.data_length;
        cmd_dat_idx = regular_desc.dev_idx;
        cmd_mode = regular_desc.mode;
        cmd_present = regular_desc.cp;
        cmd_code = regular_desc.cmd;
        cmd_sre = regular_desc.sre;
        cmd_has_rnw = 1'b1;
        cmd_has_data_len = 1'b1;
        cmd_has_mode = 1'b1;
        cmd_has_present = 1'b1;
        cmd_has_sre = 1'b1;
      end

      ImmediateDataTransfer: begin
        cmd_rnw = immediate_desc.rnw;
        cmd_dtt = immediate_desc.dtt;
        cmd_dat_idx = immediate_desc.dev_idx;
        cmd_mode = immediate_desc.mode;
        cmd_present = immediate_desc.cp;
        cmd_code = immediate_desc.cmd;
        cmd_has_rnw = 1'b1;
        cmd_has_dtt = 1'b1;
        cmd_has_mode = 1'b1;
        cmd_has_present = 1'b1;
        cmd_is_ccc = immediate_desc.cp;
      end

      AddressAssignment: begin
        cmd_dev_count = daa_desc.dev_count;
        cmd_dat_idx = daa_desc.dev_idx;
        cmd_code = daa_desc.cmd;
        cmd_has_dev_count = 1'b1;
        cmd_is_ccc = 1'b1;
      end

      ComboTransfer: begin
        cmd_rnw = combo_desc.rnw;
        cmd_data_len = combo_desc.data_length;
        cmd_dat_idx = combo_desc.dev_idx;
        cmd_mode = combo_desc.mode;
        cmd_present = combo_desc.cp;
        cmd_code = combo_desc.cmd;
        cmd_has_rnw = 1'b1;
        cmd_has_data_len = 1'b1;
        cmd_has_mode = 1'b1;
        cmd_has_present = 1'b1;
      end

      default: begin
        cmd_known_attr = 1'b0;
      end
    endcase
  endfunction

  virtual function void write(reg_seq_item t);
    reg_item = t;
    decode_reg_access(t);
    if (t.addr == ADDR_HC_CONTROL) begin
      csr_hc_control_raw = t.is_write ? t.wdata : t.rdata;
      csr_bus_enable = csr_hc_control_raw[HC_CTRL_BUS_ENABLE_BIT];
      csr_broadcast_enable = csr_hc_control_raw[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
      csr_hc_abort = csr_hc_control_raw[HC_CTRL_ABORT_BIT];
      cg_hc_control.sample();
    end

    if (dat_access) begin
      dat_entry = controller_pkg::dat_entry_t'(t.is_write ? t.wdata : t.rdata);
      cg_dat_entry.sample();
      if (t.is_write) begin
        dat_shadow[dat_idx] = controller_pkg::dat_entry_t'(t.wdata);
        dat_shadow_valid[dat_idx] = 1'b1;
      end
    end

    if (t.is_write && (t.addr == ADDR_PIO_DATA_PORT)) begin
      queue_sw_op = QUEUE_TX_PUSH;
      cg_queue_sw_port.sample();
    end

    if (!t.is_write && (t.addr == ADDR_PIO_DATA_PORT)) begin
      queue_sw_op = QUEUE_RX_POP;
      cg_queue_sw_port.sample();
    end

    if (!t.is_write && (t.addr == ADDR_RESP)) begin
      queue_sw_op = QUEUE_RESP_POP;
      cg_queue_sw_port.sample();
    end

    if (!t.is_write && (t.addr == ADDR_HC_STATUS)) last_fsm_idle = t.rdata[HC_STS_FSM_IDLE_BIT];

    if (t.is_write && (t.addr == ADDR_RESET_CONTROL) &&
        t.wdata[RESET_CTRL_SOFT_RST_BIT] && last_fsm_idle) begin
      clear_command_tracking();
    end

    if (t.is_write && (t.addr == ADDR_CMD_QUEUE)) begin
      if (!cmd_dw0_valid) begin
        cmd_dw0 = t.wdata;
        cmd_dw0_valid = 1'b1;
      end else begin
        queue_sw_op = QUEUE_CMD_PUSH;
        cg_queue_sw_port.sample();
        decode_cmd_desc({t.wdata, cmd_dw0});
        cg_cmd_desc.sample();

        cmd_dat_correlation_valid =
            cmd_known_attr && (cmd_attr != ComboTransfer) && dat_shadow_valid[cmd_dat_idx];
        if (cmd_dat_correlation_valid) begin
          cmd_device_type = dat_shadow[cmd_dat_idx].device;
          cg_cmd_dat_correlation.sample();
        end

        cmd_dw0_valid = 1'b0;
        cmd_dw0 = '0;
      end
    end
  endfunction

  virtual function void report_phase(uvm_phase phase);
    super.report_phase(phase);

    `uvm_info("REG_COVERAGE", $sformatf(
              {
                "cg_dat_entry=%0.2f%% ",
                "cg_cmd_desc=%0.2f%% cg_cmd_dat_correlation=%0.2f%% ",
                "cg_hc_control=%0.2f%% ",
                "cg_queue_sw_port=%0.2f%%"
              },
              cg_dat_entry.get_inst_coverage(),
              cg_cmd_desc.get_inst_coverage(),
              cg_cmd_dat_correlation.get_inst_coverage(),
              cg_hc_control.get_inst_coverage(),
              cg_queue_sw_port.get_inst_coverage()
              ), UVM_NONE)
  endfunction
endclass
