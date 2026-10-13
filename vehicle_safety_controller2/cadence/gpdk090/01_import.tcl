foreach key {slow fast lef captable qrc} {need_file $cfg($key)}
need_file $OUT/controller_mapped.v
set init_top_cell $cfg(top)
set init_verilog $OUT/controller_mapped.v
set init_lef_file [list $cfg(lef)]
set init_mmmc_file [file join $PROJECT_ROOT cadence gpdk090 mmmc.tcl]
set init_pwr_net $cfg(power)
set init_gnd_net $cfg(ground)
init_design
# Fixes the bcwc post-route timing failure observed in the UART archive.
# This selects OCV analysis mode; it does NOT invent missing foundry derates.
setAnalysisMode -analysisType onChipVariation -cppr both
set ::vsc_stage imported
