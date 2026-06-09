class csr_timing_rw_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_timing_rw_vseq)

  function new(string name = "csr_timing_rw_vseq");
    super.new(name);
  endfunction

  task body();
    bit [19:0] rand_value;
    bit [11:0] timing_addr[21] = '{
        ADDR_T_R,
        ADDR_T_F,
        ADDR_T_LOW,
        ADDR_T_LOW_OD,
        ADDR_T_HIGH,
        ADDR_T_SU_STA,
        ADDR_T_HD_STA,
        ADDR_T_SU_STO,
        ADDR_T_SU_DAT,
        ADDR_T_HD_DAT,
        ADDR_T_BUS_FREE,
        ADDR_I2C_T_R,
        ADDR_I2C_T_F,
        ADDR_I2C_T_LOW,
        ADDR_I2C_T_HIGH,
        ADDR_I2C_T_SU_STA,
        ADDR_I2C_T_HD_STA,
        ADDR_I2C_T_SU_STO,
        ADDR_I2C_T_SU_DAT,
        ADDR_I2C_T_HD_DAT,
        ADDR_I2C_T_BUF
    };
    string timing_reg[21] = '{
        "T_R",
        "T_F",
        "T_LOW",
        "T_LOW_OD",
        "T_HIGH",
        "T_SU_STA",
        "T_HD_STA",
        "T_SU_STO",
        "T_SU_DAT",
        "T_HD_DAT",
        "T_BUS_FREE",
        "I2C_T_R",
        "I2C_T_F",
        "I2C_T_LOW",
        "I2C_T_HIGH",
        "I2C_T_SU_STA",
        "I2C_T_HD_STA",
        "I2C_T_SU_STO",
        "I2C_T_SU_DAT",
        "I2C_T_HD_DAT",
        "I2C_T_BUF"
    };

    bit [19:0] timing_reg_value[21] = '{
        RST_T_R,
        RST_T_F,
        RST_T_LOW,
        RST_T_LOW_OD,
        RST_T_HIGH,
        RST_T_SU_STA,
        RST_T_HD_STA,
        RST_T_SU_STO,
        RST_T_SU_DAT,
        RST_T_HD_DAT,
        RST_T_BUS_FREE,
        RST_I2C_T_R,
        RST_I2C_T_F,
        RST_I2C_T_LOW,
        RST_I2C_T_HIGH,
        RST_I2C_T_SU_STA,
        RST_I2C_T_HD_STA,
        RST_I2C_T_SU_STO,
        RST_I2C_T_SU_DAT,
        RST_I2C_T_HD_DAT,
        RST_I2C_T_BUF
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

endclass
