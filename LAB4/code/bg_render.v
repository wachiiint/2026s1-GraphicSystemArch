`default_nettype none

module bg_render #(
    parameter IMG_SIZE = 320,  // number pixel per lines
    parameter MUL_FACTOR = 2,   // vga_res/img_size
    parameter DISPLAY_HEIGHT = 240  // VGA display height
)(
    input wire [9:0]    xin, // pix_x input
    input wire [9:0]    yin, // pix_y input
    input wire          clk,
    input wire          inp_l,
    input wire          inp_r,
    input wire          vsync,
    input wire          rst_n,
    output wire [5:0]   out // color
);

    reg [5:0] bg[IMG_SIZE*DISPLAY_HEIGHT-1:0];  // 320x240 word, 1 word = 6 bit{R,G,B}

    initial begin
        $readmemh("../data/img.mem", bg);
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

    wire [31:0] x,y;
    reg [31:0] offset;

    /*
    IMG_SIZE = 457
    DISPLAY_WIDTH = 320
    swipe display frame in 2 canvas
    virutal pix = 914, off set = 0..457
    */
    always @(posedge clk) begin
        if(~rst_n) offset <= 32'd0;
        if(inp_l) offset <= offset == 32'd0 ? IMG_SIZE-32'd1 : offset - 32'd1;
        if(inp_r) offset <= offset == IMG_SIZE - 32'd1 ? 32'd0 : offset + 32'd1;
    end
    assign x = ({22'd0, xin} + offset) % IMG_SIZE*MUL_FACTOR;
    assign y = {22'd0, yin};



    wire[16:0] mem_index = 17'((y / MUL_FACTOR) * IMG_SIZE + (x / MUL_FACTOR));  // read 6 bit at (y/2*320)
    assign out = bg[mem_index];
    // assign out = offset[5:0] & 6'b000010;

endmodule