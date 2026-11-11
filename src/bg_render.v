`default_nettype none

module bg_render #(
    parameter IMG_SIZE = 320,  // number pixel per lines
    parameter MUL_FACTOR = 2,   // vga_res/img_size
    parameter DISPLAY_WIDTH = 320,  // VGA display width
    parameter DISPLAY_HEIGHT = 240  // VGA display height
)(
    input wire [9:0]    xin, // pix_x input
    input wire [9:0]    yin, // pix_y input
    input wire          clk,
    input wire          inp_l,
    input wire          inp_r,
    input wire          video_active,
    input wire          vsync,
    input wire          rst_n,
    output wire [5:0]   out // color
);
    localparam MAX_T = 650;  // maximum time of the transition

    reg [5:0] bg[IMG_SIZE*DISPLAY_HEIGHT-1:0];  // 320x240 word, 1 word = 6 bit{R,G,B}

    initial begin
        $readmemh("../data/bg.mem", bg);
    end

    reg v_prev; // last vsync
    reg frame; // new frame
    always @(posedge clk) begin
        if(~rst_n) v_prev <= 1'b1;
        else begin
            if(v_prev & ~vsync) frame <= 1'b1;
            if(vsync & frame) frame <= 1'b0;
            v_prev <= vsync;
        end
    end

    wire [11:0] x,y;
    reg [11:0] offset;

    /*
    IMG_SIZE = 457
    DISPLAY_WIDTH = 320
    swipe display frame in 2 canvas
    virutal pix = 914, off set = 0..457
    */
    always @(posedge clk) begin
        if(~rst_n) offset <= 11'b0;
        if(inp_l) offset <= offset == 11'd0 ? IMG_SIZE-11'd1 : offset - 11'd1;
        if(inp_r) offset <= offset == IMG_SIZE - 11'd1 ? 11'd0 : offset + 11'd1;
    end
    assign x = (xin + offset) % IMG_SIZE*MUL_FACTOR;
    assign y = yin;



    wire[16:0] mem_index = (y / MUL_FACTOR) * IMG_SIZE + (x / MUL_FACTOR);  // read 6 bit at (y/2*320)
    assign out = bg[mem_index];
    // assign out = offset[5:0] & 6'b000010;

endmodule