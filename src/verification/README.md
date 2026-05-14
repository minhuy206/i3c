# I3C UVM Verification

Xcelium build and simulation flow for the I3C UVM environment.

## Prerequisites

- Cadence Xcelium with `xrun` on `PATH`
- Cadence UVM 1.2 library available as `CDNS-1.2`

## Quick Start

Run commands from this directory:

```sh
make compile
make smoke
make regression
make waves
```

Useful overrides:

```sh
make sim TEST=i3c_base_test SEQ=i3c_write_vseq VERBOSITY=UVM_HIGH SEED=1
make sim DUMP_WAVES=1
```

Waveforms are written to `waves.shm` and can be opened with SimVision.

## Files

- `Makefile`: standard compile, sim, smoke, regression, waves, and clean targets.
- `uvm_i3c/filelist.f`: ordered RTL and UVM source list, relative to this directory.
- `uvm_i3c/xrun.args`: reusable Xcelium compile/elaboration arguments.

## Adding Tests

- Add agent-level sequences under `uvm_i3c/dv_i3c/seq_lib/`.
- Add virtual sequences under `uvm_i3c/i3c_core/i3c_vseqs/`.
- Include new virtual sequences from `uvm_i3c/i3c_core/i3c_vseqs/i3c_vseq_list.sv`.
- Run with `make sim SEQ=<sequence_type_name>`.
