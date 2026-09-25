`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 25.09.2026 14:17:01
// Design Name: 
// Module Name: audio_loopback
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


module audio_loopback(
    // RX output
    input  wire [31:0] rx_tdata,
    input  wire [2:0]  rx_tid,
    input  wire        rx_tvalid,
    output wire        rx_tready,

    // TX input
    output wire [31:0] tx_tdata,
    output wire [2:0]  tx_tid,
    output wire        tx_tvalid,
    input  wire        tx_tready
);
    assign tx_tdata  = rx_tdata;
    assign tx_tid    = rx_tid;
    assign tx_tvalid = rx_tvalid;

    assign rx_tready = tx_tready;
endmodule
