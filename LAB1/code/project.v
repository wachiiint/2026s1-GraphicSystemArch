/*
 * Copyright (c) 2024 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_vga_example(
  input  wire [7:0] ui_in,    // Dedicated inputs
  output wire [7:0] uo_out,   // Dedicated outputs
  input  wire [7:0] uio_in,   // IOs: Input path
  output wire [7:0] uio_out,  // IOs: Output path
  output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
  input  wire       ena,      // always 1 when the design is powered, so you can ignore it
  input  wire       clk,      // clock
  input  wire       rst_n     // reset_n - low to reset
);
  wire inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_left, inp_right, inp_a, inp_x, inp_l, inp_r;

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
      .r(inp_r)
  );

  // VGA signals
  wire hsync;
  wire vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // TinyVGA PMOD
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;

  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [9:0] counter;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );
  localparam SIZE=50;
  localparam SPEED=8;
  localparam RESOLUTION_X = 640;
  localparam RESOLUTION_Y = 480;
  wire [9:0] moving_x = pix_x + counter;
  reg[9:0] pos_x, pos_y;
  wire box = (pix_x > pos_x-SIZE & pix_x < pos_x + SIZE) 
              & (pix_y > pos_y-SIZE & pix_y < pos_y + SIZE);
  wire circle = (pix_x - pos_x) * (pix_x - pos_x) + (pix_y - pos_y) * (pix_y - pos_y) < SIZE * SIZE; 
  always @(*) begin
    {R,G,B} = 6'b000000;
    if(circle) G = 2'b11;
  end
  always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      // counter <= 0;
      pos_x <= 100;
      pos_y <= 100;
    end else begin
      // counter <= counter + 1;
      if(inp_left) pos_x <= pos_x == 0 ? RESOLUTION_X : pos_x-SPEED;
      if(inp_right) pos_x <= pos_x >= RESOLUTION_X ? 0 : pos_x+SPEED;
      if(inp_up) pos_y <= pos_y == 0 ? RESOLUTION_Y : pos_y-SPEED;
      if(inp_down) pos_y <= pos_y >= RESOLUTION_Y ? 0 : pos_y+SPEED;
    end
  end

  // Suppress unused signals warning
  wire _unused_ok_ = &{moving_x, pix_y};

endmodule