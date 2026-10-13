# Starting interface budget, NOT measured timing. Confirm the library time unit is ns.
# One synchronous clock domain; reset is synchronous and remains a timed input.
create_clock -name core_clk -period 50.000 [get_ports clk]
set_clock_uncertainty 0.200 [get_clocks core_clk]
set_clock_transition 0.100 [get_clocks core_clk]
set data_inputs [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay -clock core_clk -max 5.000 $data_inputs
set_input_delay -clock core_clk -min 0.500 $data_inputs
set_input_transition 0.100 $data_inputs
set_output_delay -clock core_clk -max 5.000 [all_outputs]
set_output_delay -clock core_clk -min 0.500 [all_outputs]
# 0.01 in the library capacitance unit; confirm/replace with actual receiving load.
set_load 0.010 [all_outputs]
# No blanket false paths or multicycle exceptions.
