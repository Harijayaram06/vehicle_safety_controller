`timescale 1ns/1ps
module tb_policy;
    reg requested,deterministic_ok,monitor_bad,mlp_confident,cancelled,internal_error;
    reg [1:0] mlp_class;
    wire eligible; wire [2:0] code;
    integer expected, checks=0;
    request_policy_validator #(.USE_MONITOR(1),.USE_MLP(1)) dut(.*);
    initial begin
        for(integer v=0;v<256;v++) begin
            {internal_error,cancelled,mlp_confident,monitor_bad,deterministic_ok,requested,mlp_class}=v;
            #1;
            if(internal_error) expected=6;
            else if(cancelled) expected=5;
            else if(!requested) expected=0;
            else if(!deterministic_ok) expected=2;
            else if(monitor_bad) expected=3;
            else if(!mlp_confident) expected=4;
            else if(mlp_class!=1) expected=(mlp_class==2)?3:0;
            else expected=1;
            if(code!==expected[2:0] || eligible!==(expected==1)) $fatal(1,"policy truth table %0d",v);
            checks++;
        end
        $display("PASS tb_policy combinations=%0d",checks); $finish;
    end
endmodule
