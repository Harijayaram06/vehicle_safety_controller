# How the RTL works

## 1. The project in one example

Imagine a gateway has decoded a request to yield to an emergency vehicle. Our chip receives that decoded message and the gateway's validity decision. It checks the message, gives an eligible emergency higher priority than caution requests, and issues an abstract yield output only while external safety logic permits it.

We do not implement the CAN electrical interface. The 64-bit `can_data` bus is an input from an existing CAN controller or the testbench. Likewise `override_enable` is an abstract request, not a direct wire to a real brake or steering motor.

## 2. The blocks in execution order

1. **request_monitor:** produces a millisecond tick, counts relevant messages per window, remembers the last relevant payload, and counts identical repeats. Saturation means a counter stops at 255 instead of wrapping to zero.
2. **can_feature_extractor:** checks ID, length, payload format, CRC-status and upstream validity. It also produces eight scaled integer features for the future trained MLP.
3. **vehicle_safety_top transaction registers:** capture the original request's metadata. Later traffic cannot alter a job already being evaluated. New traffic during busy is diagnosed as overrun.
4. **request_policy_validator:** decides eligibility. Neural confidence, when enabled, is only one of several conditions. It cannot excuse invalid gateway status or malformed data.
5. **priority_arbiter:** selects P3 emergency, P2 elevated concern, P1 caution or P0 normal.
6. **emergency_fsm:** stores operating mode, accepted-request lifetime, pending-emergency status and recovery progress.
7. **registered outputs:** use the next FSM state and current sampled safety conditions together. This prevents an extra stale cycle of yield after a sampled safety veto.

The live gate is `sensor_valid && safe_to_act && !safety_conflict`. Its action is synchronous: a changed input is reflected on the next sampling clock edge.

## 3. Inputs for your testbench

Use one rising-edge clock domain. Assert synchronous `reset=1` over at least one rising edge. Drive normal test inputs on falling edges to avoid a simulation race.

| Field | Example / meaning |
|---|---|
| `can_frame_valid` | One-cycle observation pulse |
| `can_id` | `11'h120` for the configured emergency source |
| `can_dlc` | 2 |
| `can_data[7:0]` | 01 active, 02 clear, 00 neither; 03 is invalid |
| `can_data[15:8]` | Sequence byte used only in duplicate comparison |
| `can_data[63:16]` | Zero for this prototype |
| `can_format_ok`, `can_crc_ok` | External decoder results |
| `upstream_request_valid` | Gateway's result associated with this exact observation |
| `sensor_valid` | Safety input is valid |
| `safe_to_act` | External logic permits the yield request |
| `safety_conflict` | A conflicting safety condition exists |
| `recovery_ok` | External logic permits return toward normal operation |
| `fault_ack` | Acknowledgement; cannot authorize override by itself |

An ID is not proof of sender identity. The upstream validity signal is an assumed service from another subsystem, not cryptographic authentication implemented here.

## 4. States and outputs

| State | Code | Meaning |
|---|---|---|
| INIT | 0 | Initialize the controller |
| NORMAL | 1 | Watch traffic; normal/caution/elevated outputs |
| EVALUATE | 2 | Wait for the captured job |
| OVERRIDE | 3 | Yield while gate and accepted lease remain valid |
| CLEARANCE | 4 | Yield withdrawn; validate stable clearance |
| RECOVERY | 5 | Hold while stable recovery conditions accumulate |
| HOLD | 6 | Fault/denial condition; wait for healthy acknowledgement |
| Reserved | 7 | Illegal state routed to HOLD |

`action_code`: 0 normal, 1 caution, 2 yield, 3 hold/deny-and-alert. `override_enable` is true exactly for the registered yield action. A high request priority does not force a yield action.

`decision_code`: 0 no eligible active request, 1 eligible, 2 invalid deterministic checks, 3 anomaly/monitor deny, 4 uncertain classifier, 5 cancelled/expired, 6 internal inference/model error. `decision_valid` pulses once; it does not remain high throughout override.

The request lease prevents one old message from keeping override asserted forever. Only a fully accepted new active request renews the lease. Gateway-valid active observations also maintain a separate `emergency_pending` diagnostic even when screening denies entry. This diagnostic cannot renew a lease.

## 5. Parameters you can explain in a viva

| Parameter | Default | Reason |
|---|---:|---|
| TICK_CYCLES | 20000 | 1 ms at the proposed 20 MHz clock |
| WINDOW_TICKS | 100 | 100 tick tumbling rate window |
| RATE_LIMIT | 16 | Deny the 17th relevant observation in the window |
| DUP_LIMIT | 4 | Deny fourth consecutive identical relevant observation |
| DUP_GAP_TICKS | 100 | Long gap starts a fresh duplicate run |
| LEASE_TICKS | 500 | Expire old accepted/pending requests |
| CLEAR_TICKS | 20 | Stable-clearance sample count |
| RECOVERY_TICKS | 50 | Stable-recovery sample count |
| RECOVERY_TIMEOUT_TICKS | 1000 | Bound time spent in clearance and recovery together |
| WATCHDOG_CYCLES | 256 | Bound inference transaction duration |
| USE_MONITOR | 1 | Default includes hard rate/duplicate veto |
| USE_MLP | 0 | Default uses no untrained classifier |

These are documented experiment settings, not standardized automotive limits. Testbenches override timing parameters to keep simulation short. Default synthesis uses the full-size counters and defaults; never call fast-test parameters the real controller timings.

## 6. Neural arithmetic

The inference engine has 8 input values, 8 hidden neurons, 4 hidden neurons and 3 scores. It reuses one signed multiplier. Weight matrices contain 108 numbers and there are 15 biases.

For each neuron: load the bias, add one input-times-weight product each MAC cycle, then store the result. Hidden results are shifted right by 7 and clipped to 0..127. Final scores retain the signed 24-bit sum. The class with the highest score wins, subject to a positive top-two score margin.

The implementation takes 139 cycles from accepted `start` to `done`: 108 MAC cycles, 15 bias-load cycles, 15 write-result cycles and one selection cycle. Start captures the features; these 139 subsequent edges perform inference. Top-level completion consumes `done` on the following edge, so neural transaction completion is 140 cycles from frame capture when no cancellation/watchdog intervenes.

The tests alter the external features and pulse start while busy to show that the captured vector is preserved. They compare all three scores, selected class, margin and uncertainty against Python. This verifies arithmetic, not the usefulness of a model.

## 7. Small innovation and how to evaluate it

The design combines confidence-aware screening with a live deterministic safety veto and recovery that requires stable conditions. To demonstrate the recovery part, inject fluctuating clearance/recovery signals and compare mode transitions and recovery delay with stability counts of one tick versus the defaults.

The confidence-aware part requires actual model training before usefulness can be measured. An uncertain prediction is not silently treated as permission. A valid upstream emergency remains visible through `emergency_pending`, which supports a documented downstream fallback or human alert.

## 8. What to run first

Run `tb_monitor`, `tb_features` and `tb_policy` to understand individual blocks. Then run `tb_fsm` and `tb_controller` to see end-to-end behaviour. Run `tb_mlp` to inspect neural arithmetic and `tb_neural_adapter` to see why a neural result cannot bypass the safety policy. The regression script runs all of them automatically.
