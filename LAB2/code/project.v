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
  wire hsync;
  wire vsync;
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
      .hsync(hsync),
      .vsync(vsync),
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



  // Colors
  localparam [5:0] BLACK = {2'b00, 2'b00, 2'b00};
  localparam [5:0] GREEN = {2'b00, 2'b11, 2'b00};
  localparam [5:0] WHITE = {2'b11, 2'b11, 2'b11};





/*
module font_rom (
    input  wire        clk,
    input  wire [10:0] addr, // 10:4 is character, 3:0 is row
    output reg  [7:0]  data // per row
);
*/

  wire [6:0] tile_char_ascii_number;       // The character stored in this screen cell
  wire [10:0] font_addr;      // Character + row in that character

  assign font_addr = {tile_char_ascii_number, pix_y[3:0]};
  reg [7:0] font_ram_output;

  font_rom f_rom (
    .clk(clk),
    .addr(font_addr),
    .data(font_ram_output)
  );

/*
module simple_dp_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 12
) (
    input  wire                  clk,

    // Write port: write dat_in into memory[wr_adr] when wr_en is 1.
    input  wire [DATA_WIDTH-1:0] dat_in,
    input  wire [ADDR_WIDTH-1:0] wr_adr,
    input  wire                  wr_en,

    // Read port: dat_out receives memory[rd_adr] one clock later.
    input  wire [ADDR_WIDTH-1:0] rd_adr,
    output reg  [DATA_WIDTH-1:0] dat_out
);
*/

  reg [6:0] col_pos_cursor;
  reg [4:0] row_pos_cursor;

  reg [6:0] ascii_number_to_write;

  reg clean_inp_a, clean_inp_b;

  wire write_enable;
  assign write_enable = inp_a || inp_b;


  debounce a_debounce (
    .clk(clk),
    .noisy_button(inp_a),
    .clean_button(clean_inp_a)
  );
  debounce b_debounce (
    .clk(clk),
    .noisy_button(inp_b),
    .clean_button(clean_inp_b)
  );

  always @(*) begin
    if (clean_inp_a) ascii_number_to_write = 7'd65; // A
    else if (clean_inp_b) ascii_number_to_write = 7'd0; // blank
  end

  simple_dp_ram #(
    .DATA_WIDTH(11),
    .ADDR_WIDTH(12)
  ) tile_ram (

    .clk(clk),
    .dat_in(ascii_number_to_write),
    .wr_adr({row_pos_cursor, col_pos_cursor}),
    .wr_en(write_enable),

    .rd_adr({pix_y[9:4], pix_x[9:3]}),
    .dat_out(tile_char_ascii_number)
  );

  

  /*
  // Glyph positions
  localparam LEFT_X = 48, LEFT_Y = 240;
  localparam RIGHT_X = 144, RIGHT_Y = 240;
  localparam UP_X = 96, UP_Y = 192;
  localparam DOWN_X = 96, DOWN_Y = 288;
  localparam A_X = 560, A_Y = 240;
  localparam B_X = 512, B_Y = 296;
  localparam X_X = 512, X_Y = 184;
  localparam Y_X = 464, Y_Y = 240;
  localparam L_X = 32, L_Y = 92;
  localparam R_X = 592, R_Y = 92;
  localparam SEL_X = 264, SEL_Y = 240;
  localparam STRT_X = 328, STRT_Y = 240;
  */
  /*
  // Glyph activation logic
  wire left_act = glyph_active(LEFT_X, LEFT_Y, LEFT_GLYPH);
  wire right_act = glyph_active(RIGHT_X, RIGHT_Y, RIGHT_GLYPH);
  wire up_act = glyph_active(UP_X, UP_Y, UP_GLYPH);
  wire down_act = glyph_active(DOWN_X, DOWN_Y, DOWN_GLYPH);
  wire a_act = glyph_active(A_X, A_Y, A_GLYPH);
  wire b_act = glyph_active(B_X, B_Y, B_GLYPH);
  wire x_act = glyph_active(X_X, X_Y, X_GLYPH);
  wire y_act = glyph_active(Y_X, Y_Y, Y_GLYPH);
  wire l_act = glyph_active(L_X, L_Y, L_GLYPH);
  wire r_act = glyph_active(R_X, R_Y, R_GLYPH);
  wire sel_act = glyph_active(SEL_X, SEL_Y, SELECT_GLYPH);
  wire strt_act = glyph_active(STRT_X, STRT_Y, START_GLYPH);
  */



  wire bit_active_this_pix;
  assign bit_active_this_pix = font_ram_output[7 - pix_x[2:0]];

  // RGB output logic
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
      col_pos_cursor <= 0;
      row_pos_cursor <= 0;

    end else begin
      if (video_active) begin

        if (clean_inp_a) col_pos_cursor <= col_pos_cursor + 1;
        else if (clean_inp_b) col_pos_cursor <= col_pos_cursor - 1;    

        {R, G, B} <= bit_active_this_pix ? GREEN : BLACK;
      end else begin
        {R, G, B} <= 0;
      end
    end
  end




endmodule
