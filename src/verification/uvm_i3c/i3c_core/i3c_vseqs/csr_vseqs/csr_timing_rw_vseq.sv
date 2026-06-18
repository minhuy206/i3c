class csr_timing_rw_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_timing_rw_vseq)

  typedef enum int {
    TIMING_VALUE_DEFAULT,
    TIMING_VALUE_MIN_NONZERO,
    TIMING_VALUE_MAX,
    TIMING_VALUE_RANDOM,
    TIMING_VALUE_RESERVED_MASK,
    TIMING_VALUE_ZERO
  } timing_value_kind_e;

  covergroup timing_rw_cg with function sample(bit [11:0] addr, timing_value_kind_e value_kind);
    option.per_instance = 1;

    cp_timing_reg: coverpoint addr {
      bins i3c_timing_regs[] = {
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
          ADDR_T_BUS_FREE
      };
      bins i2c_timing_regs[] = {
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
    }

    cp_timing_value: coverpoint value_kind {
      bins default_value     = {TIMING_VALUE_DEFAULT};
      bins minimum_nonzero   = {TIMING_VALUE_MIN_NONZERO};
      bins maximum_20bit     = {TIMING_VALUE_MAX};
      bins random_legal      = {TIMING_VALUE_RANDOM};
      bins reserved_bit_mask = {TIMING_VALUE_RESERVED_MASK};
      bins zero_value        = {TIMING_VALUE_ZERO};
    }

    cr_timing_reg_value: cross cp_timing_reg, cp_timing_value;
  endgroup

  function new(string name = "csr_timing_rw_vseq");
    super.new(name);
    timing_rw_cg = new();
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

    bit [19:0] expected_value[21];

    foreach (timing_addr[i]) begin
      expected_value[i] = timing_reg_value[i];
    end

    verify_all_timing_regs(timing_addr, timing_reg, expected_value, "initial expected defaults");

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, 20'd1,
                                 "minimum nonzero", TIMING_VALUE_MIN_NONZERO);
    end

    foreach (timing_addr[i]) begin
      rand_value = $urandom_range(32'h000F_FFFF, 32'h0000_0001);
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, rand_value,
                                 "random legal", TIMING_VALUE_RANDOM);
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, timing_reg_value[i],
                                 "rewrite default", TIMING_VALUE_DEFAULT);
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, 32'h000F_FFFF,
                                 "maximum 20-bit", TIMING_VALUE_MAX);
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, 32'h0000_0000,
                                 "zero value", TIMING_VALUE_ZERO);
    end

    foreach (timing_addr[i]) begin
      write_and_check_timing_reg(timing_addr, timing_reg, expected_value, i, 32'hFFFF_FFFF,
                                 "reserved-bit mask", TIMING_VALUE_RESERVED_MASK);
    end

  endtask

  task write_and_check_timing_reg(ref bit [11:0] timing_addr[21], ref string timing_reg[21],
                                  ref bit [19:0] expected_value[21], input int index,
                                  input bit [31:0] value, input string phase_name,
                                  input timing_value_kind_e value_kind);
    reg_write(timing_addr[index], value);
    expected_value[index] = value[19:0];
    verify_all_timing_regs(timing_addr, timing_reg, expected_value,
                           $sformatf("after %s write to %s", phase_name, timing_reg[index]));
    timing_rw_cg.sample(timing_addr[index], value_kind);
  endtask

  task verify_all_timing_regs(ref bit [11:0] timing_addr[21], ref string timing_reg[21],
                              ref bit [19:0] expected_value[21], input string ctxt);
    foreach (timing_addr[i]) begin
      check_timing_reg(timing_addr[i], expected_value[i], timing_reg[i], ctxt);
    end
  endtask

endclass
