module floor_collision_tb;
  reg clk = 0, rst_n = 0, frame_sync = 0;
  reg left_button = 0, right_button = 0;
  reg [9:0] seed_x, seed_y;
  reg [4:0] seed_velocity;
  integer checks = 0, n, expected_y, expected_velocity;
  tt_um_vga_example dut (
    .clk(clk), .rst_n(rst_n), .ena(1'b1), .ui_in(8'd0), .uio_in(8'd0),
    .uo_out(), .uio_out(), .uio_oe()
  );

  task tick;
    begin clk = 0; #1; clk = 1; #1; end
  endtask

  task expect_velocity(input [4:0] expected);
    begin
      assert(dut.monster_velocity_y == expected)
        else $fatal(1,"Wrong vertical velocity: got=%0d expected=%0d",dut.monster_velocity_y,expected);
      checks = checks + 1;
    end
  endtask

  task set_velocity(input [4:0] velocity);
    begin
      seed_velocity = velocity;
      force dut.monster_velocity_y = seed_velocity;
      tick();
      release dut.monster_velocity_y;
    end
  endtask

  task frame;
    begin
      frame_sync = 1; tick();
      frame_sync = 0; repeat (4) tick();
    end
  endtask

  task place(input [9:0] x, input [9:0] y);
    begin
      frame_sync = 0; left_button = 0; right_button = 0;
      rst_n = 0; tick(); rst_n = 1;
      seed_x = x; seed_y = y;
      force dut.monster_x = seed_x;
      force dut.monster_y = seed_y;
      repeat (3) tick();
      release dut.monster_x;
      release dut.monster_y;
    end
  endtask

  task expect_y(input [9:0] expected);
    begin
      assert(dut.monster_y == expected)
        else $fatal(1,"Wrong floor height: x=%0d y=%0d expected=%0d",dut.monster_x,dut.monster_y,expected);
      checks = checks + 1;
    end
  endtask

  task check_stable(input [9:0] x, input [9:0] y, input [9:0] expected);
    begin
      place(x,y);
      frame(); expect_y(expected); expect_velocity(0);
      repeat (4) begin frame(); expect_y(expected); expect_velocity(0); end
    end
  endtask

  task check_airborne(input [9:0] x, input [9:0] y);
    begin
      place(x,y);
      frame(); expect_y(y); expect_velocity(1);
      frame(); expect_y(y+10'd1); expect_velocity(2);
    end
  endtask

  initial begin
    force dut.vsync = frame_sync;
    force dut.inp_left = left_button;
    force dut.inp_right = right_button;

    check_stable(64,360,352);  // Feet penetrate the sand surface at y=416.
    check_stable(64,352,352);  // Last sprite pixel is y=415: already standing.
    check_stable(64,353,352);  // Inclusive bottom exactly touches the floor.
    check_stable(330,360,352); // Only the left foot overlaps the bank.
    check_stable(460,360,352); // Only the right foot overlaps the other bank.
    check_stable(341,360,352); // Inset left probe exactly at the bank's last pixel.
    check_airborne(342,360);  // Sprite artwork overlaps, but inset feet are past the bank.
    check_stable(459,360,352); // Inset right probe exactly at the next bank's first pixel.
    check_airborne(458,360);  // Inset right probe is one pixel short of the bank.
    check_airborne(360,360); // Water surface is not solid.
    check_airborne(360,400); // Water body is not solid.
    check_airborne(32,330);  // Grass is not solid.
    check_airborne(128,295); // Tree trunk is not solid.
    check_airborne(96,240);  // Palm leaves are not solid.
    check_airborne(128,100); // Empty foreground is not solid.

    // Deeper penetration resolves through the two sand rows, then stops.
    place(64,400);
    frame(); expect_y(384);
    frame(); expect_y(352);
    repeat (4) begin frame(); expect_y(352); expect_velocity(0); end

    // Accelerate through open space and stop when landing on the bank.
    place(64,100);
    frame(); expect_y(100); expect_velocity(1);
    frame(); expect_y(101); expect_velocity(2);
    frame(); expect_y(103); expect_velocity(3);
    repeat (40) begin
      frame();
      assert(dut.monster_y <= 352) else $fatal(1,"Fell through the floor");
    end
    expect_y(352); expect_velocity(0);

    // Terminal-speed landings: exact contact and penetration both stop velocity.
    place(64,336); set_velocity(16);
    frame(); expect_y(352); expect_velocity(0);
    place(64,340); set_velocity(16);
    frame(); expect_y(352); expect_velocity(0);

    // Falling into water continues, caps speed and cannot wrap world coordinates.
    place(360,0);
    expected_y = 0; expected_velocity = 0;
    for (n=0; n<100; n=n+1) begin
      expected_y = expected_y + expected_velocity;
      if (expected_y > 1023) expected_y = 1023;
      if (expected_velocity < 16) expected_velocity = expected_velocity + 1;
      frame(); expect_y(10'(expected_y)); expect_velocity(5'(expected_velocity));
    end

    // Walking off a bank starts falling rather than keeping a grounded velocity.
    place(459,352); left_button = 1;
    frame(); expect_y(352); expect_velocity(1);
    left_button = 0;
    frame(); expect_y(353); expect_velocity(2);

    // Collision must use the new world x after movement, not a stale ROM result.
    place(456,360);
    right_button = 1;
    frame();
    assert(dut.monster_x == 461) else $fatal(1,"Right movement changed");
    expect_y(352);
    expect_velocity(0);
    place(459,360);
    left_button = 1;
    frame();
    assert(dut.monster_x == 454) else $fatal(1,"Left movement changed");
    expect_y(360);
    expect_velocity(1);

    // Map addressing must not wrap a foot below y=511 back into solid ground.
    place(64,500);
    force dut.floor_left_tile = 6'd13;
    force dut.floor_middle_tile = 6'd13;
    force dut.floor_right_tile = 6'd13;
    frame(); expect_y(500);
    release dut.floor_left_tile;
    release dut.floor_middle_tile;
    release dut.floor_right_tile;

    // A floor too high for a 64-pixel sprite clamps at the top of the screen.
    place(64,0);
    force dut.floor_left_tile = 6'd13;
    force dut.floor_middle_tile = 6'd13;
    force dut.floor_right_tile = 6'd13;
    frame(); expect_y(0);
    release dut.floor_left_tile;
    release dut.floor_middle_tile;
    release dut.floor_right_tile;

    rst_n = 0; tick();
    assert(dut.monster_y == 352 && dut.monster_velocity_y == 0 && dut.floor_check_pending == 0)
      else $fatal(1,"Floor collision reset failed");
    $display("PASS: %0d gravity/floor checks, acceleration, terminal speed, landing, stable standing, ledges, non-solid tiles and reset",checks);
    $finish;
  end
endmodule
