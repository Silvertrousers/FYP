`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps

module calcArea_Test;
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h0;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam EighthFP = 32'h3e000000;
    localparam PERIOD = 20;

    reg clk;
    reg resetn, en;
    reg  [63:0] P1,P2,P3; //x,y
    wire [65:0] P1RecFN,P2RecFN,P3RecFN;
    wire [31:0] TwoA;
    wire [32:0] TwoArecFN, tst;
    fNToRecFN#(8,24) fNToRecFNx1 (P1[63:32], P1RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNx2 (P2[63:32], P2RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNx3 (P3[63:32], P3RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNy1 (P1[31:0], P1RecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNy2 (P2[31:0], P2RecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNy3 (P3[31:0], P3RecFN[32:0]);
   
    calcArea DUT(clk, enable, resetn, P1RecFN, P2RecFN, P3RecFN, TwoArecFN);
    recFNToFN#(8,24) recFNToFN1 (TwoArecFN, TwoA);
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
            P1 = p;
            P2 = p2;
            P3 = p3;
            #PERIOD; // wait for period 
            $display("TwoArecFN == %h", TwoArecFN);
            $display("TwoA == %h", TwoA);
            $display("tst == %h", tst);

            if(TwoA != HalfFP)  begin
                $display("test failed for input combination A(0.5 0.5, 01, 10) != 1");
            end else begin
                $display("test passed for input combination A(0.5 0.5, 01, 10) = 1");
            
            end
            P1 = p1;
            P2 = p;
            P3 = p3;
            #PERIOD; // wait for period 
            $display("TwoArecFN == %h", TwoArecFN);
            $display("TwoA == %h", TwoA);

            if(TwoA != QuarterFP)  begin
                $display("test failed for input combination A(00, 0.5 0.5, 10) != 1");
            end else begin
                $display("test passed for input combination A(00, 0.5 0.5, 10) = 1");
            
            end
            P1 = p1;
            P2 = p2;
            P3 = p;
            #PERIOD; // wait for period 
            $display("TwoArecFN == %h", TwoArecFN);
            $display("TwoA == %h", TwoA);

            if(TwoA != QuarterFP)  begin
                $display("test failed for input combination A(00, 01, 0.5 0.5) != 1");
            end else begin
                $display("test passed for input combination A(00, 01, 0.5 0.5) = 1");
            
            end
            // values for a and b
            P1 = {ZeroFP,ZeroFP};
            P2 = {OneFP,ZeroFP};
            P3 = {ZeroFP,OneFP};
            #PERIOD; // wait for period 
            $display("tst == %h", tst);
            $display("TwoArecFN == %h", TwoArecFN);
            $display("TwoA == %h", TwoA);

            if(TwoA != OneFP)  begin
                $display("test failed for input combination A(00, 10, 01) != 1");
            end else begin
                $display("test passed for input combination A(00, 10, 01) = 1");
            
            end
            // values for a and b
            P1 = {ZeroFP,ZeroFP};
            P2 = {ZeroFP,OneFP};
            P3 = {OneFP,ZeroFP};
            #PERIOD; // wait for period 
            $display("tst == %h", tst);
            $display("TwoArecFN == %h", TwoArecFN);
            $display("TwoA == %h", TwoA);

            if(TwoA != OneFP)  begin
                $display("test passed for input combination A(00, 01, 10) != 1");
            end else begin
                $display("test failed for input combination A(00, 01, 10) = 1");
            
            end
            
            $finish;
        end
endmodule 