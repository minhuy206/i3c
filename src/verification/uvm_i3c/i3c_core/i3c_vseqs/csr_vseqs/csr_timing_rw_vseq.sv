class csr_timing_rw_vseq extends i3c_base_vseq;
  `uvm_object_utils(csr_timing_rw_vseq)

  function new(string name = "csr_timing_rw_vseq");
    super.new(name);
  endfunction

  task body();
    bit [19:0] rand_value;
    bit [11:0] timing_addr[9] = '{
        ADDR_T_R,
        ADDR_T_F,
        ADDR_T_LOW,
        ADDR_T_HIGH,
        ADDR_T_SU_STA,
        ADDR_T_HD_STA,
        ADDR_T_SU_STO,
        ADDR_T_SU_DAT,
        ADDR_T_HD_DAT
    };
    string timing_reg[9] = '{
        "T_R",
        "T_F",
        "T_LOW",
        "T_HIGH",
        "T_SU_STA",
        "T_HD_STA",
        "T_SU_STO",
        "T_SU_DAT",
        "T_HD_DAT"
    };

    bit [19:0] timing_reg_value[9] = '{
        20'd4,  // T_R       0x010
        20'd4,  // T_F       0x014
        20'd8,  // T_LOW     0x018
        20'd8,  // T_HIGH    0x01C
        20'd8,  // T_SU_STA  0x020
        20'd8,  // T_HD_STA  0x024
        20'd4,  // T_SU_STO  0x028
        20'd1,  // T_SU_DAT  0x02C
        20'd4  // T_HD_DAT  0x030
    };

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr[i], 20'd1, timing_reg[i], "minimum nonzero");
    end

    foreach (timing_addr[i]) begin
      rand_value = $urandom_range(32'h000F_FFFF, 32'h0000_0001);
      write_and_check_timing_reg(timing_addr[i], rand_value, timing_reg[i], "random legal");
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr[i], timing_reg_value[i], timing_reg[i],
                                 "rewrite default");
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr[i], 32'hFFF0_0001, timing_reg[i], "reserved-bit mask");
    end

    `uvm_info(`gfn, "CSR timing write and read checks passed", UVM_LOW)
  endtask

  task write_and_check_timing_reg(bit [11:0] addr, bit [31:0] value, string reg_name,
                                  string phase_name);
    reg_write(addr, value);
    check_timing_reg(addr, value[19:0], reg_name, phase_name);
  endtask

  task check_timing_reg(bit [11:0] addr, bit [19:0] exp, string reg_name, string phase_name);
    bit [31:0] data;

    reg_read(addr, data);
    `DV_CHECK_EQ(data[19:0], exp, $sformatf("csr_timing_rw_vseq: %s %s value mismatch", reg_name,
                                            phase_name))
    `DV_CHECK_EQ(data[31:20], 12'h0, $sformatf(
                                         "csr_timing_rw_vseq: %s %s reserved bits should read 0",
                                         reg_name, phase_name))
  endtask

endclass
