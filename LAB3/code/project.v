/*
 * Copyright (c) 2024 Tiny Tapeout LTD
 * SPDX-License-Identifier: Apache-2.0
 * Author: Uri Shaked


 - Modified by Pongsgon Vichitvejpaisal to 
  load 320x240 6-bit color image
 */

`default_nettype none

/*
  VGA Display = 640*480
  img = 320*240 -> mem = 76800 line
  Therefore,
  IMG_SIZE = 320 -> "number of x pixel in 1 line"
  MUL_FACTOR = 640/320 = 2
  color(x,y) = img[ y/MUL_FACTOR * IMG_SIZE + pix_x / MUL_FACTOR ]
  assign mem_index = (pix_y / MUL_FACTOR) * IMG_SIZE + pix_x / MUL_FACTOR;  // read 6 bit at (y/2*320)
*/
parameter IMG_SIZE = 320;  // Size of the image in pixels
parameter MUL_FACTOR = 2;   // vga_res/img_size
parameter DISPLAY_WIDTH = 320;  // VGA display width
parameter DISPLAY_HEIGHT = 240;  // VGA display height

`define COLOR_WHITE 3'd7

module tt_um_vga_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7:1], uio_in};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // reg [5:0] img[76799:0];  // 320x240
  // wire [16:0] mem_index;
  reg [5:0] color;

  // initial begin
  //   $readmemh("../data/img.mem", img);
  //   // $readmemh("../data/bg1.mem", img2);
  // end

  // always @(posedge clk)begin
  //     color <= img[mem_index]+img2[mem_index];
  // end

  // assign color = img[mem_index];
  // assign mem_index = (pix_y / MUL_FACTOR) * IMG_SIZE + pix_x / MUL_FACTOR;  // read 6 bit at (y/2*320)

  reg [31:0] counter;
  reg [15:0] t;
  always @(posedge clk) begin
    if(~rst_n) counter <= 0;
    else counter <= counter + 1;
    t <= counter[23:8]; //offset
  end
  compute  #(
    .IMG_SIZE(IMG_SIZE),
    .MUL_FACTOR(MUL_FACTOR)
  ) _compute (
    .x(pix_x),
    .y(pix_y),
    .t(t),
    .rst_n(rst_n),
    .out(color)
  );
  
  
  //assign color = img[mem_index]+img2[mem_index];
  assign R = (video_active)? color[5:4]:0;
  assign G = (video_active)? color[3:2]:0;
  assign B = (video_active)? color[1:0]:0;



endmodule
