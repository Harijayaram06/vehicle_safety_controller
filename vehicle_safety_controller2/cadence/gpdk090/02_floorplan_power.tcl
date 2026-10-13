require_stage imported
floorPlan -site $cfg(site) -r 1.0 $cfg(utilization) \
    $cfg(core_margin) $cfg(core_margin) $cfg(core_margin) $cfg(core_margin)
# Spread actual top-level signal pins BEFORE placement/routing. Port count differs from UART.
set names [lsort [dbGet top.terms.name]]
set signal_pins {}
foreach name $names {if {$name ne $cfg(power) && $name ne $cfg(ground)} {lappend signal_pins $name}}
set sides {Top Bottom Left Right}
for {set i 0} {$i<4} {incr i} {set pins($i) {}}
set i 0
foreach name $signal_pins {lappend pins([expr {$i%4}]) $name; incr i}
for {set i 0} {$i<4} {incr i} {
    if {[llength $pins($i)]} {
        editPin -pin $pins($i) -side [lindex $sides $i] -spreadType center -layer Metal3 -fixOverlap 1
    }
}
clearGlobalNets
globalNetConnect $cfg(power) -type pgpin -pin $cfg(power) -instanceBasename * -hierarchicalInstance {}
globalNetConnect $cfg(ground) -type pgpin -pin $cfg(ground) -instanceBasename * -hierarchicalInstance {}
if {$cfg(special_cells_tcl) ne ""} {need_file $cfg(special_cells_tcl); source $cfg(special_cells_tcl)}
setAddRingMode -stacked_via_top_layer Metal9 -stacked_via_bottom_layer Metal1
addRing -nets [list $cfg(power) $cfg(ground)] -type core_rings -follow core \
    -layer {top Metal9 bottom Metal9 left Metal8 right Metal8} \
    -width $cfg(ring_width) -spacing $cfg(ring_spacing) -offset $cfg(ring_offset)
setAddStripeMode -stacked_via_top_layer Metal9 -stacked_via_bottom_layer Metal1
addStripe -nets [list $cfg(power) $cfg(ground)] -layer Metal8 -direction vertical \
    -width $cfg(stripe_width) -spacing $cfg(stripe_spacing) \
    -set_to_set_distance $cfg(stripe_pitch) -start_from left
sroute -connect {corePin floatingStripe} -nets [list $cfg(power) $cfg(ground)] \
    -layerChangeRange {Metal1 Metal9} -crossoverViaLayerRange {Metal1 Metal9} \
    -targetViaLayerRange {Metal1 Metal9} -allowJogging 1 -allowLayerChange 1 \
    -corePinTarget {firstAfterRowEnd} -floatingStripeTarget {ring stripe followpin}
verifyConnectivity -type special -report $REP/floorplan_pg_connectivity.rpt
verify_drc -report $REP/floorplan_drc.rpt
set ::vsc_stage floorplan
