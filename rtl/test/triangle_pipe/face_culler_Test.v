module face_culler_Test();

    localparam FourFP = 32'h40800000;
    localparam TwoFP = 32'h40000000;
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
     //areaSign
    localparam PLUS = 1'b0;
    localparam MINUS = 1'b1;

    //origin_location
    localparam TL = 1'b0;
    localparam BL = 1'b1;

    //windingOrder
    localparam CW = 1'b1 ;
    localparam ACW = 1'b0;

    //mode must be one of these as opposed to what I said in my orignal report
    localparam B = 'b00;
    localparam F = 'b01;
    localparam FB = 'b10;

    reg [63:0] Pa, Pb, Pc;
    wire [65:0] PaRecFN, PbRecFN, PcRecFN;
    reg Enable, windingOrder, origin_location;  
    reg [1:0] Mode;  
    wire cull;
    wire [32:0] TwoArecFN;

    fNToRecFN#(8,24) fNToRecFNax (Pa[63:32], PaRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNay (Pa[31:0], PaRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNbx (Pb[63:32], PbRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNby (Pb[31:0], PbRecFN[32:0]);
    fNToRecFN#(8,24) fNToRecFNcx (Pc[63:32], PcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNcy (Pc[31:0], PcRecFN[32:0]);

    calcArea Area(1'b0, 1'b1, 1'b1, PaRecFN, PbRecFN, PcRecFN, TwoArecFN);
    face_culler DUT(PaRecFN,PbRecFN,PcRecFN,Enable, Mode, windingOrder,origin_location, TwoArecFN[32],cull);

    initial begin
        $display("Starting");
        Enable = 1'b1; 
        Mode = {1'b0,B};
        windingOrder = ACW;
        origin_location = TL;
        //dont cull front facing, acw, TL 
        Pa = {ZeroFP, ZeroFP};  // 0,0
        Pb = {ZeroFP,  OneFP}; // 0,1
        Pc = { OneFP, ZeroFP}; //1,0
        #10 
        $display("cull,areaSign: (%b,%b)", cull, TwoArecFN[32]);
        if(~cull) begin
            $display("dont cull front facing, acw, TL tst passed");
        end
        #10
        // cull back facing, acw, TL 
        Pa = {ZeroFP, ZeroFP};  // 0,0
        Pb = { OneFP, ZeroFP}; //1,0
        Pc = {ZeroFP,  OneFP}; // 0,1
        #10 
        $display("cull,areaSign: (%b,%b)", cull, TwoArecFN[32]);
        if(cull) begin
            $display("cull back facing, acw, TL tst passed");
        end
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("face_culler_Test.vcd");
            $dumpvars(0,face_culler_Test);
            #1;
        end
endmodule