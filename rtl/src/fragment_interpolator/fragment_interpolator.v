

module fragment_interpolator #(
    parameter DATA_WIDTH=32,    //width of data bus
    parameter ADDR_WIDTH=4,      //to fit, xyzwrgbst and 7 extra attrs
    parameter CYCLES_WAIT_FOR_RECIEVE=4'b0001 //number of cycles it takes to recieve an item from mem, min 1, this means you send  a req, then not the next cycles but the one after that the item is recieved
)(
    input wire clk,
    input wire resetn,
    input wire en,

    //ports to fragment mem
    output reg [DATA_WIDTH-1:0] frag_attr_wr_data,       
    output reg [ADDR_WIDTH-1:0] frag_attr_wr_addr, 
    output reg                  frag_attr_wr_en,  

    //ports from vertex attribute mem       
    input  wire [2:0][DATA_WIDTH-1:0] vert_attr_rd_data,       
    output reg  [2:0][ADDR_WIDTH-1:0] vert_attr_rd_addr, 
    output reg  [2:0][0:0]            vert_attr_rd_en,    

    //from point sampler (inside detection will be 
    //done by top module and will be used to start this one)
    input wire [65:0] Pin,

    input  wire start,
    output reg ready,
    output reg done,   
    
    // flags
    input  wire noPerspective,
    input  wire flat,
    input  wire provokeMode,
    input  wire [ADDR_WIDTH-1:0] vertexSize //index of last element of vertex so vertexSize(xyzrgb) = 5, vertexSize(xyzrgbst) = 7
);
    reg isDepth;
    reg [63:0] P0, P1, P2;
    reg [65:0] P;
    
    reg [31:0] z0, z1, z2, f0, f1, f2;
    wire [31:0] f,z;
    reg attrInterp_inValid;
    wire attrInterp_inReady, attrInterp_outValid, attrInterp_en;
    assign attrInterp_en = en;
    

    // states of the processing stage (grey code)
    localparam        IDLE = 3'b000;
    localparam     REQUEST = 3'b001;
    localparam WAIT_FOR_RECIEVE = 3'b011;
    localparam     RECIEVE = 3'b010;
    localparam INTERPOLATE = 3'b110;
    localparam       WRITE = 3'b111;
    
    reg [2:0] processingStage;

    // state of what is being processed (grey code)
    localparam PROC_X = 2'b00;
    localparam PROC_Y = 2'b01;
    localparam PROC_Z = 2'b11;
    localparam PROC_F = 2'b10;
    reg [1:0] thingBeingProcessed;

    reg [ADDR_WIDTH-1:0] rd_wr_addr;
    reg [3:0] passedCyclesWaitForRecieve;

    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            thingBeingProcessed <= PROC_X;
            processingStage <= IDLE;
            rd_wr_addr <= 'b0;
            passedCyclesWaitForRecieve <= 4'b0001;
            P <= 'b0;
            done <= 1'b0;
            ready <= 1'b0;
            isDepth <= 1'b0;
        end else begin
            case (processingStage)
                IDLE: begin
                    rd_wr_addr <= 'b0;
                    done <= 1'b0;
                    if(start) begin 
                        P <= Pin;
                        processingStage <= REQUEST; 
                        ready <= 1'b0;
                    end else begin
                        ready <= 1'b1;
                    end
                end
                REQUEST: processingStage <= WAIT_FOR_RECIEVE;   
                WAIT_FOR_RECIEVE: begin
                    if(passedCyclesWaitForRecieve == CYCLES_WAIT_FOR_RECIEVE) begin
                        processingStage <= RECIEVE;
                        passedCyclesWaitForRecieve <= 4'b0001;
                    end else begin
                        processingStage <= WAIT_FOR_RECIEVE;
                        passedCyclesWaitForRecieve <= passedCyclesWaitForRecieve + 4'b0001;
                    end
                end
                RECIEVE:
                    case (thingBeingProcessed)
                        PROC_X: begin
                            thingBeingProcessed <= PROC_Y;
                            processingStage <= REQUEST;
                            rd_wr_addr <= 'b01;
                        end
                        PROC_Y: begin
                            thingBeingProcessed <= PROC_Z;
                            processingStage <= REQUEST;
                            rd_wr_addr <= 'b10;
                        end
                        PROC_Z: begin
                            isDepth <= 1'b1;
                            processingStage <= INTERPOLATE;
                        end
                        PROC_F: begin
                            isDepth <= 1'b0;
                            processingStage <= INTERPOLATE;
                        end
                    endcase

                INTERPOLATE: begin
                    if(attrInterp_outValid) begin
                        processingStage <= WRITE;
                    end
                end
                WRITE: begin
                    
                    if(rd_wr_addr < vertexSize) begin
                        rd_wr_addr <= rd_wr_addr + 'b1;
                        processingStage <= REQUEST;
                        if(thingBeingProcessed == PROC_Z) begin
                            thingBeingProcessed <= PROC_F;  
                        end
                           
                    end
                    if(rd_wr_addr == vertexSize) begin
                        thingBeingProcessed <= PROC_X;
                        rd_wr_addr <= 'b0;
                        done <= 1'b1;
                        processingStage <= IDLE;
                    end

                end
            endcase
        end

    end

    reg attrInterp_resetn;
    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            frag_attr_wr_data <= 'b0;       
            frag_attr_wr_addr <= 'b0; 
            frag_attr_wr_en <= 'b0;  
            vert_attr_rd_addr [0]  <= 'b0; 
            vert_attr_rd_en   [0] <= 'b0;
            vert_attr_rd_addr [1]  <= 'b0; 
            vert_attr_rd_en   [1] <= 'b0;
            vert_attr_rd_addr [2]  <= 'b0; 
            vert_attr_rd_en   [2] <= 'b0;
            
            attrInterp_inValid <= 1'b0;
            attrInterp_resetn <= 1'b1;


            thingBeingProcessed <= PROC_X;
            processingStage <= IDLE;

            P0 <= 'b0;
            P1 <= 'b0;
            P2 <= 'b0;
            f0 <= 1'b0;
            f1 <= 1'b0;
            f2 <= 1'b0;
            z0 <= 1'b0;
            z1 <= 1'b0;
            z2 <= 1'b0;
        end else begin
            case (processingStage)
                IDLE: begin
                    vert_attr_rd_addr<= 'b0; 
                    vert_attr_rd_en <= 'b0;  
                    frag_attr_wr_en <= 1'b0;
                end

                REQUEST: begin
                    vert_attr_rd_addr[0] <= rd_wr_addr;  
                    vert_attr_rd_addr[1] <= rd_wr_addr; 
                    vert_attr_rd_addr[2] <= rd_wr_addr; 
                    vert_attr_rd_en <= 3'b111;  
                    frag_attr_wr_en <= 1'b0;
                    attrInterp_resetn <= 1'b0;
                end          
                RECIEVE: begin
                    attrInterp_resetn <= 1'b1;
                    vert_attr_rd_en <= 3'b000;
                    case(thingBeingProcessed)
                        PROC_X: begin
                            P0[63:32] <= vert_attr_rd_data[0];
                            P1[63:32] <= vert_attr_rd_data[1];
                            P2[63:32] <= vert_attr_rd_data[2];
                        end
                        PROC_Y: begin
                            P0[31:0] <= vert_attr_rd_data[0];
                            P1[31:0] <= vert_attr_rd_data[1];
                            P2[31:0] <= vert_attr_rd_data[2];
                        end
                        PROC_Z: begin
                            z0 <= vert_attr_rd_data[0];
                            z1 <= vert_attr_rd_data[1];
                            z2 <= vert_attr_rd_data[2];

                        end
                        PROC_F: begin
                            f0 <= vert_attr_rd_data[0];
                            f1 <= vert_attr_rd_data[1];
                            f2 <= vert_attr_rd_data[2];
                        end
                    endcase
                end
                INTERPOLATE: begin
                    if(attrInterp_inReady) begin
                        //pass inputs to attr interp done in last stage, but theyre only accepted when the following happens 
                        // set inValid set enable
                        attrInterp_inValid <= 1'b1;
                    end else begin
                        attrInterp_inValid <= 1'b0;
                    end
                    

                end
                WRITE: begin
                    case (thingBeingProcessed)
                    
                        PROC_X: begin
                            
                        end
                        PROC_Y: begin
                            
                        end
                        PROC_Z: begin
                            frag_attr_wr_data <= z; 
                            frag_attr_wr_addr <= rd_wr_addr; 
                            frag_attr_wr_en <= 1'b1;
                        end
                        PROC_F: begin
                            frag_attr_wr_data <= f; 
                            frag_attr_wr_addr <= rd_wr_addr; 
                            frag_attr_wr_en <= 1'b1;
                        end
                    endcase
                    
                end
            endcase
        end

    end
    
    //need converters
    wire [65:0]PRecFN, PaRecFN, PbRecFN, PcRecFN;
    wire [32:0] zaRecFN, zbRecFN, zcRecFN, faRecFN, fbRecFN, fcRecFN, fRecFN, zRecFN;
    
    fNToRecFN#(8,24) fNToRecFNz0 (z0, zaRecFN);
    fNToRecFN#(8,24) fNToRecFNz1 (z1, zbRecFN);
    fNToRecFN#(8,24) fNToRecFNz2 (z2, zcRecFN);

    fNToRecFN#(8,24) fNToRecFNf0 (f0, faRecFN);
    fNToRecFN#(8,24) fNToRecFNf1 (f1, fbRecFN);
    fNToRecFN#(8,24) fNToRecFNf2 (f2, fcRecFN);

    fNToRecFN#(8,24) fNToRecFNP0x (P0[63:32], PaRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNP0y (P0[31:0], PaRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFnP1x (P1[63:32], PbRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNP1y (P1[31:0], PbRecFN[32:0]);

    fNToRecFN#(8,24) fNToRecFNP2x (P2[63:32], PcRecFN[65:33]);
    fNToRecFN#(8,24) fNToRecFNP2y (P2[31:0], PcRecFN[32:0]);

    attrInterp attrInterp_inst(
        .clk(clk), 
        .resetn(reset && attrInterp_resetn), //negative edge will be transmitted by which ever goes negative
        .en(attrInterp_en),
        .inReady(attrInterp_inReady), 
        .inValid(attrInterp_inValid), 
        .outValid(attrInterp_outValid),

        .P(P), //x,y
        .Pa(PaRecFN), //x,y
        .Pb(PbRecFN), //x,y
        .Pc(PcRecFN), //x,y
        
        .za(zaRecFN), 
        .zb(zbRecFN),
        .zc(zcRecFN), 

        .fa(faRecFN), 
        .fb(fbRecFN), 
        .fc(fcRecFN), 

        .f(fRecFN),
        .z(zRecFN),
        .flags({isDepth, noPerspective, flat, provokeMode})
    );

    recFNToFN#(8,24) recFNToFN15 (fRecFN, f);
    recFNToFN#(8,24) recFNToFN16 (zRecFN, z);
    always @(*) begin
        //$display("[frag_interp_state] proc_stage,thing proc: %b, %b",processingStage,thingBeingProcessed);
        //$display("{\"label\":\"[frag_interp_done]\", \"done\":\"%b\"}", done);
        
    end
endmodule