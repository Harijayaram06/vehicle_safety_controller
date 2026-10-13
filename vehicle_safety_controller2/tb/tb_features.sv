`timescale 1ns/1ps
module tb_features;
    reg frame_valid;
    reg [10:0] can_id;
    reg [3:0] can_dlc;
    reg [63:0] can_data;
    reg format_ok,crc_ok,upstream_valid;
    reg [7:0] rate_now,duplicate_now,gap_now;
    wire [63:0] features;
    wire valid_active,valid_clear,deterministic_ok;
    integer checks=0;
    can_feature_extractor dut(.*);
    task check(input bit ok,input string s); begin checks++; if(!ok) $fatal(1,"feature: %s",s); end endtask
    initial begin
        frame_valid=1; can_id=11'h120; can_dlc=2; can_data=64'h101;
        format_ok=1; crc_ok=1; upstream_valid=1;
        for(integer n=0;n<256;n++) begin
            rate_now=n; duplicate_now=n; gap_now=n; #1;
            check(features[31:24]==((n*4>127)?127:n*4),"rate quantization");
            check(features[39:32]==((n>127)?127:n),"gap quantization");
            check(features[47:40]==((n<=1)?0:((n-1)*32>127)?127:(n-1)*32),"duplicate quantization");
            check(valid_active && deterministic_ok,"valid active");
        end
        can_data=64'h0202; #1; check(valid_clear && !valid_active,"clear decode");
        can_data=64'h10001; #1; check(!deterministic_ok && features[55:48]==0,"unused bytes rejected");
        can_data=64'h0201; can_id=11'h121; #1;
        check(!deterministic_ok && features[31:24]==0 && features[39:32]==127 && features[47:40]==0,"unrelated ID features");
        can_id=11'h120; frame_valid=0; #1; check(!valid_active && !valid_clear,"no observation pulse");
        $display("PASS tb_features checks=%0d",checks); $finish;
    end
endmodule
