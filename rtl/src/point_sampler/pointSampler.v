module pointSampler(
    input wire [65:0] Pa,
    input wire [65:0] Pb,
    input wire [65:0] Pc,
    input wire [65:0] Pin,
    output wire [65:0] Pout,
    output wire inside,
    input wire windingOrder,
    input wire origin_location,
    input wire areaSign

);
//asumes tl for now, bl will invert winding order
    localparam CW = 1'b1 ;
    localparam ACW = 1'b0;

    //origin_location
    localparam TL = 1'b0;
    localparam BL = 1'b1;

    localparam FORWARDS = 1'b0;
    localparam BACKWARDS = 1'b1;

    localparam PLUS = 1'b0;
    localparam MINUS = 1'b1;

    reg for_or_back;
    always @(*) begin
        case({origin_location, windingOrder, areaSign})
            {TL, CW, PLUS}: for_or_back = FORWARDS;
            {TL, CW, MINUS}: for_or_back = BACKWARDS;
            {TL, ACW, PLUS}: for_or_back = BACKWARDS;
            {TL, ACW, MINUS}: for_or_back = FORWARDS;
            {BL, CW, PLUS}: for_or_back = BACKWARDS;
            {BL, CW, MINUS}: for_or_back = FORWARDS;
            {BL, ACW, PLUS}: for_or_back = FORWARDS;
            {BL, ACW, MINUS}: for_or_back = BACKWARDS;
        endcase
    end
    // E01(xp, yp) = (xp − xv0) ∗ (yv1 − yv0) − (yp − yv0) ∗ (xv1 − xv0)
    // E12(xp, yp) = (xp − xv1) ∗ (yv2 − yv1) − (yp − yv1) ∗ (xv2 − xv1)
    // E20(xp, yp) = (xp − xv2) ∗ (yv0 − yv2) − (yp − yv2) ∗ (xv0 − xv2)
    wire [32:0] outab, outbc, outca;
    halfSpaceEquation Eab(Pin,Pa,Pb,outab,lt0ab,gt0ab);
    halfSpaceEquation Ebc(Pin,Pb,Pc,outbc,lt0bc,gt0bc);
    halfSpaceEquation Eca(Pin,Pc,Pa,outca,lt0ca,gt0ca);
    wire antiClockInside, clockInside;
    assign antiClockInside = gt0ab && gt0bc && gt0ca; //this is the opposite of what it says in scratch a pixel but oh well
    assign clockInside = lt0ab && lt0bc && lt0ca;
    assign inside = (windingOrder ^ origin_location) ^ for_or_back ? clockInside : antiClockInside;
    assign Pout = Pin;
        
        
endmodule

module halfSpaceEquation(
    input wire [65:0] P, //x,y
    input wire [65:0] Pa, 
    input wire [65:0] Pb,
    output wire [32:0] out,
    output wire lt0,
    output wire gt0
);
    wire [32:0] xva, xvb, xp, yva, yvb, yp, sub1, sub2, sub3, sub4, mul1, mul2;
    assign xva = Pa[65:33];
    assign xvb = Pb[65:33];
    assign xp = P[65:33];
    assign yp = P[32:0];
    assign yva = Pa[32:0];
    assign yvb = Pb[32:0];
    

    // (xp − xva) ∗ (yvb − yva) − (yp − yva) ∗ (xvb − xva)
    addRecFN #(8,24) fpsub1 (.control(1'b0), .subOp(1'b1), .a(xp), .b(xva), .roundingMode(`round_min), .out(sub1), .exceptionFlags());
    addRecFN #(8,24) fpsub2 (.control(1'b0), .subOp(1'b1), .a(yvb), .b(yva), .roundingMode(`round_min), .out(sub2), .exceptionFlags());
    mulRecFN #(8,24) fpmul1 (.control(1'b0), .a(sub1), .b(sub2), .roundingMode(`round_min), .out(mul1), .exceptionFlags());

    addRecFN #(8,24) fpsub3 (.control(1'b0), .subOp(1'b1), .a(yp), .b(yva), .roundingMode(`round_min), .out(sub3), .exceptionFlags());
    addRecFN #(8,24) fpsub4 (.control(1'b0), .subOp(1'b1), .a(xvb), .b(xva), .roundingMode(`round_min), .out(sub4), .exceptionFlags());
    mulRecFN #(8,24) fpmul2 (.control(1'b0), .a(sub3), .b(sub4), .roundingMode(`round_min), .out(mul2), .exceptionFlags());
   
    addRecFN #(8,24) fpsub5 (.control(1'b0), .subOp(1'b1), .a(mul1), .b(mul2), .roundingMode(`round_min), .out(out), .exceptionFlags());

    assign lt0 = out[32];
    assign gt0 = (out != 33'b0) && ~lt0; // greater than 0 if not lt0 and neq0
endmodule
