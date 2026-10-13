require_stage floorplan
setPlaceMode -fp false
place_design
optDesign -preCTS
checkPlace $REP/placement_check.rpt
timeDesign -preCTS -outDir $REP/preCTS
set ::vsc_stage placed
