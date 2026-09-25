`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: i2s_codec_loopback
// Description: Clean 24-bit I2S audio loopback for SSM2603 codec (Zybo Z7-10)
//              Fixed LRCLK framing (50% duty cycle) and removed hard-clipping gain.
//////////////////////////////////////////////////////////////////////////////////
module i2s_codec_loopback (
    input  wire clk_12m288,
    input  wire reset_n,
    // SSM2603
    input  wire codec_recdat,

    output reg codec_bclk,
    output reg codec_reclrc,
    output reg codec_pblrc,
    output reg codec_pbdat,
    output reg codec_mute
);

// ---------------------------------------------------------
// BCLK generation
// 12.288 MHz / 4 = 3.072 MHz BCLK
// 3.072 MHz / 64 = 48 kHz sample rate
// ---------------------------------------------------------

reg [1:0] clk_div;

// Position within 64-bit I2S frame
reg [5:0] bit_count;

// ADC receive shift registers
reg [23:0] rx_left_shift;
reg [23:0] rx_right_shift;

// Completed ADC samples
reg [23:0] left_sample;
reg [23:0] right_sample;

// DAC transmit shift register
reg [23:0] tx_shift;

// [MODIFIED] Removed 'function gain_x2_sat' to eliminate digital fuzz/clipping.
// Audio samples are passed linearly to preserve full dynamic range.

// ---------------------------------------------------------
// Main I2S logic
// ---------------------------------------------------------

always @(posedge clk_12m288) begin

    if (!reset_n) begin
        clk_div        <= 2'd0;

        codec_bclk     <= 1'b0;
        codec_reclrc   <= 1'b0;
        codec_pblrc    <= 1'b0;

        codec_pbdat    <= 1'b0;
        codec_mute     <= 1'b0;

        bit_count      <= 6'd0;

        rx_left_shift  <= 24'd0;
        rx_right_shift <= 24'd0;

        left_sample    <= 24'd0;
        right_sample   <= 24'd0;

        tx_shift       <= 24'd0;
    end
    else begin

        // -------------------------------------------------
        // Generate BCLK
        // -------------------------------------------------
        if (clk_div == 2'd1) begin
            clk_div <= 2'd0;

            // =============================================
            // BCLK RISING EDGE (Sample incoming ADC data)
            // =============================================
            if (codec_bclk == 1'b0) begin
                codec_bclk <= 1'b1;

                // -----------------------------------------
                // LEFT ADC shift
                // -----------------------------------------
                if ((bit_count >= 6'd1) && (bit_count <= 6'd24)) begin
                    rx_left_shift <= {rx_left_shift[22:0], codec_recdat};
                end

                // -----------------------------------------
                // RIGHT ADC shift
                // -----------------------------------------
                if ((bit_count >= 6'd33) && (bit_count <= 6'd56)) begin
                    rx_right_shift <= {rx_right_shift[22:0], codec_recdat};
                end

                // -----------------------------------------
                // Complete LEFT sample
                // -----------------------------------------
                if (bit_count == 6'd24) begin
                    // [MODIFIED] Direct unclipped sample passthrough (removed gain_x2_sat)
                    left_sample <= {rx_left_shift[22:0], codec_recdat};
                end

                // -----------------------------------------
                // Complete RIGHT sample
                // -----------------------------------------
                if (bit_count == 6'd56) begin
                    // [MODIFIED] Direct unclipped sample passthrough (removed gain_x2_sat)
                    right_sample <= {rx_right_shift[22:0], codec_recdat};
                end

                // Frame bit counter increment
                if (bit_count == 6'd63)
                    bit_count <= 6'd0;
                else
                    bit_count <= bit_count + 6'd1;

            end

            // =============================================
            // BCLK FALLING EDGE (Drive outgoing DAC data & LRCLK)
            // =============================================
            else begin
                codec_bclk <= 1'b0;

                // -----------------------------------------
                // LRCLK Framing (50% Duty Cycle)
                // In standard Philips I2S:
                // - LRCLK = 0 for Left channel (bits 0 to 31)
                // - LRCLK = 1 for Right channel (bits 32 to 63)
                // Transition occurs 1 BCLK before the data MSB.
                // -----------------------------------------
                if (bit_count == 6'd63) begin
                    // [MODIFIED] Assert LOW 1 cycle prior to Left channel data (bit 0)
                    codec_reclrc <= 1'b0;
                    codec_pblrc  <= 1'b0;
                    codec_pbdat  <= 1'b0;
                end
                else if (bit_count == 6'd31) begin
                    // [MODIFIED] Added missing HIGH transition 1 cycle prior to Right channel data (bit 32)
                    codec_reclrc <= 1'b1;
                    codec_pblrc  <= 1'b1;
                    codec_pbdat  <= 1'b0;
                end

                // -----------------------------------------
                // LEFT CHANNEL TRANSMIT (Bits 0 to 23)
                // -----------------------------------------
                else if (bit_count == 6'd0) begin
                    codec_pbdat <= left_sample[23];
                    // [MODIFIED] Pre-shift lower 23 bits to eliminate index off-by-one errors
                    tx_shift    <= {left_sample[22:0], 1'b0};
                end
                else if ((bit_count >= 6'd1) && (bit_count <= 6'd23)) begin
                    // [MODIFIED] Consolidated range and aligned to MSB of shift register
                    codec_pbdat <= tx_shift[23];
                    tx_shift    <= {tx_shift[22:0], 1'b0};
                end

                // -----------------------------------------
                // RIGHT CHANNEL TRANSMIT (Bits 32 to 55)
                // -----------------------------------------
                else if (bit_count == 6'd32) begin
                    codec_pbdat <= right_sample[23];
                    // [MODIFIED] Pre-shift lower 23 bits
                    tx_shift    <= {right_sample[22:0], 1'b0};
                end
                else if ((bit_count >= 6'd33) && (bit_count <= 6'd55)) begin
                    // [MODIFIED] Consolidated range and aligned to MSB of shift register
                    codec_pbdat <= tx_shift[23];
                    tx_shift    <= {tx_shift[22:0], 1'b0};
                end

                // -----------------------------------------
                // Unused/Padding bits (24..30 and 56..62)
                // -----------------------------------------
                else begin
                    codec_pbdat <= 1'b0;
                end

            end

        end
        else begin
            clk_div <= clk_div + 2'd1;
        end

        // -------------------------------------------------
        // Unmute codec (Active High for SSM2603 mute signal)
        // -------------------------------------------------
        codec_mute <= 1'b1;

    end
end

endmodule