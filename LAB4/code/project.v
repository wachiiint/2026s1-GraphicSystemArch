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

  parameter IMG_SIZE = 457;  // Source image width: img.mem words / 240
  parameter MUL_FACTOR = 2;   // vga_res/img_size
  parameter DISPLAY_HEIGHT = 240;  // VGA display height

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;
  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7], ui_in[4:0], uio_in,
      inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_a, inp_x, inp_l, inp_r};

  // TinyVGA PMOD
  assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(hsync),
      .vsync(vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // Gamepad Pmod
  wire inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_left, inp_right, inp_a, inp_x, inp_l, inp_r;

  wire unused_is_present;
  gamepad_pmod_single driver (
      // Inputs:
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(ui_in[6]),
      .pmod_clk(ui_in[5]),
      .pmod_latch(ui_in[4]),
      // Outputs:
      .b(inp_b),
      .y(inp_y),
      .select(inp_select),
      .start(inp_start),
      .up(inp_up),
      .down(inp_down),
      .left(inp_left),
      .right(inp_right),
      .a(inp_a),
      .x(inp_x),
      .l(inp_l),
      .r(inp_r),
      .is_present(unused_is_present)
  );
  
  wire clean_inp_left, clean_inp_right;
  debounce ll_debounce (.clk(clk), .in(inp_left), .out(clean_inp_left));
  debounce rr_debounce (.clk(clk), .in(inp_right), .out(clean_inp_right));


  reg [5:0] color;
  bg_render  #(
    .IMG_SIZE(IMG_SIZE),
    .MUL_FACTOR(MUL_FACTOR),
    .DISPLAY_HEIGHT(DISPLAY_HEIGHT)
  ) rend1 (
    .xin(pix_x),
    .yin(pix_y),
    .clk(clk),
    .inp_l(clean_inp_left),
    .inp_r(clean_inp_right),
    .vsync(vsync),
    .rst_n(rst_n),
    .out(color)
  );
  
  //assign color = img[mem_index]+img2[mem_index];
  assign R = (video_active)? color[5:4]:0;
  assign G = (video_active)? color[3:2]:0;
  assign B = (video_active)? color[1:0]:0;



endmodule
