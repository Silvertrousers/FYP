module attrInterp_Test();
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h0;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam EighthFP = 32'h3e000000;
    localparam Point375 = 32'h3ec00000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*400;

    reg clk, resetn, en, inValid, isDepth,noPerspective,flat,provokeMode;
    wire inReady, outValid;
    wire [3:0] flags;
    wire [31:0] f,z;
    reg [95:0] zabc, fabc;
    reg [63:0] P, Pa, Pb, Pc;

    wire [32:0] fRecFN,zRecFN;
    wire [98:0] zabcRecFN, fabcRecFN;
    wire [65:0] PRecFN, PaRecFN, PbRecFN, PcRecFN;
    fNToRecFN#(8,24) fNToRecFN1 (zabc[95:64], zabcRecFN[98:66]);
    fNToRecFN#(8,24) fNToRecFN2 (zabc[63:32], zabcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN3 (zabc[31:0], zabcRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFN4 (fabc[95:64], fabcRecFN[98:66]);
    fNToRecFN#(8,24) fNToRecFN5 (fabc[63:32], fabcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN6 (fabc[31:0], fabcRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFN7 (P[63:32], PRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN8 (P[31:0], PRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFN9 (Pa[63:32], PaRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN10 (Pa[31:0], PaRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFn11 (Pb[63:32], PbRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN12 (Pb[31:0], PbRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFN13 (Pc[63:32], PcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFN14 (Pc[31:0], PcRecFN[32:0]);

    recFNToFN#(8,24) recFNToFN15 (fRecFN, f);
    recFNToFN#(8,24) recFNToFN16 (zRecFN, z);

    assign flags[3] = isDepth;
    assign flags[2] = noPerspective;
    assign flags[1] = flat;
    assign flags[0] = provokeMode;

    attrInterp DUT (
        clk, resetn, en, 
        inReady,inValid,outValid, 
        PRecFN, PaRecFN, PbRecFN, PcRecFN, 
        zabcRecFN[98:66],zabcRecFN[65:33],zabcRecFN[32:0], 
        fabcRecFN[98:66],fabcRecFN[65:33],fabcRecFN[32:0],
        fRecFN, zRecFN,
        flags
    );
    always 
        begin
            clk = 1'b1; 
            #(PERIOD/2);
            clk = 1'b0;
            #(PERIOD/2);
        end
    initial
        begin
            inValid = 1'b0;
            en = 1'b0;
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            #(PERIOD/2);
            inValid = 1'b1;
            en = 1'b1;
            P = {QuarterFP,QuarterFP};
            Pa = {ZeroFP,ZeroFP};
            Pb = {OneFP,ZeroFP};
            Pc = {ZeroFP,OneFP};
            zabc = {OneFP,OneFP,OneFP};
            fabc = {HalfFP,HalfFP,HalfFP};
            isDepth = 1'b0;
            noPerspective = 1'b0;
            flat = 1'b0;
            provokeMode = 1'b0; 
        end
    always@(negedge clk) begin
        if (outValid == 1'b1) begin
                $display("f,z == %h,%h", f,z);
                if({f, z} != {HalfFP,OneFP})  begin
                    $display("test failed for input combination");
                end else begin
                    $display("test passed for input combination");
                
                end

                $finish;
            end
    end
    initial begin
        #TIMEOUT;
        $display("Simulation Timed Out :(");
        $finish;
    end
    initial
        begin
            $dumpfile("attrInterp_Test.vcd");
            $dumpvars(0,attrInterp_Test);
            #1;
        end
endmodule