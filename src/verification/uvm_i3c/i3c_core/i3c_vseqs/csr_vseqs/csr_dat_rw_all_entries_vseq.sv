class csr_dat_rw_all_entries_vseq extends csr_base_vseq;
  `uvm_object_utils(csr_dat_rw_all_entries_vseq)

  localparam bit [31:0] DAT_RESERVED_MASK = 32'h7F80_FF80;

  function new(string name = "csr_dat_rw_all_entries_vseq");
    super.new(name);
  endfunction

  task body();
    bit [31:0] exp_dat[DAT_DEPTH];

    foreach (exp_dat[i]) begin
      exp_dat[i] = '0;
      reg_write(dat_addr(i), exp_dat[i]);
    end

    foreach (exp_dat[i]) begin
      exp_dat[i] =
          build_dat_entry(static_addr_for_index(i), dynamic_addr_for_index(i), device_for_index(i));
      reg_write(dat_addr(i), exp_dat[i]);

      foreach (exp_dat[j]) begin
        check_dat_entry(j, exp_dat[j], $sformatf("after DAT[%0d] write", i));
      end

      reg_write(dat_addr(i), exp_dat[i] | DAT_RESERVED_MASK);

      foreach (exp_dat[j]) begin
        check_dat_entry(j, exp_dat[j],
                        $sformatf("after DAT[%0d] reserved-bit write", i));
      end
    end

    `uvm_info(`gfn, "CSR DAT read/write all entries checks passed", UVM_LOW)
  endtask

  function bit [31:0] build_dat_entry(bit [6:0] static_addr, bit [6:0] dynamic_addr, bit device);
    bit [31:0] value;

    value        = '0;
    value[6:0]   = static_addr;
    value[22:16] = dynamic_addr;
    value[31]    = device;
    return value;
  endfunction

  function bit [6:0] static_addr_for_index(int unsigned index);
    return (7'h20 + (index * 3)) & 7'h7f;
  endfunction

  function bit [6:0] dynamic_addr_for_index(int unsigned index);
    return (7'h08 + (index * 5)) & 7'h7f;
  endfunction

  function bit device_for_index(int unsigned index);
    return (index % 2) != 0;
  endfunction

  task check_dat_entry(int unsigned index, bit [31:0] exp, string phase_name);
    bit [31:0] data;

    reg_read(dat_addr(index), data);
    `DV_CHECK_EQ(data[6:0], exp[6:0],
                 $sformatf("csr_dat_rw_all_entries_vseq: DAT[%0d] static address mismatch %s",
                           index, phase_name))
    `DV_CHECK_EQ(data[22:16], exp[22:16],
                 $sformatf("csr_dat_rw_all_entries_vseq: DAT[%0d] dynamic address mismatch %s",
                           index, phase_name))
    `DV_CHECK_EQ(data[31], exp[31],
                 $sformatf("csr_dat_rw_all_entries_vseq: DAT[%0d] device bit mismatch %s", index,
                           phase_name))
    `DV_CHECK_EQ(data[15:7], 9'h0,
                 $sformatf("csr_dat_rw_all_entries_vseq: DAT[%0d] reserved[15:7] should read 0 %s",
                           index, phase_name))
    `DV_CHECK_EQ(data[30:23], 8'h0,
                 $sformatf("csr_dat_rw_all_entries_vseq: DAT[%0d] reserved[30:23] should read 0 %s",
                           index, phase_name))
  endtask

endclass
