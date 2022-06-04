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
    always @(*) begin
        case({origin_location, windingOrder, Mode[0]})
            {TL, ACW, F}: signForCulling = MINUS;
            {BL,  CW, F}: signForCulling = MINUS;
            {TL,  CW, B}: signForCulling = MINUS;
            {BL, ACW, B}: signForCulling = MINUS;
            default:      signForCulling = PLUS;
        endcase
    end
    

    assign cull = Enable && ((areaSign == signForCulling) || (Mode == FB));
    
endmodule