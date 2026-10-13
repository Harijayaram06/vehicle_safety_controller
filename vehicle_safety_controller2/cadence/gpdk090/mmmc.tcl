# Called after common.tcl. Recovered UART slow/fast + ONE RC-model educational setup.
foreach key {slow fast captable qrc} {need_file $cfg($key)}
need_file $OUT/controller_mapped.sdc
create_library_set -name MAX -timing [list $cfg(slow)]
create_library_set -name MIN -timing [list $cfg(fast)]
create_rc_corner -name RC -cap_table $cfg(captable) -qx_tech_file $cfg(qrc) \
    -preRoute_res 1.0 -preRoute_cap 1.0 -preRoute_clkres 0.0 -preRoute_clkcap 0.0 \
    -postRoute_res 1.0 -postRoute_cap 1.0 -postRoute_xcap 1.0 -postRoute_clkres 0.0 -postRoute_clkcap 0.0
create_delay_corner -name MAX_DELAY -library_set MAX -rc_corner RC
create_delay_corner -name MIN_DELAY -library_set MIN -rc_corner RC
create_constraint_mode -name CONSTRAINTS -sdc_files [list $OUT/controller_mapped.sdc]
create_analysis_view -name WORST_CASE -constraint_mode CONSTRAINTS -delay_corner MAX_DELAY
create_analysis_view -name BEST_CASE -constraint_mode CONSTRAINTS -delay_corner MIN_DELAY
set_analysis_view -setup {WORST_CASE} -hold {BEST_CASE}
