`timescale 1ns/1ps
module vehicle_safety_top #(
    parameter integer TICK_CYCLES=20000, WINDOW_TICKS=100, RATE_LIMIT=16,
    DUP_LIMIT=4, DUP_GAP_TICKS=100, LEASE_TICKS=500, CLEAR_TICKS=20,
    RECOVERY_TICKS=50, RECOVERY_TIMEOUT_TICKS=1000,
    WATCHDOG_CYCLES=256, USE_MONITOR=1, USE_MLP=0,
    parameter [10:0] EMERGENCY_ID=11'h120
)(
    input wire clk, reset, can_frame_valid,
    input wire [10:0] can_id,
    input wire [3:0] can_dlc,
    input wire [63:0] can_data,
    input wire can_format_ok, can_crc_ok, upstream_request_valid,
    input wire sensor_valid, safe_to_act, safety_conflict,
    input wire caution_request, elevated_request, recovery_ok, fault_ack,
    output reg classifier_busy, decision_valid,
    output reg [2:0] decision_code,
    output wire [1:0] priority_level, action_code,
    output wire override_enable, emergency_pending, fault_status,
    output reg suspicious_traffic, uncertain_status, overrun_status,
    output wire [2:0] fsm_state
);
    wire tick, rate_bad, duplicate_bad;
    wire [7:0] rate_now, duplicate_now, gap_now;
    request_monitor #(.TICK_CYCLES(TICK_CYCLES),.WINDOW_TICKS(WINDOW_TICKS),
        .RATE_LIMIT(RATE_LIMIT),.DUP_LIMIT(DUP_LIMIT),.DUP_GAP_TICKS(DUP_GAP_TICKS),.EMERGENCY_ID(EMERGENCY_ID)) monitor(
        .clk(clk),.reset(reset),.frame_valid(can_frame_valid),.can_id(can_id),.can_dlc(can_dlc),.can_data(can_data),
        .tick(tick),.rate_now(rate_now),.duplicate_now(duplicate_now),.gap_now(gap_now),.rate_bad(rate_bad),.duplicate_bad(duplicate_bad));
    wire [63:0] features;
    wire valid_active, valid_clear, deterministic_ok;
    can_feature_extractor #(.EMERGENCY_ID(EMERGENCY_ID)) extractor(
        .frame_valid(can_frame_valid),.can_id(can_id),.can_dlc(can_dlc),.can_data(can_data),
        .format_ok(can_format_ok),.crc_ok(can_crc_ok),.upstream_valid(upstream_request_valid),
        .rate_now(rate_now),.duplicate_now(duplicate_now),.gap_now(gap_now),.features(features),
        .valid_active(valid_active),.valid_clear(valid_clear),.deterministic_ok(deterministic_ok));

    reg captured_requested, captured_ok, captured_monitor_bad, cancelled;
    reg [15:0] age_cycles, age_ticks;
    wire can_capture=(fsm_state!=3'd0 && fsm_state!=3'd6 && fsm_state!=3'd7);
    wire job_start=can_frame_valid && !classifier_busy && can_capture;
    wire mlp_done, mlp_busy, mlp_confident, model_valid;
    wire [1:0] mlp_class;
    wire [24:0] mlp_margin, model_margin;
    wire [6:0] weight_address;
    wire [3:0] bias_address;
    wire signed [7:0] weight_data;
    wire signed [23:0] bias_data, score0, score1, score2;
    wire timeout=classifier_busy && (age_cycles>=WATCHDOG_CYCLES-1);
    wire job_finish=classifier_busy && ((!USE_MLP) || mlp_done || timeout || fsm_state==3'd6);
    wire model_error=USE_MLP && !model_valid;
    wire job_error=timeout || model_error;
    wire job_cancelled=cancelled || valid_clear || fsm_state==3'd6 ||
        !sensor_valid || safety_conflict || age_ticks>=LEASE_TICKS ||
        (tick && age_ticks>=LEASE_TICKS-1);
    wire eligible;
    wire [2:0] policy_code;
    wire acknowledge_idle;
    generate if(USE_MLP) begin: neural
        mlp_parameter_rom rom(.weight_address(weight_address),.bias_address(bias_address),
            .weight_data(weight_data),.bias_data(bias_data),.model_valid(model_valid),.margin_min(model_margin));
        // Runtime ROM margin is compared in the adapter; core computes a positive-margin result.
        wire core_confident;
        mlp_inference #(.MARGIN_MIN(25'd1)) core(.clk(clk),.reset(reset || fsm_state==3'd6 || timeout),
            .start(job_start),.features(features),.busy(mlp_busy),.done(mlp_done),
            .weight_address(weight_address),.weight_data(weight_data),.bias_address(bias_address),.bias_data(bias_data),
            .score0(score0),.score1(score1),.score2(score2),.class_id(mlp_class),
            .confident(core_confident),.score_margin(mlp_margin));
        assign mlp_confident=core_confident && mlp_margin>=model_margin;
    end else begin: baseline
        assign mlp_done=1'b0; assign mlp_busy=1'b0;
        assign mlp_confident=1'b1; assign mlp_class=2'd1; assign model_valid=1'b1;
        assign mlp_margin=0; assign model_margin=1;
        assign weight_address=0; assign bias_address=0; assign weight_data=0; assign bias_data=0;
        assign score0=0; assign score1=0; assign score2=0;
    end endgenerate
    request_policy_validator #(.USE_MONITOR(USE_MONITOR),.USE_MLP(USE_MLP)) validator(
        .requested(captured_requested),.deterministic_ok(captured_ok),
        .monitor_bad(captured_monitor_bad || rate_bad),.mlp_class(mlp_class),.mlp_confident(mlp_confident),
        .cancelled(job_cancelled),.internal_error(job_error),.eligible(eligible),.code(policy_code));
    emergency_fsm #(.LEASE_TICKS(LEASE_TICKS),.CLEAR_TICKS(CLEAR_TICKS),.RECOVERY_TICKS(RECOVERY_TICKS),
        .RECOVERY_TIMEOUT_TICKS(RECOVERY_TIMEOUT_TICKS)) control(
        .clk(clk),.reset(reset),.tick(tick),.job_start(job_start),.job_finish(job_finish),
        .eligible(eligible),.internal_fault(timeout || model_error),.valid_active(valid_active),.valid_clear(valid_clear),
        .sensor_valid(sensor_valid),.safe_to_act(safe_to_act),.safety_conflict(safety_conflict),
        .caution_request(caution_request),.elevated_request(elevated_request),.recovery_ok(recovery_ok),.fault_ack(fault_ack),
        .state(fsm_state),.override_enable(override_enable),.action_code(action_code),.priority_level(priority_level),
        .emergency_pending(emergency_pending),.fault_status(fault_status),.acknowledge_idle(acknowledge_idle));
    always @(posedge clk) begin
        if(reset) begin
            classifier_busy<=0; decision_valid<=0; decision_code<=0;
            captured_requested<=0; captured_ok<=0; captured_monitor_bad<=0; cancelled<=0;
            age_cycles<=0; age_ticks<=0; suspicious_traffic<=0; uncertain_status<=0; overrun_status<=0;
        end else begin
            decision_valid<=0;
            if(acknowledge_idle) begin suspicious_traffic<=0; uncertain_status<=0; overrun_status<=0; end
            if(can_frame_valid && classifier_busy) overrun_status<=1;
            if(job_start) begin
                classifier_busy<=1; captured_requested<=can_data[0]; captured_ok<=deterministic_ok;
                captured_monitor_bad<=rate_bad || duplicate_bad; cancelled<=0;
                age_cycles<=0; age_ticks<=0;
            end else if(classifier_busy) begin
                if(age_cycles!=16'hffff) age_cycles<=age_cycles+1'b1;
                if(tick && age_ticks!=16'hffff) age_ticks<=age_ticks+1'b1;
                if(valid_clear) cancelled<=1;
                if(job_finish) begin
                    classifier_busy<=0; decision_valid<=1; decision_code<=policy_code;
                    if(policy_code==3'd3) suspicious_traffic<=1;
                    if(policy_code==3'd4) uncertain_status<=1;
                end
            end
        end
    end
endmodule
