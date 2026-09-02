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
  
  localparam _G = 10'd3;
  localparam _VelImpulseFlap = 10'd8;
  localparam _accPipe = 10'd1; //1 per ? frame -> See below
  localparam _initVelPipe = 10'd4;

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

  reg [9:0] bird_x, bird_y;
  reg [9:0] pipe1_x, pipe1_y;
  reg [9:0] pipe2_x, pipe2_y;

  reg [9:0] vel_bird, vel_pipe;
  
  wire bird = (pix_x > bird_x && pix_x < bird_x + 30 
              && pix_y > bird_y && pix_y < bird_y + 20);
  wire pipe1_vertical = (pix_x > pipe1_x && pix_x < pipe1_x + 50);
  wire pipe1_horizontal = (pix_y > pipe1_y && pix_y < pipe1_y + 150);
  wire pipe2_vertical = (pix_x > pipe2_x && pix_x < pipe2_x + 50);
  wire pipe2_horizontal = (pix_y > pipe2_y && pix_y < pipe2_y + 150);

  wire bird_hit_pipe1_x = ((bird_x + 10'd30) > pipe1_x) && (bird_x < (pipe1_x + 10'd50));
  wire bird_hit_pipe2_x = ((bird_x + 10'd30) > pipe2_x) && (bird_x < (pipe2_x + 10'd50));
  wire bird_hit_pipe1_y = (bird_y < pipe1_y) || ((bird_y + 10'd20) > (pipe1_y + 10'd150));
  wire bird_hit_pipe2_y = (bird_y < pipe2_y) || ((bird_y + 10'd20) > (pipe2_y + 10'd150));
  wire collide_pipe1 = bird_hit_pipe1_x && bird_hit_pipe1_y;
  wire collide_pipe2 = bird_hit_pipe2_x && bird_hit_pipe2_y;
  wire bird_collide_pipe = collide_pipe1 || collide_pipe2;
  

  always @(*) begin
    {R,G,B} = 6'b000000;
    if (video_active) {R,G,B} = 6'b011011;
    if (bird && video_active) {R,G,B} = 6'b111100;
    if ((pipe1_vertical && !pipe1_horizontal) && video_active) {R,G,B} = 6'b001100;
    if ((pipe2_vertical && !pipe2_horizontal) && video_active) {R,G,B} = 6'b001100;
  end

  localparam STOP = 2'd00;
  localparam PLAYING = 2'd01;
  reg [1:0] currState;

  reg last_frame_is_up = 0;
  wire any_button = inp_b || inp_y || inp_select || inp_start || inp_up || inp_down || inp_left || inp_right ||  inp_a || inp_x ||  inp_l || inp_r;

always @(posedge vsync, negedge rst_n) begin
    if (~rst_n) begin
      counter          <= 10'd0;
      bird_x           <= 10'd100;
      bird_y           <= 10'd200;
      pipe1_x          <= 10'd250;
      pipe2_x          <= 10'd550;
      pipe1_y          <= 10'd100;
      pipe2_y          <= 10'd200;
      vel_bird         <= 10'd0;
      vel_pipe         <= _initVelPipe;
      last_frame_is_up <= 1'b0;
      currState        <= STOP;
    end else begin
      case (currState)
        STOP: begin
          bird_y <= 10'd200;
          vel_bird    <= 10'd0;
          pipe1_x     <= 10'd250;
          pipe2_x     <= 10'd550;
          pipe1_y     <= 10'd100;
          pipe2_y     <= 10'd200;
          vel_pipe    <= _initVelPipe;
          if (any_button) currState <= PLAYING;  
        end

        PLAYING: begin

          if (bird_y > 10'd450 || bird_collide_pipe)
            currState <= STOP;     

          counter          <= counter + 1'b1;
          last_frame_is_up <= inp_up;    

          // GRAVITY
          if (inp_up && !last_frame_is_up) //already debounce ?
            vel_bird <= -_VelImpulseFlap; // top < bottom (Row domain)
          // ACCELERATION
          // THIS IS THE BUG, Real Hardware Implement can overwrite -> put else if here
          else if (counter[1:0] == 0) // 1 per 4 frame
            vel_bird <= vel_bird + _G; // bottom > top (Row domain)
          if (counter[5:0] == 0) // 1 per 64 frame
            vel_pipe <= vel_pipe + _accPipe;
          
          // update position pipe + bird
          pipe1_x <= pipe1_x <= vel_pipe ? 10'd690: pipe1_x - vel_pipe;
          pipe2_x <= pipe2_x <= vel_pipe ? 10'd690: pipe2_x - vel_pipe;
          bird_y <= bird_y + vel_bird; 
        end

        default: currState <= STOP;
      endcase
    end
  end

endmodule