`timescale 1ns/1ps
module can_feature_extractor #(parameter [10:0] EMERGENCY_ID=11'h120)(
    input wire frame_valid,
    input wire [10:0] can_id,
    input wire [3:0] can_dlc,
    input wire [63:0] can_data,
    input wire format_ok, crc_ok, upstream_valid,
    input wire [7:0] rate_now, duplicate_now, gap_now,
    output wire [63:0] features,
    output wire valid_active, valid_clear, deterministic_ok
);
    wire allowed=(can_id==EMERGENCY_ID);
    wire payload_ok=(can_data[63:16]==48'd0) && (can_data[7:2]==6'd0) && (can_data[1:0]!=2'b11);
    wire frame_ok=format_ok && crc_ok && (can_dlc==4'd2) && payload_ok;
    assign deterministic_ok=allowed && frame_ok && upstream_valid;
    assign valid_active=frame_valid && deterministic_ok && can_data[0];
    assign valid_clear=frame_valid && deterministic_ok && can_data[1];
    // Explicit widening/saturation avoids multiply truncation.
    wire [7:0] rate_feature=(rate_now>=8'd32) ? 8'd127 : {rate_now[5:0],2'b00};
    wire [7:0] dup_feature=(duplicate_now>=8'd5) ? 8'd127 : ((duplicate_now<=8'd1) ? 8'd0 : ((duplicate_now-8'd1)<<5));
    assign features[7:0]=can_data[0] ? 8'd127 : 8'd0;
    assign features[15:8]=allowed ? 8'd127 : 8'd0;
    assign features[23:16]=frame_ok ? 8'd127 : 8'd0;
    assign features[31:24]=allowed ? rate_feature : 8'd0;
    assign features[39:32]=(!allowed || gap_now>8'd127) ? 8'd127 : gap_now;
    assign features[47:40]=allowed ? dup_feature : 8'd0;
    assign features[55:48]=payload_ok ? 8'd127 : 8'd0;
    assign features[63:56]=upstream_valid ? 8'd127 : 8'd0;
endmodule
