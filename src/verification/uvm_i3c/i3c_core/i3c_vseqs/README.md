# I3C Virtual Sequence Categories

Virtual sequences are grouped by the testcase-plan category in
`docs/test_plan/I3C_Testplan.md`.

Keep shared base code at this directory root:

- `i3c_base_vseq.sv`
- `i3c_vseq_list.sv`

Use these category directories for concrete test items:

| Test-plan section | Directory |
|---|---|
| 4.1 CSR, DAT, and Register Bus | `csr_vseqs/` |
| 4.2 FIFO and Queue Behavior | `fifo_vseqs/` |
| 4.3 PHY, Bus Conditions, and Timing | `bus_vseqs/` |
| 4.4 I3C SDR Private Write | `sdr_write_vseqs/` |
| 4.5 I3C SDR Private Read | `sdr_read_vseqs/` |
| 4.6 Immediate Data Transfer | `imm_vseqs/` |
| 4.7 Common Command Codes | `ccc_vseqs/` |
| 4.8 Dynamic Address Assignment / ENTDAA | `daa_vseqs/` |
| 4.9 I2C Legacy Compatibility | `i2c_vseqs/` |
| 4.10 Error Handling, Status, and Recovery | `resp_vseqs/` |
| 4.11 UVM Environment, Scoreboard, and Regression Infrastructure | `uvm_vseqs/` |
| 4.12 Stress, Robustness, and Performance | `stress_vseqs/` |

Add new files to the matching directory and include them from
`i3c_vseq_list.sv` so `+UVM_TEST_SEQ=<sequence_type_name>` can create the
class through the UVM factory.
