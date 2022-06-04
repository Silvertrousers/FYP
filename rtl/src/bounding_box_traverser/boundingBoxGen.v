module boundingBoxGen(
    input wire [65:0] Pa,
    input wire [65:0] Pb,
    input wire [65:0] Pc,
    output wire [31:0] Top,
    output wire [31:0] Bottom,
    output wire [31:0] Right,
    output wire [31:0] Left,
    input wire [31:0] resx,
    input wire [31:0] resy
);
    wire [32:0] maxx, minx, maxy, miny;

    minmax minmax_x(Pa[65:33],Pb[65:33],Pc[65:33],maxx,minx);
    minmax minmax_y(Pa[32:0],Pb[32:0],Pc[32:0],maxy,miny);

    wire [31:0] maxx_int, minx_int,maxy_int,miny_int;
    //rounding mode choice really key for these https://en.wikipedia.org/wiki/IEEE_754#Rounding_rules
    recFNToIN#(8,24,32) maxxCiel2int(.control(1'b0),.in(maxx),.roundingMode(`round_max),.signedOut(1'b1),.out(maxx_int),.intExceptionFlags());
    recFNToIN#(8,24,32) minxFloor2int(.control(1'b0),.in(minx),.roundingMode(`round_min),.signedOut(1'b1),.out(minx_int),.intExceptionFlags());
    recFNToIN#(8,24,32) maxyCiel2int(.control(1'b0),.in(maxy),.roundingMode(`round_max),.signedOut(1'b1),.out(maxy_int),.intExceptionFlags());
    recFNToIN#(8,24,32) minyFloor2int(.control(1'b0),.in(miny),.roundingMode(`round_min),.signedOut(1'b1),.out(miny_int),.intExceptionFlags());


    
    limitBB limitBB_inst(resx,resy,maxx_int,minx_int,maxy_int,miny_int,Top,Bottom,Left,Right); 
endmodule

module minmax(
    input wire [32:0] a,
    input wire [32:0] b,
    input wire [32:0] c,
    output reg [32:0] max,
    output reg [32:0] min
);
    wire altb, aeqb, agtb;
    wire altc, aeqc, agtc;
    wire bltc, beqc, bgtc;
    wire abUnordered, acUnordered, bcUnordered;
    compareRecFN#(8, 24) compareRecFNab (a,b,1'b0,altb,aeqb,agtb,abUnordered,);
    compareRecFN#(8, 24) compareRecFNac (a,c,1'b0,altc,aeqc,agtc,acUnordered,);
    compareRecFN#(8, 24) compareRecFNbc (b,c,1'b0,bltc,beqc,bgtc,bcUnordered,);

    wire bgta, cgta, cgtb;
    assign bgta = altb;
    assign cgta = altc;
    assign cgtb = bltc;

    always @(*) begin
        if ((agtb || aeqb) && (agtc || aeqc)) max = a;
        if ((bgtc || beqc) && (bgta || aeqb)) max = b;
        if ((cgta || aeqc) && (cgtb || beqc)) max = c;
    end

    wire clta, blta, cltb;
    assign clta = agtc;
    assign blta = agtb;
    assign cltb = bgtc;
    always @(*) begin
        if ((altb || aeqb) && (altc || aeqc)) min = a;
        if ((bltc || beqc) && (blta || aeqb)) min = b;
        if ((clta || aeqc) && (cltb || beqc)) min = c;
    end

    // assign max = 
    // a if abc or acb
    // b if bac or bca
    // c if cab or cba

    // assign min = 
    // a if bca or cba
    // b if acb or cab
    // c if abc or bac
          

endmodule

module limitBB(
    input wire [31:0] resx,
    input wire [31:0] resy,
    input wire [31:0] maxx,
    input wire [31:0] minx,
    input wire [31:0] maxy,
    input wire [31:0] miny,
    output wire [31:0] Top,
    output wire [31:0] Bottom,
    output wire [31:0] Left,
    output wire [31:0] Right
);

    assign Left = (minx[31] == 1'b1) ? 'b0 : minx;
    assign Right = (maxx > resx) ? resx : maxx;
    assign Top = (miny[31] == 1'b1) ? 'b0 : miny;
    assign Bottom = (maxy > resy) ? resy : maxy;
endmodule

module limitBB_tb();
    reg [31:0] resx, resy, maxx, minx,maxy,miny;
    wire [31:0] Top,Bottom,Left, Right;
    limitBB limitBB_inst(resx,resy, maxx,minx,maxy,miny, Top,Bottom,Left,Right);  
    initial begin
        $display("Starting");
        resx = 32'd1920;
        resy = 32'd1080;
        //test bb in middld4;e
        maxx = 32'd11;
        minx = 32'd4;
        maxy = 32'd14;
        miny = 32'd4;
        #10 
        if((Top == miny) && (Bottom == maxy) && (Left == minx) && (Right == maxx)) begin
            $display("basic tst passed");
        end
        #10
        //test bb out of screen on right
        maxx = 32'd1980;
        minx = 32'd4;
        maxy = 32'd14;
        miny = 32'd4;
        #10
        if((Top == miny) && (Bottom == maxy) && (Left == minx) && (Right == resx)) begin
            $display("right tst passed");
        end
        #10
        //test bb out of screen on left
        maxx = 32'd11;
        minx = 32'hFFFF_FFFC;
        maxy = 32'd14;
        miny = 32'd4;
        #10 
        if((Top == miny) && (Bottom == maxy) && (Left == 'b0) && (Right == maxx)) begin
            $display("left tst passed");
        end
        #10
        //test bb out of screen on top
        maxx = 32'd11;
        minx = 32'd4;
        maxy = 32'd14;
        miny = 32'hFFFF_FFFC;
        #10
        if((Top == 'b0) && (Bottom == maxy) && (Left == minx) && (Right == maxx)) begin
            $display("top tst passed");
        end
        #10
        //test bb out of screen on bottom
        maxx = 32'd11;
        minx = 32'd4;
        maxy = 32'd1090;
        miny = 32'd4;
        #10
        if((Top == miny) && (Bottom == resy) && (Left == minx) && (Right == maxx)) begin
            $display("bottom tst passed");
        end
        #10
        //test bb out of screen on all sides
        maxx = 32'd1980;
        minx = 32'hFFFF_FFFC;
        maxy = 32'd1090;
        miny = 32'hFFFF_FFFC;
        #10
        if((Top == 'b0) && (Bottom == resy) && (Left == 'b0) && (Right == resx)) begin
            $display("all tst passed");
        end
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("limitBB_tb.vcd");
            $dumpvars(0,limitBB_tb);
            #1;
        end
    
endmodule