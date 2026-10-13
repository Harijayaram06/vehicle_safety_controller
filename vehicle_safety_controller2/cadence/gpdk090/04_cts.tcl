require_stage placed
# The UART log failed because cell choices were supplied after the first CTS call.
# Set buffer and inverter types separately BEFORE creating/running the clock tree.
set_ccopt_property buffer_cells $cfg(clock_buffers)
set_ccopt_property inverter_cells $cfg(clock_inverters)
set_ccopt_property target_max_trans $cfg(clock_transition)
create_ccopt_clock_tree_spec
ccopt_design
timeDesign -postCTS -outDir $REP/postCTS_setup
timeDesign -postCTS -hold -outDir $REP/postCTS_hold
optDesign -postCTS -hold
# Re-report after hold optimization, not only before it.
timeDesign -postCTS -outDir $REP/postCTS_optimized_setup
timeDesign -postCTS -hold -outDir $REP/postCTS_optimized_hold
set ::vsc_stage cts
