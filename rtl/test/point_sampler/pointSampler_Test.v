module pointSampler_Test();
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h0;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam EighthFP = 32'h3e000000;
    localparam Point375 = 32'h3ec00000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*100;
    localparam CLOCKWISE = 1'b1 ;
    localparam ANTICLOCKWISE = 1'b0;

    reg windingOrder;
    wire  inside;
    wire [63:0] Pout;
    wire [65:0] PoutRecFN;
    reg [63:0] P, Pa, Pb, Pc;
    wire [65:0] PRecFN, PaRecFN, PbRecFN, PcRecFN;
    fNToRecFN#(8,24) fNToRecFNPy (P[31:0], PRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNPx (P[63:32], PRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNPay (Pa[31:0], PaRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNPax (Pa[63:32], PaRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNPby (Pb[31:0], PbRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNPbx (Pb[63:32], PbRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNPcy (Pc[31:0], PcRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNPcx (Pc[63:32], PcRecFN[65:33]);

    pointSampler DUT(PaRecFN,PbRecFN,PcRecFN,PRecFN,
                     PoutRecFN,inside,windingOrder);

    fNToRecFN#(8,24) fNToRecFNPouty (PoutRecFN[32:0], Pout[31:0]);
    fNToRecFN#(8,24) fNToRecFNPoutx (PoutRecFN[65:33], Pout[63:32]);
    initial
        begin
            
            
            P = {QuarterFP,QuarterFP};
            Pa = {ZeroFP,ZeroFP};
            Pb = {OneFP,ZeroFP};
            Pc = {ZeroFP,OneFP};
            windingOrder = CLOCKWISE;
            
            if(~inside)  begin
                $display("test failed for input combination");
            end else begin
                $display("test passed for input combination");
            end

            P = {QuarterFP,QuarterFP};
            Pa = {ZeroFP,ZeroFP};
            Pb = {ZeroFP,OneFP};
            Pc = {OneFP,ZeroFP};
            windingOrder = ANTICLOCKWISE;
            if(~inside)  begin
                $display("test failed for input combination");
            end else begin
                $display("test passed for input combination");
            end
            $finish;
        end
        
     initial begin
        #TIMEOUT;
        $display("Simulation Timed Out :(");
        $finish;
    end
    initial
        begin
            $dumpfile("pointSampler_Test.vcd");
            $dumpvars(0,pointSampler_Test);
            #1;
        end
endmodule