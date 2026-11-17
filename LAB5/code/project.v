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
  // t: map addr -> t+1: tile id -> t+2: pixel
  reg [111:0] tile_rom [0:703]; // 112 = 16(#col per tile)*7(color), 704 = 44(#tile) * 16 (#row per tile)
  initial $readmemh("../data/tiny_tropical_tiles.mem", tile_rom);

  reg [9:0] fg_x_offset, bg_x_offset;
  reg prev_video_active, prevprev_video_active;

  // t
  wire [10:0] fg_pix_x = pix_x + fg_x_offset; // current pixel + offset
  wire [10:0] bg_pix_x = pix_x + bg_x_offset;

  // t+1: {x/32, y/32} -> tile_id
  wire [5:0] fg_tile_id, bg_tile_id;
  foreground_ram fg_map (.clk(clk), .vsync(vsync), .addr({fg_pix_x[10:5], pix_y[8:5]}), .data(fg_tile_id));
  background_ram bg_map (.clk(clk), .vsync(vsync), .addr({bg_pix_x[10:5], pix_y[8:5]}), .data(bg_tile_id));

  wire fg_present_next = fg_tile_id != 6'd63; // 63 = empty

  reg [3:0] row;
  reg [7:0] col, col_d; // {fg_col, bg_col}
  reg [111:0] fg_row, bg_row;
  reg fg_present;
  always @(posedge clk) begin
    // t+1
    row   <= pix_y[4:1]; // 2x scale up 16*16 -> 32*32
    col   <= {fg_pix_x[4:1], bg_pix_x[4:1]};
    // t+2
    col_d <= col; // delaying
    fg_row <= tile_rom[{fg_present_next ? fg_tile_id : 6'd0, row}]; // keep address in range
    bg_row <= tile_rom[{bg_tile_id, row}];
    fg_present <= fg_present_next;
  end
  wire [6:0] fg_pixel = fg_row[111 - col_d[7:4]*7 -: 7]; // col 0 = MSB
  wire [6:0] bg_pixel = bg_row[111 - col_d[3:0]*7 -: 7];
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
  reg face_left; // keep facing after release
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      monster_x <= 10'd10;
      monster_y <= 10'd352;
      monster_prev_vsync <= 1'b0;
      monster_move_frame <= 1'b0;
      face_left <= 1'b0;
    end else begin
      monster_prev_vsync <= vsync;
      if (inp_left) face_left <= 1'b1;
      else if (inp_right) face_left <= 1'b0;
      if (vsync && !monster_prev_vsync) begin
        monster_move_frame <= ~monster_move_frame;
        if (!monster_move_frame) begin
          if (inp_right) begin
            if (monster_x <= 10'd1018) monster_x <= monster_x + 10'd5;
          end else if (inp_left) begin
            if (monster_x >= 10'd5) monster_x <= monster_x - 10'd5;
          end
        end
      end
    end
  end

  ////// sprites //////
  // triple line buffer, line y: show = y%3, draw (line y+1) = (y+1)%3, clear = (y+2)%3
  // 525 lines = 3*175 -> y%3 stays in sync across frames
  reg [6:0] lb0 [0:639];
  reg [6:0] lb1 [0:639];
  reg [6:0] lb2 [0:639];
  reg [1:0] sel; // = pix_y % 3
  reg [111:0] monster_ram [0:511]; // 32 frames * 16 rows, row = 16 px * 7 bit
  initial $readmemh("../data/dude_monster.mem", monster_ram);

  wire [9:0] draw_y = (pix_y == 10'd524) ? 10'd0 : pix_y + 10'd1;

  // sprite table, last = on top
  localparam N_SPR = 3'd4;
  reg [2:0] i;
  reg [10:0] spr_x; // world x
  reg [9:0] spr_y;
  reg [4:0] spr_frame; // sheet row*8 + col: idle 0-3, walk 8-13
  reg spr_flip;
  wire moving = inp_left || inp_right;
  always @(*) begin
    case (i)
      3'd0: {spr_x, spr_y, spr_frame, spr_flip} = {11'd250, 10'd352, 3'd0, walk_counter[1:0], 1'b0};
      3'd1: {spr_x, spr_y, spr_frame, spr_flip} = {11'd600, 10'd352, 3'd0, walk_counter[1:0], 1'b1};
      3'd2: {spr_x, spr_y, spr_frame, spr_flip} = {11'd900, 10'd352, 3'd0, walk_counter[1:0], 1'b0};
      default: {spr_x, spr_y, spr_frame, spr_flip} = // player
        {1'b0, monster_x, monster_y, moving ? 5'd8 + {2'd0, walk_counter} : {3'd0, walk_counter[1:0]}, face_left};
    endcase
  end

  // sprite i vs draw_y, 64x64 on screen (16x16 art * 4)
  wire [9:0]  dy = draw_y - spr_y; // < 64 -> hit (negative wraps big)
  wire [11:0] sx = {1'b0, spr_x} - {2'b0, fg_x_offset}; // screen x, can be negative
  wire hit = dy < 10'd64 && (sx + 12'd64) < 12'd704; // in line + on screen

  // FSM: render all sprites of line y+1 into draw buffer
  localparam IDLE = 2'd0, FOR_I = 2'd1, WRITE = 2'd2;
  reg [1:0] state;
  reg [111:0] spr_row;
  reg [11:0] cur_sx;
  reg cur_flip;
  reg [5:0] dx;
  wire [3:0]  spr_col = cur_flip ? 4'd15 - dx[5:2] : dx[5:2];
  wire [6:0]  wpx = spr_row[111 - spr_col*7 -: 7];
  wire [11:0] wx  = cur_sx + {6'd0, dx};
  wire we = state == WRITE && wpx[6] && wx < 12'd640; // opaque + on screen

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      sel <= 2'd0;
    end else begin
      if (pix_x == 10'd799) sel <= (sel == 2'd2) ? 2'd0 : sel + 2'd1;
      case (state)
        IDLE: if (pix_x == 10'd0 && draw_y < 10'd480) begin
          i <= 3'd0;
          state <= FOR_I;
        end
        FOR_I: if (i == N_SPR) state <= IDLE;
          else if (hit) begin
            spr_row <= monster_ram[{spr_frame, dy[5:2]}]; // ready next clk
            cur_sx <= sx;
            cur_flip <= spr_flip;
            dx <= 6'd0;
            state <= WRITE;
          end else i <= i + 3'd1;
        WRITE: begin
          dx <= dx + 6'd1;
          if (dx == 6'd63) begin
            i <= i + 3'd1;
            state <= FOR_I;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

  // buffers: clear + draw + read in parallel
  reg [6:0] sprite_pixel, prev_sprite_pixel;
  always @(posedge clk) begin
    if (pix_x < 10'd640) case (sel) // clear
      2'd0: lb2[pix_x] <= 7'd0;
      2'd1: lb0[pix_x] <= 7'd0;
      default: lb1[pix_x] <= 7'd0;
    endcase
    if (we) case (sel) // draw
      2'd0: lb1[wx[9:0]] <= wpx;
      2'd1: lb2[wx[9:0]] <= wpx;
      default: lb0[wx[9:0]] <= wpx;
    endcase
    case (sel) // show
      2'd0: sprite_pixel <= lb0[pix_x];
      2'd1: sprite_pixel <= lb1[pix_x];
      default: sprite_pixel <= lb2[pix_x];
    endcase
    prev_sprite_pixel <= sprite_pixel; // t+2, match tiles
  end

  always @(*) begin
    {R,G,B} = prevprev_video_active ?
              (prev_sprite_pixel[6] ? prev_sprite_pixel[5:0] : layered_color) : 6'd0;
  end
  ////////////////////////////////////

endmodule

