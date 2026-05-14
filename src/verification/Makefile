SIMULATOR   ?= xrun
UVM_HOME    ?= CDNS-1.2
TEST        ?= i3c_base_test
SEQ         ?= i3c_smoke_vseq
VERBOSITY   ?= UVM_MEDIUM
SEED        ?= random
DUMP_WAVES  ?= 0

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

waves:
	$(MAKE) sim DUMP_WAVES=1

clean:
	rm -rf xcelium.d INCA_libs waves.shm xrun.history .simvision \
	       xmsc_run.log *.log *.key *.shm .cxl.*

.PHONY: compile sim smoke regression waves clean
