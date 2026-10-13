`timescale 1ns/1ps
module tb_mlp;
    reg clk=0; always #5 clk=~clk;
    reg reset=1,start=0;
    reg [63:0] features;
    wire busy,done,confident;
    wire [6:0] weight_address;
    wire [3:0] bias_address;
    reg signed [7:0] weights[0:107];
    reg signed [23:0] biases[0:14];
    wire signed [7:0] weight_data=weights[weight_address];
    wire signed [23:0] bias_data=biases[bias_address];
    wire signed [23:0] score0,score1,score2;
    wire [1:0] class_id;
    wire [24:0] score_margin;
    reg signed [23:0] e0,e1,e2;
    reg [1:0] ec;
    reg [24:0] em;
    reg ef;
    integer fd,rv,n=0,latency;
    mlp_inference #(.MARGIN_MIN(25'd256)) dut(.*);
    initial begin
        fd=$fopen("vectors/mlp_vectors.txt","r"); if(!fd) $fatal(1,"missing vectors");
        repeat(2) @(negedge clk); reset=0;
        while(!$feof(fd)) begin
            rv=$fscanf(fd,"%h",features);
            if(rv==1) begin
                for(integer i=0;i<108;i++) begin rv=$fscanf(fd,"%h",weights[i]); if(rv!=1) $fatal(1,"weight parse"); end
                for(integer i=0;i<15;i++) begin rv=$fscanf(fd,"%h",biases[i]); if(rv!=1) $fatal(1,"bias parse"); end
                rv=$fscanf(fd,"%h %h %h %h %h %h",e0,e1,e2,ec,em,ef);
                if(rv!=6) $fatal(1,"expected parse");
                @(negedge clk); start=1; @(negedge clk); start=0; latency=0;
                // Mutating inputs and asserting another start while busy must not alter the job.
                features=64'h7f7f7f7f7f7f7f7f;
                while(!done && latency<200) begin
                    @(negedge clk); latency++;
                    start=(latency==10); // ignored because the core is already busy
                end
                start=0;
                if(!done || busy) $fatal(1,"MLP missing completion vector %0d",n);
                if(score0!==e0 || score1!==e1 || score2!==e2 || class_id!==ec || score_margin!==em || confident!==ef)
                    $fatal(1,"MLP mismatch vector %0d scores %0d %0d %0d expected %0d %0d %0d",n,score0,score1,score2,e0,e1,e2);
                if(latency!=139) $fatal(1,"Unexpected latency %0d",latency);
                @(negedge clk); if(done) $fatal(1,"done not pulse");
                n++;
            end
        end
        // Reset during a job must cancel it without done.
        @(negedge clk); start=1; @(negedge clk); start=0;
        repeat(10) @(negedge clk); reset=1; @(negedge clk); reset=0;
        repeat(145) begin @(negedge clk); if(done || busy) $fatal(1,"reset cancellation"); end
        $display("PASS tb_mlp bit_exact_vectors=%0d inference_cycles=139 reset_cancel=PASS",n); $finish;
    end
    initial begin #3000000; $fatal(1,"MLP timeout"); end
endmodule
