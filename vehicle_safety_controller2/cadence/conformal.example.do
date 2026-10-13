// Conformal native dofile STARTER. Copy to conformal.do and replace library paths.
// This is not Tcl and is not a proof result. Use the same RTL defaults as Genus.
set system mode setup
read library /REPLACE_WITH_AUTHORIZED_LAB_PATH/slow.lib -liberty -both
read design rtl/request_monitor.v rtl/can_feature_extractor.v rtl/request_policy_validator.v rtl/priority_arbiter.v rtl/emergency_fsm.v rtl/mlp_inference.v rtl/mlp_parameter_rom.v rtl/vehicle_safety_top.v -verilog -golden
read design outputs/controller_mapped.v -verilog -revised
set root module vehicle_safety_top -both
set system mode lec
add compare points -all
compare
report compare data
report unmapped points
// Inspect ALL non-equivalent, aborted, unmapped and black-box points.
// Do not remove failing compare points to manufacture a pass.
