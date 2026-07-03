class reg_coverage extends uvm_subscriber #(reg_seq_item);
  `uvm_component_utils(reg_coverage)

  typedef enum bit [1:0] {
    ADDR_MAPPED,
    ADDR_ALIGNED_UNMAPPED,
    ADDR_MISALIGNED
  } reg_addr_class_e;

  typedef enum bit [1:0] {
    QUEUE_CMD_PUSH,
    QUEUE_TX_PUSH,
    QUEUE_RX_POP,
    QUEUE_RESP_POP
  } queue_sw_op_e;

  typedef enum bit [2:0] {
    CMD_CLASS_REG_WRITE,
    CMD_CLASS_REG_READ,
    CMD_CLASS_IMMEDIATE,
    CMD_CLASS_CCC,
    CMD_CLASS_DAA
  } cmd_class_e;

  reg_seq_item                       reg_item;
  virtual reg_if                     vif;

  reg_addr_class_e                   addr_class;
  queue_sw_op_e                      queue_sw_op;

  bit                                dat_access;
  int unsigned                       dat_idx;
  controller_pkg::dat_entry_t        dat_entry;
  bit                         [31:0] dat_raw;
  bit                                dat_reserved_nonzero;
  controller_pkg::dat_entry_t        dat_shadow[DAT_DEPTH];
  bit                                dat_shadow_valid[DAT_DEPTH];

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
  bit                         [ 3:0] cmd_tid;
  i3c_trans_mode_e                   cmd_mode;
  bit                                cmd_present;
  bit                         [ 7:0] cmd_code;
  bit                                cmd_sre;
  bit                                cmd_dbp;

  bit                                cmd_has_rnw;
  bit                                cmd_has_data_len;
  bit                                cmd_has_dtt;
  bit                                cmd_has_dev_count;
  bit                                cmd_has_mode;
  bit                                cmd_has_present;
  bit                                cmd_has_sre_dbp;
  bit                                cmd_is_ccc;
  bit                                cmd_known_attr;
  bit                                cmd_supported;

  bit                                cmd_dat_correlation_valid;
  bit                                cmd_device_type;

  cmd_class_e                        current_cmd_class;
  cmd_class_e                        previous_cmd_class;
  bit                                previous_cmd_valid;

  i3c_response_desc_t                resp_desc;

  bit                         [31:0] csr_hc_control_raw;
  bit                                csr_bus_enable;
  bit                                csr_broadcast_enable;
  bit                                csr_hc_abort;

  bit                         [11:0] timing_addr;
  bit                         [31:0] timing_raw;
  bit                                timing_is_default;
  bit                                timing_reserved_upper;

  covergroup cg_reg_access;
    option.per_instance = 1;

    cp_access_type: coverpoint reg_item.is_write {bins read = {0}; bins write = {1};}

    cp_addr: coverpoint reg_item.addr {
      bins hc_control = {ADDR_HC_CONTROL};
      bins reset_control = {ADDR_RESET_CONTROL};
      bins hc_status = {ADDR_HC_STATUS};

      bins cmd_queue = {ADDR_CMD_QUEUE};
      bins resp = {ADDR_RESP};
      bins pio_data_port = {ADDR_PIO_DATA_PORT};
      bins queue_status = {ADDR_QUEUE_STATUS};

      bins timing_regs[] = {
        ADDR_T_R,
        ADDR_T_F,
        ADDR_T_SU_DAT,
        ADDR_I2C_T_SU_DAT,
        ADDR_T_HD_DAT,
        ADDR_T_HIGH,
        ADDR_I2C_T_HIGH,
        ADDR_T_LOW,
        ADDR_T_LOW_OD,
        ADDR_I2C_T_LOW,
        ADDR_T_HD_STA,
        ADDR_I2C_T_HD_STA,
        ADDR_T_SU_STA,
        ADDR_I2C_T_SU_STA,
        ADDR_T_SU_STO,
        ADDR_I2C_T_SU_STO,
        ADDR_T_BUS_FREE,
        ADDR_I2C_T_BUF
      };

      bins dat_table = {[ADDR_DAT_BASE : ADDR_DAT_END - 12'd4]};
    }

    cp_addr_class: coverpoint addr_class {
      bins mapped = {ADDR_MAPPED};
      bins aligned_unmapped = {ADDR_ALIGNED_UNMAPPED};
      bins misaligned = {ADDR_MISALIGNED};
    }

    cp_dat_idx: coverpoint dat_idx iff (dat_access) {bins idx[] = {[0 : DAT_DEPTH - 1]};}

    cx_access_addr: cross cp_access_type, cp_addr;
    cx_access_addr_class: cross cp_access_type, cp_addr_class;
    cx_access_dat_idx: cross cp_access_type, cp_dat_idx;
  endgroup

  covergroup cg_dat_entry;
    option.per_instance = 1;

    cp_access_type: coverpoint reg_item.is_write {bins read = {0}; bins write = {1};}

    cp_device: coverpoint dat_entry.device {bins i3c = {0}; bins legacy_i2c = {1};}

    cp_static_addr: coverpoint dat_entry.static_address {
      bins zero = {7'h00};
      bins low_range = {[7'h01 : 7'h07]};
      bins usable = {[7'h08 : 7'h77]};
      bins high_range = {[7'h78 : 7'h7f]};
    }

    cp_dynamic_addr: coverpoint dat_entry.dynamic_address {
      bins zero = {7'h00};
      bins low_range = {[7'h01 : 7'h07]};
      bins usable = {[7'h08 : 7'h77]};
      bins high_range = {[7'h78 : 7'h7f]};
    }

    cp_reserved_write_attempt: coverpoint dat_reserved_nonzero iff (reg_item.is_write) {
      bins clean = {0}; bins attempted = {1};
    }

    cx_access_device: cross cp_access_type, cp_device;
    cx_access_static_addr: cross cp_access_type, cp_static_addr;
    cx_access_dynamic_addr: cross cp_access_type, cp_dynamic_addr;
  endgroup

  covergroup cg_cmd_desc;
    option.per_instance = 1;

    cp_cmd_attr: coverpoint cmd_attr {
      bins regular = {RegularTransfer};
      bins immediate = {ImmediateDataTransfer};
      bins address_assignment = {AddressAssignment};
      bins combo = {ComboTransfer};
      bins reserved[] = {[3'd4 : 3'd7]};
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
      bins valid[] = {[0 : 4]}; bins reserved[] = {[5 : 7]};
    }

    cp_cmd_dev_count: coverpoint cmd_dev_count iff (cmd_has_dev_count) {
      bins zero = {0}; bins count[] = {[1 : 15]};
    }

    cp_cmd_dat_idx: coverpoint cmd_dat_idx iff (cmd_known_attr) {
      bins idx[] = {[0 : DAT_DEPTH - 1]};
    }

    cp_cmd_tid: coverpoint cmd_tid {bins tid[] = {[0 : 15]};}

    cp_cmd_mode: coverpoint cmd_mode iff (cmd_has_mode) {
      bins sdr0_bin = {sdr0};
      bins sdr1_bin = {sdr1};
      bins sdr2_bin = {sdr2};
      bins sdr3_bin = {sdr3};
      bins sdr4_bin = {sdr4};
      bins hdr_tsx_bin = {hdr_tsx};
      bins hdr_ddr_bin = {hdr_ddr};
      bins reserved_bin = {reserved};
    }

    cp_cmd_present: coverpoint cmd_present iff (cmd_has_present) {
      bins absent = {0}; bins present = {1};
    }

    cp_cmd_code: coverpoint cmd_code iff (cmd_is_ccc) {
      bins broadcast_enec  = {8'(ENEC)};
      bins broadcast_disec = {8'(DISEC)};
      bins direct_enec     = {8'(DIR_ENEC)};
      bins direct_disec    = {8'(DIR_DISEC)};
      bins entdaa          = {8'(ENTDAA)};
      bins unsupported = default;
    }

    cp_cmd_sre: coverpoint cmd_sre iff (cmd_has_sre_dbp) {
      bins disabled = {0}; bins enabled = {1};
    }

    cp_cmd_dbp: coverpoint cmd_dbp iff (cmd_has_sre_dbp) {
      bins absent = {0}; bins present = {1};
    }

    cx_regular_rnw_len: cross cp_cmd_rnw, cp_cmd_data_len iff (cmd_attr == RegularTransfer);

    cx_cmd_attr_toc: cross cp_cmd_attr, cp_cmd_toc{
      ignore_bins reserved_attr = binsof (cp_cmd_attr.reserved);
    }

    cx_cmd_attr_present: cross cp_cmd_attr, cp_cmd_present {
      ignore_bins non_applicable_attr =
          binsof (cp_cmd_attr.address_assignment) || binsof (cp_cmd_attr.reserved);
    }

    cx_cmd_sre_dbp: cross cp_cmd_sre, cp_cmd_dbp;

    cx_cmd_attr_dat_idx: cross cp_cmd_attr, cp_cmd_dat_idx {
      ignore_bins reserved_attr = binsof (cp_cmd_attr.reserved);
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

    cx_cmd_attr_device: cross cp_cmd_corr_attr, cp_cmd_device_type;
  endgroup

  covergroup cg_cmd_transition;
    option.per_instance = 1;

    cp_previous_cmd_class: coverpoint previous_cmd_class {
      bins regular_write = {CMD_CLASS_REG_WRITE};
      bins regular_read = {CMD_CLASS_REG_READ};
      bins immediate = {CMD_CLASS_IMMEDIATE};
      bins ccc = {CMD_CLASS_CCC};
      bins daa = {CMD_CLASS_DAA};
    }

    cp_current_cmd_class: coverpoint current_cmd_class {
      bins regular_write = {CMD_CLASS_REG_WRITE};
      bins regular_read = {CMD_CLASS_REG_READ};
      bins immediate = {CMD_CLASS_IMMEDIATE};
      bins ccc = {CMD_CLASS_CCC};
      bins daa = {CMD_CLASS_DAA};
    }

    cx_previous_next_cmd: cross cp_previous_cmd_class, cp_current_cmd_class;
  endgroup

  covergroup cg_resp_desc;
    option.per_instance = 1;

    cp_resp_status: coverpoint resp_desc.err_status {
      bins success = {Success};
      bins addr_header = {AddrHeader};
      bins nack = {Nack};
      bins overflow = {Ovl};
      bins short_read = {I3cShortReadErr};
      bins hc_aborted = {HcAborted};
      bins data_nack_or_bus_aborted = {I2cDataNackOrI3cBusAborted};
      bins not_supported = {NotSupported};
      ignore_bins unreachable = {Crc, Parity, Frame};
    }

    cp_resp_tid: coverpoint resp_desc.tid {bins tid[] = {[0 : 15]};}

    cp_resp_data_len: coverpoint resp_desc.data_length {
      bins zero = {0};
      bins one = {1};
      bins short = {[2 : 4]};
      bins mid_size = {[5 : 8]};
      bins long = {[9 : 16]};
      bins larger = {[17 : 16'hffff]};
    }

    cp_resp_reserved_zero: coverpoint resp_desc.__rsvd23_16 {bins zero = {8'h00};}
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

  covergroup cg_timing_csr;
    option.per_instance = 1;

    cp_timing_reg: coverpoint timing_addr {
      bins regs[] = {
        ADDR_T_R,
        ADDR_T_F,
        ADDR_T_SU_DAT,
        ADDR_I2C_T_SU_DAT,
        ADDR_T_HD_DAT,
        ADDR_T_HIGH,
        ADDR_I2C_T_HIGH,
        ADDR_T_LOW,
        ADDR_T_LOW_OD,
        ADDR_I2C_T_LOW,
        ADDR_T_HD_STA,
        ADDR_I2C_T_HD_STA,
        ADDR_T_SU_STA,
        ADDR_I2C_T_SU_STA,
        ADDR_T_SU_STO,
        ADDR_I2C_T_SU_STO,
        ADDR_T_BUS_FREE,
        ADDR_I2C_T_BUF
      };
    }

    cp_timing_value: coverpoint timing_raw[19:0] {
      bins zero = {20'h00000};
      bins one = {20'h00001};
      bins middle = {[20'h00002 : 20'hffffe]};
      bins max = {20'hfffff};
    }

    cp_timing_default: coverpoint timing_is_default {
      bins non_default_value = {0}; bins default_value = {1};
    }

    cp_timing_reserved_upper: coverpoint timing_reserved_upper {
      bins clear = {0}; bins write_attempt = {1};
    }

    cx_timing_reg_value: cross cp_timing_reg, cp_timing_value;
    cx_timing_reg_default: cross cp_timing_reg, cp_timing_default;
    cx_timing_reg_reserved: cross cp_timing_reg, cp_timing_reserved_upper;
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
    cg_reg_access = new();
    cg_dat_entry = new();
    cg_cmd_desc = new();
    cg_cmd_dat_correlation = new();
    cg_cmd_transition = new();
    cg_resp_desc = new();
    cg_hc_control = new();
    cg_timing_csr = new();
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
    previous_cmd_valid = 1'b0;
  endfunction

  function void clear_hard_reset_tracking();
    clear_command_tracking();
    last_fsm_idle = 1'b1;
    foreach (dat_shadow[i]) begin
      dat_shadow[i] = '0;
      dat_shadow_valid[i] = 1'b0;
    end
  endfunction

  function bit is_mapped_addr(bit [11:0] addr);
    if (addr[1:0] != 2'b00) return 1'b0;

    case (addr)
      ADDR_HC_CONTROL,
      ADDR_RESET_CONTROL,
      ADDR_HC_STATUS,
      ADDR_CMD_QUEUE,
      ADDR_RESP,
      ADDR_PIO_DATA_PORT,
      ADDR_QUEUE_STATUS,
      ADDR_T_R,
      ADDR_T_F,
      ADDR_T_SU_DAT,
      ADDR_I2C_T_SU_DAT,
      ADDR_T_HD_DAT,
      ADDR_T_HIGH,
      ADDR_I2C_T_HIGH,
      ADDR_T_LOW,
      ADDR_T_LOW_OD,
      ADDR_I2C_T_LOW,
      ADDR_T_HD_STA,
      ADDR_I2C_T_HD_STA,
      ADDR_T_SU_STA,
      ADDR_I2C_T_SU_STA,
      ADDR_T_SU_STO,
      ADDR_I2C_T_SU_STO,
      ADDR_T_BUS_FREE,
      ADDR_I2C_T_BUF:
      return 1'b1;
      default: begin
        return (addr >= ADDR_DAT_BASE) && (addr < ADDR_DAT_END);
      end
    endcase
  endfunction

  function reg_addr_class_e classify_reg_addr(bit [11:0] addr);
    if (addr[1:0] != 2'b00) return ADDR_MISALIGNED;
    if (is_mapped_addr(addr)) return ADDR_MAPPED;
    return ADDR_ALIGNED_UNMAPPED;
  endfunction

  function bit is_timing_csr(bit [11:0] addr);
    case (addr)
      ADDR_T_R,
      ADDR_T_F,
      ADDR_T_SU_DAT,
      ADDR_I2C_T_SU_DAT,
      ADDR_T_HD_DAT,
      ADDR_T_HIGH,
      ADDR_I2C_T_HIGH,
      ADDR_T_LOW,
      ADDR_T_LOW_OD,
      ADDR_I2C_T_LOW,
      ADDR_T_HD_STA,
      ADDR_I2C_T_HD_STA,
      ADDR_T_SU_STA,
      ADDR_I2C_T_SU_STA,
      ADDR_T_SU_STO,
      ADDR_I2C_T_SU_STO,
      ADDR_T_BUS_FREE,
      ADDR_I2C_T_BUF:
      return 1'b1;
      default: return 1'b0;
    endcase
  endfunction

  function bit [19:0] timing_reset_value(bit [11:0] addr);
    case (addr)
      ADDR_T_R: return RST_T_R;
      ADDR_T_F: return RST_T_F;
      ADDR_T_SU_DAT: return RST_T_SU_DAT;
      ADDR_I2C_T_SU_DAT: return RST_I2C_T_SU_DAT;
      ADDR_T_HD_DAT: return RST_T_HD_DAT;
      ADDR_T_HIGH: return RST_T_HIGH;
      ADDR_I2C_T_HIGH: return RST_I2C_T_HIGH;
      ADDR_T_LOW: return RST_T_LOW;
      ADDR_T_LOW_OD: return RST_T_LOW_OD;
      ADDR_I2C_T_LOW: return RST_I2C_T_LOW;
      ADDR_T_HD_STA: return RST_T_HD_STA;
      ADDR_I2C_T_HD_STA: return RST_I2C_T_HD_STA;
      ADDR_T_SU_STA: return RST_T_SU_STA;
      ADDR_I2C_T_SU_STA: return RST_I2C_T_SU_STA;
      ADDR_T_SU_STO: return RST_T_SU_STO;
      ADDR_I2C_T_SU_STO: return RST_I2C_T_SU_STO;
      ADDR_T_BUS_FREE: return RST_T_BUS_FREE;
      ADDR_I2C_T_BUF: return RST_I2C_T_BUF;
      default: return '0;
    endcase
  endfunction

  function void decode_reg_access(reg_seq_item item);
    addr_class = classify_reg_addr(item.addr);
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
    cmd_tid = raw_desc[6:3];
    cmd_mode = sdr0;
    cmd_present = 1'b0;
    cmd_code = raw_desc[14:7];
    cmd_sre = 1'b0;
    cmd_dbp = 1'b0;

    cmd_has_rnw = 1'b0;
    cmd_has_data_len = 1'b0;
    cmd_has_dtt = 1'b0;
    cmd_has_dev_count = 1'b0;
    cmd_has_mode = 1'b0;
    cmd_has_present = 1'b0;
    cmd_has_sre_dbp = 1'b0;
    cmd_is_ccc = 1'b0;
    cmd_known_attr = 1'b1;
    cmd_supported = 1'b0;

    case (cmd_attr)
      RegularTransfer: begin
        cmd_rnw = regular_desc.rnw;
        cmd_data_len = regular_desc.data_length;
        cmd_dat_idx = regular_desc.dev_idx;
        cmd_mode = regular_desc.mode;
        cmd_present = regular_desc.cp;
        cmd_code = regular_desc.cmd;
        cmd_sre = regular_desc.sre;
        cmd_dbp = regular_desc.dbp;
        cmd_has_rnw = 1'b1;
        cmd_has_data_len = 1'b1;
        cmd_has_mode = 1'b1;
        cmd_has_present = 1'b1;
        cmd_has_sre_dbp = 1'b1;
        cmd_supported = !regular_desc.cp && (regular_desc.mode == sdr0);
        current_cmd_class = regular_desc.rnw ? CMD_CLASS_REG_READ : CMD_CLASS_REG_WRITE;
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
        cmd_supported = !immediate_desc.rnw && (immediate_desc.mode == sdr0) &&
                        (immediate_desc.dtt <= 3'd4) &&
                        (!immediate_desc.cp ||
                         (immediate_desc.cmd inside {8'(ENEC), 8'(DISEC), 8'(DIR_ENEC), 8'(DIR_DISEC)}));
        current_cmd_class = immediate_desc.cp ? CMD_CLASS_CCC : CMD_CLASS_IMMEDIATE;
      end

      AddressAssignment: begin
        cmd_dev_count = daa_desc.dev_count;
        cmd_dat_idx = daa_desc.dev_idx;
        cmd_code = daa_desc.cmd;
        cmd_has_dev_count = 1'b1;
        cmd_is_ccc = 1'b1;
        cmd_supported = daa_desc.toc && daa_desc.wroc && (daa_desc.dev_count != 4'd0) &&
                        ((int'(daa_desc.dev_idx) + int'(daa_desc.dev_count)) <= DAT_DEPTH) &&
                        (daa_desc.cmd == 8'(ENTDAA));
        current_cmd_class = CMD_CLASS_DAA;
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
        cmd_supported = 1'b0;
      end
    endcase
  endfunction

  virtual function void write(reg_seq_item t);
    reg_item = t;
    decode_reg_access(t);
    cg_reg_access.sample();

    if (t.addr == ADDR_HC_CONTROL) begin
      csr_hc_control_raw = t.is_write ? t.wdata : t.rdata;
      csr_bus_enable = csr_hc_control_raw[HC_CTRL_BUS_ENABLE_BIT];
      csr_broadcast_enable = csr_hc_control_raw[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
      csr_hc_abort = csr_hc_control_raw[HC_CTRL_ABORT_BIT];
      cg_hc_control.sample();
    end

    if (is_timing_csr(t.addr)) begin
      timing_addr = t.addr;
      timing_raw = t.is_write ? t.wdata : t.rdata;
      timing_is_default = timing_raw[19:0] == timing_reset_value(t.addr);
      timing_reserved_upper = t.is_write && (|t.wdata[31:20]);
      cg_timing_csr.sample();
    end

    if (dat_access) begin
      dat_raw = t.is_write ? t.wdata : t.rdata;
      dat_entry = controller_pkg::dat_entry_t'(dat_raw);
      dat_reserved_nonzero = |{dat_raw[30:23], dat_raw[15:7]};
      cg_dat_entry.sample();
      if (t.is_write) begin
        dat_shadow[dat_idx] = controller_pkg::dat_entry_t'(t.wdata);
        dat_shadow_valid[dat_idx] = 1'b1;
      end
    end

    if (!t.is_write && (t.addr == ADDR_RESP) && t.resp_valid) begin
      resp_desc = i3c_response_desc_t'(t.rdata);
      cg_resp_desc.sample();
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

        if (cmd_supported) begin
          if (previous_cmd_valid) cg_cmd_transition.sample();
          previous_cmd_class = current_cmd_class;
          previous_cmd_valid = 1'b1;
        end else begin
          previous_cmd_valid = 1'b0;
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
                "cg_reg_access=%0.2f%% cg_dat_entry=%0.2f%% ",
                "cg_cmd_desc=%0.2f%% cg_cmd_dat_correlation=%0.2f%% ",
                "cg_cmd_transition=%0.2f%% cg_resp_desc=%0.2f%% ",
                "cg_hc_control=%0.2f%% cg_timing_csr=%0.2f%% ",
                "cg_queue_sw_port=%0.2f%%"
              },
              cg_reg_access.get_inst_coverage(),
              cg_dat_entry.get_inst_coverage(),
              cg_cmd_desc.get_inst_coverage(),
              cg_cmd_dat_correlation.get_inst_coverage(),
              cg_cmd_transition.get_inst_coverage(),
              cg_resp_desc.get_inst_coverage(),
              cg_hc_control.get_inst_coverage(),
              cg_timing_csr.get_inst_coverage(),
              cg_queue_sw_port.get_inst_coverage()
              ), UVM_NONE)
  endfunction
endclass
