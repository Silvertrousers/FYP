module boundingBoxGen_Test ();
    reg [31:0] resx, resy;
    wire [31:0] Top,Bottom,Left, Right;

    reg [63:0] Pa, Pb, Pc;
    wire [65:0] PaRecFN, PbRecFN, PcRecFN;
    fNToRecFN#(8,24) fNToRecFN9 (Pa[63:32], PaRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN10 (Pa[31:0], PaRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFn11 (Pb[63:32], PbRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN12 (Pb[31:0], PbRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFN13 (Pc[63:32], PcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN14 (Pc[31:0], PcRecFN[32:0]);
    boundingBoxGen DUT(PaRecFN,PbRecFN,PcRecFN,Top,Bottom,Right,Left,resx,resy);

    initial begin
        $display("Starting");
        resx = 32'd1920;
        resy = 32'd1080;
        //test bb in middld4;e
        Pa = {32'h409ccccd,32'h4098f5c3};  // 4.9, 4.78
        Pb = {32'h4119999a, 32'h4194cccd}; // 9.6, 18.6
        Pc = {32'h4149999a, 32'h3fa66666}; //12.6, 1.3
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd1) && (Bottom == 32'd19) && (Left == 32'd4) && (Right == 32'd13)) begin
            $display("basic tst passed");
        end
        #10
        //test bb out of screen on right
        Pa = {32'h409ccccd,32'h4098f5c3};  // 4.9, 4.78
        Pb = {32'h4119999a, 32'h4194cccd}; // 9.6, 18.6
        Pc = {32'h44f45666, 32'h3fa66666}; //1954.7, 1.3
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd1) && (Bottom == 32'd19) && (Left == 32'd4) && (Right == resx)) begin
            $display("right tst passed");
        end
        #10
        //test bb out of screen on left
        Pa = {32'hc0e9fbe7,32'h4098f5c3};  // -7.312, 4.78
        Pb = {32'h4119999a, 32'h4194cccd}; // 9.6, 18.6
        Pc = {32'h4149999a, 32'h3fa66666}; //12.6, 1.3
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd1) && (Bottom == 32'd19) && (Left == 32'd0) && (Right == 32'd13)) begin
            $display("left tst passed");
        end
        #10
        //test bb out of screen on top
        Pa = {32'h409ccccd,32'h4098f5c3};  // 4.9, 4.78
        Pb = {32'h4119999a, 32'h4194cccd}; // 9.6, 18.6
        Pc = {32'h4149999a, 32'hc2f6af1b}; //12.6, -123.342
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd0) && (Bottom == 32'd19) && (Left == 32'd4) && (Right == 32'd13)) begin
            $display("top tst passed");
        end
        #10
        //test bb out of screen on bottom
        Pa = {32'h409ccccd,32'h4098f5c3};  // 4.9, 4.78
        Pb = {32'h4119999a, 32'h4620d767}; // 9.6, 10293.8505
        Pc = {32'h4149999a, 32'h3fa66666}; //12.6, 1.3
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd1) && (Bottom == resy) && (Left == 32'd4) && (Right == 32'd13)) begin
            $display("bottom tst passed");
        end
        #10
        //test bb out of screen on bottom and left
        Pa = {32'hc0e9fbe7,32'h4098f5c3};  // -7.312, 4.78
        Pb = {32'h4119999a, 32'h4620d767}; // 9.6, 10293.8505
        Pc = {32'h4149999a, 32'h3fa66666}; //12.6, 1.3
        #10 
        $display("t,b,l,r: (%d,%d,%d,%d)", Top, Bottom, Left, Right);
        if((Top == 32'd1) && (Bottom == resy) && (Left == 32'd0) && (Right == 32'd13)) begin
            $display("bottom,left tst passed");
        end
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("boundingBoxGen_Test.vcd");
            $dumpvars(0,boundingBoxGen_Test);
            #1;
        end
endmodule