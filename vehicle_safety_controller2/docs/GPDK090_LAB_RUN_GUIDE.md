# GPDK090 college-server flow — v0.4

This flow adapts the library setup recovered from your previous UART project to **vehicle_safety_top**. Run every shell command below from the project root, after loading your college's Cadence environment. These commands are for the default deterministic controller (`USE_MONITOR=1`, `USE_MLP=0`). The optional MLP still needs a trained model.

The UART archive establishes a prior **90 nm GPDK090 / gsclib090** lab setup, not the availability of those files on today's server. No proprietary libraries are included. The new scripts have not been executed in Cadence here. Read errors and reports after each stage; creating a report does not mean the stage passed.

## 1. Confirm RTL simulation

Your reported Xcelium run passed `tb_controller`: 221 checks, 69 observed transitions, 1081 cycles. The first license feature failed, but a different Xcelium feature was successfully checked out and the simulation completed. That license message did not block this run.

Run all seven benches:

```bash
python3 scripts/run_tests.py xcelium
```

Expect `ALL TESTBENCHES PASSED`. This exercises the supplied tests, not exhaustive functional or code coverage. Preserve logs with your submission. Python 3.8 or later is required by the existing test runner.

## 2. Check the technology files

```bash
python3 scripts/check_lab_setup.py --stage synth
python3 scripts/check_lab_setup.py --stage pnr
```

The synthesis profile checks both timing libraries because the following STA steps use both. The PNR check additionally checks physical/extraction files and configured CTS cell names. It is a text/file check, not a Cadence library validation.

| Item | Recovered location relative to PDK root |
|---|---|
| Root | `/home/cadence/install/FOUNDRY/digital/90nm/dig` |
| Slow Liberty | `lib/slow.lib` |
| Fast Liberty | `lib/fast.lib` |
| Working translated LEF | `lef/gsclib090_translated.lef` |
| Capacitance table | `captable/gpdk090.lef.extended.CapTbl` |
| QRC technology | `qrc/gpdk090_9l.tch` |
| Placement site | `gsclib090site` |
| Supply names | `VDD`, `VSS` |
| Metal layers | `Metal1` through `Metal9` |

If the entire PDK moved, set `VSC_PDK_ROOT` for each launch. Example syntax (replace the example path):

```bash
env VSC_PDK_ROOT=/actual/path/to/dig python3 scripts/check_lab_setup.py --stage pnr
```

Use the same environment override with Genus, Innovus, Tempus and the Conformal generator. Individual Tcl overrides belong in `cadence/gpdk090/local_config.tcl`, which is ignored by Git. The Python preflight does not interpret Tcl overrides; it checks the recovered directory layout. The LEC generator accepts `--lib /actual/path/slow.lib`.

The current SDC targets **50 ns / 20 MHz** and assumes the Liberty time unit is 1 ns. It contains example I/O delays and load, not measured board specifications. Keep synchronous reset timed. Confirm the units and constraint coverage in each tool. Do not copy the UART project's 10 ns period.

## 3. Synthesis and technology mapping — Genus

```bash
genus -files cadence/gpdk090/genus.tcl
```

The script reads the RTL and slow library, elaborates the top, reads the SDC, then runs `syn_generic`, `syn_map` and `syn_opt`. Mapping replaces generic logic with cells from the selected library.

Outputs in `outputs/gpdk090/`:

- `controller_generic.v`: generic logic before mapping.
- `controller_mapped_before_opt.v`: initial mapped circuit.
- `controller_mapped.v`: optimized mapped circuit used downstream.
- `controller_mapped.sdc`: exported timing constraints.

Inspect `reports/gpdk090/genus_*.rpt` and the console: no unresolved design references, unintended latches, missing clocks or unexplained unconstrained paths. Area is now library based; the power report is only a **vectorless estimate**. Do not call it measured workload power.

## 4. Logical equivalence — Conformal

```bash
python3 scripts/make_conformal_do.py --stage synth
lec -nogui -dofile build/gpdk090/conformal_synth.do
```

The Python script writes native Conformal commands using paths on your server. The original RTL is the golden design; the optimized mapped netlist is the revised design. It does not change functionality or waive differences. Check that all intended compare points are equivalent and investigate unmapped points, aborts or non-equivalence. Preserve the session log. A successful process exit alone does not prove equivalence.

## 5. Preliminary STA — Tempus

Launch each command in a separate process, exiting the previous Tempus session first:

```bash
env VSC_STA_STAGE=synth VSC_STA_CORNER=slow tempus -init cadence/gpdk090/tempus.tcl
env VSC_STA_STAGE=synth VSC_STA_CORNER=fast tempus -init cadence/gpdk090/tempus.tcl
```

Both runs report setup and hold. Slow is the primary setup view and fast the primary hold view in the recovered lab setup; always inspect both. Before routing, there are no extracted layout parasitics, so these are preliminary reports. Read `tempus_synth_*` under `reports/gpdk090/`. Check clock definitions, unconstrained paths, slack and violations. Negative slack needs explanation or a design/constraint/implementation fix; do not hide it by removing constraints.

## 6. Floorplan and power plan — Innovus

```bash
env VSC_STOP_AFTER=floorplan innovus -files cadence/gpdk090/innovus.tcl
```

This imports the mapped netlist, translated LEF and MMMC setup, then creates a square floorplan at initial 60% utilization, 10 micrometre margins, distributed signal pins, power rings, stripes and row connections. These are starting parameters for this controller. The UART's successful geometry does not prove the new controller's power grid is adequate.

Inspect the GUI and `floorplan_*` reports. Verify that pins fit, supplies connect, rows exist and no PG shorts/opens remain. Have the lab confirm whether tap, endcap and tie cells are required; supply those commands through `cfg(special_cells_tcl)` before placement. Geometry checks do not establish IR-drop or electromigration compliance.

## 7. Placement

Exit the previous Innovus session before resuming:

```bash
env VSC_RESUME_STAGE=floorplan VSC_STOP_AFTER=placed innovus -files cadence/gpdk090/innovus.tcl
```

This restores the saved database, places cells and optimizes before CTS. Inspect placement legality, congestion and `preCTS` timing reports. A small floorplan can be limited by the number of top-level pins; adjust utilization/margins and rerun from import if needed.

## 8. Clock tree synthesis

```bash
env VSC_RESUME_STAGE=placed VSC_STOP_AFTER=cts innovus -files cadence/gpdk090/innovus.tcl
```

The script configures the recovered clock buffers and inverters **before** building the clock tree. The initial transition target is 0.2 ns, based on the UART log; confirm it is appropriate for your library and clock. Review clock connectivity, skew, insertion delay and post-CTS setup/hold reports, including reports after hold optimization.

## 9. Routing, extraction and implementation timing

```bash
env VSC_RESUME_STAGE=cts VSC_STOP_AFTER=routed innovus -files cadence/gpdk090/innovus.tcl
```

This routes, performs post-route optimization, extracts RC, writes SPEF, runs setup/hold timing and writes connectivity/DRC reports. It sets OCV analysis with CPPR before post-route timing, addressing the analysis-mode error found in the UART archive.

Outputs: `controller_routed.v`, `controller_routed.sdc`, `controller_RC.spef`, plus the routed checkpoint. Read routing, DRC and connectivity results. The script does not automatically classify every report or declare signoff.

Checkpoints use `controller_<stage>.enc` / `.enc.dat` under `outputs/gpdk090/`. Do not alter RTL, SDC, libraries or floorplan configuration and then resume an old checkpoint. Restart from import after upstream changes. Each step needs the prior successful checkpoint. A typo in a stage name is rejected.

## 10. Extracted STA and routed equivalence

```bash
env VSC_STA_STAGE=route VSC_STA_CORNER=slow tempus -init cadence/gpdk090/tempus.tcl
env VSC_STA_STAGE=route VSC_STA_CORNER=fast tempus -init cadence/gpdk090/tempus.tcl
python3 scripts/make_conformal_do.py --stage route
lec -nogui -dofile build/gpdk090/conformal_route.do
```

Routed STA loads the SPEF and propagates clocks. Inspect parasitic annotation, clocks, timing coverage, setup/hold slack and transition/capacitance limits. Investigate missing or mismatched SPEF/netlist names. Routed LEC can require lab-specific handling of physical-only cells; do not suppress logic mismatches or arbitrarily black-box cells to obtain a pass.

This is the UART-style **two Liberty corners with one RC model**, not a complete signoff corner matrix. OCV mode and CPPR alone do not supply foundry derates. Your lab must provide required RC corners, derates, SI settings and signoff rules.

## 11. Final physical cells and GDSII

The archive did not establish these required inputs:

- Valid filler cell names and any tap/endcap/tie requirements.
- Standard-cell GDS files and the layer stream-out map.
- Final foundry/lab DRC, LVS and antenna requirements/decks.

After obtaining them, place real values in `cadence/gpdk090/local_config.tcl` (not guessed values):

```tcl
set cfg(filler_cells) {ACTUAL_FILLER_CELL_NAMES}
set cfg(gds_files) [list /actual/path/to/standard_cells.gds]
set cfg(gds_map) /actual/path/to/streamout.map
# If required, use an actual lab-approved command file before placement:
# set cfg(special_cells_tcl) /actual/path/to/tap_endcap_tie_setup.tcl
```

Reopen the routed database through the driver to load the configuration:

```bash
env VSC_RESUME_STAGE=routed innovus -files cadence/gpdk090/innovus.tcl
```

Then, in the **Innovus Tcl console**:

```tcl
source cadence/gpdk090/gds_export.tcl
```

The export script refuses to proceed while the required GDS/filler configuration is empty. It inserts fillers, checks connectivity/DRC, regenerates routed handoff files and exports `controller.gds`. Review results before treating the GDS as final. Rerun extracted STA and routed LEC after final database changes, and run the lab's DRC/LVS/antenna flow. A GDS file is not evidence that these checks passed.

## What to send back if a stage fails

Send the first relevant error and nearby log lines, the command you used, and the affected report. For missing libraries, send the preflight output or the actual file locations supplied by the lab. Do not upload proprietary library contents or license files. The useful next result is the complete preflight output followed by the Genus synthesis log.
