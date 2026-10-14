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
  localparam [5:0] BLUE = {2'b00, 2'b00, 2'b11};

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



  //////// Tile ram //////////////////
  // memory of current board: Row*Col = 11 * 40
  /*
    note: 
    tr = tile row,
    tc = tile col,
    inp_a = insert
    inp_b = delete
  */
  reg [5:0] tc_cursor;
  reg [3:0] tr_cursor;

  wire write_enable = clean_inp_a || clean_inp_b;
  //---------------------------------
  // [Fixed Bug Note] (Might help nong pun understand code more): คือเวลาเขียนอะต้องเขียนก่อนแล้วค่อยเลื่อน cursor แบบปกติมันถูกละเพราะทำ clock เดียวกัน
  // แต่เวลาลบมันต้องเลื่อน cursor ก่อนแล้วค่อยเขียนตัว blank แต่ทีนี้มันทำใน clock เดียวกัน มันเลยเขียนที่cursor ปัจจุบันก่อนเลื่อน
  // เห็นใช่ไหมว่าถ้าจะทำให้เสร็จใน clock ถัดไป มันต้องบอกทั้ง write_enable ที่จะเขียนและตำแหน่งที่จะเขียน ซึ่งมันบอกลำดับไม่ได้
  // จึงต้อง delay เขียนไป 1 clock เพื่อที่จะบอกค่าทั้งสอง
  reg delay_write_enable;
  reg [3:0] tr_to_write;
  reg [5:0] tc_to_write;
  //---------------------------------

  reg [6:0] char_ascii_w; // ascii to write to tile e.g. 65 = 'A'
  wire [6:0] char_ascii_r; // ascii read from given tile

  simple_dp_ram #(
    .DATA_WIDTH(7),
    .ADDR_WIDTH(10)
  ) tile_ram (

    .clk(clk),
    .dat_in(char_ascii_w),
    .wr_adr({tr_to_write, tc_to_write}),
    .wr_en(delay_write_enable),

    .rd_adr({pix_y[8:5], pix_x[9:4]}),
    .dat_out(char_ascii_r)
  );
  ////////////////////////////////////

  ////////// Font Rom ////////////////
  
  reg [7:0] font_ram_output; 
  reg [6:0] selected_char;  //the current char to write (show only on bottom left)
  reg [7:0] selected_font_output;

  font_rom f_rom (
    .clk(clk), 
    .addr({char_ascii_r, pix_y[4:1]}), 
    .data(font_ram_output)
  );
  font_rom selector_f_rom (
    .clk(clk),
    .addr({selected_char, pix_y[6:3]}),
    .data(selected_font_output)
  );
  /////////////////////////////////////
  
  //////// RENDER /////////////////////
  // write actual pixel
  wire bit_active_this_pix;
  wire selector_bit_active_this_pix;
  reg [9:0] prev_pix_x, prevprev_pix_x;  // delay 2 clock from tile ram + font rom (just like in lecture)
  // read same for two bits then move, 7 - because data read from ram is BigEndian

  assign bit_active_this_pix = font_ram_output[3'b111 - prevprev_pix_x[3:1]]; 
  assign selector_bit_active_this_pix = (pix_y >= 384) && (pix_x<64) && selected_font_output[3'b111 - pix_x[5:3]];

  reg [10:0] timer;
  wire cursor_is_here =
      ((pix_x >= {tc_cursor,4'd4}) && (pix_x <= {tc_cursor,4'd6})) &&  // 2 px cursor size
      (pix_y[8:5] == tr_cursor);
  reg cursor_is_on;
  reg [5:0] num_char_this_row [0:10]; // array size 11 of 6 bit 
  reg [3:0] num_row_have_text; // num of row that have text

    // delay
    always @(posedge clk) begin
      prev_pix_x <= pix_x;
      prevprev_pix_x <= prev_pix_x;
      delay_write_enable <= ~rst_n ? 0 : write_enable;
    end
    always @(posedge vsync) begin
      timer <= ~rst_n ? 0 : timer + 1;
      cursor_is_on <= ~rst_n ? 0 : (timer[2:0] == 3'd0 ? ~cursor_is_on : cursor_is_on);
    end
    //vga
    always @(posedge clk) begin
      if (~rst_n) {R,G,B} <= 6'd0;
      else begin
        if (video_active) {R, G, B} <= selector_bit_active_this_pix ? WHITE : bit_active_this_pix ? GREEN : (cursor_is_here && cursor_is_on) ? WHITE : BLACK;
        else {R, G, B} <= 6'd0;
      end
    end
  ////////////////////////////////////

  //////////// LOGIC /////////////////
  integer i;
  always @(posedge clk) begin
    if (~rst_n) begin
      tc_cursor <= 0;
      tr_cursor <= 0;
      tc_to_write <= 0;
      tr_to_write <= 0;
      selected_char <= 7'd65;
      char_ascii_w <= 7'd65;
      cursor_is_on <= 1'b0;
      num_row_have_text <= 4'd0;
      for (i=0; i<=10; i = i+1) num_char_this_row[i] <= 6'd0;
    end else begin
      char_ascii_w <= selected_char;
      // change char forward
      if (clean_inp_x) selected_char <= selected_char + 1;
      // change char backward
      else if (clean_inp_y) selected_char <= selected_char - 1;
      // move cursor left
      else if (clean_inp_left) begin
        //normal case, left most case, first char case
        if (tr_cursor==4'd0 && tc_cursor==6'd0) ; // Do nothing
        else if (tc_cursor==6'd0) begin
          tr_cursor <= tr_cursor - 4'd1;
          tc_cursor <= num_char_this_row[tr_cursor-1];
        end else tc_cursor <= tc_cursor - 6'd1;
      end
      // move cursor right
      else if (clean_inp_right) begin
        //normal case, right most case, last char case
        if (tr_cursor==4'd10 && tc_cursor==6'd39) ;
        else if (tr_cursor==num_row_have_text) ;
        else if (tc_cursor==num_char_this_row[tr_cursor]) begin
          tr_cursor <= tr_cursor + 4'd1;
          tc_cursor <= 6'd0;
        end else tc_cursor <= tc_cursor + 6'd1;
      end
      // move cursor up
      else if (clean_inp_up) begin
        //first line case, go up have char, go up don't have char
        if (tr_cursor==4'd0) ;
        else if (num_char_this_row[tr_cursor-1] >= tc_cursor) tr_cursor <= tr_cursor - 4'd1;
        else begin
          tr_cursor <= tr_cursor - 4'd1;
          tc_cursor <= num_char_this_row[tr_cursor-1];
        end
      end
      // move cursor down
      else if (clean_inp_down) begin
        //last line case, go down have char, go down don't have char
        if (tr_cursor >= num_row_have_text) ;
        else if (tr_cursor<4'd10 && num_char_this_row[tr_cursor+1] >= tc_cursor) tr_cursor <= tr_cursor + 4'd1;
        else if (tr_cursor<4'd10 && num_char_this_row[tr_cursor+1] < tc_cursor) begin
          tr_cursor <= tr_cursor + 4'd1;
          tc_cursor <= num_char_this_row[tr_cursor+1];
        end
      end
      // move next
      else if (clean_inp_r) begin
        if (tr_cursor == num_row_have_text) num_row_have_text <= num_row_have_text + 4'd1;
        char_ascii_w <= 7'd0; //empty char
        if (tc_cursor==39 && tr_cursor==10) ; // very end
        else if (tc_cursor==39) begin // end line but not very end
          tc_cursor <= 0;
          tr_cursor <= tr_cursor + 1;
          num_char_this_row[tr_cursor+1] <= 1;
        end else begin
          tc_cursor <= tc_cursor + 1;
          num_char_this_row[tr_cursor] <= num_char_this_row[tr_cursor] + 1;
        end
        tc_to_write <= tc_cursor;
        tr_to_write <= tr_cursor;
      end
      // insert
      else if (clean_inp_a) begin
        if (tr_cursor == num_row_have_text) num_row_have_text <= num_row_have_text + 4'd1;
        // โค้ดตอนนี้คือถ้าอยู่บรรทัดท้ายตัวสุดท้ายแล้วพิมพ์ มันจะแก้ตัวสุดท้าย ไม่ใช่พิมพ์ไม่ได้ ดูแปลกๆแต่ก็ช่างมัน ใครมันจะไปพิมพ์จนหมดหน้า
        if (tc_cursor==39 && tr_cursor==10) ; // very end
        else if (tc_cursor==39) begin // end line but not very end
          tc_cursor <= 0;
          tr_cursor <= tr_cursor + 1;
          num_char_this_row[tr_cursor+1] <= 1;
        end else begin
          tc_cursor <= tc_cursor + 1;
          if (tc_cursor==num_char_this_row[tr_cursor]) num_char_this_row[tr_cursor] <= num_char_this_row[tr_cursor] + 1;
        end
        tc_to_write <= tc_cursor;
        tr_to_write <= tr_cursor;
      end
      // delete
      else if (clean_inp_b) begin
        if (tr_cursor == num_row_have_text) num_row_have_text <= num_row_have_text - 4'd1;
        char_ascii_w <= 7'd0;
        if (tr_cursor==0 && tc_cursor==0) ;
        else if (tc_cursor==0) begin
          //เคสนี้ ตอนลบต้องแบ่งเคสว่าบรรทัดก่อนเต็มไหม ถ้าเต็มก็ลบตัวท้ายบรรทัดก่อน ถ้าไม่เต็มก็แค่เอา cursor ไปต่อท้าย
          tr_cursor <= tr_cursor - 1;
          tr_to_write <= tr_cursor - 1;
          if (num_char_this_row[tr_cursor-1]==40) begin
            tc_cursor <= 39;
            tc_to_write <= 39;
            num_char_this_row[tr_cursor-1] <= 39;
          end else begin
            tc_cursor <= num_char_this_row[tr_cursor-1];
            tc_to_write <= num_char_this_row[tr_cursor-1];
          end
        end else begin
          tc_cursor <= tc_cursor - 1;
          tc_to_write <= tc_cursor - 1;
          num_char_this_row[tr_cursor] <= num_char_this_row[tr_cursor] - 1;
        end
      end
      // move next line
      else if (clean_inp_l) begin
        if (tr_cursor == num_row_have_text) num_row_have_text <= num_row_have_text + 4'd1;
        if (tr_cursor<10) begin
          tc_cursor <= 0;
          tr_cursor <= tr_cursor + 1;
        end
      end
    end
  end
  ////////////////////////////////////

endmodule
