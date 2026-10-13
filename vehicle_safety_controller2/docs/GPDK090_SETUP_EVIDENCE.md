# Recovered setup and validation boundaries

Source: user's uploaded `uart_asic.zip`. Only setup facts were reused; UART netlists, physical databases and PDK assets are not part of this kit.

| Archived evidence | What it establishes |
|---|---|
| `uart_asic/scripts/uart_tcl.tcl` | Genus uses the 90 nm `dig/lib/slow.lib` tree and generic/map/opt flow. |
| `uart_asic/scripts/run_tempus.tcl` | `read_lib`, `read_verilog`, `set_top_module`, `read_sdc`, setup/hold reports; Tempus init launcher. |
| `uart_asic/scripts/clean_lec.do` | Native Conformal read-library/read-design/LEC/compare flow. |
| `uart_asic/pnr/uart.view` | Slow/fast views, one captable/QRC RC corner and MMMC structure. |
| `uart_asic/pnr/innovus.cmd1` and `innovus.log1` | Original LEF import failed; translated LEF then loaded. Site, supply/layer names, power geometry and CTS configuration. |
| `uart_asic/pnr/post_route_timing.rpt` | Post-route timing failed with IMPOPT-7027 requesting onChipVariation analysis and CPPR. |
| `uart_asic/pnr/task6_drc.rpt` | One UART check reported no violations; it is not complete UART signoff or validation of this controller. |

Archive logs identify Genus 21.14, Innovus 21.15 and Tempus 22.11. Current server versions may differ. User independently supplied a passing controller simulation in Xcelium 24.09.

New engineering choices include initial 60% utilization and distributed controller pins. The 50 ns clock comes from the current controller constraints. Clock-cell lists, 0.2 ns CTS transition target and power geometry were adapted from UART records. All require verification against the actual libraries and new physical design.

Local verification covers Python compilation, fixture-based preflight and Conformal generation, Tcl completeness and a mocked command-order evaluation. Mock Cadence commands do not validate tool-option compatibility, mapping, equivalence, extraction, timing, DRC, LVS or GDS correctness. No Cadence implementation results are claimed. RTL was unchanged in this update.

Unknown: valid GDS stream map/cell GDS, filler and other physical-only-cell policy, full PVT/RC matrix/derates, antenna and DRC/LVS decks, power integrity requirements. GDS export remains conditional on supplying real lab inputs.
