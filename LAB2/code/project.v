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



////// debounce //////

  reg clean_inp_a, clean_inp_b, clean_inp_l;
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
  debounce l_debounce (
    .clk(clk),
    .noisy_button(inp_l),
    .clean_button(clean_inp_l)
  );
//////////////////////////



///// Map character want to write ////////
always @(*) begin
  ascii_number_to_write = 7'd0;
  if (clean_inp_a)
    ascii_number_to_write = 7'd65; // A
end
//////////////////////////////////////////


//////// Tile ram ///////////////////////

  reg [6:0] col_pos_cursor;
  reg [4:0] row_pos_cursor;
  reg [6:0] ascii_number_to_write;

  wire write_enable;
  assign write_enable = clean_inp_a || clean_inp_b;
  //---------------------------------
  // Bug note (Fixed): คือเวลาเขียนอะต้องเขียนก่อนแล้วค่อยเลื่อน cursor แบบปกติมันถูกละเพราะทำ clock เดียวกัน
  // แต่เวลาลบมันต้องเลื่อน cursor ก่อนแล้วค่อยเขียนตัว blank แต่ทีนี้มันทำใน clock เดียวกัน มันเลยเขียนที่cursor ปัจจุบันก่อนเลื่อน
  // เห็นใช่ไหมว่าถ้าจะทำให้เสร็จใน clock ถัดไป มันต้องบอกทั้ง write_enable ที่จะเขียนและตำแหน่งที่จะเขียน ซึ่งมันบอกลำดับไม่ได้
  // จึงต้อง delay เขียนไป 1 clock เพื่อที่จะบอกค่าทั้งสอง
  reg delay_write_enable;
  reg [4:0] row_pos_to_write;
  reg [6:0] col_pos_to_write;
  reg [6:0] delay_ascii_number_to_write;
  //---------------------------------
    
  simple_dp_ram #(
    .DATA_WIDTH(11),
    .ADDR_WIDTH(12)
  ) tile_ram (

    .clk(clk),
    .dat_in(delay_ascii_number_to_write),
    .wr_adr({row_pos_to_write, col_pos_to_write}),
    .wr_en(delay_write_enable),

    .rd_adr({pix_y[9:4], pix_x[9:3]}),
    .dat_out(tile_char_ascii_number)
  );
////////////////////////////////////////////

////////// Font Rom /////////////////
  wire [6:0] tile_char_ascii_number;
  wire [10:0] font_addr;  
  assign font_addr = {tile_char_ascii_number, pix_y[3:0]};
  reg [7:0] font_ram_output;

  font_rom f_rom (
    .clk(clk),
    .addr(font_addr),
    .data(font_ram_output)
  );
///////////////////////////////////////
  


/////// Write actual pixel //////////////
  wire bit_active_this_pix;
  reg [9:0] prev_pix_x, prevprev_pix_x;  // delay 2 clock from tile ram, and font rom just like in lecture
  assign bit_active_this_pix = font_ram_output[7 - prevprev_pix_x[2:0]];
/////////////////////////////////////////


  // Same old shi
  always @(posedge clk) begin
    if (~rst_n) begin
      R <= 0;
      G <= 0;
      B <= 0;
      col_pos_cursor <= 0;
      row_pos_cursor <= 0;
      col_pos_to_write <= 0;
      row_pos_to_write <= 0;
      delay_write_enable <= 0;

    end else begin
      prev_pix_x <= pix_x;
      prevprev_pix_x <= prev_pix_x;
      delay_write_enable <= write_enable;
      delay_ascii_number_to_write <= ascii_number_to_write;

      if (clean_inp_a) begin
        col_pos_cursor <= col_pos_cursor + 1;
        col_pos_to_write <= col_pos_cursor;
        row_pos_to_write <= row_pos_cursor;
      end
      else if (clean_inp_b) begin
        col_pos_cursor <= col_pos_cursor - 1;
        col_pos_to_write <= col_pos_cursor - 1;
        row_pos_to_write <= row_pos_cursor;
      end
      else if (clean_inp_l) begin
        col_pos_cursor <= 0;
        row_pos_cursor <= row_pos_cursor + 1;
      end


      if (video_active) begin
        {R, G, B} <= (pix_x==0) ? WHITE : bit_active_this_pix ? GREEN : BLACK;
      end else begin
        {R, G, B} <= 0;
      end
    end
  end




endmodule
