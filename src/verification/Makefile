SIMULATOR   ?= xrun
UVM_HOME    ?= CDNS-1.2
TEST        ?= i3c_base_test
SEQ         ?= i3c_smoke_vseq
VERBOSITY   ?= UVM_MEDIUM
SEED        ?= random
DUMP_WAVES  ?= 0

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
	$(SIMULATOR) -R \
	  +UVM_TESTNAME=$(TEST) \
	  +UVM_TEST_SEQ=$(SEQ) \
	  +UVM_VERBOSITY=$(VERBOSITY) \
	  -svseed $(SEED) \
	  -xceligen on $(if $(filter 1,$(DUMP_WAVES)),+DUMP_WAVES,) \
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

waves:
	$(MAKE) sim DUMP_WAVES=1

clean:
	rm -rf xcelium.d INCA_libs waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.*

.PHONY: compile sim smoke regression csr_regression waves clean
