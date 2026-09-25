`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.09.2026 15:27:29
// Design Name: 
// Module Name: i2s_codec_loopback
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
    //
    // 12.288 MHz / 4 = 3.072 MHz
    // 3.072 MHz / 64 = 48 kHz
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


    // ---------------------------------------------------------
    // Signed ×2 with saturation
    //
    // 24-bit signed range:
    //
    //   -8388608 ... +8388607
    //
    // We temporarily use 25 bits for the multiplication.
    // ---------------------------------------------------------

    function [23:0] gain_x2_sat;
        input [23:0] sample;

        reg signed [24:0] temp;

        begin

            temp = $signed({sample[23], sample}) <<< 1;

            if (temp > 25'sd8388607)
                gain_x2_sat = 24'h7FFFFF;

            else if (temp < -25'sd8388608)
                gain_x2_sat = 24'h800000;

            else
                gain_x2_sat = temp[23:0];

        end
    endfunction


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
                // BCLK RISING EDGE
                // =============================================

                if (codec_bclk == 1'b0) begin

                    codec_bclk <= 1'b1;


                    // -----------------------------------------
                    // LEFT ADC
                    // -----------------------------------------

                    if ((bit_count >= 6'd1) &&
                        (bit_count <= 6'd24)) begin

                        rx_left_shift <= {
                            rx_left_shift[22:0],
                            codec_recdat
                        };

                    end


                    // -----------------------------------------
                    // RIGHT ADC
                    // -----------------------------------------

                    if ((bit_count >= 6'd33) &&
                        (bit_count <= 6'd56)) begin

                        rx_right_shift <= {
                            rx_right_shift[22:0],
                            codec_recdat
                        };

                    end


                    // -----------------------------------------
                    // Complete LEFT sample
                    // -----------------------------------------

                    if (bit_count == 6'd24) begin

                        left_sample <= gain_x2_sat(
                            {
                                rx_left_shift[22:0],
                                codec_recdat
                            }
                        );

                    end


                    // -----------------------------------------
                    // Complete RIGHT sample
                    // -----------------------------------------

                    if (bit_count == 6'd56) begin

                        right_sample <= gain_x2_sat(
                            {
                                rx_right_shift[22:0],
                                codec_recdat
                            }
                        );

                    end


                    // Next bit
                    if (bit_count == 6'd63)
                        bit_count <= 6'd0;
                    else
                        bit_count <= bit_count + 6'd1;

                end


                // =============================================
                // BCLK FALLING EDGE
                // =============================================

                else begin

                    codec_bclk <= 1'b0;


                    // -----------------------------------------
                    // Frame boundary
                    // -----------------------------------------

                    if (bit_count == 6'd63) begin

                        codec_reclrc <= 1'b1;
                        codec_pblrc  <= 1'b1;

                        codec_pbdat  <= 1'b0;

                    end


                    // -----------------------------------------
                    // LEFT CHANNEL
                    // -----------------------------------------

                    else if (bit_count == 6'd0) begin

                        codec_reclrc <= 1'b0;
                        codec_pblrc  <= 1'b0;

                        tx_shift <= left_sample;

                        codec_pbdat <= left_sample[23];

                    end


                    else if ((bit_count >= 6'd1) &&
                             (bit_count <= 6'd22)) begin

                        codec_pbdat <= tx_shift[22];

                        tx_shift <= {
                            tx_shift[22:0],
                            1'b0
                        };

                    end


                    else if (bit_count == 6'd23) begin

                        codec_pbdat <= tx_shift[22];

                        tx_shift <= {
                            tx_shift[22:0],
                            1'b0
                        };

                    end


                    // -----------------------------------------
                    // RIGHT CHANNEL
                    // -----------------------------------------

                    else if (bit_count == 6'd32) begin

                        tx_shift <= right_sample;

                        codec_pbdat <= right_sample[23];

                    end


                    else if ((bit_count >= 6'd33) &&
                             (bit_count <= 6'd54)) begin

                        codec_pbdat <= tx_shift[22];

                        tx_shift <= {
                            tx_shift[22:0],
                            1'b0
                        };

                    end


                    else if (bit_count == 6'd55) begin

                        codec_pbdat <= tx_shift[22];

                        tx_shift <= {
                            tx_shift[22:0],
                            1'b0
                        };

                    end


                    else begin

                        codec_pbdat <= 1'b0;

                    end

                end

            end

            else begin

                clk_div <= clk_div + 2'd1;

            end


            // -------------------------------------------------
            // Unmute codec
            // -------------------------------------------------

            codec_mute <= 1'b1;

        end
    end

endmodule