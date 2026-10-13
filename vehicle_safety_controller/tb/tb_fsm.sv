`timescale 1ns/1ps
module tb_fsm;
    reg clk=0; always #5 clk=~clk;
    reg reset=1,tick=0,job_start=0,job_finish=0,eligible=0,internal_fault=0;
    reg valid_active=0,valid_clear=0,sensor_valid=1,safe_to_act=1,safety_conflict=0;
    reg caution_request=0,elevated_request=0,recovery_ok=1,fault_ack=0;
    wire [2:0] state;
    wire override_enable,emergency_pending,fault_status,acknowledge_idle;
    wire [1:0] action_code,priority_level;
    integer checks=0;
    emergency_fsm #(.LEASE_TICKS(6),.CLEAR_TICKS(3),.RECOVERY_TICKS(3),.RECOVERY_TIMEOUT_TICKS(12)) dut(.*);
    task check(input bit ok,input string s); begin checks++; if(!ok) $fatal(1,"fsm: %s, state=%0d",s,state); end endtask
    task edge_step; begin @(posedge clk); #1; @(negedge clk); end endtask
    task start_override;
        begin
            reset=1; tick=0; valid_clear=0; valid_active=0; job_start=0; job_finish=0; eligible=0;
            internal_fault=0; fault_ack=0; sensor_valid=1; safe_to_act=1; safety_conflict=0;
            edge_step(); reset=0; edge_step(); check(state==1,"normal");
            job_start=1; valid_active=1; edge_step(); job_start=0; valid_active=0;
            job_finish=1; eligible=1; edge_step(); job_finish=0; eligible=0;
            check(state==3 && override_enable,"override entry");
        end
    endtask
    task clear_to_recovery;
        begin
            valid_clear=1; edge_step(); valid_clear=0; tick=1;
            check(state==4 && !override_enable,"clear enters hold");
            edge_step(); check(state==4,"clear tick 1"); edge_step(); check(state==4,"clear tick 2");
            edge_step(); check(state==5,"clear tick 3");
        end
    endtask
    initial begin
        @(negedge clk);
        start_override(); clear_to_recovery();
        edge_step(); edge_step(); check(state==5,"recovery not early");
        valid_clear=1; edge_step(); valid_clear=0;
        check(state==5 && dut.recovery_count==0,"new clear on terminal recovery tick restarts counter");
        edge_step(); edge_step(); check(state==5,"full new recovery interval");
        edge_step(); check(state==1,"recovery completes");

        start_override(); tick=1;
        repeat(5) edge_step(); check(override_enable,"lease still valid before final tick");
        eligible=1; job_finish=1; edge_step(); job_finish=0; eligible=0;
        check(state==6 && !override_enable,"expiry wins same-edge late renewal");

        start_override(); clear_to_recovery();
        valid_active=1; edge_step(); valid_active=0;
        check(state==5 && dut.recovery_count==0,"pending active inhibits recovery");
        repeat(9) edge_step(); check(state==6,"total recovery timeout is not restarted");

        start_override(); valid_clear=1; internal_fault=1; edge_step();
        check(state==6 && !override_enable,"fault wins simultaneous clear");
        internal_fault=0; valid_clear=0; fault_ack=1; edge_step();
        check(state==0,"healthy cleared acknowledgement enters INIT");
        edge_step(); check(state==1,"ack returns normal without override");

        start_override(); safe_to_act=0; edge_step(); check(state==6,"veto hold");
        safe_to_act=1; fault_ack=1; edge_step(); check(state==6,"ack with pending emergency denied");
        valid_clear=1; edge_step(); valid_clear=0; edge_step(); check(state==0,"ack after clear");
        $display("PASS tb_fsm checks=%0d",checks); $finish;
    end
    initial begin #100000; $fatal(1,"fsm timeout"); end
endmodule
