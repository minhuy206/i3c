SIMULATOR   ?= xrun
UVM_HOME    ?= CDNS-1.2
TEST        ?= i3c_base_test
SEQ         ?= i3c_imm_vseq
VERBOSITY   ?= UVM_MEDIUM
SEED        ?= random
DUMP_WAVES  ?= 0
WAVE_ROOT   ?= waves
RUN_NAME    ?= $(SEQ)
WAVE_DIR    ?= $(WAVE_ROOT)/$(RUN_NAME)
WAVE_FILE   ?= $(WAVE_DIR)/waves.shm
COV         ?= 0
COV_ROOT    ?= cov_work
COV_TEST    ?= $(SEQ)_$(SEED)
COV_OPTS    = -coverage all -covworkdir $(COV_ROOT) -covtest $(COV_TEST)
FIFO_005_LOG ?= fifo_non_power_of_two_elaboration.log
FIFO_005_LIB ?= xcelium_fifo005.d

CSR_REGRESSION_SEQS ?= \
	csr_reset_defaults_vseq \
	csr_enable_disable_vseq \
	csr_broadcast_header_control_vseq \
	csr_timing_rw_vseq \
	csr_dat_rw_all_entries_vseq \
	csr_dat_hw_read_selection_vseq \
	csr_cmd_queue_2dw_staging_vseq \
	csr_cmd_partial_then_other_write_vseq \
	csr_rx_resp_read_pop_vseq \
	csr_queue_status_flags_vseq \
	csr_sw_reset_flush_queues_vseq \
	csr_sw_reset_clears_cmd_staging_vseq \
	csr_unmapped_addr_no_side_effect_vseq

FIFO_REGRESSION_SEQS ?= \
	fifo_basic_push_pop_order_vseq \
	fifo_full_empty_boundaries_vseq \
	fifo_simultaneous_read_write_vseq \
	fifo_flush_during_activity_vseq

BUS_REGRESSION_SEQS ?= \
	bus_phy_reset_and_sync_vseq \
	bus_start_stop_detect_vseq \
	bus_repeated_start_detect_vseq \
	bus_scl_start_stop_timing_vseq \
	bus_scl_clock_low_high_timing_vseq \
	bus_scl_waitcmd_stall_resume_vseq \
	bus_scl_repeated_start_from_waitcmd_vseq \
	bus_tx_byte_and_bit_order_vseq \
	bus_rx_byte_and_bit_order_vseq \
	bus_od_pp_phase_switch_vseq \
	bus_tb_pad_model_odpp_wiring_vseq

SDRW_REGRESSION_SEQS ?= \
	i3c_write_vseq \
	i3c_write_len_sweep_vseq \
	i3c_write_data_patterns_vseq \
	i3c_write_toc_zero_vseq \
	i3c_write_back_to_back_vseq \
	i3c_write_multi_dat_idx_vseq

SDRR_REGRESSION_SEQS ?= \
	i3c_read_vseq \
	i3c_read_len_sweep_vseq \
	i3c_read_target_more_than_requested_vseq \
	i3c_read_data_patterns_vseq \
	i3c_read_toc_zero_vseq \
	i3c_read_back_to_back_vseq \
	i3c_read_multi_dat_idx_vseq

IMM_REGRESSION_SEQS ?= \
	i3c_imm_vseq \
	i3c_imm_dtt_sweep_vseq \
	i3c_imm_toc_vseq \
	i3c_imm_i2c_write_vseq

I2C_REGRESSION_SEQS ?= \
	i2c_regular_write_basic_vseq \
	i2c_regular_read_basic_vseq \
	i2c_broadcast_addr_enable_ignored_vseq \
	i2c_len_sweep_partial_rx_vseq

CCC_REGRESSION_SEQS ?= \
	i3c_ccc_entdaa_opening_frame_vseq \
	i3c_ccc_broadcast_enec_vseq \
	i3c_ccc_broadcast_disec_vseq \
	i3c_ccc_direct_enec_vseq \
	i3c_ccc_direct_disec_vseq

DAA_REGRESSION_SEQS ?= \
	i3c_daa_single_device_success_vseq \
	i3c_daa_no_device_vseq \
	i3c_daa_fewer_devices_than_count_vseq \
	i3c_daa_multi_device_dat_loop_vseq \
	i3c_daa_address_rejected_vseq \
	i3c_daa_dat_boundary_vseq

ERR_REGRESSION_SEQS ?= \
	i3c_private_addr_nack_resp_vseq \
	i3c_broadcast_header_nack_resp_vseq \
	i3c_read_tbit_no_parity_resp_vseq \
	i3c_read_short_target_end_vseq \
	i3c_ovl_resp_vseq \
	i3c_write_tx_fifo_underflow_vseq \
	i3c_read_rx_fifo_full_overflow_vseq \
	i3c_entdaa_rx_fifo_partial_overflow_vseq \
	i3c_write_abort_vseq \
	i3c_read_abort_vseq \
	i3c_imm_data_nack_i2c_vseq \
	i3c_imm_abort_vseq \
	i2c_data_nack_write_vseq \
	i2c_regular_abort_vseq \
	i3c_daa_hc_abort_vseq

compile:
	$(SIMULATOR) -compile -elaborate \
	  -uvmhome $(UVM_HOME) \
	  -f uvm_i3c/filelist.f \
	  -timescale 1ns/1ps \
	  -access +rwc \
	  -define UVM \
	  -64 \
	  -xceligen on \
	  $(if $(filter 1,$(COV)),$(COV_OPTS),)

sim: compile
	$(if $(filter 1,$(DUMP_WAVES)),@mkdir -p $(WAVE_DIR),)
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED) \
	  -xceligen on \
	  $(if $(filter 1,$(COV)),$(COV_OPTS),) \
	  $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES +WAVE_FILE=$(WAVE_FILE),) \
	  2>&1 | tee sim.log

smoke:
	$(MAKE) sim TEST=i3c_base_test SEQ=i3c_imm_vseq

regression:
	$(MAKE) csr_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) fifo_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) bus_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) sdr_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) imm_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) i2c_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) ccc_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) daa_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)
	$(MAKE) err_regression TEST=$(TEST) VERBOSITY=$(VERBOSITY) SEED=$(SEED)

csr_regression:
	@set -e; \
	for seq in $(CSR_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

fifo_regression:
	@set -e; \
	for seq in $(FIFO_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done
	$(MAKE) fifo_non_power_of_two_elaboration

bus_regression:
	@set -e; \
	for seq in $(BUS_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

sdrw_regression:
	@set -e; \
	for seq in $(SDRW_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

sdrr_regression:
	@set -e; \
	for seq in $(SDRR_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

imm_regression:
	@set -e; \
	for seq in $(IMM_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

i2c_regression:
	@set -e; \
	for seq in $(I2C_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

ccc_regression:
	@set -e; \
	for seq in $(CCC_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

daa_regression:
	@set -e; \
	for seq in $(DAA_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

err_regression:
	@set -e; \
	for seq in $(ERR_REGRESSION_SEQS); do \
	  $(MAKE) sim TEST=$(TEST) SEQ=$$seq VERBOSITY=$(VERBOSITY) SEED=$(SEED); \
	done

sdr_regression: sdrw_regression sdrr_regression

fifo_non_power_of_two_elaboration:
	@set +e; \
	$(SIMULATOR) \
	  -timescale 1ns/1ps \
	  -access +rwc \
	  -64 \
	  -xmlibdirname $(FIFO_005_LIB) \
	  ../rtl/hci/sync_fifo.sv \
	  uvm_i3c/block_tests/fifo_non_power_of_two_tb.sv \
	  -top fifo_non_power_of_two_tb > $(FIFO_005_LOG) 2>&1; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
	  echo "FIFO_005 failed: illegal sync_fifo depth unexpectedly passed"; \
	  cat $(FIFO_005_LOG); \
	  exit 1; \
	fi; \
	if grep -q "sync_fifo: Depth (3) must be a power of 2" $(FIFO_005_LOG); then \
	  echo "FIFO_005 passed: illegal sync_fifo depth rejected"; \
	else \
	  echo "FIFO_005 failed: expected sync_fifo depth fatal was not found"; \
	  cat $(FIFO_005_LOG); \
	  exit 1; \
	fi

waves:
	$(MAKE) sim DUMP_WAVES=1

coverage:
	$(MAKE) sim COV=1

clean:
	rm -rf xcelium.d $(FIFO_005_LIB) INCA_libs $(COV_ROOT) waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.*

.PHONY: compile sim smoke regression csr_regression fifo_regression bus_regression \
        sdrw_regression sdrr_regression imm_regression i2c_regression ccc_regression \
        err_regression sdr_regression \
        fifo_non_power_of_two_elaboration waves coverage clean
