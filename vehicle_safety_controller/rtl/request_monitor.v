`timescale 1ns/1ps
// Observes all relevant frames, including those received while inference is busy.
module request_monitor #(
    parameter integer TICK_CYCLES=20000,
    parameter integer WINDOW_TICKS=100,
    parameter integer RATE_LIMIT=16,
    parameter integer DUP_LIMIT=4,
    parameter integer DUP_GAP_TICKS=100,
    parameter [10:0] EMERGENCY_ID=11'h120
)(
    input wire clk, reset, frame_valid,
    input wire [10:0] can_id,
    input wire [3:0] can_dlc,
    input wire [63:0] can_data,
    output wire tick,
    output wire [7:0] rate_now, duplicate_now, gap_now,
    output wire rate_bad, duplicate_bad
);
    function integer bits_for;
        input integer n;
        integer t;
        begin t=n-1; bits_for=1; while(t>1) begin bits_for=bits_for+1; t=t>>1; end end
    endfunction
    localparam integer TW=bits_for(TICK_CYCLES);
    localparam integer WW=bits_for(WINDOW_TICKS);
    reg [TW-1:0] divider;
    reg [WW-1:0] window_age;
    reg [7:0] rate_count, duplicate_count, gap_count;
    reg have_previous;
    reg [3:0] previous_dlc;
    reg [63:0] previous_data;
    wire relevant=frame_valid && (can_id==EMERGENCY_ID);
    assign tick=(divider==TICK_CYCLES-1);
    wire boundary=tick && (window_age==WINDOW_TICKS-1);
    wire [7:0] rate_base=boundary ? 8'd0 : rate_count;
    wire [7:0] gap_at_edge=(tick && gap_count!=8'hff) ? gap_count+8'd1 : gap_count;
    wire same_frame=have_previous && previous_dlc==can_dlc && previous_data==can_data;
    wire continue_run=same_frame && gap_at_edge<DUP_GAP_TICKS;
    assign rate_now=relevant ? ((rate_base==8'hff) ? 8'hff : rate_base+8'd1) : rate_base;
    assign duplicate_now=relevant ? (continue_run ? ((duplicate_count==8'hff) ? 8'hff : duplicate_count+8'd1) : 8'd1) : duplicate_count;
    assign gap_now=have_previous ? gap_at_edge : 8'hff;
    assign rate_bad=(rate_now>RATE_LIMIT);
    assign duplicate_bad=relevant && (duplicate_now>=DUP_LIMIT);
    always @(posedge clk) begin
        if(reset) begin
            divider<=0; window_age<=0; rate_count<=0; duplicate_count<=0;
            gap_count<=8'hff; have_previous<=0; previous_dlc<=0; previous_data<=0;
        end else begin
            if(tick) begin
                divider<=0;
                if(boundary) window_age<=0; else window_age<=window_age+1'b1;
            end else divider<=divider+1'b1;
            rate_count<=rate_now;
            if(relevant) begin
                duplicate_count<=duplicate_now; gap_count<=0; have_previous<=1;
                previous_dlc<=can_dlc; previous_data<=can_data;
            end else gap_count<=gap_at_edge;
        end
    end
endmodule
