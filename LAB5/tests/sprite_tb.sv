module sprite_tb;
  reg clk = 0;
  reg rst_n = 0;
  reg left_button = 0, right_button = 0;
  reg [9:0] world_x = 10, world_y = 384, scroll_offset = 0;
  reg [111:0] reference_sprite [0:511];
  reg [6:0] expected_now, expected_prev;
  reg active_now, active_prev, valid;
  reg manual_vsync = 0;
  reg [9:0] move_start;
  integer scenario, step, x, y, dx, dy, frame_id;
  integer checked = 0, opaque = 0, transparent = 0;

  tt_um_vga_example dut (
    .clk(clk), .rst_n(rst_n), .ena(1'b1),
    .ui_in(8'd0), .uio_in(8'd0), .uo_out(), .uio_out(), .uio_oe()
  );

  task tick;
    begin clk = 0; #1; clk = 1; #1; end
  endtask

  task check_move(input [9:0] start_x, input go_left, input go_right, input [9:0] expected);
    begin
      manual_vsync = 0;
      left_button = go_left;
      right_button = go_right;
      move_start = start_x;
      force dut.monster_x = move_start;
      tick();
      release dut.monster_x;
      manual_vsync = 1;
      tick();
      assert(dut.monster_x == expected) else $fatal(1, "Position wrapped at x=%0d",start_x);
    end
  endtask

  initial begin
    $readmemh("../data/dude_monster.mem", reference_sprite);
    force dut.monster_x = world_x;
    force dut.monster_y = world_y;
    force dut.foreground_x_offset = scroll_offset;
    force dut.background_x_offset = scroll_offset >> 1;
    force dut.inp_left = left_button;
    force dut.inp_right = right_button;

    for (scenario = 0; scenario < 5; scenario = scenario + 1) begin
      case (scenario)
        0: begin world_x=10; world_y=384; scroll_offset=0; left_button=0; right_button=0; end
        1: begin world_x=70; world_y=384; scroll_offset=31; left_button=0; right_button=1; end
        2: begin world_x=652; world_y=384; scroll_offset=31; left_button=0; right_button=1; end
        3: begin world_x=15; world_y=475; scroll_offset=31; left_button=1; right_button=0; end
        4: begin world_x=1020; world_y=2; scroll_offset=512; left_button=0; right_button=0; end
      endcase
      rst_n = 0;
      repeat (3) tick();
      rst_n = 1;
      valid = 0;
      for (step = 0; step < 800*525+2; step = step + 1) begin
        clk = 0; #1;
        x = int'(dut.pix_x); y = int'(dut.pix_y);
        dx = x + int'(scroll_offset) - int'(world_x);
        dy = y - int'(world_y);
        active_now = x < 640 && y < 480;
        expected_now = 0;
        frame_id = (left_button || right_button) ? 8 : 0;
        if (active_now && dx >= 0 && dx < 32 && dy >= 0 && dy < 32)
          expected_now = 7'(reference_sprite[frame_id*16+dy/2] >> ((15-dx/2)*7));
        clk = 1; #1;
        if (valid) begin
          if (active_prev) begin
            assert(dut.prev_sprite_pixel === expected_prev)
              else $fatal(1,"Sprite pixel mismatch scenario=%0d step=%0d got=%h expected=%h",scenario,step,dut.prev_sprite_pixel,expected_prev);
            if (expected_prev[6]) begin
              assert({dut.R,dut.G,dut.B} === expected_prev[5:0]) else $fatal(1,"Sprite priority failed");
              opaque = opaque + 1;
            end else begin
              assert({dut.R,dut.G,dut.B} === dut.layered_color) else $fatal(1,"Transparency failed");
              transparent = transparent + 1;
            end
          end else
            assert({dut.R,dut.G,dut.B} === 6'd0) else $fatal(1,"Blanking failed");
          checked = checked + 1;
        end
        expected_prev = expected_now;
        active_prev = active_now;
        valid = 1;
      end
    end

    force dut.vsync = manual_vsync;
    force dut.monster_move_frame = 1'b0;
    check_move(10'd2, 1, 0, 10'd2);
    check_move(10'd4, 1, 0, 10'd4);
    check_move(10'd5, 1, 0, 10'd0);
    check_move(10'd1018, 0, 1, 10'd1023);
    check_move(10'd1019, 0, 1, 10'd1019);
    check_move(10'd1021, 0, 1, 10'd1021);
    assert(opaque > 0 && transparent > 0) else $fatal(1,"Missing opacity coverage");
    $display("PASS: %0d pixels, idle/walk, scrolling, clipping, opacity and movement bounds",checked);
    $finish;
  end
endmodule
