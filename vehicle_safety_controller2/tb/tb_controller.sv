`timescale 1ns/1ps
module tb_controller;
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
    vehicle_safety_top #(.TICK_CYCLES(10),.WINDOW_TICKS(100),.RATE_LIMIT(16),.DUP_LIMIT(4),
        .DUP_GAP_TICKS(100),.LEASE_TICKS(30),.CLEAR_TICKS(3),.RECOVERY_TICKS(4),
        .RECOVERY_TIMEOUT_TICKS(20)) dut(.*);
    task check(input bit ok, input string label_text);
        begin checks++; if(!ok) begin $display("FAIL: %s at cycle %0d state %0d",label_text,cycles,fsm_state); $fatal(1); end end
    endtask
    task step(input integer n);
        repeat(n) begin @(posedge clk); #1; end
    endtask
    task fresh;
        begin
            @(negedge clk); reset=1; can_frame_valid=0; can_id=11'h120; can_dlc=2; can_data=0;
            can_format_ok=1; can_crc_ok=1; upstream_request_valid=1;
            sensor_valid=1; safe_to_act=1; safety_conflict=0; recovery_ok=1; fault_ack=0;
            caution_request=0; elevated_request=0;
            step(2); check(!override_enable && action_code==3,"reset safe output");
            @(negedge clk); reset=0; step(2); check(fsm_state==1,"reset to normal");
        end
    endtask
    task send(input [7:0] flags, input [7:0] seq, input [2:0] expected);
        begin
            @(negedge clk); can_data={48'd0,seq,flags}; can_frame_valid=1;
            step(1); check(classifier_busy,"capture busy");
            @(negedge clk); can_frame_valid=0;
            step(1); check(decision_valid && decision_code==expected,"decision code");
            step(1); check(!decision_valid,"one-cycle completion");
        end
    endtask
    task wait_state(input [2:0] target, input integer limit);
        integer n;
        begin n=0; while(fsm_state!=target && n<limit) begin step(1); n++; end
            check(fsm_state==target,"bounded state transition"); end
    endtask
    // Invariants sampled after all nonblocking assignments. Test inputs change on falling edges.
    always @(posedge clk) begin
        #2; cycles++;
        if(!reset) begin
            if(override_enable && !(sensor_valid && safe_to_act && !safety_conflict && fsm_state==3 && dut.control.lease_left!=0))
                $fatal(1,"override safety invariant");
            if((action_code==2)!==override_enable) $fatal(1,"action/override consistency");
            if(fsm_state!=last_state) transitions++;
            last_state=fsm_state;
        end
    end
    initial begin
        if($test$plusargs("WAVES")) begin $dumpfile("build/controller.vcd"); $dumpvars(0,tb_controller); end
        fresh();
        @(negedge clk); caution_request=1; step(1); check(priority_level==1 && action_code==1,"caution");
        @(negedge clk); elevated_request=1; step(1); check(priority_level==2 && action_code==3,"P2 over P1");
        send(1,1,1); check(override_enable && priority_level==3,"P3 over P2 and P1");
        send(2,2,0); check(fsm_state==4 && !override_enable,"clear removes yield");
        wait_state(5,50); check(action_code==3,"recovery hold");
        wait_state(1,60); check(!override_enable,"normal after recovery");

        fresh(); upstream_request_valid=0; send(1,1,2); check(!override_enable && !emergency_pending,"untrusted active denied");
        fresh(); can_id=11'h121; send(1,1,2); check(!override_enable,"wrong ID denied");
        fresh(); can_dlc=8; send(1,1,2); check(!override_enable,"wrong DLC denied");
        fresh(); can_crc_ok=0; send(1,1,2); check(!override_enable,"bad CRC denied");
        fresh(); can_format_ok=0; send(1,1,2); check(!override_enable,"bad format denied");
        fresh(); send(3,1,2); check(!override_enable,"active-clear conflict denied");
        fresh(); send(5,1,2); check(!override_enable,"reserved bits denied");
        fresh(); send(0,1,0); check(!override_enable,"no request");
        fresh(); safe_to_act=0; send(1,1,1); check(fault_status && !override_enable && emergency_pending,"eligible but unsafe hold");

        fresh(); send(1,1,1); @(negedge clk); safe_to_act=0; step(1); check(fault_status && !override_enable,"live gate withdrawal");
        fresh(); send(1,1,1); @(negedge clk); sensor_valid=0; step(1); check(fault_status && !override_enable,"sensor withdrawal");
        fresh(); send(1,1,1); @(negedge clk); safety_conflict=1; step(1); check(fault_status && !override_enable,"conflict withdrawal");

        fresh(); send(1,9,1); send(1,9,1); send(1,9,1); send(1,9,3);
        check(suspicious_traffic && override_enable,"duplicate denied without revoking prior lease");
        fresh(); for(integer j=1;j<=16;j++) send(1,j,1);
        send(1,17,3); check(suspicious_traffic,"rate threshold");

        fresh(); send(1,1,1); step(150); send(1,2,1); step(180);
        check(override_enable,"approved renewal extends lease"); wait_state(6,160); check(!override_enable,"lease expiry holds");
        @(negedge clk); fault_ack=1; step(2); check(fsm_state==1 && !override_enable,"healthy acknowledgement via INIT");

        fresh(); send(1,1,1); send(2,2,0); step(10);
        // Valid active with a failing monitor must not reenter override and restarts clearance.
        force dut.captured_monitor_bad=1'b1; send(1,3,3); release dut.captured_monitor_bad;
        step(50); check(fsm_state==4 && !override_enable,"denied active interrupts clear stability");
        send(2,4,0); wait_state(5,50);
        step(10); @(negedge clk); recovery_ok=0; step(15); check(fsm_state==5,"recovery condition interrupted");
        @(negedge clk); recovery_ok=1; step(20); check(fsm_state==5,"recovery must restart full count"); wait_state(1,40);

        fresh(); send(1,1,1); send(2,2,0); recovery_ok=0;
        wait_state(6,230); check(!override_enable,"total recovery timeout");
        fresh(); send(1,1,1); send(2,2,0); send(1,3,1); check(override_enable,"new approved active during clearance");

        fresh();
        @(negedge clk); can_frame_valid=1; can_data=64'h0101;
        step(1); check(classifier_busy,"job capture before immediate clear");
        @(negedge clk); can_data=64'h0202; // completion and clearance on same edge
        step(1); check(decision_valid && decision_code==5 && !override_enable,"clear wins over completion");
        check(overrun_status,"busy arrival diagnosed");
        @(negedge clk); can_frame_valid=0; step(2);

        fresh(); @(negedge clk); can_frame_valid=1; can_data=64'h0101; step(1);
        @(negedge clk); reset=1; step(1); check(!classifier_busy && !override_enable && !decision_valid,"reset cancels job");
        fresh(); force dut.control.state=3'd7; step(1); release dut.control.state; step(1); check(fault_status,"illegal state hold");
        $display("PASS tb_controller checks=%0d observed_transitions=%0d cycles=%0d",checks,transitions,cycles); $finish;
    end
    initial begin #10000000; $fatal(1,"testbench timeout"); end
endmodule
