`timescale 1ns/1ps
// Deliberately INVALID model. Replace using ml/export_model.py after training.
// Enabling USE_MLP with this ROM fails closed; zero scores are not a trained model.
module mlp_parameter_rom(
    input wire [6:0] weight_address,
    input wire [3:0] bias_address,
    output wire signed [7:0] weight_data,
    output wire signed [23:0] bias_data,
    output wire [24:0] margin_min,
    output wire model_valid
);
    assign weight_data=8'sd0;
    assign bias_data=24'sd0;
    assign margin_min=25'd1;
    assign model_valid=1'b0;
endmodule
