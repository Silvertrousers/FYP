module face_culler(
    input wire [65:0] Pa,
    input wire [65:0] Pb,
    input wire [65:0] Pc,
    input wire Enable,
    input wire [1:0] Mode,
    input wire windingOrder,
    input wire origin_location,
    input wire areaSign,
    output wire cull
);
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
    reg signForCulling;
//    assign signForCulling = ({windingOrder, Mode[0]} == {ACW, F}) ? PLUS : (({windingOrder, Mode[0]} == {CW, F}) ? MINUS : (({windingOrder, Mode[0]} == {CW, B}) ? PLUS : MINUS));

// (windingOrder == ACW) ? (Mode[0] == F ? signForCulling = PLUS : {ACW, F}: signForCulling = PLUS) : ({ CW, F}: signForCulling = MINUS; { CW, B}: signForCulling = PLUS;) ;
    always @(windingOrder or Mode[0]) begin
        case({windingOrder, Mode[0]})
        //ACW = PLUS#
        //CW = MINUS
            {ACW, F}: signForCulling = PLUS;
            { CW, F}: signForCulling = MINUS;
            { CW, B}: signForCulling = PLUS;
            {ACW, B}: signForCulling = MINUS;
        endcase
    end
    

    assign cull = Enable && ((areaSign == signForCulling) || (Mode == FB));
    
endmodule