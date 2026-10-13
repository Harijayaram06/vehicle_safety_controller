`timescale 1ns/1ps
// 8-8-4-3 inference core. ROM interface is combinational, not synchronous SRAM.
// Weights: neuron-major, W1[0:63], W2[64:95], W3[96:107]. Biases: 0:7, 8:11, 12:14.
module mlp_inference #(
    parameter [24:0] MARGIN_MIN=25'd1
)(
    input wire clk, reset, start,
    input wire [63:0] features,
    output reg busy, done,
    output reg [6:0] weight_address,
    input wire signed [7:0] weight_data,
    output reg [3:0] bias_address,
    input wire signed [23:0] bias_data,
    output reg signed [23:0] score0, score1, score2,
    output reg [1:0] class_id,
    output reg confident,
    output reg [24:0] score_margin
);
    localparam IDLE=3'd0, LOAD=3'd1, MAC=3'd2, WRITE=3'd3, SELECT=3'd4;
    reg [2:0] state;
    reg [1:0] layer;
    reg [3:0] neuron, input_index;
    reg [7:0] x[0:7], h1[0:7], h2[0:3];
    reg signed [23:0] accumulator;
    reg signed [7:0] activation;
    wire signed [15:0] product=activation * weight_data;
    wire signed [23:0] product_wide={{8{product[15]}},product};
    reg signed [23:0] best, second;
    reg [1:0] winner;
    wire signed [24:0] margin_wide=$signed({best[23],best})-$signed({second[23],second});
    integer i;
    function [7:0] relu_q7;
        input signed [23:0] value;
        begin
            if(value<=0) relu_q7=0;
            else if((value>>>7)>127) relu_q7=127;
            else relu_q7=value[14:7];
        end
    endfunction
    always @* begin
        weight_address=0; bias_address=0; activation=0;
        case(layer)
            0: begin weight_address=neuron*8+input_index; bias_address=neuron; activation=$signed(x[input_index[2:0]]); end
            1: begin weight_address=64+neuron*8+input_index; bias_address=8+neuron; activation=$signed(h1[input_index[2:0]]); end
            2: begin weight_address=96+neuron*4+input_index; bias_address=12+neuron; activation=$signed(h2[input_index[1:0]]); end
            default: begin end
        endcase
        // Stable tie rule: the lowest index wins, but zero margin is uncertain.
        if(score0>=score1) begin best=score0; second=score1; winner=0; end
        else begin best=score1; second=score0; winner=1; end
        if(score2>best) begin second=best; best=score2; winner=2; end
        else if(score2>second) second=score2;
    end
    always @(posedge clk) begin
        if(reset) begin
            state<=IDLE; busy<=0; done<=0; layer<=0; neuron<=0; input_index<=0;
            accumulator<=0; score0<=0; score1<=0; score2<=0; class_id<=0;
            confident<=0; score_margin<=0;
            for(i=0;i<8;i=i+1) begin x[i]<=0; h1[i]<=0; end
            for(i=0;i<4;i=i+1) h2[i]<=0;
        end else begin
            done<=0;
            case(state)
                IDLE: if(start) begin
                    for(i=0;i<8;i=i+1) x[i]<=features[i*8 +: 8];
                    layer<=0; neuron<=0; input_index<=0; busy<=1; state<=LOAD;
                    confident<=0;
                end
                LOAD: begin accumulator<=bias_data; input_index<=0; state<=MAC; end
                MAC: begin
                    accumulator<=accumulator+product_wide;
                    if((layer==2 && input_index==3) || (layer!=2 && input_index==7)) state<=WRITE;
                    else input_index<=input_index+1'b1;
                end
                WRITE: begin
                    input_index<=0;
                    if(layer==0) begin
                        h1[neuron[2:0]]<=relu_q7(accumulator);
                        if(neuron==7) begin neuron<=0; layer<=1; end else neuron<=neuron+1'b1;
                        state<=LOAD;
                    end else if(layer==1) begin
                        h2[neuron[1:0]]<=relu_q7(accumulator);
                        if(neuron==3) begin neuron<=0; layer<=2; end else neuron<=neuron+1'b1;
                        state<=LOAD;
                    end else begin
                        case(neuron)
                            0: score0<=accumulator;
                            1: score1<=accumulator;
                            2: score2<=accumulator;
                            default: begin end
                        endcase
                        if(neuron==2) state<=SELECT;
                        else begin neuron<=neuron+1'b1; state<=LOAD; end
                    end
                end
                SELECT: begin
                    class_id<=winner; score_margin<=margin_wide;
                    confident<=(margin_wide>0) && ($unsigned(margin_wide)>=MARGIN_MIN);
                    busy<=0; done<=1; state<=IDLE;
                end
                default: begin state<=IDLE; busy<=0; confident<=0; end
            endcase
        end
    end
endmodule
