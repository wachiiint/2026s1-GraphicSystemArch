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
  // reg clean_inp_a, clean_inp_b, clean_inp_l, clean_inp_r, clean_inp_x, clean_inp_y;
  // reg clean_inp_up, clean_inp_down, clean_inp_left, clean_inp_right;
  // debounce a_debounce (.clk(clk), .in(inp_a), .out(clean_inp_a));
  // debounce b_debounce (.clk(clk), .in(inp_b), .out(clean_inp_b));
  // debounce x_debounce (.clk(clk), .in(inp_x), .out(clean_inp_x));
  // debounce y_debounce (.clk(clk), .in(inp_y), .out(clean_inp_y));
  // debounce uu_debounce (.clk(clk), .in(inp_up), .out(clean_inp_up));
  // debounce dd_debounce (.clk(clk), .in(inp_down), .out(clean_inp_down));
  // debounce ll_debounce (.clk(clk), .in(inp_left), .out(clean_inp_left));
  // debounce rr_debounce (.clk(clk), .in(inp_right), .out(clean_inp_right));
  // debounce l_debounce (.clk(clk), .in(inp_l), .out(clean_inp_l)); 
  // debounce r_debounce (.clk(clk), .in(inp_r), .out(clean_inp_r));
  //////////////////////////

  ////// tile layers //////
  /*
  Tile = 16x16 art drawn 2x -> 32x32 on screen.
  3 steps, 1 clock each:  t: map address  ->  t+1: tile id  ->  t+2: pixel
  Tile ROM, shared by both layers: 44 tiles x 16 rows.
  One entry = one tile row = 16 px x 7 bit {opaque, R[1:0], G[1:0], B[1:0]}.
  */
  reg [111:0] tile_rom [0:703]; //112 = 16(#col per tile)*7(color), 704 = 44(#tile) * 16 (#row per tile)
  initial $readmemh("../data/tiny_tropical_tiles.mem", tile_rom);

  reg [9:0] fg_x_offset, bg_x_offset;
  reg prev_video_active, prevprev_video_active;

  // step t: screen pixel -> world pixel -> map address {tile_x, tile_y} (5+4 bit)
  wire [10:0] fg_pix_x = {1'b0, pix_x} + {1'b0, fg_x_offset}; // current pixel + offset
  wire [10:0] bg_pix_x = {1'b0, pix_x} + {1'b0, bg_x_offset};
  wire [9:0] fg_map_addr = {fg_pix_x[10:5], pix_y[8:5]}; // map of tile_id in (x,y) {fg_pix_x /16, pix_y / 16} (5+4 = 9 bit)
  wire [9:0] bg_map_addr = {bg_pix_x[10:5], pix_y[8:5]};

  // step t+1: look up map_addr in rom -> get tile_id
  wire [5:0] fg_tile_id, bg_tile_id;
  foreground_ram foreground_ram_inst (.clk(clk), .vsync(vsync), .addr(fg_map_addr), .data(fg_tile_id));
  background_ram background_ram_inst (.clk(clk), .vsync(vsync), .addr(bg_map_addr), .data(bg_tile_id));

  reg [3:0] row; // row to render in art pixel, obtain from real pix_x in fg, bg
  reg [3:0] fg_col, bg_col;
  always @(posedge clk) begin
    row    <= pix_y[4:1]; // 2x scale up 16*16 -> 32*32
    fg_col <= fg_pix_x[4:1];
    bg_col <= bg_pix_x[4:1];
  end

  // step t+2: tile ROM gives one row of 16 px (1 clock late) ----
  reg [111:0] fg_row, bg_row;
  reg [3:0] fg_col_d, bg_col_d;   // column, delayed again to match the ROM
  reg fg_present;
  always @(posedge clk) begin
    fg_row   <= tile_rom[{(fg_tile_id == 6'd63) ? 6'd0 : fg_tile_id, row}]; // 63 = empty, keep address in range
    bg_row   <= tile_rom[{bg_tile_id, row}];
    fg_col_d <= fg_col;
    bg_col_d <= bg_col;
    fg_present <= fg_tile_id !=  6'd63; // delaying
  end

  // pick 1 pixel from the row (column 0 = most significant 7 bits)
  wire [6:0] fg_pixel = fg_row[111 - fg_col_d*7 -: 7]; // same as  [111 - fg_col_d*7 : 111 - fg_col_d*7 - 7]
  wire [6:0] bg_pixel = bg_row[111 - bg_col_d*7 -: 7];
  //////////////////////////

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
  reg [2:0] walk_counter;
  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      counter <= 10'd0;
      walk_counter <= 3'd0;
      fg_x_offset <= 10'd0;
      bg_x_offset <= 10'd0;
    end else begin
      counter <= counter + 10'd1;
      if (counter[0] == 1'b0) begin
        if (inp_left && fg_x_offset >= 10'd4) begin
          fg_x_offset <= fg_x_offset - 10'd4;
          bg_x_offset <= bg_x_offset - 10'd2;
        end else if (inp_right && fg_x_offset <= 10'd1016) begin
          fg_x_offset <= fg_x_offset + 10'd4;
          bg_x_offset <= bg_x_offset + 10'd2;
        end
        if (walk_counter > 3'd4) begin
          walk_counter <= 3'd0;
        end else begin
          walk_counter <= walk_counter + 3'd1;
        end

      end
    end
  end


  wire [5:0] layered_color = (fg_present && fg_pixel[6]) ? fg_pixel[5:0] : // 63 = transparent
                             bg_pixel[6] ? bg_pixel[5:0] : 6'd0;

////////////////////////////////////////////////////////////

///////////////////////////////////////////////////////////

  reg [9:0] monster_x, monster_y;
  reg monster_prev_vsync;
  reg monster_move_frame;
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      monster_x <= 10'd10;
      monster_y <= 10'd352;
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
  wire [10:0] monster_dx = fg_pix_x - {1'b0, monster_x};
  wire [10:0] monster_dy = next_y - {1'b0, monster_y};
  wire monster_present = fg_pix_x >= {1'b0, monster_x} &&
                         monster_dx < 11'd64 && next_y >= {1'b0, monster_y} &&
                         monster_dy < 11'd64;
  ///wire [8:0] monster_word_selector = {5'd0, monster_dy[4:1]}; // Idle frame 0.
  wire [6:0] monster_pixel_shift = (7'd15 - {3'd0, monster_dx[5:2]}) * 7'd7;
  wire [6:0] monster_pixel_shift_reverse = ({3'd0, monster_dx[5:2]}) * 7'd7;
  reg [6:0] monster_pixel; //= monster_present ?
  //    monster_ram[monster_word_selector][monster_pixel_shift+:7] : 7'd0;
  integer line_pixel;
  reg [6:0] sprite_pixel, prev_sprite_pixel;
  

  always @(*) begin
    if (monster_present) begin  
      if (inp_right) begin
        monster_pixel = monster_ram[{5'd8 + walk_counter, monster_dy[5:2]}][monster_pixel_shift+:7];
      end else if (inp_left) begin
        monster_pixel = monster_ram[{5'd8 + walk_counter, monster_dy[5:2]}][monster_pixel_shift_reverse+:7];
      end
      else monster_pixel = monster_ram[{5'd0, monster_dy[5:2]}][monster_pixel_shift+:7];
    end else begin
      monster_pixel = 7'd0;
    end
  end

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

