# Common-UI Genus STARTER. Not executed in Cadence here; adapt to lab release.
source [file join [file dirname [info script]] common.tcl]
require_cfg liberty
foreach f $cfg(liberty) {require_file $f}
set_db library $cfg(liberty)
read_hdl [rtl_files]
elaborate $cfg(top)
check_design -unresolved
read_sdc constraints/controller.sdc
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium
syn_generic
syn_map
syn_opt
report_area > reports/genus_area.rpt
report_timing > reports/genus_timing.rpt
report_gates > reports/genus_gates.rpt
write_hdl > outputs/controller_mapped.v
write_sdc > outputs/controller_mapped.sdc
# No power number is exported without an explicit activity/assumption methodology.
puts "Synthesis script finished. Review logs, constraints and reports; no automatic signoff claim."
