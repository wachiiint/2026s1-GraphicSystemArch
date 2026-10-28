`default_nettype none

module compute_fade #(
    parameter IMG_SIZE = 320,  // number pixel per lines
    parameter MUL_FACTOR = 2   // vga_res/img_size
    // parameter DISPLAY_WIDTH = 320;  // VGA display width
    // parameter DISPLAY_HEIGHT = 240;  // VGA display height
)(
    input wire [9:0]    xin, // pix_x input
    input wire [9:0]    yin, // pix_y input
    input wire          clk,
    input wire          fsync,
    input wire          rst_n,
    output wire [5:0]   out // color
);
    localparam MAX_T = 196;      // maximum time of the transition
    localparam BLOCK = 16;       // block size
    localparam BAND = 4;         // BAND of changing
    localparam T_SCALE = 4;      // TIME SCALING

    reg [5:0] img1[76799:0];  // 320x240 word, 1 word = 6 bit{R,G,B}
    reg [5:0] img2[76799:0]; 

    initial begin
        $readmemh("../data/img1.mem", img1);
        $readmemh("../data/img2.mem", img2);
    end

    reg [15:0] counter;
    reg [15:0] tick;
    reg f_prev; // last fsync
    always @(posedge clk) begin
        if(~rst_n) begin
            counter <= 0;
            tick <= 0;
        end
        else if (~f_prev & fsync) 
            counter <= counter == MAX_T ? 0: counter + 1; // +1 when complete the render frame
        
        f_prev <= fsync;
        tick <= counter / T_SCALE;
    end
    /*
    do the math equation without always block
    tick + 1 when for each complete render loop
    fade by manhuttan distance from mid right (x0, y0)
    */

    //
    wire [11:0] x,y; //640, 480
    wire [11:0] xb,yb; // block
    wire [11:0] dx,dy; // diff
    assign x = xin;
    assign y = yin;
    assign xb = x / BLOCK;
    assign yb = y / BLOCK;

    localparam x0 = 639 / BLOCK;
    localparam y0 = 239 / BLOCK;
    wire[16:0] mem_index = (y / MUL_FACTOR) * IMG_SIZE + (x / MUL_FACTOR);
    
    assign dx = (xb > x0 ? xb-x0 : x0-xb) * 2 / 3; // from *0.667 cuz aspect ration 640x480 idk
    assign dy = yb > y0 ? yb-y0 : y0-yb;
    // wire in_pass = (dx+dy) == tick; // currently passing
    wire in_pass = tick >= (dx+dy) & tick - (dx+dy) < BAND; // currently passing
    wire is_pass = tick >= (dx+dy) & tick - (dx+dy) >= BAND; // already passed

    localparam GRAY = 6'b101010;

    /*
    if passing -> graining effect in chess pattern with GREY 333 for 2 bit color
    if passed -> negative image
    */
    // wire [2:0] dt = tick - (dx+dy);
    // wire [8:0] lerp = {
    //     ((BAND - dt) * {1'b0, img1[mem_index][5:4]} + dt *{1'b0, img2[mem_index][5:4]}) / BAND,
    //     ((BAND - dt) * {1'b0, img1[mem_index][3:2]} + dt *{1'b0, img2[mem_index][3:2]}) / BAND,
    //     ((BAND - dt) * {1'b0, img1[mem_index][1:0]} + dt *{1'b0, img2[mem_index][1:0]}) / BAND
    // };
    wire [2:0] dt = tick - (dx+dy);   // 0..BAND-1 = img1 -> img2, logic apply only in_pass
    wire [5:0] c1 = img1[mem_index];
    wire [5:0] c2 = img2[mem_index];

    function [1:0] mix(input [1:0] a, input [1:0] b, input [2:0] t);
        mix = ((BAND - t) * a + t * b) / BAND;
    endfunction

    wire [5:0] lerp = { mix(c1[5:4], c2[5:4], dt),
                        mix(c1[3:2], c2[3:2], dt),
                        mix(c1[1:0], c2[1:0], dt) };

    // assign out =    in_pass ? ((x & 3'b010) ^ (y & 3'b010) ? lerp : GRAY): 
    //                 is_pass ? img2[mem_index] : img1[mem_index];
    assign out =    in_pass ? lerp: 
                    is_pass ? img2[mem_index] : img1[mem_index];

endmodule
