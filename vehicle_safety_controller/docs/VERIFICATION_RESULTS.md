# Verification results — release v0.2

These are actual local runs, not predicted results or Cadence outputs. Full logs are in `reports/` and tool/source identities are in `reports/build_manifest.json`.

## Simulation

Simulator: Icarus Verilog 12.0. Seven independently compiled self-checking testbenches completed successfully.

| Testbench | Actual passing checks / vectors | Main evidence |
|---|---:|---|
| tb_monitor | 7 directed checks | Counter saturation, first-frame gap, duplicate gap, boundary arrival |
| tb_policy | 256 input combinations | Exhaustive Boolean/class decision table |
| tb_controller | 221 checks | Priority, rejection, override, live veto, monitor thresholds, lease, recovery, cancellation and illegal state |
| tb_mlp | 1,024 vectors plus reset-cancellation check | Exact equality of three integer scores, class, margin, confidence and latency |
| tb_neural_adapter | 11 checks | Invalid-ROM guard, uncertainty, failed-policy vetoes, captured metadata, cancellation and watchdog |
| tb_features | 1,028 checks | Complete 8-bit count/gap scaling ranges and payload validity examples |
| tb_fsm | 32 checks | Exact recovery/lease boundaries, competing events, timeout and acknowledgement |

The controller regression observed 69 state transitions over 1,081 simulation cycles. This is an execution count, not 69 unique transition types and not a coverage percentage.

## Measured cycle latency

- Deterministic controller decision: one clock after frame capture, checked in the integrated testbench.
- MLP start-to-done: 139 subsequent rising edges, checked for every arithmetic vector.
- Neural top-level frame-capture-to-decision: 140 cycles, checked with the zero-score verification setup and validity guard overridden only inside the testbench.
- At the proposed 20 MHz clock, these correspond to 50 ns, 6.95 microseconds and 7.00 microseconds respectively. The conversion is arithmetic; 20 MHz timing closure has not been demonstrated in a technology library.

The MLP test fixtures include score ties, positive/negative weights, extreme legal biases, minimum feature values, and confidence margins immediately below/at threshold. Inputs are changed and start is reasserted while busy to test snapshot preservation. No vector is labelled as a trained emergency detector or real-world attack sample.

## Structural checks

YoWASP Yosys 0.69 completed hierarchy elaboration, process conversion, optimization, `check -assert`, and an explicit no-`$dlatch` assertion for:

1. Default monitor-assisted controller.
2. Standalone MLP engine.
3. Top-level neural parameter selection with the shipped invalid ROM.

All three checks passed. The MLP structural output contains one generic multiply operation, consistent with a shared-MAC architecture. The tool warns that the input activation array is represented by registers; this is expected. Icarus may report combinational sensitivity to all words of an array; those warnings are not latches.

The neural-top structural run uses the deliberately invalid constant ROM and can optimize away unreachable inference logic. It is not evidence of the area of a future trained hybrid. The standalone engine is checked separately. These runs are NOT standard-cell mapped synthesis, equivalence checking, timing analysis, power analysis or physical implementation.

## Corrections made during verification

- A captured clear-only message initially inherited active-job cancellation status; this was corrected so that an ordinary captured clearance completes with no active request, while clearance arriving during an active job still cancels that job.
- A new clearance on the terminal recovery tick now restarts counting instead of allowing a same-edge return to normal. A dedicated boundary test covers it.

## What remains unverified

- Real trained/quantized model behaviour, accuracy, false positives/negatives and confidence calibration.
- Actual Xcelium execution in the college environment and release-specific script compatibility.
- Genus mapped area/timing/power, Conformal equivalence, Innovus implementation and Tempus post-route timing.
- Full simulator code coverage or formal proof. Test pass counts must not be presented as coverage percentages.
- DRC, LVS, GDSII, IO ring, scan/ATPG, packaging or automotive qualification.

The source-level RTL and testbenches are ready for the next college-lab simulation step. The physical-design templates require the exact PDK and lab setup.
