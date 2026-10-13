# Based on UART Genus 21.14 Common UI; new design has not been run in Cadence here.
source [file join [file dirname [info script]] common.tcl]
need_file $cfg(slow)
read_libs $cfg(slow)
read_hdl [design_files]
elaborate $cfg(top)
check_design -unresolved
read_sdc constraints/controller.sdc
set_db syn_generic_effort medium
set_db syn_map_effort medium
set_db syn_opt_effort medium
syn_generic
write_hdl > $OUT/controller_generic.v
syn_map
write_hdl > $OUT/controller_mapped_before_opt.v
syn_opt
write_hdl > $OUT/controller_mapped.v
write_sdc > $OUT/controller_mapped.sdc
report_area > $REP/genus_area.rpt
report_qor > $REP/genus_qor.rpt
report_timing > $REP/genus_timing.rpt
report_gates > $REP/genus_gates.rpt
# Optional vectorless estimate: no workload-activity claim.
report_power > $REP/genus_power_vectorless.rpt
puts "Saved mapped baseline netlist. Review all warnings, constraints and LEC results."
