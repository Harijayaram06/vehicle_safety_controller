# Tempus 22.11-style single-library runs, matching the archived run_tempus.tcl.
# Launch separate processes: VSC_STA_STAGE=synth|route and VSC_STA_CORNER=slow|fast.
source [file join [file dirname [info script]] common.tcl]
set stage synth
set corner slow
if {[info exists ::env(VSC_STA_STAGE)]} {set stage $::env(VSC_STA_STAGE)}
if {[info exists ::env(VSC_STA_CORNER)]} {set corner $::env(VSC_STA_CORNER)}
if {$corner ni {slow fast}} {error "VSC_STA_CORNER must be slow or fast"}
if {$stage ni {synth route}} {error "VSC_STA_STAGE must be synth or route"}
set tag ${stage}_${corner}
set netlist $OUT/controller_mapped.v
set sdc $OUT/controller_mapped.sdc
if {$stage eq "route"} {set netlist $OUT/controller_routed.v; set sdc $OUT/controller_routed.sdc}
need_file $cfg($corner)
need_file $netlist
need_file $sdc
read_lib $cfg($corner)
read_verilog $netlist
set_top_module $cfg(top)
read_sdc $sdc
if {$stage eq "route"} {
    need_file $OUT/controller_RC.spef
    read_spef $OUT/controller_RC.spef
    set_propagated_clock [all_clocks]
    setAnalysisMode -analysisType onChipVariation -cppr both
}
report_timing -check_type setup -max_paths 50 > $REP/tempus_${tag}_setup.rpt
report_timing -check_type hold -max_paths 50 > $REP/tempus_${tag}_hold.rpt
report_analysis_summary > $REP/tempus_${tag}_summary.rpt
puts "STA report set $tag generated. Inspect unconstrained and unannotated paths."
