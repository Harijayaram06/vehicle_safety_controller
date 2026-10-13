# Optional, incomplete until real PDK GDS views/map/filler names are supplied.
# Source in the routed Innovus session. No approval flag is a substitute for DRC/LVS.
require_stage routed
foreach key {gds_files gds_map filler_cells} {
    if {[llength $cfg($key)]==0} {error "GDS blocked: cfg($key) unknown in UART archive. Fill local_config.tcl from lab PDK."}
}
need_file $cfg(gds_map)
foreach f $cfg(gds_files) {need_file $f}
addFiller -cell $cfg(filler_cells) -prefix FILL
# Fillers can affect checks/extraction. Regenerate final handoff from this database.
globalNetConnect $cfg(power) -type pgpin -pin $cfg(power) -instanceBasename * -hierarchicalInstance {}
globalNetConnect $cfg(ground) -type pgpin -pin $cfg(ground) -instanceBasename * -hierarchicalInstance {}
verify_drc -report $REP/final_drc.rpt
verifyConnectivity -type all -report $REP/final_connectivity.rpt
extractRC
rcOut -spef $OUT/controller_RC.spef -rc_corner RC
saveNetlist $OUT/controller_routed.v
write_sdc $OUT/controller_routed.sdc
saveDesign $OUT/controller_final.enc
streamOut $OUT/controller.gds -mapFile $cfg(gds_map) -libName VSC90 \
    -structureName $cfg(top) -mode ALL -merge $cfg(gds_files)
puts "GDS exported. Rerun routed STA/LEC on final exports and perform lab DRC/LVS; export is not signoff."
