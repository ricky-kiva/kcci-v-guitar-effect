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
// Clock & I2S State Registers
// ---------------------------------------------------------
reg [1:0] clk_div;
reg [5:0] bit_count;

// ADC receive shift registers
reg [23:0] rx_left_shift;
reg [23:0] rx_right_shift;

// Completed ADC raw samples
reg [23:0] left_sample;
reg [23:0] right_sample;

// DAC transmit shift register
reg [23:0] tx_shift;

// ---------------------------------------------------------
// FX MODULE INTEGRATION
// ---------------------------------------------------------
wire [23:0] fx_left_out;
wire [23:0] fx_right_out;

// Pulse sample_tick for exactly 1 system clock cycle when both 
// Left and Right samples have been fully captured from the ADC (Bit 56)
wire sample_tick = (clk_div == 2'd1) && (codec_bclk == 1'b0) && (bit_count == 6'd56);

// Instantiate Gated Fuzz for the Left Channel
gated_fuzz fx_left (
    .clk         (clk_12m288),
    .reset_n     (reset_n),
    .sample_tick (sample_tick),
    .audio_in    (left_sample),
    .audio_out   (fx_left_out)
);

// Instantiate Gated Fuzz for the Right Channel
gated_fuzz fx_right (
    .clk         (clk_12m288),
    .reset_n     (reset_n),
    .sample_tick (sample_tick),
    .audio_in    (right_sample),
    .audio_out   (fx_right_out)
);

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

        if (clk_div == 2'd1) begin
            clk_div <= 2'd0;

            // =============================================
            // BCLK RISING EDGE (Sample incoming ADC data)
            // =============================================
            if (codec_bclk == 1'b0) begin
                codec_bclk <= 1'b1;

                // Shift in LEFT channel bits
                if ((bit_count >= 6'd1) && (bit_count <= 6'd24)) begin
                    rx_left_shift <= {rx_left_shift[22:0], codec_recdat};
                end

                // Shift in RIGHT channel bits
                if ((bit_count >= 6'd33) && (bit_count <= 6'd56)) begin
                    rx_right_shift <= {rx_right_shift[22:0], codec_recdat};
                end

                // Latch complete LEFT sample
                if (bit_count == 6'd24) begin
                    left_sample <= {rx_left_shift[22:0], codec_recdat};
                end

                // Latch complete RIGHT sample
                if (bit_count == 6'd56) begin
                    right_sample <= {rx_right_shift[22:0], codec_recdat};
                end

                // Frame bit counter increment
                if (bit_count == 6'd63)
                    bit_count <= 6'd0;
                else
                    bit_count <= bit_count + 6'd1;
            end

            // =============================================
            // BCLK FALLING EDGE (Drive outgoing DAC data)
            // =============================================
            else begin
                codec_bclk <= 1'b0;

                // -----------------------------------------
                // LRCLK Framing (50% Duty Cycle)
                // -----------------------------------------
                if (bit_count == 6'd63) begin
                    codec_reclrc <= 1'b0;
                    codec_pblrc  <= 1'b0;
                    codec_pbdat  <= 1'b0;
                end
                else if (bit_count == 6'd31) begin
                    codec_reclrc <= 1'b1;
                    codec_pblrc  <= 1'b1;
                    codec_pbdat  <= 1'b0;
                end

                // -----------------------------------------
                // LEFT CHANNEL TRANSMIT (Bits 0 to 23)
                // -----------------------------------------
                else if (bit_count == 6'd0) begin
                    // Transmit processed FX output instead of raw sample
                    codec_pbdat <= fx_left_out[23];
                    tx_shift    <= {fx_left_out[22:0], 1'b0};
                end
                else if ((bit_count >= 6'd1) && (bit_count <= 6'd23)) begin
                    codec_pbdat <= tx_shift[23];
                    tx_shift    <= {tx_shift[22:0], 1'b0};
                end

                // -----------------------------------------
                // RIGHT CHANNEL TRANSMIT (Bits 32 to 55)
                // -----------------------------------------
                else if (bit_count == 6'd32) begin
                    // Transmit processed FX output instead of raw sample
                    codec_pbdat <= fx_right_out[23];
                    tx_shift    <= {fx_right_out[22:0], 1'b0};
                end
                else if ((bit_count >= 6'd33) && (bit_count <= 6'd55)) begin
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

        // Unmute codec
        codec_mute <= 1'b1;
    end
end
endmodule