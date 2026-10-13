# Running the project with your college's Cadence tools

## Current status

The project has been simulated using Icarus and checked structurally using Yosys. Cadence is not installed in the authoring environment. All Cadence scripts are version-dependent STARTERS, not logs of completed Cadence runs. The process is intentionally unspecified until the lab confirms it.

45 nm or 90 nm alone is not enough to select a library. Ask for the exact library name, compatible .lib/.lef/.gds views, RC extraction setup and the lab's existing working flow. An educational generic PDK and a licensed manufacturing PDK can have the same nominal node and different capabilities.

## Tool order

| Step | Tool | Main input | Main result |
|---|---|---|---|
| 1 | Xcelium | RTL and self-checking testbench | Simulation logs and waveforms |
| 2 | Genus | RTL, Liberty library, SDC | Mapped netlist, area and timing reports |
| 3 | Conformal LEC | Original RTL and mapped netlist with libraries | Equivalence result, including unmapped/aborted point review |
| 4 | Innovus | Mapped netlist, MMMC, LEF, lab physical setup | Placement, clock tree, routing, extracted design and layout export |
| 5 | Tempus | Routed netlist, matched corner libraries, SDC, SPEF | Post-route setup/hold and timing-analysis coverage |
| 6 | Lab physical-verification flow | Layout, reference connectivity, foundry decks | DRC/LVS reports; not replaced by LEC |

After physical changes, also compare the routed functional netlist with the mapped/reference design as appropriate to the lab flow. Physical-only cells and power pins need correct, explicit handling; do not black-box functional logic to get a pass.

## 1. Xcelium: usable before PDK confirmation

From the extracted project root:

```bash
python3 scripts/run_tests.py xcelium
```

For one testbench:

```bash
xrun -64bit -sv -access +rwc -f rtl/files.f tb/tb_controller.sv -top tb_controller
```

No standard-cell library is needed for behavioural RTL simulation. Do not compile all testbench tops into one simulation accidentally; the runner selects one top at a time. Tests use accelerated tick parameters. The RTL default still targets a 20 MHz clock with a 1 ms tick.

## 2. Configure the lab paths

```bash
cp cadence/lab_config.example.tcl cadence/lab_config.tcl
```

Edit the file. Do not guess PDK filenames. Fill cfg(liberty) with the actual compatible timing-library set, cfg(lef) with technology and cell LEFs, and power/ground names from your library. Keep the local configuration private if it contains sensitive paths.

The common script stops if required files are missing. All commands below assume that your normal lab environment already exposes the Cadence executables and licence setup.

## 3. Genus

```bash
genus -files cadence/genus.tcl
```

The script uses Common-UI commands. If your lab invokes legacy UI or an older release, adapt from its working synthesis script. Review `check_design`, unresolved references, inferred latches, unclocked registers, unconstrained paths, area and timing reports. The shipped defaults synthesize the monitor-assisted baseline, not a trained neural controller.

SDC assumptions: 50 ns period, 0.2 ns uncertainty, 5 ns max input/output delay, 0.5 ns minimum I/O delay, 0.1 ns input/clock transition, and 0.01 output-load units. These are starting budgets, not measured external electrical conditions. Confirm the Liberty time/capacitance units and replace budgets with the real integration assumptions. Reset is synchronous and is not declared a false path.

Do not claim power from an unannotated estimate. Later specify activity source, annotation coverage, voltage, frequency, corner and whether the result is pre- or post-route.

## 4. Conformal

```bash
cp cadence/conformal.example.do cadence/conformal.do
```

Edit library paths and confirm native dofile syntax for your release. Then, for installations using the `lec` executable:

```bash
lec -nogui -dofile cadence/conformal.do
```

Some colleges use a wrapper command instead. Use the lab's launcher. The dofile compares the original default-parameter RTL against `outputs/controller_mapped.v`. Both sides must use the same parameter/model configuration. Inspect all compare results, unresolved cells, unmapped points and aborts. A tool exiting normally does not necessarily establish equivalence.

Conformal equivalence checking answers whether two representations implement the same logic. It does not prove the original safety specification correct and does not perform layout-versus-schematic checking.

## 5. Innovus

```bash
innovus -files cadence/innovus.tcl
```

This starter uses a legacy-style import/implementation sequence. It intentionally cannot complete without three lab files:

1. **MMMC file:** library sets, RC corners, delay corners, constraint mode using `outputs/controller_mapped.sdc`, and appropriate setup/hold analysis views.
2. **Physical setup hook:** legal core/site dimensions, utilization, pin placement, power connections and grid, tap/endcap/tie-cell requirements, route layers and clock-tree settings. Use the lab's PDK rules, not generic dimensions invented here.
3. **Physical finish hook:** filler/decap/antenna work as needed, connectivity and physical checks, extraction, and export of `outputs/controller_routed.v`, `outputs/controller_routed.sdc`, `outputs/controller.spef` and GDS using the correct layer map and merged cell layouts.

If your lab uses Stylus/Common UI, translate the starter using that release's command help. Do not mix command families blindly. A core-level GDS does not imply that IO pads, ESD, scan, packaging or manufacturing signoff have been completed.

## 6. Tempus

```bash
tempus -files cadence/tempus.tcl
```

The lab timing-setup hook must establish matched libraries and analysis corners. The starter's single SPEF read needs per-corner annotation for a real MMMC flow. Review setup and hold, unconstrained endpoints, clock propagation and parasitic annotation coverage. Do not present an unannotated ideal-wire result as post-route timing.

## What to send back for the next adaptation

The exact PDK/library name, tool version output, existing lab flow filenames and the first error log are enough to start. There is no need to send proprietary library contents unless permitted. When the model is trained and the platform confirmed, the flow can be adapted to the complete neural variant and measured against the baseline.

## Primary-source command references consulted

These links ground the broad tool/command choices; they do not validate every command against your installed release.

- Cadence Community, Xcelium command usage: https://community.cadence.com/cadence_technology_forums/f/functional-verification/57967/xcelium---usage-of-xrun-command/1392714
- Cadence Community, waveform generation: https://community.cadence.com/cadence_technology_forums/f/functional-verification/55541/how-to-generate-waveforms-with-1-xrun-2-xmsim-3-irun-commands
- Cadence Community, Genus synthesis commands: https://community.cadence.com/cadence_technology_forums/f/digital-implementation/55520/genus-standard-cells-to-module
- Cadence Conformal training overview: https://www.cadence.com/en_US/home/training/all-courses/82123.html
- Cadence Community, compare-point caution: https://community.cadence.com/cadence_technology_forums/f/logic-design/2479/how-to-tell-conformal-to-ignore-a-module
- Cadence Community, Innovus import configuration: https://community.cadence.com/cadence_technology_forums/f/digital-implementation/56884/drc-violations-on-auto-generated-layout-using-innovus/1388757
