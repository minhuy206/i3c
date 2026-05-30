class csr_reset_defaults_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_reset_defaults_vseq)

  function new(string name = "csr_reset_defaults_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] data;

    check_reg(ADDR_HC_CONTROL, 32'h0000_0000, "HC_CONTROL");

    reg_read(ADDR_HC_STATUS, data);
    `DV_CHECK_EQ(data, 32'h0000_0005, "csr_reset_defaults_vseq: HC_STATUS reset value mismatch")
    `DV_CHECK_EQ(data[HC_STS_FSM_IDLE_BIT], 1'b1,
                 "csr_reset_defaults_vseq: HC_STATUS[FSM_IDLE] should be 1 after reset")
    `DV_CHECK_EQ(data[HC_STS_CMD_FULL_BIT], 1'b0,
                 "csr_reset_defaults_vseq: HC_STATUS[CMD_FULL] should be 0 after reset")
    `DV_CHECK_EQ(data[HC_STS_RESP_EMPTY_BIT], 1'b1,
                 "csr_reset_defaults_vseq: HC_STATUS[RESP_EMPTY] should be 1 after reset")
    `DV_CHECK_EQ(data[31:3], 29'h0,
                 "csr_reset_defaults_vseq: HC_STATUS reserved bits should be 0 after reset")

    check_timing_reg(ADDR_T_R, RST_T_R, "T_R");
    check_timing_reg(ADDR_T_F, RST_T_F, "T_F");
    check_timing_reg(ADDR_T_LOW, RST_T_LOW, "T_LOW");
    check_timing_reg(ADDR_T_HIGH, RST_T_HIGH, "T_HIGH");
    check_timing_reg(ADDR_T_SU_STA, RST_T_SU_STA, "T_SU_STA");
    check_timing_reg(ADDR_T_HD_STA, RST_T_HD_STA, "T_HD_STA");
    check_timing_reg(ADDR_T_SU_STO, RST_T_SU_STO, "T_SU_STO");
    check_timing_reg(ADDR_T_SU_DAT, RST_T_SU_DAT, "T_SU_DAT");
    check_timing_reg(ADDR_T_HD_DAT, RST_T_HD_DAT, "T_HD_DAT");

    check_reg(ADDR_QUEUE_STATUS, 32'h0000_00AA, "QUEUE_STATUS");

    for (int unsigned i = 0; i < DAT_DEPTH; i++) begin
      reg_read(dat_addr(i), data);
      `DV_CHECK_EQ(data, 32'h0000_0000,
                   $sformatf("csr_reset_defaults_vseq: DAT[%0d] reset value mismatch", i))
    end

    `uvm_info(`gfn, "CSR reset default checks passed", UVM_LOW)
  endtask

  task check_reg(bit [11:0] addr, bit [31:0] exp, string reg_name);
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data, exp,
                 $sformatf("csr_reset_defaults_vseq: %s reset value mismatch", reg_name))
  endtask

  task check_timing_reg(bit [11:0] addr, bit [19:0] exp, string reg_name);
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data[19:0], exp,
                 $sformatf("csr_reset_defaults_vseq: %s reset value mismatch", reg_name))
    `DV_CHECK_EQ(data[31:20], 12'h0,
                 $sformatf("csr_reset_defaults_vseq: %s reserved bits should be 0 after reset",
                           reg_name))
  endtask

endclass
