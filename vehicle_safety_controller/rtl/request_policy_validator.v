`timescale 1ns/1ps
module request_policy_validator #(parameter integer USE_MONITOR=1, USE_MLP=0)(
    input wire requested, deterministic_ok, monitor_bad,
    input wire [1:0] mlp_class,
    input wire mlp_confident, cancelled, internal_error,
    output reg eligible,
    output reg [2:0] code
);
    always @* begin
        eligible=0; code=0;
        if(internal_error) code=3'd6;
        else if(cancelled) code=3'd5;
        else if(!requested) code=3'd0;
        else if(!deterministic_ok) code=3'd2;
        else if(USE_MONITOR && monitor_bad) code=3'd3;
        else if(USE_MLP && !mlp_confident) code=3'd4;
        else if(USE_MLP && mlp_class!=2'd1) code=(mlp_class==2'd2) ? 3'd3 : 3'd0;
        else begin eligible=1; code=3'd1; end
    end
endmodule
