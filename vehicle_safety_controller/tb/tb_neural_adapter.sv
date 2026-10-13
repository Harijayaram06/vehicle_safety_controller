`timescale 1ns/1ps
module tb_neural_adapter;
    reg clk=0; always #25 clk=~clk;
    reg reset=1, can_frame_valid=0;
    reg [10:0] can_id=11'h120;
    reg [3:0] can_dlc=2;
    reg [63:0] can_data=0;
    reg can_format_ok=1, can_crc_ok=1, upstream_request_valid=1;
    reg sensor_valid=1, safe_to_act=1, safety_conflict=0;
    reg caution_request=0, elevated_request=0, recovery_ok=1, fault_ack=0;
    wire classifier_busy, decision_valid, override_enable, emergency_pending, fault_status;
    wire suspicious_traffic, uncertain_status, overrun_status;
    wire [2:0] decision_code, fsm_state;
    wire [1:0] priority_level, action_code;
    integer checks=0, cycles=0, transitions=0;
    reg [2:0] last_state=0;
    vehicle_safety_top #(.USE_MLP(1),.TICK_CYCLES(10),.WINDOW_TICKS(100),.RATE_LIMIT(16),.DUP_LIMIT(4),
        .DUP_GAP_TICKS(100),.LEASE_TICKS(500),.CLEAR_TICKS(3),.RECOVERY_TICKS(4),
        .RECOVERY_TIMEOUT_TICKS(20)) dut(.*);
    task check(input bit ok,input string s); begin checks++; if(!ok) $fatal(1,"adapter: %s",s); end endtask
    task step(input integer n); repeat(n) begin @(posedge clk); #1; end endtask
    task fresh;
        begin
            @(negedge clk); reset=1; can_frame_valid=0; can_id=11'h120; can_dlc=2; can_data=0;
            can_format_ok=1; can_crc_ok=1; upstream_request_valid=1;
            sensor_valid=1; safe_to_act=1; safety_conflict=0; fault_ack=0;
            step(2); @(negedge clk); reset=0; step(2);
        end
    endtask
    task active;
        begin
            @(negedge clk); can_frame_valid=1; can_data=64'h101;
            step(1); @(negedge clk); can_frame_valid=0;
        end
    endtask
    task inject_emergency;
        begin
            @(negedge clk);
            force dut.mlp_class=2'd1; force dut.mlp_confident=1'b1; force dut.mlp_done=1'b1;
            step(1);
            release dut.mlp_class; release dut.mlp_confident; release dut.mlp_done;
        end
    endtask
    initial begin
        // Shipped ROM is explicitly untrained and cannot enable an override.
        fresh(); check(fault_status && !override_enable,"invalid ROM fails closed");
        force dut.model_valid=1'b1;
        fresh(); active(); cycles=0;
        while(!decision_valid && cycles<200) begin step(1); cycles++; end
        check(decision_valid && cycles==140,"neural transaction completion latency");
        check(!override_enable && uncertain_status && emergency_pending,"zero-score uncertainty denies entry");

        fresh(); upstream_request_valid=0; active(); step(4); inject_emergency();
        check(decision_valid && decision_code==2 && !override_enable,"confident neural result cannot bypass gateway");
        fresh(); can_crc_ok=0; active(); step(4); inject_emergency();
        check(decision_code==2 && !override_enable,"neural result cannot bypass CRC");
        fresh(); active(); step(4); force dut.captured_monitor_bad=1'b1; inject_emergency();
        check(decision_code==3 && !override_enable,"neural result cannot bypass monitor"); release dut.captured_monitor_bad;
        fresh(); active(); step(4); safe_to_act=0; inject_emergency();
        check(fault_status && !override_enable,"neural result cannot bypass live gate");
        fresh(); active(); step(4); inject_emergency();
        check(override_enable,"adapter accepts all valid checks with injected result");

        fresh(); active(); step(4);
        @(negedge clk); can_data=64'h0202; can_frame_valid=1; step(1);
        @(negedge clk); can_frame_valid=0; step(3); inject_emergency();
        check(decision_code==5 && !override_enable && overrun_status,"clear during busy cancels old neural result");

        fresh(); upstream_request_valid=0; active();
        @(negedge clk); upstream_request_valid=1; can_data=64'h0301; can_frame_valid=1; step(1);
        @(negedge clk); can_frame_valid=0; step(3); inject_emergency();
        check(decision_code==2 && !override_enable && overrun_status,"busy arrival cannot replace captured metadata");

        fresh(); active(); force dut.mlp_done=1'b0; step(258);
        check(fault_status && !override_enable && !classifier_busy,"watchdog terminates stuck inference");
        release dut.mlp_done; release dut.model_valid;
        $display("PASS tb_neural_adapter checks=%0d (injected classes are protocol tests, not trained-model accuracy)",checks); $finish;
    end
    initial begin #1000000; $fatal(1,"adapter timeout"); end
endmodule
