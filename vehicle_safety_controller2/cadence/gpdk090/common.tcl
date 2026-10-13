set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ../..]]
cd $PROJECT_ROOT
source [file join $PROJECT_ROOT cadence gpdk090 config.tcl]
set OUT [file join $PROJECT_ROOT outputs gpdk090]
set REP [file join $PROJECT_ROOT reports gpdk090]
file mkdir $OUT $REP
proc need_file {p} {if {![file isfile $p] || ![file readable $p]} {error "Missing/unreadable required file: $p"}}
proc design_files {} {
    set fd [open rtl/files.f r]; set lines [split [string trim [read $fd]] "\n"]; close $fd
    return $lines
}
proc require_stage {expected} {
    if {![info exists ::vsc_stage] || $::vsc_stage ne $expected} {
        error "Expected stage $expected. Use innovus.tcl or restore the correct checkpoint before continuing."
    }
}
proc stage_complete {stage} {
    global OUT cfg
    saveDesign [file join $OUT controller_${stage}.enc]
    set ::vsc_stage $stage
    puts "VSC STAGE COMPLETED: $stage. Review the reports before continuing."
    return [expr {[info exists ::env(VSC_STOP_AFTER)] && $::env(VSC_STOP_AFTER) eq $stage}]
}
