`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: KCCI
// Engineer: Ricky Fadel M
// 
// Create Date: 25.09.2026 18:31:52
// Design Name: 
// Module Name: gated_fuzz
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module gated_fuzz (
    input  wire        clk,          // 12.288 MHz system clock
    input  wire        reset_n,      // Active-low reset
    input  wire        sample_tick,  // 1-clock-cycle pulse at 48 kHz
    input  wire [23:0] audio_in,     // Raw ADC sample
    output reg  [23:0] audio_out     // Processed DAC sample
);

    // =========================================================
    // PARAMETERS
    // =========================================================
    // Noise floor threshold (Adjust if gate is too sensitive/insensitive)
    // 24'h00FFFF is roughly 0.7% of full scale
    localparam [23:0] THRESHOLD = 24'h00FFFF;
    
    // Hold time before closing gate (4800 samples @ 48kHz = 100ms)
    localparam [15:0] HOLD_MAX  = 16'd4800;

    // FSM States
    localparam [1:0] ST_CLOSED = 2'b00,
                     ST_OPEN   = 2'b01,
                     ST_HOLD   = 2'b10;

    // =========================================================
    // CIRCUIT 1: COMBINATIONAL (Arithmetic & Logic)
    // =========================================================
    reg [23:0] abs_val;
    reg        over_threshold;
    reg signed [26:0] extended_in;
    reg signed [26:0] amplified;
    reg [23:0] fuzz_out;

    always @(*) begin
        // 1A. Rectifier (Absolute Value)
        if (audio_in[23]) 
            abs_val = -audio_in;
        else 
            abs_val = audio_in;

        // 1B. Comparator
        over_threshold = (abs_val > THRESHOLD);

        // 1C. Hard Fuzz (8x Gain + Saturation/Clipping)
        // Sign-extend to 27 bits to prevent intermediate overflow
        extended_in = $signed({{3{audio_in[23]}}, audio_in});
        amplified   = extended_in <<< 3; // 8x Gain

        // Clamp to 24-bit min/max bounds if clipped
        if (amplified > 27'sd8388607)
            fuzz_out = 24'h7FFFFF;
        else if (amplified < -27'sd8388608)
            fuzz_out = 24'h800000;
        else
            fuzz_out = amplified[23:0];
    end

    // =========================================================
    // CIRCUIT 2: FINITE STATE MACHINE (Next State Logic)
    // =========================================================
    reg [1:0] state, next_state;
    reg [15:0] hold_timer;

    always @(*) begin
        next_state = state; // Default to stay in current state
        
        case (state)
            ST_CLOSED: begin
                if (over_threshold)
                    next_state = ST_OPEN;
            end
            
            ST_OPEN: begin
                if (!over_threshold)
                    next_state = ST_HOLD;
            end
            
            ST_HOLD: begin
                if (over_threshold)
                    next_state = ST_OPEN;
                else if (hold_timer >= HOLD_MAX)
                    next_state = ST_CLOSED;
            end
            
            default: next_state = ST_CLOSED;
        endcase
    end

    // =========================================================
    // CIRCUIT 3: SEQUENTIAL (Registers & Counters)
    // =========================================================
    always @(posedge clk) begin
        if (!reset_n) begin
            state      <= ST_CLOSED;
            hold_timer <= 16'd0;
            audio_out  <= 24'd0;
        end
        else if (sample_tick) begin
            // Advance FSM state
            state <= next_state;

            // Manage Hold Timer Counter
            if (state == ST_HOLD && !over_threshold)
                hold_timer <= hold_timer + 16'd1;
            else
                hold_timer <= 16'd0;

            // Output Multiplexer based on state
            if (state == ST_CLOSED)
                audio_out <= 24'd0;       // Dead silence
            else
                audio_out <= fuzz_out;    // Passing distorted guitar tone
        end
    end

endmodule
