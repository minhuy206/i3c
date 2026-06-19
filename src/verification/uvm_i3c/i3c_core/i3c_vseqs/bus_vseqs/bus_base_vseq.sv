class bus_base_vseq extends i3c_base_vseq;
  `uvm_object_utils(bus_base_vseq)

  localparam int unsigned CLK_PERIOD_NS = 3;

  typedef struct {
    string rst_n_path;
    string scl_i_path;
    string sda_i_path;
    string scl_sync_path;
    string sda_sync_path;
    string start_det_path;
    string rstart_det_path;
    string stop_det_path;
    string scl_gen_start_path;
    string scl_gen_rstart_path;
    string scl_gen_stop_path;
    string scl_gen_clock_path;
    string scl_gen_idle_path;
    string scl_gen_scl_i_path;
    string scl_gen_use_od_low_path;
  } bus_hdl_paths_t;

  bus_hdl_paths_t bus_paths;

  function new(string name = "bus_base_vseq");
    super.new(name);
    init_bus_hdl_paths();
  endfunction

  virtual function void init_bus_hdl_paths();
    bus_paths.rst_n_path          = "tb_i3c_top.rst_n";
    bus_paths.scl_i_path          = "tb_i3c_top.scl_i";
    bus_paths.sda_i_path          = "tb_i3c_top.sda_i";
    bus_paths.scl_sync_path       = "tb_i3c_top.dut.ctrl_scl_from_phy";
    bus_paths.sda_sync_path       = "tb_i3c_top.dut.ctrl_sda_from_phy";
    bus_paths.start_det_path      = "tb_i3c_top.dut.u_ctrl.bus_state.start_det";
    bus_paths.rstart_det_path     = "tb_i3c_top.dut.u_ctrl.bus_state.rstart_det";
    bus_paths.stop_det_path       = "tb_i3c_top.dut.u_ctrl.bus_state.stop_det";
    bus_paths.scl_gen_start_path  = "tb_i3c_top.dut.u_ctrl.u_scl_gen.gen_start_i";
    bus_paths.scl_gen_rstart_path = "tb_i3c_top.dut.u_ctrl.u_scl_gen.gen_rstart_i";
    bus_paths.scl_gen_stop_path   = "tb_i3c_top.dut.u_ctrl.u_scl_gen.gen_stop_i";
    bus_paths.scl_gen_clock_path  = "tb_i3c_top.dut.u_ctrl.u_scl_gen.gen_clock_i";
    bus_paths.scl_gen_idle_path   = "tb_i3c_top.dut.u_ctrl.u_scl_gen.gen_idle_i";
    bus_paths.scl_gen_scl_i_path  = "tb_i3c_top.dut.u_ctrl.u_scl_gen.scl_i";
    bus_paths.scl_gen_use_od_low_path = "tb_i3c_top.dut.u_ctrl.u_scl_gen.scl_use_od_low_i";
  endfunction

  virtual task wait_sync_cycles(int unsigned cycles);
    repeat (cycles) @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    #1;
  endtask

  virtual task force_phy_inputs(bit scl, bit sda);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(bus_paths.scl_i_path, scl);
    hdl_force_checked(bus_paths.sda_i_path, sda);
    #1;
  endtask

  virtual task release_phy_inputs();
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(bus_paths.scl_i_path);
    hdl_release_checked(bus_paths.sda_i_path);
    #1;
  endtask

  virtual task force_hard_reset();
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(bus_paths.rst_n_path, 1'b0);
    #1;
  endtask

  virtual task release_hard_reset();
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(bus_paths.rst_n_path, 1'b1);
    #1;
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.rst_n_path), 1'b1,
                     $sformatf("%s: reset should be high before force release", get_type_name()))
    hdl_release_checked(bus_paths.rst_n_path);
    #1;
    `DV_CHECK_EQ(hdl_read_bit(bus_paths.rst_n_path), 1'b1,
                     $sformatf("%s: reset should remain high after force release", get_type_name()))
  endtask

  virtual task configure_bus_monitor_zero_delay();
    reg_write(ADDR_T_R, 32'h0);
    reg_write(ADDR_T_F, 32'h0);
    enable_dut();
    wait_sync_cycles(2);
  endtask

  virtual task force_scl_generator_controls(bit start, bit rstart, bit stop, bit clock, bit idle);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(bus_paths.scl_gen_start_path, start);
    hdl_force_checked(bus_paths.scl_gen_rstart_path, rstart);
    hdl_force_checked(bus_paths.scl_gen_stop_path, stop);
    hdl_force_checked(bus_paths.scl_gen_clock_path, clock);
    hdl_force_checked(bus_paths.scl_gen_idle_path, idle);
    #1;
  endtask

  virtual task release_scl_generator_controls();
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(bus_paths.scl_gen_start_path);
    hdl_release_checked(bus_paths.scl_gen_rstart_path);
    hdl_release_checked(bus_paths.scl_gen_stop_path);
    hdl_release_checked(bus_paths.scl_gen_clock_path);
    hdl_release_checked(bus_paths.scl_gen_idle_path);
    #1;
  endtask

  virtual task set_scl_generator_controls_now(bit start, bit rstart, bit stop, bit clock, bit idle);
    hdl_force_checked(bus_paths.scl_gen_start_path, start);
    hdl_force_checked(bus_paths.scl_gen_rstart_path, rstart);
    hdl_force_checked(bus_paths.scl_gen_stop_path, stop);
    hdl_force_checked(bus_paths.scl_gen_clock_path, clock);
    hdl_force_checked(bus_paths.scl_gen_idle_path, idle);
    #1;
  endtask

  virtual task force_scl_generator_timing_mode(bit use_od_low);
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_force_checked(bus_paths.scl_gen_use_od_low_path, use_od_low);
    #1;
  endtask

  virtual task release_scl_generator_timing_mode();
    @(negedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    hdl_release_checked(bus_paths.scl_gen_use_od_low_path);
    #1;
  endtask

  virtual task program_timing_registers(int unsigned t_r, int unsigned t_f, int unsigned t_low,
                                        int unsigned t_high, int unsigned t_su_sta,
                                        int unsigned t_hd_sta, int unsigned t_su_sto,
                                        int unsigned t_su_dat, int unsigned t_hd_dat,
                                        int unsigned t_bus_free = RST_T_BUS_FREE,
                                        int unsigned t_low_od = RST_T_LOW_OD);
    reg_write(ADDR_T_R, t_r);
    reg_write(ADDR_T_F, t_f);
    reg_write(ADDR_T_LOW, t_low);
    reg_write(ADDR_T_LOW_OD, t_low_od);
    reg_write(ADDR_T_HIGH, t_high);
    reg_write(ADDR_T_SU_STA, t_su_sta);
    reg_write(ADDR_T_HD_STA, t_hd_sta);
    reg_write(ADDR_T_SU_STO, t_su_sto);
    reg_write(ADDR_T_SU_DAT, t_su_dat);
    reg_write(ADDR_T_HD_DAT, t_hd_dat);
    reg_write(ADDR_T_BUS_FREE, t_bus_free);
  endtask

  virtual task reset_scl_generator_to_idle();
    force_scl_generator_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    wait_sync_cycles(1);
    force_scl_generator_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    wait_sync_cycles(2);
  endtask

  virtual task reset_and_program_timing(int unsigned t_r, int unsigned t_f, int unsigned t_low,
                                        int unsigned t_high, int unsigned t_su_sta,
                                        int unsigned t_hd_sta, int unsigned t_su_sto,
                                        int unsigned t_su_dat, int unsigned t_hd_dat,
                                        int unsigned t_bus_free = RST_T_BUS_FREE,
                                        int unsigned t_low_od = RST_T_LOW_OD);
    force_scl_generator_controls(1'b0, 1'b0, 1'b0, 1'b0, 1'b1);
    force_hard_reset();
    wait_sync_cycles(2);
    release_hard_reset();
    program_timing_registers(t_r, t_f, t_low, t_high, t_su_sta, t_hd_sta, t_su_sto, t_su_dat,
                             t_hd_dat, t_bus_free, t_low_od);
    enable_dut();
    reset_scl_generator_to_idle();
  endtask

  virtual task start_generator(bit clock_en = 1'b0);
    set_scl_generator_controls_now(1'b1, 1'b0, 1'b0, clock_en, 1'b0);
    @(posedge p_sequencer.cfg.m_i3c_agent_cfg.vif.clk_i);
    #1;
    set_scl_generator_controls_now(1'b0, 1'b0, 1'b0, clock_en, 1'b0);
  endtask

endclass
