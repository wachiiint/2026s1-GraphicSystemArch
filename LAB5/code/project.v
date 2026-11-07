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
  reg [111:0] foreground_tile_ram [0:703];
  reg [111:0] background_tile_ram [0:703];
  wire [5:0] foreground_tile_id, background_tile_id;
  reg [3:0] tile_row;
  wire [9:0] foreground_tile_addr = {(foreground_tile_id == 6'd63 ? 6'd0 : foreground_tile_id), tile_row};
  reg foreground_present;
  reg [111:0] foreground_tile_ram_output;
  reg [111:0] background_tile_ram_output;
  wire [9:0] background_tile_addr = {background_tile_id, tile_row}; // Blue background tile.

  initial $readmemh("../data/tiny_tropical_tiles.mem", foreground_tile_ram);
  initial $readmemh("../data/tiny_tropical_tiles.mem", background_tile_ram);

  reg [3:0] foreground_tile_col, prev_foreground_tile_col;
  reg [3:0] background_tile_col, prev_background_tile_col;
  reg prev_video_active, prevprev_video_active;

  reg [9:0] foreground_x_offset, background_x_offset;
  wire [10:0] foreground_world_pix_x = {1'b0, pix_x} + {1'b0, foreground_x_offset};
  wire [10:0] background_world_pix_x = {1'b0, pix_x} + {1'b0, background_x_offset};
  wire [9:0] foreground_map_addr = {foreground_world_pix_x[10:5], pix_y[8:5]};
  wire [9:0] background_map_addr = {background_world_pix_x[10:5], pix_y[8:5]};

  foreground_ram foreground_ram_inst (
    .clk(clk),
    .vsync(vsync),
    .addr(foreground_map_addr),
    .data(foreground_tile_id)
  );

  background_ram background_ram_inst (
    .clk(clk),
    .vsync(vsync),
    .addr(background_map_addr),
    .data(background_tile_id)
  );

  always @(posedge clk) begin
    tile_row <= pix_y[4:1];
    foreground_tile_col <= foreground_world_pix_x[4:1];
    background_tile_col <= background_world_pix_x[4:1];
    prev_foreground_tile_col <= foreground_tile_col;
    prev_background_tile_col <= background_tile_col;
    foreground_tile_ram_output <= foreground_tile_ram[foreground_tile_addr];
    foreground_present <= foreground_tile_id != 6'd63;
    background_tile_ram_output <= background_tile_ram[background_tile_addr];
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
      foreground_x_offset <= 10'd0;
      background_x_offset <= 10'd0;
    end else begin
      counter <= counter + 10'd1;
      if (counter[0] == 1'b0) begin
        if (inp_left && foreground_x_offset >= 10'd4) begin
          foreground_x_offset <= foreground_x_offset - 10'd4;
          background_x_offset <= background_x_offset - 10'd2;
        end else if (inp_right && foreground_x_offset <= 10'd1016) begin
          foreground_x_offset <= foreground_x_offset + 10'd4;
          background_x_offset <= background_x_offset + 10'd2;
        end
      end
    end
  end


  wire [6:0] foreground_pixel_shift = (7'd15 - {3'd0, prev_foreground_tile_col}) * 7'd7;
  wire [6:0] background_pixel_shift = (7'd15 - {3'd0, prev_background_tile_col}) * 7'd7;
  wire [6:0] foreground_pixel = foreground_tile_ram_output[foreground_pixel_shift+:7];
  wire [6:0] background_pixel = background_tile_ram_output[background_pixel_shift+:7];
  wire [5:0] layered_color = (foreground_present && foreground_pixel[6]) ? foreground_pixel[5:0] :
                             background_pixel[6] ? background_pixel[5:0] : 6'd0;

////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////

  reg [9:0] monster_x, monster_y;
  reg monster_prev_vsync;
  reg monster_move_frame;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      monster_x <= 10'd10;
      monster_y <= 10'd350;
      monster_prev_vsync <= 1'b0;
      monster_move_frame <= 1'b0;
    end else begin
      monster_prev_vsync <= vsync;
      if (vsync && !monster_prev_vsync) begin
        monster_move_frame <= ~monster_move_frame;
        if (!monster_move_frame) begin
          if (inp_right) begin
            if (monster_x <= 10'd1021) monster_x <= monster_x + 10'd5;
          end else if (inp_left) begin
            if (monster_x >= 10'd2) monster_x <= monster_x - 10'd5;
          end
        end
      end
    end
  end

  reg [6:0] line_buffer_A [0:639];
  reg [6:0] line_buffer_B [0:639];
  wire curr_buff_active = pix_y[0];
  reg [111:0] monster_ram [0:511];
  initial $readmemh("../data/dude_monster.mem", monster_ram);

  wire [10:0] next_y = pix_y == 10'd524 ? 11'd0 : {1'b0, pix_y} + 11'd1;
  wire [10:0] monster_dx = foreground_world_pix_x - {1'b0, monster_x};
  wire [10:0] monster_dy = next_y - {1'b0, monster_y};
  wire monster_present = foreground_world_pix_x >= {1'b0, monster_x} &&
                         monster_dx < 11'd32 && next_y >= {1'b0, monster_y} &&
                         monster_dy < 11'd32;
  wire [8:0] monster_word_selector = {5'd0, monster_dy[4:1]}; // Idle frame 0.
  wire [6:0] monster_pixel_shift = (7'd15 - {3'd0, monster_dx[4:1]}) * 7'd7;
  wire [6:0] monster_pixel = monster_present ?
      monster_ram[monster_word_selector][monster_pixel_shift+:7] : 7'd0;
  integer line_pixel;
  reg [6:0] sprite_pixel, prev_sprite_pixel;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      for (line_pixel = 0; line_pixel < 640; line_pixel = line_pixel + 1) begin
        line_buffer_A[line_pixel] = 7'd0;
        line_buffer_B[line_pixel] = 7'd0;
      end
      sprite_pixel <= 0;
      prev_sprite_pixel <= 0;
    end else begin
      sprite_pixel <= 0;
      if (pix_x < 10'd640) begin
        if (curr_buff_active) begin
          sprite_pixel <= line_buffer_A[pix_x];
          line_buffer_B[pix_x] <= monster_pixel;
        end else begin
          sprite_pixel <= line_buffer_B[pix_x];
          line_buffer_A[pix_x] <= monster_pixel;
        end
      end
      prev_sprite_pixel <= sprite_pixel;
    end
  end


  always @(*) begin
    {R,G,B} = prevprev_video_active ?
              (prev_sprite_pixel[6] ? prev_sprite_pixel[5:0] : layered_color) : 6'd0;
  end
  ////////////////////////////////////

endmodule

