# File: dv_macros.svh

> Status: Adapt from reference
> Reference: `i3c-core/verification/uvm_i3c/dv_inc/dv_macros.svh` (647 lines)
> Location: `verification/uvm_i3c/dv_inc/dv_macros.svh`

## 1. Purpose

Provide a centralized set of UVM utility macros used across the entire verification environment. These macros simplify common UVM patterns (checking, randomization, wait conditions, logging) and reduce boilerplate in agent, environment, and test code.

Adapted from the lowRISC/OpenTitan `dv_macros.svh` used by the ChipAlliance i3c-core project.

## 2. Dependencies

- `uvm_macros.svh` (included conditionally when `UVM` is defined)
- No other verification files depend on this being a module/package — it is a pure `include` file

### Used By

- Every package in the verification environment (`reg_agent_pkg`, `i3c_agent_pkg`, `i3c_env_pkg`, `i3c_test_pkg`)

## 3. Macro Categories

### 3.1. Shorthand Name Macros

| Macro | Expansion | Description |
|-------|-----------|-------------|
| `` `gfn `` | `get_full_name()` | UVM component full hierarchical name |
| `` `gtn `` | `get_type_name()` | UVM component type name |
| `` `gn `` | `get_name()` | UVM component short name |
| `` `gmv(csr) `` | `csr.get_mirrored_value()` | RAL register mirrored value (Phase 2) |

### 3.2. Check Macros

All check macros follow the pattern:
```
`DV_CHECK_<OP>(ACT, EXP, MSG="", SEV=error, ID=`gfn)
```

| Macro | Operation | Description |
|-------|-----------|-------------|
| `` `DV_CHECK `` | `T_` is true | Generic boolean check |
| `` `DV_CHECK_EQ `` | `ACT == EXP` | Equality check |
| `` `DV_CHECK_NE `` | `ACT != EXP` | Not-equal check |
| `` `DV_CHECK_LT `` | `ACT < EXP` | Less-than check |
| `` `DV_CHECK_GT `` | `ACT > EXP` | Greater-than check |
| `` `DV_CHECK_LE `` | `ACT <= EXP` | Less-or-equal check |
| `` `DV_CHECK_GE `` | `ACT >= EXP` | Greater-or-equal check |
| `` `DV_CHECK_CASE_EQ `` | `ACT === EXP` | 4-state equality check |
| `` `DV_CHECK_CASE_NE `` | `ACT !== EXP` | 4-state not-equal check |
| `` `DV_CHECK_STREQ `` | String `==` | String equality |
| `` `DV_CHECK_STRNE `` | String `!=` | String not-equal |

Each has a `_FATAL` variant that uses `fatal` severity instead of `error`.

**Example usage:**
```systemverilog
`DV_CHECK_EQ(actual_data, expected_data, "RX data mismatch")
`DV_CHECK_EQ_FATAL(resp.err_status, 4'b0000, "Response error")
```

### 3.3. Randomization Macros

| Macro | Description |
|-------|-------------|
| `` `DV_CHECK_RANDOMIZE_FATAL(VAR) `` | `VAR.randomize()` with fatal on failure |
| `` `DV_CHECK_RANDOMIZE_WITH_FATAL(VAR, CONSTRAINTS) `` | `VAR.randomize() with { CONSTRAINTS }` with fatal |
| `` `DV_CHECK_STD_RANDOMIZE_FATAL(VAR) `` | `std::randomize(VAR)` with fatal |
| `` `DV_CHECK_STD_RANDOMIZE_WITH_FATAL(VAR, C) `` | `std::randomize(VAR) with { C }` with fatal |

### 3.4. Wait / Spin Macros

| Macro | Description |
|-------|-------------|
| `` `DV_WAIT(COND, MSG, TIMEOUT_NS, ID) `` | Wait for condition with timeout |
| `` `DV_SPINWAIT(WAIT_STMT, MSG, TIMEOUT_NS, ID) `` | Execute statement with timeout |
| `` `DV_SPINWAIT_EXIT(WAIT, EXIT, MSG, ID) `` | Execute WAIT but exit early if EXIT completes |
| `` `DV_WAIT_TIMEOUT(TIMEOUT_NS, ID, MSG, FATAL) `` | Pure delay followed by error/fatal |

**Example usage:**
```systemverilog
`DV_WAIT(cfg.vif.scl_i === 1'b1,, 10_000_000, "SCL did not go high")
```

### 3.5. Logging Macros (non-UVM compatible)

For use in modules/interfaces that may run without UVM:

| Macro | Severity |
|-------|----------|
| `` `dv_info(MSG, VERBOSITY, ID) `` | Info |
| `` `dv_warning(MSG, ID) `` | Warning |
| `` `dv_error(MSG, ID) `` | Error |
| `` `dv_fatal(MSG, ID) `` | Fatal |

When `UVM` is defined, these map to `uvm_report_*` functions. Otherwise, they map to `$display` / `$error` / `$fatal`.

### 3.6. UVM Object/Component Convenience

| Macro | Description |
|-------|-------------|
| `` `uvm_object_new `` | Standard `new()` function for uvm_object |
| `` `uvm_component_new `` | Standard `new()` function for uvm_component |
| `` `uvm_create_obj(TYPE, INST) `` | `INST = TYPE::type_id::create(...)` |
| `` `uvm_create_comp(TYPE, INST) `` | `INST = TYPE::type_id::create(..., this)` |

### 3.7. Debug / Print Macros

| Macro | Description |
|-------|-------------|
| `` `DV_PRINT_ARR_CONTENTS(ARR, V, ID) `` | Print all elements of an array/queue |
| `` `DV_EOT_PRINT_TLM_FIFO_CONTENTS(TYP, FIFO, SEV, ID) `` | Print uncompared items at end-of-test |
| `` `DV_EOT_PRINT_Q_CONTENTS(TYP, Q, SEV, ID) `` | Print uncompared queue items at EOT |

### 3.8. Utility Macros

| Macro | Description |
|-------|-------------|
| `` `DV_STRINGIFY(I) `` | Convert expression to string literal |
| `` `GET_PARITY(val, odd) `` | Compute parity (usable in constraints) |
| `` `DV_MAX2(a, b) `` | Maximum of two values |
| `` `downcast(EXT, BASE, MSG, SEV, ID) `` | `$cast` with error reporting |

## 4. Adaptations from Reference

| Aspect | Reference | This Design |
|--------|-----------|-------------|
| `DV_ASSERT_CTRL` | Included for DUT assertion control | Include (useful for disabling assertions during reset) |
| `DV_CREATE_SIGNAL_PROBE_FUNCTION` | Included for internal signal probing | Include (useful for debug) |
| `DV_COMMON_CLK_CONSTRAINT` | Clock frequency randomization | Include but not used in Phase 1 (fixed 100 MHz) |
| `BUILD_SEED` | Build-time randomization seed | Include |

## 5. Guard Conditions

All macros are wrapped with `` `ifndef `` guards to prevent redefinition:
```systemverilog
`ifndef DV_CHECK_EQ
  `define DV_CHECK_EQ(ACT_, EXP_, MSG_="", SEV_=error, ID_=`gfn) \
    ...
`endif
```

## 6. Implementation Notes

- Copy the reference file with minimal changes — proven and battle-tested
- Ensure the `default_spinwait_timeout_ns` parameter used by `DV_SPINWAIT` is set appropriately (default: 10ms should be sufficient for I3C at clock-cycle-count timing)
- The file is included via `` `include "dv_macros.svh" `` in each agent/env package, NOT compiled as a separate unit
