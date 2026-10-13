# Copy to cadence/lab_config.tcl and edit using your lab's EXISTING working flow.
# Nothing here selects a 45 nm or 90 nm PDK automatically.
set cfg(top) vehicle_safety_top
set cfg(liberty) [list /REPLACE_WITH_AUTHORIZED_LAB_PATH/slow.lib]
set cfg(lef) [list /REPLACE_WITH_AUTHORIZED_LAB_PATH/technology.lef /REPLACE_WITH_AUTHORIZED_LAB_PATH/cells.lef]
set cfg(power_net) VDD
set cfg(ground_net) VSS
# Lab-supplied, version-compatible files; examples described in CADENCE_GUIDE.md.
set cfg(mmmc) /REPLACE_WITH_AUTHORIZED_LAB_PATH/controller_mmmc.tcl
set cfg(physical_setup) /REPLACE_WITH_AUTHORIZED_LAB_PATH/controller_floorplan_power.tcl
set cfg(physical_finish) /REPLACE_WITH_AUTHORIZED_LAB_PATH/controller_finish_export.tcl
set cfg(tempus_setup) /REPLACE_WITH_AUTHORIZED_LAB_PATH/controller_tempus_corners.tcl
