`timescale 1ns/1ps
module priority_arbiter(input wire emergency, elevated, caution, output wire [1:0] priority_level);
    assign priority_level=emergency ? 2'd3 : elevated ? 2'd2 : caution ? 2'd1 : 2'd0;
endmodule
