# Optional: xrun ... -gui -input cadence/xcelium_gui.tcl
# Confirm SHM probe syntax in your installed Xcelium version.
database -open waves -shm -into build/controller.shm
probe -create tb_controller -all -depth all -database waves
run
