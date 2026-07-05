// -----------------------------------------------------------------------------
// i3c_scoreboard: Reference model
// -----------------------------------------------------------------------------

function void i3c_scoreboard::handle_hc_control_write(bit [31:0] wdata);
  hc_abort_active = wdata[HC_CTRL_HC_ABORT_BIT];
  broadcast_header_enable = wdata[HC_CTRL_BROADCAST_HEADER_ENABLE_BIT];
  if (hc_abort_active)
    `uvm_info(`gfn, "HC abort asserted: next write transaction will infer HcAborted", UVM_MEDIUM)
endfunction

function void i3c_scoreboard::handle_reset_control_write(bit [31:0] wdata);
  if (wdata[RESET_CTRL_SOFT_RST_BIT]) begin
    if (controller_idle_for_sw_reset()) begin
      handle_sw_reset();
    end else begin
      `uvm_info(`gfn, "Busy SW_RESET write ignored by scoreboard model", UVM_MEDIUM)
    end
  end
endfunction

function bit i3c_scoreboard::controller_idle_for_sw_reset();
  uvm_hdl_data_t value;

  if (!uvm_hdl_read(I3C_FSM_IDLE_PATH, value)) begin
    `uvm_error(`gfn, $sformatf("uvm_hdl_read failed for %s", I3C_FSM_IDLE_PATH))
    return 1'b0;
  end
  return value[0];
endfunction

function bit i3c_scoreboard::response_fifo_is_full();
  uvm_hdl_data_t value;

  if (!uvm_hdl_read(RESP_FULL_PATH, value)) return 1'b0;
  return value[0];
endfunction

function void i3c_scoreboard::clear_transaction_model();
  exp_txn_queue.delete();
  tx_data_queue.delete();
  exp_rx_data_queue.delete();
  exp_resp_queue.delete();
  unknown_resp_fifo_words = 0;
  got_dw0 = 1'b0;
  cmd_dw0 = '0;
  pending_private_transfer = 1'b0;
  next_read_id = 0;
  read_integrity_pass.delete();
  pending_abort_response_valid = 1'b0;
endfunction

function void i3c_scoreboard::handle_sw_reset();
  capture_reset_recovery_context();
  clear_transaction_model();
  `uvm_info(`gfn, "SW_RESET observed: scoreboard queues flushed", UVM_MEDIUM)
endfunction

function void i3c_scoreboard::handle_hard_reset();
  capture_reset_recovery_context();
  clear_transaction_model();
  foreach (dat_model[i]) dat_model[i] = dat_model_entry_t'('0);
  broadcast_header_enable = 1'b0;
  hc_abort_active = 1'b0;
  `uvm_info(`gfn, "Hard reset observed: scoreboard model returned to reset state", UVM_MEDIUM)
endfunction

function void i3c_scoreboard::capture_reset_recovery_context();
  i3c_resp_cmd_class_e cmd_class;
  reset_point_e        reset_point;

  cmd_class   = RESP_CMD_CLASS_OTHER;
  reset_point = RESET_POINT_IDLE;
  if (exp_txn_queue.size() > 0) begin
    cmd_class = classify_response_cmd(exp_txn_queue[0].cmd_attr, exp_txn_queue[0].is_ccc);
    reset_point = controller_idle_for_sw_reset() ? RESET_POINT_QUEUED_COMMAND :
                  RESET_POINT_ACTIVE_UNKNOWN;
  end else if (command_history_valid) begin
    cmd_class = previous_command_class;
  end

  publish_abort_observation(RESET, PREAMBLE, 0);
  start_recovery_context(RECOVERY_RESET, cmd_class, reset_point);
  reset_history_valid = cmd_class != RESP_CMD_CLASS_OTHER;
  reset_history_class = cmd_class;
  command_history_valid = 1'b0;
  stall_recovery_pending = 1'b0;
endfunction

function void i3c_scoreboard::handle_dat_write(bit [11:0] addr, bit [31:0] wdata);
  controller_pkg::dat_entry_t entry;
  int unsigned                idx;

  idx = (addr - ADDR_DAT_BASE) >> 2;
  if (idx >= DAT_DEPTH) begin
    `uvm_warning(`gfn, $sformatf("DAT write ignored: addr=0x%03h idx=%0d", addr, idx))
    return;
  end

  entry                          = controller_pkg::dat_entry_t'(wdata);
  dat_model[idx].valid           = 1'b1;
  dat_model[idx].device          = entry.device;
  dat_model[idx].dynamic_address = entry.dynamic_address;
  dat_model[idx].static_address  = entry.static_address;
  `uvm_info(`gfn, $sformatf(
            "DAT[%0d] updated: device=%0b static=0x%02h dynamic=0x%02h",
            idx,
            dat_model[idx].device,
            dat_model[idx].static_address,
            dat_model[idx].dynamic_address
            ), UVM_MEDIUM)
endfunction

function bit i3c_scoreboard::invalid_cmd_descriptor(bit [63:0] raw_desc);
  regular_trans_desc_t        reg_desc;
  immediate_data_trans_desc_t imm_desc;
  addr_assign_desc_t          daa_desc;
  int unsigned                dat_end;

  reg_desc = regular_trans_desc_t'(raw_desc);
  imm_desc = immediate_data_trans_desc_t'(raw_desc);
  daa_desc = addr_assign_desc_t'(raw_desc);
  dat_end  = int'(daa_desc.dev_idx) + int'(daa_desc.dev_count);

  case (raw_desc[2:0])
    3'b000: return reg_desc.cp || (reg_desc.mode != sdr0);
    3'b001:
    return imm_desc.rnw || (imm_desc.mode != sdr0) || (imm_desc.dtt > 3'd4) ||
                  (imm_desc.cp && !((imm_desc.cmd == 8'(ENEC))     || (imm_desc.cmd == 8'(DISEC)) ||
                                    (imm_desc.cmd == 8'(DIR_ENEC)) || (imm_desc.cmd == 8'(DIR_DISEC))));
    3'b010:
    return !daa_desc.toc || !daa_desc.wroc || (daa_desc.dev_count == 4'd0) ||
                  (dat_end > DAT_DEPTH) || (daa_desc.cmd != 8'(ENTDAA));
    default: return 1'b1;
  endcase
endfunction

function void i3c_scoreboard::handle_cmd_dword(bit [31:0] wdata);
  regular_trans_desc_t        reg_desc;
  immediate_data_trans_desc_t imm_desc;
  addr_assign_desc_t          daa_desc;
  exp_txn_t                   exp;
  bit                         target_is_i3c;

  if (!got_dw0) begin
    cmd_dw0 = wdata;
    got_dw0 = 1'b1;
    return;
  end
  got_dw0       = 1'b0;

  reg_desc      = regular_trans_desc_t'({wdata, cmd_dw0});
  imm_desc      = immediate_data_trans_desc_t'({wdata, cmd_dw0});
  daa_desc      = addr_assign_desc_t'({wdata, cmd_dw0});
  target_is_i3c = is_i3c_device(reg_desc.dev_idx);

  if (invalid_cmd_descriptor({wdata, cmd_dw0})) begin
    bit                  daa_crosses_boundary;
    bit                  invalid_rnw;
    int                  invalid_requested_length;
    i3c_resp_cmd_class_e invalid_cmd_class;

    daa_crosses_boundary = (daa_desc.attr == AddressAssignment) &&
                           (daa_desc.cmd == 8'(ENTDAA)) &&
                           (daa_desc.dev_count != 0) &&
                           ((int'(daa_desc.dev_idx) + int'(daa_desc.dev_count)) > DAT_DEPTH);
    invalid_cmd_class = classify_response_cmd(
        reg_desc.attr, (reg_desc.attr == ImmediateDataTransfer) && imm_desc.cp);
    invalid_rnw = (reg_desc.attr == RegularTransfer) ? reg_desc.rnw :
                  (reg_desc.attr == ImmediateDataTransfer) ? imm_desc.rnw : 1'b0;
    invalid_requested_length = (reg_desc.attr == RegularTransfer) ?
                               int'(reg_desc.data_length) :
                               (reg_desc.attr == ImmediateDataTransfer) ?
                               int'(imm_desc.dtt) : 0;
    record_exp_resp('{
        rnw:                     invalid_rnw,
        tid:                     reg_desc.tid,
        data_length:             0,
        resp_status:             NotSupported,
        is_ccc:                  1'b0,
        ccc_opcode:              ENEC,
        ccc_direct:              1'b0,
        daa_dat_valid:           daa_crosses_boundary,
        daa_start_index:         daa_desc.dev_idx,
        daa_requested_count:     daa_desc.dev_count,
        daa_response_valid:      1'b0,
        daa_result:              DAA_RESULT_OTHER,
        response_cmd_class:      invalid_cmd_class,
        requested_length:        invalid_requested_length,
        wroc:                    reg_desc.wroc,
        address_response_valid:  1'b0,
        address_phase_broadcast: 1'b0,
        address_acked:           1'b1
    });
    `uvm_info(
        `gfn,
        $sformatf(
            "CMD rejected before DAT/bus activity: attr=0x%0h mode=0x%0h cp=%0b rnw=%0b cmd=0x%02h tid=0x%0h",
            cmd_dw0[2:0], reg_desc.mode, reg_desc.cp, reg_desc.rnw, reg_desc.cmd, reg_desc.tid),
        UVM_MEDIUM)
    return;
  end

  exp.tid                         = reg_desc.tid;
  exp.dat_idx                     = reg_desc.dev_idx;
  exp.cmd_attr                    = reg_desc.attr;
  exp.cmd_present                 = reg_desc.cp;
  exp.cmd_code                    = reg_desc.cmd;
  exp.toc                         = reg_desc.toc;
  exp.wroc                        = reg_desc.wroc;
  exp.sre                         = reg_desc.sre;
  exp.addr                        = get_device_addr(reg_desc.dev_idx);
  exp.is_ccc                      = 1'b0;
  exp.uses_tx_queue               = 1'b0;
  exp.ccc_target_addr             = exp.addr;
  exp.event_byte                  = imm_desc.def_or_data_byte1;
  exp.target_is_i3c               = target_is_i3c;
  exp.broadcast_header_eligible   = 1'b0;
  exp.updates_private_transfer    = 1'b0;
  exp.start_with_broadcast_header = 1'b0;

  case (reg_desc.attr)
    RegularTransfer: begin
      exp.rnw                       = reg_desc.rnw;
      exp.data_length               = int'(reg_desc.data_length);
      exp.uses_tx_queue             = !reg_desc.rnw;
      exp.broadcast_header_eligible = target_is_i3c;
      exp.updates_private_transfer  = target_is_i3c;
    end
    ImmediateDataTransfer: begin
      exp.cmd_attr     = imm_desc.attr;
      exp.cmd_present  = imm_desc.cp;
      exp.cmd_code     = imm_desc.cmd;
      exp.wroc         = imm_desc.wroc;
      if (imm_desc.cp && is_enec_disec_ccc(imm_desc.cmd)) begin
        exp.addr        = I3C_RSVD_ADDR;
        exp.rnw         = 1'b0;
        exp.data_length = 1;
        exp.is_ccc      = 1'b1;
      end else begin
        exp.rnw                       = imm_desc.rnw;
        exp.data_length               = int'(imm_desc.dtt);
        exp.broadcast_header_eligible = !imm_desc.cp && target_is_i3c;
        exp.imm_data_byte[0]          = imm_desc.def_or_data_byte1;
        exp.imm_data_byte[1]          = imm_desc.data_byte2;
        exp.imm_data_byte[2]          = imm_desc.data_byte3;
        exp.imm_data_byte[3]          = imm_desc.data_byte4;
      end
    end
    AddressAssignment: begin
      exp.cmd_attr      = daa_desc.attr;
      exp.cmd_present   = 1'b0;
      exp.cmd_code      = daa_desc.cmd;
      exp.wroc          = daa_desc.wroc;
      // ENTDAA always broadcasts to 0x7E.
      exp.addr          = I3C_RSVD_ADDR;
      exp.rnw           = 1'b0;
      exp.data_length   = 0;
      exp.is_ccc        = 1'b1;
      exp.daa_dev_idx   = daa_desc.dev_idx;
      exp.daa_dev_count = daa_desc.dev_count;
      for (int round = 0; round < daa_desc.dev_count; round++) begin
        int unsigned dat_idx;

        dat_idx = daa_desc.dev_idx + round;
        if ((dat_idx < DAT_DEPTH) && dat_model[dat_idx].valid) begin
          exp.daa_addr_valid[round]    = 1'b1;
          exp.daa_assigned_addr[round] = dat_model[dat_idx].dynamic_address;
        end
      end
    end
    default: begin
      exp.rnw         = reg_desc.rnw;
      exp.data_length = 0;
    end
  endcase

  exp_txn_queue.push_back(exp);
  if (exp.is_ccc) begin
    `uvm_info(`gfn,
              $sformatf(
                  "CMD queued: attr=%s CCC=%s(0x%02h) addr=0x%02h event=0x%02h len=%0d toc=%0b",
                  reg_desc.attr.name(), ccc_to_string(exp.cmd_code), exp.cmd_code, exp.addr,
                  exp.event_byte, exp.data_length, exp.toc), UVM_MEDIUM)
  end else begin
    `uvm_info(`gfn, $sformatf(
              "CMD queued: attr=%s dev_idx=%0d addr=0x%02h rnw=%0b len=%0d toc=%0b target_i3c=%0b",
              reg_desc.attr.name(),
              reg_desc.dev_idx,
              exp.addr,
              exp.rnw,
              exp.data_length,
              exp.toc,
              exp.target_is_i3c
              ), UVM_MEDIUM)
  end
endfunction

function bit [6:0] i3c_scoreboard::get_device_addr(bit [4:0] dev_idx);
  if ((dev_idx < DAT_DEPTH) && dat_model[dev_idx].valid) begin
    if (dat_model[dev_idx].device) return dat_model[dev_idx].static_address;
    return dat_model[dev_idx].dynamic_address;
  end
  if (dev_idx == 0 && cfg != null) return cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr;
  `uvm_warning(`gfn, $sformatf("get_device_addr: unresolved dev_idx=%0d", dev_idx))
  return 7'h00;
endfunction

function bit i3c_scoreboard::is_i3c_device(bit [4:0] dev_idx);
  if ((dev_idx < DAT_DEPTH) && dat_model[dev_idx].valid) return !dat_model[dev_idx].device;
  if (dev_idx == 0 && cfg != null) return cfg.m_i3c_agent_cfg.i3c_target0.dynamic_addr_valid;
  return 1'b0;
endfunction

function bit i3c_scoreboard::is_enec_disec_ccc(bit [7:0] cmd);
  return (cmd == ENEC) || (cmd == DISEC) || (cmd == DIR_ENEC) || (cmd == DIR_DISEC);
endfunction
