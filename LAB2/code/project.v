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

  reg clean_inp_a, clean_inp_b, clean_inp_l, clean_inp_up, clean_inp_down, clean_inp_r;
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
  debounce up_debounce (
    .clk(clk),
    .noisy_button(inp_up),
    .clean_button(clean_inp_up)
  );
    debounce down_debounce (
    .clk(clk),
    .noisy_button(inp_down),
    .clean_button(clean_inp_down)
  );
  debounce r_debounce (
    .clk(clk),
    .noisy_button(inp_r),
    .clean_button(clean_inp_r)
  );

//////////////////////////



//////// Tile ram ///////////////////////

  reg [5:0] col_pos_cursor;
  reg [3:0] row_pos_cursor;

  wire write_enable;
  assign write_enable = clean_inp_a || clean_inp_b;
  //---------------------------------
  // [Fixed Bug Note] (Might help nong pun understand code more): คือเวลาเขียนอะต้องเขียนก่อนแล้วค่อยเลื่อน cursor แบบปกติมันถูกละเพราะทำ clock เดียวกัน
  // แต่เวลาลบมันต้องเลื่อน cursor ก่อนแล้วค่อยเขียนตัว blank แต่ทีนี้มันทำใน clock เดียวกัน มันเลยเขียนที่cursor ปัจจุบันก่อนเลื่อน
  // เห็นใช่ไหมว่าถ้าจะทำให้เสร็จใน clock ถัดไป มันต้องบอกทั้ง write_enable ที่จะเขียนและตำแหน่งที่จะเขียน ซึ่งมันบอกลำดับไม่ได้
  // จึงต้อง delay เขียนไป 1 clock เพื่อที่จะบอกค่าทั้งสอง
  reg delay_write_enable;
  reg [3:0] row_pos_to_write;
  reg [5:0] col_pos_to_write;
  //---------------------------------

  reg [6:0] selector_font_to_actually_write;  
    
  simple_dp_ram #(
    .DATA_WIDTH(7),
    .ADDR_WIDTH(10)
  ) tile_ram (

    .clk(clk),
    .dat_in(selector_font_to_actually_write),
    .wr_adr({row_pos_to_write, col_pos_to_write}),
    .wr_en(delay_write_enable),

    .rd_adr({pix_y[8:5], pix_x[9:4]}),
    .dat_out(tile_char_ascii_number)
  );
////////////////////////////////////////////

////////// Font Rom /////////////////
  wire [6:0] tile_char_ascii_number;
  wire [10:0] font_addr;  
  assign font_addr = {tile_char_ascii_number, pix_y[4:1]}; // read same for two bits then move
  reg [7:0] font_ram_output;

  font_rom f_rom (
    .clk(clk),
    .addr(font_addr),
    .data(font_ram_output)
  );

  reg [6:0] selector_font_select_reg;  
  wire [10:0] selector_font_addr;
  assign selector_font_addr = {selector_font_select_reg, pix_y[6:3]};
  reg [7:0] selector_font_ram_output;
  font_rom selector_f_rom (
    .clk(clk),
    .addr(selector_font_addr),
    .data(selector_font_ram_output)
  );
///////////////////////////////////////
  


/////// Write actual pixel //////////////
  wire bit_active_this_pix;
  reg [9:0] prev_pix_x, prevprev_pix_x;  // delay 2 clock from tile ram, and font rom just like in lecture
  assign bit_active_this_pix = font_ram_output[7 - prevprev_pix_x[3:1]]; // read same for two bits then move
/////////////////////////////////////////

/////////////////////////////////////////
  wire selector_bit_active_this_pix;
  assign selector_bit_active_this_pix = (pix_y >= 384) && (pix_x<64) && selector_font_ram_output[7 - pix_x[5:3]]; //โคตร hardcode but i don't care
/////////////////////////////////////////

/*\
  reg [5:0] col_pos_cursor;
  reg [3:0] row_pos_cursor;
  */
wire cursor_is_here;
reg cursor_is_on;
assign cursor_is_here =
    ((pix_x >= {col_pos_cursor,4'd4}) && (pix_x <= {col_pos_cursor,4'd6})) &&
    (pix_y[8:5] == row_pos_cursor);

//80 tile col * 30 tile row

  // Same old shi

  reg [10:0] timer;

  always @(posedge vsync) begin
    if (~rst_n) begin
      timer <= 0;
      cursor_is_on <= 0;
    end
    else begin
      timer <= timer + 1;
      if (timer[2:0] == 3'd0) cursor_is_on <= ~cursor_is_on;

    end
  end

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
      selector_font_select_reg <= 7'd65;
      selector_font_to_actually_write <= 7'd65;
      cursor_is_on <= 1'b0;

    end else begin
      prev_pix_x <= pix_x;
      prevprev_pix_x <= prev_pix_x;
      delay_write_enable <= write_enable;
      selector_font_to_actually_write <= selector_font_select_reg;

      if (clean_inp_up) begin
        selector_font_select_reg <= selector_font_select_reg + 1;
      end
      else if (clean_inp_down) begin
        selector_font_select_reg <= selector_font_select_reg - 1;
      end
      else if (clean_inp_r) begin
        selector_font_to_actually_write <= 7'd0;
        if (col_pos_cursor==39 && row_pos_cursor==10) ; // very end
        else if (col_pos_cursor==39) begin // end line but not very end
          col_pos_cursor <= 0;
          row_pos_cursor <= row_pos_cursor + 1;
        end else begin
          col_pos_cursor <= col_pos_cursor + 1;
          row_pos_cursor <= row_pos_cursor;
        end
        col_pos_to_write <= col_pos_cursor;
        row_pos_to_write <= row_pos_cursor;
      end
      
      else if (clean_inp_a) begin

        // โค้ดตอนนี้คือถ้าอยู่บรรทัดท้ายตัวสุดท้ายแล้วพิมพ์ มันจะแก้ตัวสุดท้าย ไม่ใช่พิมพ์ไม่ได้ ดูแปลกๆแต่ก็ช่างมัน ใครมันจะไปพิมพ์จนหมดหน้า
        if (col_pos_cursor==39 && row_pos_cursor==10) ; // very end
        else if (col_pos_cursor==39) begin // end line but not very end
          col_pos_cursor <= 0;
          row_pos_cursor <= row_pos_cursor + 1;
        end else begin
          col_pos_cursor <= col_pos_cursor + 1;
          row_pos_cursor <= row_pos_cursor;
        end
        col_pos_to_write <= col_pos_cursor;
        row_pos_to_write <= row_pos_cursor;

      end
      else if (clean_inp_b) begin
        selector_font_to_actually_write <= 7'd0;
        if (row_pos_cursor==0 && col_pos_cursor==0) ;
        else if (col_pos_cursor==0) begin
          col_pos_cursor <= 39;
          row_pos_cursor <= row_pos_cursor - 1;

          col_pos_to_write <= 39;
          row_pos_to_write <= row_pos_cursor - 1;
        end else begin
          col_pos_cursor <= col_pos_cursor - 1;
          row_pos_cursor <= row_pos_cursor;

          col_pos_to_write <= col_pos_cursor - 1;
          row_pos_cursor <= row_pos_cursor;
        end

      end
      else if (clean_inp_l) begin
        col_pos_cursor <= 0;
        row_pos_cursor <= row_pos_cursor + 1;
      end


      if (video_active) begin
        {R, G, B} <= selector_bit_active_this_pix ? WHITE : bit_active_this_pix ? GREEN : (cursor_is_here && cursor_is_on) ? WHITE : BLACK;
      end else begin
        {R, G, B} <= 0;
      end
    end
  end




endmodule
