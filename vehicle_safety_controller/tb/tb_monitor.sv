`timescale 1ns/1ps
module tb_monitor;
    reg clk=0; always #5 clk=~clk;
    reg reset=1, frame_valid=0;
    reg [10:0] can_id=11'h120;
    reg [3:0] can_dlc=2;
    reg [63:0] can_data=64'h101;
    wire tick,rate_bad,duplicate_bad;
    wire [7:0] rate_now,duplicate_now,gap_now;
    integer checks=0;
    request_monitor #(.TICK_CYCLES(2),.WINDOW_TICKS(200),.DUP_GAP_TICKS(100)) dut(.*);
    task check(input bit ok,input string s); begin checks++; if(!ok) $fatal(1,"monitor: %s",s); end endtask
    initial begin
        repeat(2) @(negedge clk); reset=0;
        check(gap_now==255,"first frame gap");
        // Drive one frame each cycle to exercise saturating counters, irrespective of CAN bitrate.
        frame_valid=1; #1; check(rate_now==1 && duplicate_now==1,"current frame included");
        repeat(260) @(negedge clk);
        check(rate_now==255 && duplicate_now==255,"counters saturate");
        check(rate_bad && duplicate_bad,"saturation cannot bypass checks");
        frame_valid=0;
        repeat(202) @(negedge clk);
        frame_valid=1; #1; check(duplicate_now==1,"long gap resets duplicate run");
        @(negedge clk); frame_valid=0;
        // Boundary semantics: current boundary frame belongs to the new window.
        while(!(tick && dut.window_age==199)) @(negedge clk);
        frame_valid=1; #1; check(rate_now==1,"boundary frame new window");
        @(negedge clk); frame_valid=0;
        repeat(520) @(negedge clk); check(gap_now==255,"gap saturates");
        $display("PASS tb_monitor checks=%0d",checks); $finish;
    end
    initial begin #100000; $fatal(1,"monitor timeout"); end
endmodule
