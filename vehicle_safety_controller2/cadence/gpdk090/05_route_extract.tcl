require_stage cts
setAnalysisMode -analysisType onChipVariation -cppr both
routeDesign
optDesign -postRoute
optDesign -postRoute -hold
# Single RC corner inherited from the UART educational setup; not RC-min/max signoff.
extractRC
rcOut -spef $OUT/controller_RC.spef -rc_corner RC
timeDesign -postRoute -outDir $REP/postRoute_setup
timeDesign -postRoute -hold -outDir $REP/postRoute_hold
verifyConnectivity -type all -report $REP/routed_connectivity.rpt
verify_drc -report $REP/routed_drc.rpt
saveNetlist $OUT/controller_routed.v
# Preserve clock-tree and post-CTS timing constraints, not only the original SDC.
write_sdc $OUT/controller_routed.sdc
set ::vsc_stage routed
puts "Routed educational core: filler/tap/antenna/LVS and GDS still require PDK review."
