# Vehicle Safety Controller — RTL and GPDK090 Flow Kit v0.4

A student-level ASIC project: decoded-CAN request screening, deterministic priority, live safety veto, emergency override and stable recovery. Prepared for a university flow using Xcelium, Genus, Conformal, Innovus and Tempus. The uploaded UART lab project identifies a GPDK090 / gsclib090 90 nm setup. Its paths have been adapted into a dedicated flow; availability on the current server must still be checked.

## What is working now

- Synthesizable Verilog deterministic controller, with a selectable monitor veto.
- Shared-MAC 8-8-4-3 fixed-point MLP engine and optional integration path.
- Seven self-checking SystemVerilog testbenches, including 1,024 bit-exact MLP arithmetic vectors.
- Actual Icarus simulation logs, controller VCD waveform, and technology-independent Yosys structural/latch-check logs.
- Python integer reference, fixture generator and trained-model-to-ROM exporter.
- Xcelium runner, SDC, and unexecuted Cadence implementation templates.

**Default build = deterministic baseline with rate/duplicate monitoring.** The neural ROM is intentionally invalid until training is performed. With `USE_MLP=1`, the shipped ROM causes a fault hold. This prevents untrained or fabricated weights from being presented as a working classifier.

**Cadence evidence:** the user reported `tb_controller` passing in Xcelium 24.09 (221 checks, 69 observed transitions, 1081 cycles). The remaining six benches have not yet been reported passing in Xcelium.

**Not yet done:** training a useful model, dataset evaluation, Cadence implementation execution, mapped PPA, Conformal proof, place-and-route, DRC/LVS or GDSII. This release completes the next RTL/verification stage and prepares the neural arithmetic/integration for the training stage.

## New: recovered 90 nm lab flow

Start with [GPDK090_LAB_RUN_GUIDE.md](docs/GPDK090_LAB_RUN_GUIDE.md). Use `cadence/gpdk090/` for the recovered lab setup; the older scripts directly under `cadence/` remain generic templates. The new flow includes synthesis, LEC generation, STA, floorplan/power, placement, CTS, routing and extraction. GDS export needs additional lab PDK information.

## Start in your college Linux terminal

First use your lab's normal Cadence environment setup. Then extract this archive and enter the `vehicle_safety_controller` folder (the folder containing this README):

```bash
xrun -version
python3 scripts/run_tests.py xcelium
```

No PDK is needed for RTL simulation. Python scripts use only the standard library. `run_tests.py` generates the arithmetic vectors, compiles each testbench, runs it, and stops on failure. Read the final `ALL TESTBENCHES PASSED` message and `reports/verification_summary.json`.

To inspect the main controller in SimVision:

```bash
xrun -64bit -sv -access +rwc -f rtl/files.f tb/tb_controller.sv -top tb_controller -gui -input cadence/xcelium_gui.tcl
```

The GUI/SHM script is a starter; check command compatibility with the installed release. The portable tests also generate `build/controller.vcd`, which can be opened in a VCD-capable waveform viewer. Recommended signals: `can_frame_valid`, `can_data`, `classifier_busy`, `decision_valid`, `decision_code`, `fsm_state`, `priority_level`, `override_enable`, `action_code`, `emergency_pending` and `fault_status`.

If using Icarus instead of Xcelium:

```bash
python3 scripts/run_tests.py iverilog
```

## Folder guide

| Folder/file | What to use it for |
|---|---|
| `rtl/vehicle_safety_top.v` | Top-level DUT; start here for integration |
| `rtl/files.f` | Ordered design file list, shared by simulation and synthesis |
| `tb/tb_controller.sv` | Main emergency-controller demonstration and regression |
| `tb/tb_mlp.sv` | Bit-exact neural arithmetic verification |
| `tb/tb_neural_adapter.sv` | Tests the policy boundary using deliberately injected results |
| `ml/` | Integer reference, arithmetic fixtures and ROM export; not a training dataset |
| `vectors/` | Reproducible expected-score fixtures and manifest |
| `cadence/` | Lab configuration examples and tool scripts |
| `constraints/controller.sdc` | Initial 20 MHz clock and assumed interface budgets |
| `reports/` | Actual local test and structural-check evidence |
| `build/controller.vcd` | Waveform from the actual controller regression |
| `docs/RTL_WALKTHROUGH.md` | Short beginner-friendly block overview and run order |
| `docs/BEGINNER_RTL_PYTHON_GUIDE.md` | Detailed line-by-line concepts, Python/vector layout and RTL bridge |
| `docs/CADENCE_GUIDE.md` | Tool sequence, required lab files, and template limitations |
| `docs/IMPLEMENTATION_NOTES.md` | Contract clarifications and parameter restrictions |
| `docs/VERIFICATION_RESULTS.md` | What passed, what was checked, and what remains unverified |
| `docs/project_specification_v0.1.md` | Original first-stage architecture; v0.2 notes take precedence |

## Simple demonstration

At ID `0x120`, send DLC=2 with data `0x0000000000000101` and all decoder/upstream validity inputs true. Byte 0 is active=1; byte 1 is sequence=1. With the live safety gate true, the default controller enters override one clock after capture.

Send data `0x0000000000000202` to provide a validated clearance. Override is withdrawn; clearance and recovery timers run before normal mode resumes. Drop `safe_to_act` during override to demonstrate the live safety veto. The integrated testbench demonstrates all three.

## Progression to the final project

1. Run and understand this deterministic baseline in Xcelium.
2. Train/evaluate an 8-8-4-3 MLP on documented episode-level data and quantize it to the arithmetic contract.
3. Export genuine model coefficients with `ml/export_model.py`; rerun bit-accuracy and integrated scenario evaluation with trained coefficients.
4. Enable the neural variant only after training and model validation. Keep the deterministic build for the ablation comparison.
5. Confirm the exact PDK/library and Cadence release. Run Genus, Conformal, Innovus and Tempus with the lab setup.
6. Record actual area, timing, power methodology, physical checks and GDS export status.

Do not upload proprietary foundry libraries unless your licence permits it. A screenshot of the library name, local file paths, tool version and errors is enough to adapt the scripts in many cases.
