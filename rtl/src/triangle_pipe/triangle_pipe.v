module triangle_pipe#(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,      
    parameter CYCLES_WAIT_FOR_RECIEVE = 4'b0001
    
)(
    input wire clk,
    input wire resetn,
    input wire en,
    input wire start,
    output reg done,
    output reg ready,

    //ports to write to fragment fifo
    output wire [DATA_WIDTH-1:0] frag_fifo_wr_data,
    output wire frag_fifo_wr_en, 

    //fragment fifo control (unused for the moment) TODO: use these flags to control output
    input wire frag_fifo_full, 
    input wire frag_fifo_empty, 
    input wire frag_fifo_threshold, 
    input wire frag_fifo_overflow, 
    input wire frag_fifo_underflow,

    //ports to read from triangle  fifo
    input wire [DATA_WIDTH-1:0] tri_fifo_rd_data,
    output wire tri_fifo_rd_en, 

    //triangle fifo control (unused for the moment) TODO: use these flags to control output
    input wire tri_fifo_full, 
    input wire tri_fifo_empty, 
    input wire tri_fifo_threshold, 
    input wire tri_fifo_overflow, 
    input wire tri_fifo_underflow,

    //flags
    input  wire noPerspective,
    input  wire flat,
    input  wire provokeMode,
    input wire windingOrder,
    input  wire [ADDR_WIDTH-1:0] vertexSize,
    input wire faceCullerEnable,
    input wire [1:0] Mode,
    input wire origin_location,
    input wire [31:0] resx,
    input wire [31:0] resy
);
    wire bounding_box_traverser_done;
    wire [65:0] Pa, Pb, Pc;
    wire [63:0] PaFN, PbFN, PcFN;
    reg [63:0] PaFNReg, PbFNReg, PcFNReg;
    reg startTraversal, doneCull;
    wire startCull;
    wire [32:0] TwoA;
    wire cull;
    
    wire [31:0] bb_t,bb_b,bb_l,bb_r;

    wire [2:0][DATA_WIDTH-1:0] vert_attr_wr_data;       
    wire [2:0][ADDR_WIDTH-1:0] vert_attr_wr_addr; 
    wire [2:0][0:0]            vert_attr_wr_en;  
    wire [2:0][DATA_WIDTH-1:0] vert_attr_rd_data;       
    wire [2:0][ADDR_WIDTH-1:0] vert_attr_rd_addr; 
    wire [2:0][0:0]            vert_attr_rd_en; 

    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            ready <= 1'b1;
            done <= 1'b0;
            PaFNReg <= 'b0;
            PbFNReg <= 'b0;
            PcFNReg <= 'b0;
        end else begin
            if(start) begin 
                ready <= 1'b0;
            end
            if(done) begin
                ready <= 1'b1;
                done <= 1'b0;
            end else if((bounding_box_traverser_done || (doneCull && cull) ) && ~ready) begin
                done <= 1'b1;
                PaFNReg <= 'b0;
                PbFNReg <= 'b0;
                PcFNReg <= 'b0;
            end
            if(startCull) begin
                PaFNReg <= PaFN;
                PbFNReg <= PbFN;
                PcFNReg <= PcFN;
                doneCull <= 'b1;
            end else begin
                doneCull <= 'b0;
            end
            if(frag_fifo_threshold && doneCull) begin
                startTraversal <= 1'b1;
            end else begin
                startTraversal <= 1'b0;
            end
        end
    end
      

    triangleFetcher #(
        DATA_WIDTH,  
        ADDR_WIDTH
    ) triangleFetcher_inst (
        .clk(clk),
        .resetn(resetn),
        .en(en),
        .startFetch(start),
        .cull(cull),
        .startCull(startCull),

        //ports from vertex attribute mem       
        .vert_attr_wr_data(vert_attr_wr_data),       
        .vert_attr_wr_addr(vert_attr_wr_addr), 
        .vert_attr_wr_en(vert_attr_wr_en),   

        //ports to read from triangle  fifo
        .tri_fifo_rd_data(tri_fifo_rd_data), 
        .tri_fifo_rd_en(tri_fifo_rd_en), 

        //fifo control (unused for the moment) TODO: use these flags to control output
        .tri_fifo_full(tri_fifo_full), 
        .tri_fifo_empty(tri_fifo_empty), 
        .tri_fifo_threshold(tri_fifo_threshold), 
        .tri_fifo_overflow(tri_fifo_overflow), 
        .tri_fifo_underflow(tri_fifo_underflow),

        .Pa(PaFN),
        .Pb(PbFN),
        .Pc(PcFN),

        .vertexSize(vertexSize)
        
    );


    fNToRecFN#(8,24) fNToRecFNax (PaFNReg[63:32], Pa[65:33]);
    fNToRecFN#(8,24) fNToRecFNay (PaFNReg[31:0], Pa[32:0]);
    fNToRecFN#(8,24) fNToRecFNbx (PbFNReg[63:32], Pb[65:33]);
    fNToRecFN#(8,24) fNToRecFNby (PbFNReg[31:0], Pb[32:0]);
    fNToRecFN#(8,24) fNToRecFNcx (PcFNReg[63:32], Pc[65:33]);
    fNToRecFN#(8,24) fNToRecFNcy (PcFNReg[31:0], Pc[32:0]);

    
    calcArea calcArea_inst (
        .clk(clk),
        .enable(en),
        .resetn(resetn),
        .P1(Pa),
        .P2(Pb),
        .P3(Pc),
        .TwoArecFN(TwoA)
    );
    

    face_culler face_culler_inst (
        .Pa(Pa),
        .Pb(Pb),
        .Pc(Pc),
        .Enable(faceCullerEnable),
        .Mode(Mode),
        .windingOrder(windingOrder),
        .origin_location(origin_location),
        .areaSign(TwoA[32]),
        .cull(cull)
    );
    boundingBoxGen boundingBoxGen_inst(
        .Pa(Pa),
        .Pb(Pb),
        .Pc(Pc),
        .Top(bb_t),
        .Bottom(bb_b),
        .Right(bb_r),
        .Left(bb_l),
        .resx(resx),
        .resy(resy)
    );


    bounding_box_traverser#(
        DATA_WIDTH, 
        ADDR_WIDTH,
        CYCLES_WAIT_FOR_RECIEVE //number of cycles it takes to recieve an item from mem, min 1, this means you send  a req, then not the next cycles but the one after that the item is recieved
    ) bounding_box_traverser_inst (
        .clk(clk),
        .resetn(resetn),
        .en(en),
        .start(startTraversal),
        .done(bounding_box_traverser_done),

        .bb_t(bb_t),
        .bb_b(bb_b),
        .bb_l(bb_l),
        .bb_r(bb_r),

        .Pa(Pa),
        .Pb(Pb),
        .Pc(Pc),

        //ports from vertex attribute mem       
        .vert_attr_rd_data(vert_attr_rd_data),       
        .vert_attr_rd_addr(vert_attr_rd_addr), 
        .vert_attr_rd_en(vert_attr_rd_en),   

        //ports to write to fragment fifo
        .frag_fifo_wr_data(frag_fifo_wr_data),       
        .frag_fifo_wr_addr(),
        .frag_fifo_wr_en(frag_fifo_wr_en), 

        //fragment fifo control (unused for the moment) TODO: use these flags to control output
        .fifo_full(frag_fifo_full), 
        .fifo_empty(frag_fifo_empty), 
        .fifo_threshold(frag_fifo_threshold), 
        .fifo_overflow(frag_fifo_overflow),
        .fifo_underflow(frag_fifo_underflow),

        // flags
        .areaSign(TwoA[32]),
        .noPerspective(noPerspective),
        .flat(flat),
        .provokeMode(provokeMode),
        .windingOrder(windingOrder),
        .origin_location(origin_location),
        .vertexSize(vertexSize)
    ); 

    simple_ram_dual_clock #(
        DATA_WIDTH,                 
        ADDR_WIDTH                  
    ) v0_mem (
        .data(vert_attr_wr_data[0]),       
        .read_addr(vert_attr_rd_addr[0]),  
        .write_addr(vert_attr_wr_addr[0]), 
        .we(vert_attr_wr_en[0]),         
        .read_clk(clk),  
        .write_clk(clk), 
        .re(vert_attr_rd_en[0]),        
        .q(vert_attr_rd_data[0])         
    );
    simple_ram_dual_clock #(
        DATA_WIDTH,                 
        ADDR_WIDTH                  
    ) v1_mem (
        .data(vert_attr_wr_data[1]),       
        .read_addr(vert_attr_rd_addr[1]),  
        .write_addr(vert_attr_wr_addr[1]), 
        .we(vert_attr_wr_en[1]),         
        .read_clk(clk),  
        .write_clk(clk), 
        .re(vert_attr_rd_en[1]),        
        .q(vert_attr_rd_data[1])         
    );
    simple_ram_dual_clock #(
        DATA_WIDTH,                 
        ADDR_WIDTH                  
    ) v2_mem (
        .data(vert_attr_wr_data[2]),       
        .read_addr(vert_attr_rd_addr[2]),  
        .write_addr(vert_attr_wr_addr[2]), 
        .we(vert_attr_wr_en[2]),         
        .read_clk(clk),  
        .write_clk(clk), 
        .re(vert_attr_rd_en[2]),        
        .q(vert_attr_rd_data[2])         
    );

endmodule