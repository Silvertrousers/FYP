`timescale 1 ns/10 ps  // time-unit = 1 ns, precision = 10 ps


module calcBary_Test();
    //Need to add the ability for this module to deal with colinearity
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*1000;
    reg clk;
    reg resetn, en;
    reg [63:0] P,P1,P2,P3; //x,y
    wire [65:0] PRecFN,P1RecFN,P2RecFN,P3RecFN; //x,y
    wire [32:0] aFN,bFN,cFN;
    wire [31:0] a,b,c;
    wire [32:0] FourAsquaredrecFN, tst;
    wire inReady;
    reg inValid;
    wire outValid;

    fNToRecFN#(8,24) fNToRecFNx (P[63:32], PRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNy (P[31:0], PRecFN[32:0]);
    
    fNToRecFN#(8,24) fNToRecFNx1 (P1[63:32], P1RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNx2 (P2[63:32], P2RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNx3 (P3[63:32], P3RecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNy1 (P1[31:0], P1RecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNy2 (P2[31:0], P2RecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNy3 (P3[31:0], P3RecFN[32:0]);

    calcBary DUT(clk, en, resetn, PRecFN, P1RecFN, P2RecFN, P3RecFN, aFN,bFN,cFN,inReady,inValid,outValid);
    
    recFNToFN#(8,24) recFNToFN1 (aFN, a);
    recFNToFN#(8,24) recFNToFN2 (bFN, b);
    recFNToFN#(8,24) recFNToFN3 (cFN, c);
    fNToRecFN#(8,24) fNToRecFNtst (OneFP, tst);
    wire [31:0] tsto1, tstso2;
    recFNToFN#(8,24) tester1 (33'h114000000, tsto1);
    recFNToFN#(8,24) tester2 (33'h080000000, tstso2);


    initial
        begin
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            inValid = 1'b1;
            en = 1'b1;
        end
    always 
        begin
            clk = 1'b1; 
            #(PERIOD/2);
            clk = 1'b0;
            #(PERIOD/2);
        end
    
    initial // initial block executes only once
        begin
            // values for a and b
            P = {QuarterFP,QuarterFP};
            P1 = {ZeroFP,ZeroFP};
            P2 = {OneFP,ZeroFP};
            P3 = {ZeroFP,OneFP};
            
        end
    always@(negedge clk) begin
        if (outValid == 1'b1) begin
                $display("aFN,bFN,cFN == %h,%h,%h", aFN,bFN,cFN);
                $display("a,b,c == %h,%h,%h", a,b,c);
                if({a,b,c} != {HalfFP,QuarterFP,QuarterFP})  begin
                    $display("test failed for input combination");
                end else begin
                    $display("test passed for input combination");
                
                end

                $finish;
            end
    end
    //Timeout
    initial begin
        #TIMEOUT;
        $display("tsts1, tst2 == %h,%h", tsto1,tstso2);
        $display("Simulation Timed Out :(");
        $finish;
    end
    initial
        begin
            $dumpfile("calcBary_Test.vcd");
            $dumpvars(0,calcBary_Test);
            #1;
        end
    
endmodule 