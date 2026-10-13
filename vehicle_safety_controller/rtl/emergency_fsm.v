`timescale 1ns/1ps
// Timers count sampled millisecond enables, not physical vehicle safety deadlines.
module emergency_fsm #(
    parameter integer LEASE_TICKS=500, CLEAR_TICKS=20,
    RECOVERY_TICKS=50, RECOVERY_TIMEOUT_TICKS=1000
)(
    input wire clk, reset, tick,
    input wire job_start, job_finish, eligible, internal_fault,
    input wire valid_active, valid_clear,
    input wire sensor_valid, safe_to_act, safety_conflict,
    input wire caution_request, elevated_request, recovery_ok, fault_ack,
    output reg [2:0] state,
    output reg override_enable,
    output reg [1:0] action_code, priority_level,
    output wire emergency_pending,
    output wire fault_status,
    output wire acknowledge_idle
);
    localparam INIT=3'd0, NORMAL=3'd1, EVALUATE=3'd2, OVERRIDE=3'd3,
               CLEARANCE=3'd4, RECOVERY=3'd5, HOLD=3'd6;
    reg [2:0] next_state;
    reg [15:0] lease_left, pending_left, clear_count, recovery_count, recovery_age;
    reg [15:0] next_lease, next_pending, next_clear_count, next_recovery_count, next_recovery_age;
    reg clear_latched, next_clear_latched;
    wire gate_ok=sensor_valid && safe_to_act && !safety_conflict;
    wire healthy=sensor_valid && !safety_conflict;
    wire lease_expired=tick && lease_left==16'd1;
    wire recovery_timeout=tick && (recovery_age>=RECOVERY_TIMEOUT_TICKS-1);
    wire approved=job_finish && eligible;
    wire fault_now=!healthy || internal_fault;
    assign emergency_pending=(pending_left!=0);
    assign fault_status=(state==HOLD);
    assign acknowledge_idle=fault_ack && healthy && recovery_ok && !emergency_pending && !valid_active && (state==HOLD || state==NORMAL);
    wire [1:0] next_priority;
    priority_arbiter arb(.emergency((next_lease!=0) || (approved && next_state==HOLD)),
        .elevated(elevated_request),.caution(caution_request),.priority_level(next_priority));

    always @* begin
        next_state=state; next_lease=lease_left; next_pending=pending_left;
        next_clear_count=clear_count; next_recovery_count=recovery_count;
        next_recovery_age=recovery_age; next_clear_latched=clear_latched;
        if(tick) begin
            if(lease_left!=0) next_lease=lease_left-1'b1;
            if(pending_left!=0) next_pending=pending_left-1'b1;
        end
        if(valid_active) next_pending=LEASE_TICKS;
        if(valid_clear) next_pending=0;
        case(state)
            INIT: begin
                next_lease=0; next_clear_count=0; next_recovery_count=0;
                next_recovery_age=0; next_clear_latched=0;
                next_state=NORMAL;
            end
            NORMAL: if(job_start) next_state=EVALUATE;
            EVALUATE: begin
                if(valid_clear) next_state=NORMAL;
                else if(job_finish) begin
                    if(eligible) begin
                        if(gate_ok) begin next_state=OVERRIDE; next_lease=LEASE_TICKS; end
                        else next_state=HOLD;
                    end else next_state=NORMAL;
                end
            end
            OVERRIDE: begin
                if(!gate_ok) next_state=HOLD;
                else if(valid_clear) begin
                    next_state=CLEARANCE; next_lease=0; next_clear_latched=1;
                    next_clear_count=0; next_recovery_count=0; next_recovery_age=0;
                end else if(lease_expired || lease_left==0) next_state=HOLD;
                else if(approved) next_lease=LEASE_TICKS;
            end
            CLEARANCE: begin
                if(valid_active) begin next_clear_latched=0; next_clear_count=0; end
                if(valid_clear) begin next_clear_latched=1; next_clear_count=0; end
                if(tick) begin
                    next_recovery_age=recovery_age+1'b1;
                    if(clear_latched && !valid_active && !valid_clear) begin
                        if(clear_count>=CLEAR_TICKS-1) begin next_state=RECOVERY; next_recovery_count=0; end
                        else next_clear_count=clear_count+1'b1;
                    end
                end
                if(approved && !valid_clear) begin
                    if(gate_ok) begin next_state=OVERRIDE; next_lease=LEASE_TICKS; end
                    else next_state=HOLD;
                end
                if(recovery_timeout) next_state=HOLD;
            end
            RECOVERY: begin
                if(!recovery_ok || next_pending!=0 || valid_active || valid_clear) next_recovery_count=0;
                else if(tick) begin
                    if(recovery_count>=RECOVERY_TICKS-1) next_state=NORMAL;
                    else next_recovery_count=recovery_count+1'b1;
                end
                if(tick) next_recovery_age=recovery_age+1'b1;
                if(valid_clear) next_recovery_count=0;
                if(approved && !valid_clear) begin
                    if(gate_ok) begin next_state=OVERRIDE; next_lease=LEASE_TICKS; end
                    else next_state=HOLD;
                end
                if(recovery_timeout) next_state=HOLD;
            end
            HOLD: begin
                next_lease=0;
                if(acknowledge_idle) next_state=INIT;
            end
            default: next_state=HOLD;
        endcase
        // Reset is handled in the sequential block. Fault has highest runtime priority.
        if(fault_now) next_state=HOLD;
        if(next_state==HOLD) next_lease=0;
        if(next_state!=CLEARANCE && next_state!=RECOVERY) begin
            next_clear_count=0; next_recovery_count=0; next_recovery_age=0; next_clear_latched=0;
        end
    end
    always @(posedge clk) begin
        if(reset) begin
            state<=INIT; lease_left<=0; pending_left<=0; clear_count<=0;
            recovery_count<=0; recovery_age<=0; clear_latched<=0;
            override_enable<=0; action_code<=2'd3; priority_level<=0;
        end else begin
            state<=next_state; lease_left<=next_lease; pending_left<=next_pending;
            clear_count<=next_clear_count; recovery_count<=next_recovery_count;
            recovery_age<=next_recovery_age; clear_latched<=next_clear_latched;
            priority_level<=next_priority;
            override_enable<=(next_state==OVERRIDE) && gate_ok && next_lease!=0;
            if(next_state==OVERRIDE && gate_ok && next_lease!=0) action_code<=2'd2;
            else if(next_state==INIT || next_state==HOLD || next_state==CLEARANCE || next_state==RECOVERY || next_priority==2'd2) action_code<=2'd3;
            else if(next_priority==2'd1) action_code<=2'd1;
            else action_code<=2'd0;
        end
    end
endmodule
