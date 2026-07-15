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
COV_OPTS    = -coverage all -covworkdir $(COV_ROOT) -covtest $(COV_TEST) -covoverwrite
LOG_FILE    ?= sim.log

XRUN       = $(shell command -v $(SIMULATOR) 2>/dev/null)
UCIS_ROOT  = $(if $(XRUN),$(abspath $(dir $(XRUN))/../ucd))
UCIS_INC  ?= $(if $(UCIS_ROOT),$(UCIS_ROOT)/include)
UCIS_LIB  ?= $(if $(UCIS_ROOT),$(UCIS_ROOT)/lib/64bit)
TOOLS_DIR = $(CURDIR)/tools
UCD2JSON  = $(TOOLS_DIR)/ucd2json
UCD2SVA   = $(TOOLS_DIR)/ucd2sva
UCD2SVA_SRC = $(TOOLS_DIR)/ucd2sva.c
SVA_EXTRACTOR = $(TOOLS_DIR)/extract_sva_coverage.py
SVA_TOOL_SOURCES = $(wildcard $(UCD2SVA_SRC) $(SVA_EXTRACTOR))
SVA_TOOLS_READY = $(if $(filter 2,$(words $(SVA_TOOL_SOURCES))),1)
COV_REPORT ?= coverage_report.txt
SVA_COV_REPORT ?= sva_coverage_report.txt

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
	csr_unmapped_addr_no_side_effect_vseq \
	csr_hc_abort_control_vseq

FIFO_REGRESSION_SEQS ?= \
	fifo_basic_push_pop_order_vseq \
	fifo_full_empty_boundaries_vseq \
	fifo_simultaneous_read_write_vseq \
	fifo_flush_during_activity_vseq \
	fifo_pointer_wrap_reuse_vseq

BUS_REGRESSION_SEQS ?= \
	bus_phy_reset_and_sync_vseq \
	bus_start_stop_detect_vseq \
	bus_repeated_start_detect_vseq \
	bus_monitor_glitch_and_simultaneous_edge_filter_vseq \
	bus_monitor_enable_gating_and_edge_pulses_vseq \
	bus_scl_clock_low_high_timing_vseq \
	bus_scl_waitcmd_stall_resume_vseq \
	bus_scl_repeated_start_from_waitcmd_vseq \
	bus_tx_byte_and_bit_order_vseq \
	bus_rx_byte_and_bit_order_vseq \
	bus_tb_pad_model_odpp_wiring_vseq

SDRW_REGRESSION_SEQS ?= \
	i3c_write_vseq \
	i3c_write_len_sweep_vseq \
	i3c_write_toc_zero_vseq \
	i3c_write_back_to_back_vseq \
	i3c_write_multi_dat_idx_vseq

SDRR_REGRESSION_SEQS ?= \
	i3c_read_vseq \
	i3c_read_len_sweep_vseq \
	i3c_read_target_more_than_requested_vseq \
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
	i3c_daa_dat_boundary_vseq \
	i3c_daa_reserved_addr_resp_vseq

ERR_REGRESSION_SEQS ?= \
	i3c_private_addr_nack_resp_vseq \
	i3c_broadcast_header_nack_resp_vseq \
	i3c_read_short_target_end_vseq \
	i3c_write_tx_fifo_underflow_vseq \
	i3c_read_rx_fifo_full_overflow_vseq \
	i3c_entdaa_rx_fifo_partial_overflow_vseq \
	i3c_resp_fifo_full_backpressure_vseq \
	i3c_write_abort_vseq \
	i3c_read_abort_vseq \
	i3c_imm_data_nack_i2c_vseq \
	i3c_imm_abort_vseq \
	i2c_data_nack_write_vseq \
	i2c_regular_abort_vseq \
	i3c_daa_hc_abort_vseq \
	i3c_hc_abort_policy_vseq \
	i3c_wroc_policy_vseq \
	i3c_invalid_descriptor_attr_vseq \
	i3c_entdaa_invalid_descriptor_resp_vseq \
	i3c_reset_during_idle_vseq \
	i3c_reset_during_transfer_phases_vseq \
	i3c_sw_reset_while_busy_policy_vseq

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
	@mkdir -p $(dir $(LOG_FILE))
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED) \
	  -xceligen on \
	  $(if $(filter 1,$(COV)),$(COV_OPTS),) \
	  $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES +WAVE_FILE=$(WAVE_FILE),) \
	  2>&1 | tee $(LOG_FILE)

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

waves:
	$(MAKE) sim DUMP_WAVES=1

coverage:
	$(MAKE) sim COV=1

tools: $(UCD2JSON) $(if $(SVA_TOOLS_READY),$(UCD2SVA))

check_ucis:
	@if [ ! -f "$(UCIS_INC)/ucis.h" ] || [ ! -d "$(UCIS_LIB)" ]; then \
	  echo "Error: Xcelium UCIS headers/libraries not found." >&2; \
	  echo "Put $(SIMULATOR) on PATH or override UCIS_INC and UCIS_LIB." >&2; \
	  exit 1; \
	fi

$(UCD2JSON): $(TOOLS_DIR)/ucd2json.c | check_ucis
	gcc -std=c11 -Wall -Wextra -m64 -I$(UCIS_INC) -L$(UCIS_LIB) -o $@ $< -lucis

ifeq ($(SVA_TOOLS_READY),1)
$(UCD2SVA): $(UCD2SVA_SRC) | check_ucis
	gcc -std=c11 -Wall -Wextra -m64 -I$(UCIS_INC) -L$(UCIS_LIB) \
	  -o $@ $< -lucis
endif

cov_report: $(UCD2JSON)
	LD_LIBRARY_PATH=$(UCIS_LIB):$${LD_LIBRARY_PATH} \
	  python3 $(TOOLS_DIR)/extract_coverage.py $(COV_ROOT) $(COV_REPORT)

ifeq ($(SVA_TOOLS_READY),1)
sva_cov_report: $(UCD2SVA)
	LD_LIBRARY_PATH=$(UCIS_LIB):$${LD_LIBRARY_PATH} UCD2SVA=$(UCD2SVA) \
	  python3 $(SVA_EXTRACTOR) \
	  $(COV_ROOT) $(SVA_COV_REPORT)
else
sva_cov_report:
	@echo "Error: sva_cov_report requires tools/ucd2sva.c and tools/extract_sva_coverage.py." >&2
	@exit 1
endif

clean:
	rm -rf xcelium.d INCA_libs $(COV_ROOT) waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.* $(UCD2JSON) $(UCD2SVA)

.PHONY: compile sim smoke regression csr_regression fifo_regression bus_regression \
        sdrw_regression sdrr_regression imm_regression i2c_regression ccc_regression \
        err_regression sdr_regression \
        waves coverage tools check_ucis cov_report sva_cov_report clean
