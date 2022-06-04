module attrInterp(
    input wire clk,
    input wire resetn,
    input wire en,

    output reg inReady,
    input  wire inValid,
    output reg outValid,

    input wire [65:0] P, //x,y
    input wire [65:0] Pa, //x,y
    input wire [65:0] Pb, //x,y
    input wire [65:0] Pc, //x,y
    
    input wire [32:0] za,
    input wire [32:0] zb, 
    input wire [32:0] zc, 

    input wire [32:0] fa, 
    input wire [32:0] fb, 
    input wire [32:0] fc, 

    output wire [32:0] f,
    output wire [32:0] z,

    input wire [3:0] flags //isDepth, noPerspective, flat, provokeMode
);
    
    
    wire calcBaryReady, divReady, calcBaryOutValid; 

    
    reg isDepth, noPerspective, flat, provokeMode, inValidReg;
    reg [65:0] PReg, PaReg, PbReg, PcReg;
    reg [32:0] faReg, fbReg, fcReg, zaReg, zbReg, zcReg;
    always @(posedge clk or negedge resetn) begin
        if(resetn == 1'b0) begin
            faReg <= 'b0;
            fbReg <= 'b0;
            fcReg <= 'b0;
            zaReg <= 'b0;
            zbReg <= 'b0;
            zcReg <= 'b0;
            isDepth <= 'b0;
            noPerspective <= 'b0;
            flat<= 'b0;
            provokeMode <= 'b0;
            inValidReg <= 'b0;
            inReady <= 1'b1;
        end else begin
            calcBaryOutValidDelay1 <= calcBaryOutValid;
            if(inValid & inReady) begin
                faReg <= fa;
                fbReg <= fb;
                fcReg <= fc;
                zaReg <= za;
                zbReg <= zb;
                zcReg <= zc;
                isDepth <= flags[3]; 
                noPerspective <= flags[2];
                flat<= flags[1];
                provokeMode <= flags[0];
                inValidReg <= inValid;
                inReady <= 1'b0;
            end else begin
                inValidReg <= 1'b0;
            end
            if(outValid && ~inReady) begin
                inReady <= 1'b1;
            end
        end
    end

    always @(posedge clk or negedge resetn) begin
        if(resetn == 1'b0) begin
            outValid <= 1'b0;
        end else begin
            if (isDepth) begin
                outValid <= calcBaryOutValidDelay1;
            end else if(flat) begin
                outValid <= inValidReg;
                if(outValid) begin
                    outValid <= 1'b0;
                end
            end else if (noPerspective) begin
                outValid <= calcBaryOutValidDelay1;
            end else if (~noPerspective) begin
                outValid <= divOutValid;
            end 
        end
    end
    wire [32:0] a,b,c;
    calcBary calcBary(clk,(isDepth || ~flat),resetn,
                      P,Pa,Pb,Pc,a,b,c,calcBaryReady,
                      inValidReg,calcBaryOutValid);

    reg [32:0] aReg,bReg,cReg;
    reg calcBaryOutValidReg;
    always @(posedge clk or negedge resetn) begin
        if(resetn == 1'b0) begin
            aReg <= 1'b0;
            bReg <= 1'b0;
            cReg <= 1'b0;
            calcBaryOutValidReg <= 1'b0;
        end else begin
            if(calcBaryOutValid) begin
                aReg <= a;
                bReg <= b;
                cReg <= c;
                calcBaryOutValidReg <= calcBaryOutValid;
            end
        end
    end

    reg calcBaryOutValidDelay1;
    always @(posedge clk or negedge resetn) begin
        if(resetn == 1'b0) begin
            calcBaryOutValidDelay1 = 1'b0;
        end else begin
            calcBaryOutValidDelay1 <= /*~isDepth && */calcBaryOutValid;
        end
    end

    wire [32:0] fNoPersp, fPersp;
    depthInterpolator fInterp(clk,(en && ~isDepth),aReg,bReg,cReg,faReg,fbReg,fcReg,fNoPersp);
    depthInterpolator zInterp(clk,1'b1,aReg,bReg,cReg,zaReg,zbReg,zcReg,z);

    
    wire divOutValid;
    divSqrtRecFN_small#(8, 24, 0) div (
                .nReset(resetn),
                .clock(clk),
                .control(1'b0), 
                .inReady(divReady),
                .inValid(calcBaryOutValidDelay1),
                .sqrtOp(1'b0),
                .a(fNoPersp),
                .b(z),
                .roundingMode(`round_min),
                .outValid(divOutValid),
                .sqrtOpOut(),
                .out(fPersp),
                .exceptionFlags()
            );
    
    wire [32:0] f0,f1;
    assign f0 = noPerspective ? fNoPersp : fPersp;
    assign f1 = provokeMode ? fcReg : faReg;
    assign f = flat ? f1 : f0;
 
    
endmodule

module depthInterpolator(
    input wire clk,
    input wire en,
    input wire [32:0] a,
    input wire [32:0] b,
    input wire [32:0] c,
    input wire [32:0] za,
    input wire [32:0] zb,
    input wire [32:0] zc,
    output wire [32:0] out
);
    output wire [32:0] aMULza, bMULzb, cMULzc, aADDb;
    

    mulRecFN #(8,24) fpmula (.control(1'b0), .a(a), .b(za), .roundingMode(`round_min), .out(aMULza), .exceptionFlags());
    mulRecFN #(8,24) fpmulb (.control(1'b0), .a(b), .b(zb), .roundingMode(`round_min), .out(bMULzb), .exceptionFlags());
    mulRecFN #(8,24) fpmulc (.control(1'b0), .a(c), .b(zc), .roundingMode(`round_min), .out(cMULzc), .exceptionFlags());

    addRecFN #(8,24) fpadd1 (.control(1'b0), .subOp(1'b0), .a(aMULza), .b(bMULzb), .roundingMode(`round_min), .out(aADDb), .exceptionFlags());
    addRecFN #(8,24) fpadd2 (.control(1'b0), .subOp(1'b0), .a(cMULzc), .b(aADDb), .roundingMode(`round_min), .out(out), .exceptionFlags());
endmodule