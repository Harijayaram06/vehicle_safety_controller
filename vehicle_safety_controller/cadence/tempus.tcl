# Tempus STARTER. Lab hook defines matching timing corners and analysis views.
source [file join [file dirname [info script]] common.tcl]
require_cfg tempus_setup
require_file $cfg(tempus_setup)
foreach f {outputs/controller_routed.v outputs/controller_routed.sdc outputs/controller.spef} {require_file $f}
source $cfg(tempus_setup)
read_verilog outputs/controller_routed.v
set_top_module $cfg(top)
read_sdc outputs/controller_routed.sdc
# For MMMC, replace this with per-RC-corner read_spef assignments from the lab flow.
read_spef outputs/controller.spef
set_propagated_clock [all_clocks]
report_timing -late -max_paths 20 > reports/tempus_setup.rpt
report_timing -early -max_paths 20 > reports/tempus_hold.rpt
report_analysis_coverage > reports/tempus_analysis_coverage.rpt
puts "Review setup/hold, unconstrained paths and parasitic annotation coverage for all corners."
