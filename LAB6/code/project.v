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
  reg foreground_water;
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
    foreground_water <= foreground_tile_id == 6'd4 || foreground_tile_id == 6'd5 ||
                        foreground_tile_id == 6'd15 || foreground_tile_id == 6'd26 || foreground_tile_id == 6'd37;
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
  reg [2:0] walk_counter, jump_counter;
  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      counter <= 10'd0;
      walk_counter <= 3'd0;
      jump_counter <= 3'd0;
      foreground_x_offset <= 10'd0;
      background_x_offset <= 10'd0;
    end else begin
      counter <= counter + 10'd1;
      if (floor_contact) jump_counter <= 3'd0;
      else if (counter[0] == 1'b0) jump_counter <= jump_counter + 3'd1;
      if (counter[0] == 1'b0) begin
        if (inp_left && foreground_x_offset >= 10'd4) begin
          foreground_x_offset <= foreground_x_offset - 10'd4;
          background_x_offset <= background_x_offset - 10'd2;
        end else if (inp_right && foreground_x_offset <= 10'd1016) begin
          foreground_x_offset <= foreground_x_offset + 10'd4;
          background_x_offset <= background_x_offset + 10'd2;
        end

        if (walk_counter > 3'd4) begin
          walk_counter <= 3'd0;
        end else begin
          walk_counter <= walk_counter + 3'd1;
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
  reg signed [5:0] monster_velocity_y;
  reg monster_prev_up;
  reg floor_contact;
  wire [10:0] monster_bottom = {1'b0, monster_y} + 11'd63;
  wire signed [11:0] monster_fall_y = $signed({2'b00, monster_y}) +
                                    $signed({{6{monster_velocity_y[5]}}, monster_velocity_y});
  wire [10:0] floor_probe_y = monster_bottom + 11'd1;
  wire [10:0] monster_left_x = {1'b0, monster_x} + 11'd15;
  wire [10:0] monster_middle_x = {1'b0, monster_x} + 11'd32;
  wire [10:0] monster_right_x = {1'b0, monster_x} + 11'd48;
  wire [5:0] floor_left_tile, floor_middle_tile, floor_right_tile;
  wire [9:0] floor_top = {1'b0, floor_probe_y[8:5], 5'd0};

  foreground_ram floor_left_rom (
    .clk(clk), .vsync(vsync),
    .addr({monster_left_x[10:5], floor_probe_y[8:5]}),
    .data(floor_left_tile)
  );
  foreground_ram floor_middle_rom (
    .clk(clk), .vsync(vsync),
    .addr({monster_middle_x[10:5], floor_probe_y[8:5]}),
    .data(floor_middle_tile)
  );
  foreground_ram floor_right_rom (
    .clk(clk), .vsync(vsync),
    .addr({monster_right_x[10:5], floor_probe_y[8:5]}),
    .data(floor_right_tile)
  );

  function is_floor;
    input [5:0] tile;
    begin
      is_floor = (tile <= 6'd3) || (tile >= 6'd11 && tile <= 6'd14) ||
                 (tile >= 6'd22 && tile <= 6'd25) || (tile >= 6'd33 && tile <= 6'd36);
    end
  endfunction
  wire floor_hit = is_floor(floor_left_tile) || is_floor(floor_middle_tile) || is_floor(floor_right_tile);

  always @(posedge vsync or negedge rst_n) begin
    if (~rst_n) begin
      monster_x <= 10'd10;
      monster_y <= 10'd352;
      monster_velocity_y <= 6'sd0;
      monster_prev_up <= 1'b0;
      floor_contact <= 1'b0;
    end else begin
      monster_prev_up <= inp_up;

      if (monster_velocity_y >= 6'sd0 && floor_probe_y < 11'd512 && floor_hit) begin
        monster_y <= floor_top >= 10'd64 ? floor_top - 10'd64 : 10'd0;
        monster_velocity_y <= (inp_up && !monster_prev_up) ? -6'sd12 : 6'sd0;
        floor_contact <= !(inp_up && !monster_prev_up);
      end else begin
        floor_contact <= 1'b0;
        if (monster_fall_y < 12'sd0) begin
          monster_y <= 10'd0;
          monster_velocity_y <= 6'sd0;
        end else begin
          monster_y <= monster_fall_y > 12'sd1023 ? 10'd1023 : monster_fall_y[9:0];
          if (monster_velocity_y < 6'sd16)
            monster_velocity_y <= monster_velocity_y + 6'sd1;
        end
      end
      if (inp_right) begin
        if (monster_x <= 10'd1000) monster_x <= monster_x + 10'd5;
      end else if (inp_left) begin
        if (monster_x >= 10'd2) monster_x <= monster_x - 10'd5;
      end
    end
  end


  reg [6:0] line_buffer_A [0:639];
  reg [6:0] line_buffer_B [0:639];
  wire curr_buff_active = pix_y[0];
  // 32*32 source frames, display at x2 (64*64).
  reg [223:0] monster_ram [0:1023];
  initial $readmemh("../data/dude_monster_full.mem", monster_ram);

  wire [10:0] next_y = pix_y == 10'd524 ? 11'd0 : {1'b0, pix_y} + 11'd1;
  wire [10:0] monster_dx = foreground_world_pix_x - {1'b0, monster_x};
  wire [10:0] monster_dy = next_y - {1'b0, monster_y};
  wire monster_present = foreground_world_pix_x >= {1'b0, monster_x} &&
                         monster_dx < 11'd64 && next_y >= {1'b0, monster_y} &&
                         monster_dy < 11'd64;
  wire [7:0] monster_pixel_shift = (8'd31 - {3'd0, monster_dx[5:1]}) * 8'd7;
  wire [7:0] monster_pixel_shift_reverse = {3'd0, monster_dx[5:1]} * 8'd7;
  reg [4:0] monster_frame;
  reg [6:0] monster_pixel;
  integer line_pixel;
  reg [6:0] sprite_pixel, prev_sprite_pixel;
  

  always @(*) begin
    if (!floor_contact) monster_frame = 5'd24 + {2'd0, jump_counter};
    else if (inp_right || inp_left) monster_frame = 5'd8 + {2'd0, walk_counter};
    else monster_frame = 5'd0;

    if (monster_present) begin  
      if (inp_right) begin
        monster_pixel = monster_ram[{monster_frame, monster_dy[5:1]}][monster_pixel_shift+:7];
      end else if (inp_left) begin
        monster_pixel = monster_ram[{monster_frame, monster_dy[5:1]}][monster_pixel_shift_reverse+:7];
      end
      else monster_pixel = monster_ram[{monster_frame, monster_dy[5:1]}][monster_pixel_shift+:7];
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


  wire water_in_front = foreground_present && foreground_water && foreground_pixel[6];
  always @(*) begin
    {R,G,B} = prevprev_video_active ?
              (water_in_front ? foreground_pixel[5:0] :
               prev_sprite_pixel[6] ? prev_sprite_pixel[5:0] : layered_color) : 6'd0;
  end
  ////////////////////////////////////

endmodule

