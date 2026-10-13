# Library paths recovered from the user's UART project. No PDK bytes are bundled.
set pdk_root /home/cadence/install/FOUNDRY/digital/90nm/dig
if {[info exists ::env(VSC_PDK_ROOT)]} {set pdk_root [file normalize $::env(VSC_PDK_ROOT)]}
set cfg(top) vehicle_safety_top
set cfg(slow) [file join $pdk_root lib slow.lib]
set cfg(fast) [file join $pdk_root lib fast.lib]
# UART's tech+macro pair failed; the translated LEF subsequently loaded.
set cfg(lef) [file join $pdk_root lef gsclib090_translated.lef]
set cfg(captable) [file join $pdk_root captable gpdk090.lef.extended.CapTbl]
set cfg(qrc) [file join $pdk_root qrc gpdk090_9l.tch]
set cfg(site) gsclib090site
set cfg(power) VDD
set cfg(ground) VSS
set cfg(utilization) 0.60
set cfg(core_margin) 10.0
# Initial engineering choices; inspect congestion and PG DRC for this new design.
set cfg(ring_width) 2.0
set cfg(ring_spacing) 1.0
set cfg(ring_offset) 1.8
set cfg(stripe_width) 1.0
set cfg(stripe_spacing) 1.0
set cfg(stripe_pitch) 20.0
set cfg(clock_buffers) {CLKBUFX2 CLKBUFX3 CLKBUFX4 CLKBUFX6 CLKBUFX8 CLKBUFX12 CLKBUFX16 CLKBUFX20}
set cfg(clock_inverters) {CLKINVX1 CLKINVX2 CLKINVX3 CLKINVX4 CLKINVX6 CLKINVX8 CLKINVX12 CLKINVX16 CLKINVX20}
set cfg(clock_transition) 0.2ns
# These were NOT established by the archive. Fill only from the actual PDK.
set cfg(filler_cells) {}
set cfg(gds_files) {}
set cfg(gds_map) {}
# Optional lab-approved tap/endcap/tie commands, executed before placement.
set cfg(special_cells_tcl) {}
# Optional local overrides, ignored by Git.
set local_cfg [file join [file dirname [info script]] local_config.tcl]
if {[file exists $local_cfg]} {source $local_cfg}
