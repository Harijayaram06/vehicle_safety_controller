# Innovus 21.15 legacy UI flow, adapted from user's UART archive.
source [file join [file dirname [info script]] common.tcl]
set steps {
    {imported 01_import.tcl}
    {floorplan 02_floorplan_power.tcl}
    {placed 03_place.tcl}
    {cts 04_cts.tcl}
    {routed 05_route_extract.tcl}
}
if {[info exists ::env(VSC_STOP_AFTER)] && $::env(VSC_STOP_AFTER) ni {imported floorplan placed cts routed}} {
    error "Bad VSC_STOP_AFTER: $::env(VSC_STOP_AFTER)"
}
set start_at 0
if {[info exists ::env(VSC_RESUME_STAGE)]} {
    set previous $::env(VSC_RESUME_STAGE)
    set found 0
    foreach item $steps {
        incr start_at
        if {[lindex $item 0] eq $previous} {set found 1; break}
    }
    if {!$found} {error "Bad VSC_RESUME_STAGE: $previous"}
    set checkpoint $OUT/controller_${previous}.enc.dat
    if {![file isdirectory $checkpoint]} {error "Checkpoint missing: $checkpoint"}
    restoreDesign $checkpoint $cfg(top)
    set ::vsc_stage $previous
}
foreach item [lrange $steps $start_at end] {
    lassign $item stage script
    source [file join $PROJECT_ROOT cadence gpdk090 $script]
    if {[stage_complete $stage]} {return}
}
puts "Flow reached routed checkpoint. Inspect reports; no signoff pass is asserted."
