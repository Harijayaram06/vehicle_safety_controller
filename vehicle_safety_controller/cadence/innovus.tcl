# Legacy-UI Innovus STARTER. Lab version and PDK determine usable commands.
# This file intentionally requires lab power/CTS/filler/extraction/GDS hooks.
source [file join [file dirname [info script]] common.tcl]
foreach key {lef mmmc physical_setup physical_finish power_net ground_net} {require_cfg $key}
foreach f $cfg(lef) {require_file $f}
foreach key {mmmc physical_setup physical_finish} {require_file $cfg($key)}
require_file outputs/controller_mapped.v
require_file outputs/controller_mapped.sdc
set init_top_cell $cfg(top)
set init_verilog outputs/controller_mapped.v
set init_lef_file $cfg(lef)
set init_mmmc_file $cfg(mmmc)
set init_pwr_net $cfg(power_net)
set init_gnd_net $cfg(ground_net)
init_design
# Must set floorplan, legal sites/layers, pin placement, power connections/grid,
# tap/endcap/tie rules, routing constraints and clock-tree cell choices.
source $cfg(physical_setup)
saveDesign outputs/controller_floorplan.enc
place_opt_design
saveDesign outputs/controller_placed.enc
ccopt_design
saveDesign outputs/controller_cts.enc
routeDesign
optDesign -postRoute
optDesign -postRoute -hold
saveDesign outputs/controller_routed.enc
# Must perform fillers/antenna handling, PDK extraction/checks and export routed
# netlist, SDC, SPEF and GDS using the lab's layer map and merged cell GDS.
source $cfg(physical_finish)
puts "Review route, timing, connectivity, DRC and LVS reports individually. GDS is not signoff."
