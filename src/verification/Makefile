SIMULATOR   ?= xrun
UVM_HOME    ?= CDNS-1.2
TEST        ?= i3c_base_test
SEQ         ?= i3c_smoke_vseq
VERBOSITY   ?= UVM_MEDIUM
SEED        ?= random
DUMP_WAVES  ?= 0
WAVE_ROOT   ?= waves
RUN_NAME    ?= $(SEQ)
WAVE_DIR    ?= $(WAVE_ROOT)/$(RUN_NAME)
WAVE_FILE   ?= $(WAVE_DIR)/waves.shm
FIFO_005_LOG ?= fifo_non_power_of_two_elaboration.log
FIFO_005_LIB ?= xcelium_fifo005.d

CSR_REGRESSION_SEQS ?= \
	csr_reset_defaults_vseq \
	csr_enable_disable_vseq \
	csr_timing_rw_vseq \
	csr_dat_rw_all_entries_vseq \
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

compile:
	$(SIMULATOR) -compile -elaborate \
	  -uvmhome $(UVM_HOME) \
	  -f uvm_i3c/filelist.f \
	  -timescale 1ns/1ps \
	  -access +rwc \
	  -define UVM \
	  -64 \
	  -xceligen on

sim: compile
	$(if $(filter 1,$(DUMP_WAVES)),@mkdir -p $(WAVE_DIR),)
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED) \
	  -xceligen on $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES +WAVE_FILE=$(WAVE_FILE),) \
	  2>&1 | tee sim.log

smoke:
	$(MAKE) sim TEST=i3c_base_test SEQ=i3c_smoke_vseq

regression:
	$(MAKE) sim SEQ=i3c_smoke_vseq
	$(MAKE) sim SEQ=i3c_write_vseq
	$(MAKE) sim SEQ=i3c_read_vseq

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

clean:
	rm -rf xcelium.d $(FIFO_005_LIB) INCA_libs waves waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.*

.PHONY: compile sim smoke regression csr_regression fifo_regression \
        fifo_non_power_of_two_elaboration waves clean
