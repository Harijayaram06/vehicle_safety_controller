# Invoke tools from the project root. This also anchors paths for sourced scripts.
set PROJECT_ROOT [file normalize [file join [file dirname [info script]] ..]]
cd $PROJECT_ROOT
set cfg_file [file join $PROJECT_ROOT cadence lab_config.tcl]
if {![file exists $cfg_file]} {
    error "Missing cadence/lab_config.tcl. Copy lab_config.example.tcl and set lab paths."
}
source $cfg_file
proc require_file {path} {
    if {![file isfile $path]} {error "Required file not found: $path"}
}
proc require_cfg {key} {
    global cfg
    if {![info exists cfg($key)] || $cfg($key) eq ""} {error "Missing cfg($key)"}
}
proc rtl_files {} {
    set fd [open rtl/files.f r]
    set result [split [string trim [read $fd]] "\n"]
    close $fd
    return $result
}
foreach dir {build reports outputs} {file mkdir $dir}
require_cfg top
