module depthInterpolator_Test();
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h0;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam EighthFP = 32'h3e000000;
    localparam Point375 = 32'h3ec00000;
    localparam PERIOD = 20;

    reg clk;
    wire [31:0] out;
    reg [31:0] a,b,c,za,zb,zc;
    wire [32:0] outFN, aFN,bFN,cFN,zaFN,zbFN,zcFN;

    fNToRecFN#(8,24) fNToRecFNa (a, aFN);
    fNToRecFN#(8,24) fNToRecFNb (b, bFN);
    fNToRecFN#(8,24) fNToRecFNc (c, cFN);
    fNToRecFN#(8,24) fNToRecFNza (za, zaFN);
    fNToRecFN#(8,24) fNToRecFNzb (zb, zbFN);
    fNToRecFN#(8,24) fNToRecFNzc (zc, zcFN);

    depthInterpolator DUT(clk,1'b1,aFN,bFN,cFN,zaFN,zbFN,zcFN,outFN);
    recFNToFN#(8,24) recFNToFN1 (outFN, out);
    
    fNToRecFN#(8,24) fNToRecFN234 (OneFP, tst);
    always 
        begin
            clk = 1'b1; 
            #20; // high for 20 * timescale = 20 ns

            clk = 1'b0;
            #20; // low for 20 * timescale = 20 ns
        end
    
    localparam p = {QuarterFP,QuarterFP};
    localparam p1 = {ZeroFP,ZeroFP};
    localparam p2 = {OneFP,ZeroFP};
    localparam p3 = {ZeroFP,OneFP};

    initial // initial block executes only once
        begin
            a = QuarterFP;
            za = HalfFP;
            b = OneFP;
            zb = ZeroFP;
            c = QuarterFP;
            zc = OneFP;
            #PERIOD; // wait for period 
            $display("outFN == %h", outFN);
            $display("out == %h", out);
            $display("tst == %h", tst);

            if(out != Point375)  begin
                $display("test failed");
            end else begin
                $display("test passed");
            
            end
            
            
            $finish;
        end
endmodule