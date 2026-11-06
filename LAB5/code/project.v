/*
 * Copyright (c) 2025 Uri Shaked
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

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

  // Unused outputs assigned to 0.
  assign uio_out = 0;
  assign uio_oe  = 0;
  // Suppress unused signals warning
  wire _unused_ok = &{ena, ui_in[7], ui_in[4:0], uio_in};

  // VGA signals
  reg hsync;
  reg vsync;
  wire raw_hsync;
  wire raw_vsync;
  reg [1:0] R;
  reg [1:0] G;
  reg [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;

  // Tiny VGA Pmod
  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
  hvsync_generator vga_sync_gen (
      .clk(clk),
      .reset(~rst_n),
      .hsync(raw_hsync),
      .vsync(raw_vsync),
      .display_on(video_active),
      .hpos(pix_x),
      .vpos(pix_y)
  );

  // Gamepad Pmod
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


  ////// debounce //////
  reg clean_inp_a, clean_inp_b, clean_inp_l, clean_inp_r, clean_inp_x, clean_inp_y;
  reg clean_inp_up, clean_inp_down, clean_inp_left, clean_inp_right;
  debounce a_debounce (.clk(clk), .in(inp_a), .out(clean_inp_a));
  debounce b_debounce (.clk(clk), .in(inp_b), .out(clean_inp_b));
  debounce x_debounce (.clk(clk), .in(inp_x), .out(clean_inp_x));
  debounce y_debounce (.clk(clk), .in(inp_y), .out(clean_inp_y));
  debounce uu_debounce (.clk(clk), .in(inp_up), .out(clean_inp_up));
  debounce dd_debounce (.clk(clk), .in(inp_down), .out(clean_inp_down));
  debounce ll_debounce (.clk(clk), .in(inp_left), .out(clean_inp_left));
  debounce rr_debounce (.clk(clk), .in(inp_right), .out(clean_inp_right));
  debounce l_debounce (.clk(clk), .in(inp_l), .out(clean_inp_l)); 
  debounce r_debounce (.clk(clk), .in(inp_r), .out(clean_inp_r));
  //////////////////////////

  // Both layers use 16 pixels per row, each {opaque, R[1:0], G[1:0], B[1:0]}.
  reg [111:0] tile_ram [0:703];
  reg [111:0] background_rom [0:703];
  wire [5:0] tile_id;
  reg [3:0] tile_row;
  wire [9:0] tile_addr = {(tile_id == 6'd63 ? 6'd0 : tile_id), tile_row};
  reg foreground_present;
  reg [111:0] tile_ram_output;
  reg [111:0] background_rom_output;
  wire [9:0] background_addr = {6'd39, tile_row}; // Blue background tile.

  initial $readmemh("../data/tiny_tropical_tiles.mem", tile_ram);
  initial $readmemh("../data/tiny_tropical_tiles.mem", background_rom);

  reg [3:0] tile_col, prev_tile_col;
  reg prev_video_active, prevprev_video_active;

  reg [9:0] x_offset;
  wire [10:0] world_pix_x = {1'b0, pix_x} + {1'b0, x_offset}; // add one more bit to prevent not enough bit
  wire [9:0] map_addr = {world_pix_x[10:5], pix_y[8:5]}; // change block every 32 pixel

  map_rom map_rom_inst (
    .clk(clk),
    .vsync(vsync),
    .addr(map_addr),
    .data(tile_id)
  );

  always @(posedge clk) begin
    // Map ROM takes one clock; tile RAM takes the next.
    tile_row <= pix_y[4:1];
    tile_col <= world_pix_x[4:1];
    prev_tile_col <= tile_col;
    tile_ram_output <= tile_ram[tile_addr];
    foreground_present <= tile_id != 6'd63;
    background_rom_output <= background_rom[background_addr];
  end

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      prev_video_active <= 1'b0;
      prevprev_video_active <= 1'b0;

    end else begin
      prev_video_active <= video_active;
      prevprev_video_active <= prev_video_active;
      hsync <= raw_hsync;
      vsync <= raw_vsync;
    end
  end

  reg [9:0] counter;
  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      counter <= 10'd0;
      x_offset <= 10'd0;
    end else begin
      counter <= counter + 10'd1;
      if (counter[0] == 10'b0) begin
        if (inp_left && x_offset > 10'd0)
          x_offset <= x_offset - 10'd5;
        else if (inp_right && x_offset < 10'd1023)
          x_offset <= x_offset + 10'd5;
      end
    end
  end


  wire [6:0] pixel_shift = (7'd15 - {3'd0, prev_tile_col}) * 7'd7;
  wire [6:0] foreground_pixel = tile_ram_output[pixel_shift+:7];
  wire [6:0] background_pixel = background_rom_output[pixel_shift+:7];
  wire [5:0] layered_color = (foreground_present && foreground_pixel[6]) ? foreground_pixel[5:0] :
                             background_pixel[6] ? background_pixel[5:0] : 6'd0;
  always @(*) begin
    {R,G,B} = prevprev_video_active ? layered_color : 6'd0;
  end
  ////////////////////////////////////

endmodule

