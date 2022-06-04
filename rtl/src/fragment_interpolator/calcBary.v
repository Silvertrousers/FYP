module calcBary(
    input wire clk,
    input wire enable,
    input wire resetn,
    input wire [65:0] P, //x,y
    input wire [65:0] P1, //x,y
    input wire [65:0] P2, //x,y
    input wire [65:0] P3, //x,y
    output reg [32:0] a,
    output reg [32:0] b,
    output reg [32:0] c,

    output wire inReady,
    input  wire inValid,
    output wire outValid
);
    //inValid comes high when input is valid, on next edge that input is consumed
    wire [3:0][32:0] A;
    wire [2:0][32:0] OUT;
    wire [2:0] divOutValid;
    reg [2:0] divOutValidReg;
    reg inValidDelay1, inValidDelay2;
    always @(posedge clk or negedge resetn) begin
        if(resetn == 1'b0) begin
            inValidDelay1 = 1'b0;
            inValidDelay2 = 1'b0;
        end else begin
            inValidDelay1 <= inValid;
            inValidDelay2 <= inValidDelay1;
        end
    end
    
    calcArea A1(clk, enable, resetn, P, P2, P3, A[0]);
    calcArea A2(clk, enable, resetn, P1, P, P3, A[1]);
    calcArea A3(clk, enable, resetn, P1, P2, P, A[2]);
    calcArea A4(clk, enable, resetn, P1, P2, P3, A[3]);
    generate
        genvar i;
        for(i=0; i<3; i=i+1) begin
            divSqrtRecFN_small#(8, 24, 0) div (
                .nReset(resetn),
                .clock(clk),
                .control(1'b0), 
                .inReady(inReady),
                .inValid(inValidDelay2),
                .sqrtOp(1'b0),
                .a(A[i]),
                .b(A[3]),
                .roundingMode(`round_min),
                .outValid(divOutValid[i]),
                .sqrtOpOut(),
                .out(OUT[i]),
                .exceptionFlags()
            );
            
        end
    endgenerate
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            a <= 'b0;
            b <= 'b0;
            c <= 'b0;
            divOutValidReg <= 'b0;
        end else begin
            if(divOutValid[0] == 1'b1) begin
                divOutValidReg[0] <= 1'b1;
                a <= OUT[0];
            end
            if(divOutValid[1] == 1'b1) begin
                divOutValidReg[1] <= 1'b1;
                b <= OUT[1];
            end
            if(divOutValid[2] == 1'b1) begin
                divOutValidReg[2] <= 1'b1;
                c <= OUT[2];
            end
            if (divOutValidReg == 3'b111) begin
                divOutValidReg <= 'b0;
            
            end
        end
    end
    assign outValid = divOutValidReg[0] && divOutValidReg[1] && divOutValidReg[2];
endmodule


module calcArea(
    input wire clk,
    input wire enable,
    input wire resetn,
    input wire [65:0] P1, //x,y
    input wire [65:0] P2, //x,y
    input wire [65:0] P3, //x,y
    output wire [32:0] TwoArecFN
);
    

    wire [32:0] x1 = P1[65:33]; 
    wire [32:0] x2 = P2[65:33];
    wire [32:0] x3 = P3[65:33];
    wire [32:0] y1 = P1[32:0];
    wire [32:0] y2 = P2[32:0];
    wire [32:0] y3 = P3[32:0];


    
    wire [32:0] y2SUBy3;
    wire [32:0] y3SUBy1; 
    wire [32:0] y1SUBy2;
    addRecFN #(8,24) fpsub1 (.control(1'b0), .subOp(1'b1), .a(y2), .b(y3), .roundingMode(`round_min), .out(y2SUBy3), .exceptionFlags());
    addRecFN #(8,24) fpsub2 (.control(1'b0), .subOp(1'b1), .a(y3), .b(y1), .roundingMode(`round_min), .out(y3SUBy1), .exceptionFlags());
    addRecFN #(8,24) fpsub3 (.control(1'b0), .subOp(1'b1), .a(y1), .b(y2), .roundingMode(`round_min), .out(y1SUBy2), .exceptionFlags());

    wire [32:0] y2SUBy3MULx1, y3SUBy1MULx2, y1SUBy2MULx3;
    mulRecFN #(8,24) fpmul1 (.control(1'b0), .a(y2SUBy3), .b(x1), .roundingMode(`round_min), .out(y2SUBy3MULx1), .exceptionFlags());
    mulRecFN #(8,24) fpmul2 (.control(1'b0), .a(y3SUBy1), .b(x2), .roundingMode(`round_min), .out(y3SUBy1MULx2), .exceptionFlags());
    mulRecFN #(8,24) fpmul3 (.control(1'b0), .a(y1SUBy2), .b(x3), .roundingMode(`round_min), .out(y1SUBy2MULx3), .exceptionFlags());

    wire [32:0] ADD1, ADD2;
    addRecFN #(8,24) fpadd1 (.control(1'b0), .subOp(1'b0), .a(y2SUBy3MULx1), .b(y3SUBy1MULx2), .roundingMode(`round_min), .out(ADD1), .exceptionFlags());
    addRecFN #(8,24) fpadd2 (.control(1'b0), .subOp(1'b0), .a(ADD1), .b(y1SUBy2MULx3), .roundingMode(`round_min), .out(TwoArecFN), .exceptionFlags());

endmodule