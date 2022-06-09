// TODO: change frag interp and tb to take triangle coords as input port, not from mem
// TODO: add support for case where point being sampled in on the triangle edge

module bounding_box_traverser#(
    parameter DATA_WIDTH=32,    //width of data bus
    parameter ADDR_WIDTH=4,      //to fit, xyzwrgbst and 7 extra attrs
    parameter CYCLES_WAIT_FOR_RECIEVE=4'b0001 //number of cycles it takes to recieve an item from mem, min 1, this means you send  a req, then not the next cycles but the one after that the item is recieved
)(
    input wire clk,
    input wire resetn,
    input wire en,
    input wire start,
    output reg done,

    input wire [31:0] bb_t,
    input wire [31:0] bb_b,
    input wire [31:0] bb_l,
    input wire [31:0] bb_r,

    input wire [65:0] Pa,
    input wire [65:0] Pb,
    input wire [65:0] Pc,

    //ports from vertex attribute mem       
    input  wire [2:0][DATA_WIDTH-1:0] vert_attr_rd_data,       
    output wire  [2:0][ADDR_WIDTH-1:0] vert_attr_rd_addr, 
    output wire  [2:0][0:0]            vert_attr_rd_en,   

    //ports to write to fragment fifo
    output reg [DATA_WIDTH-1:0] frag_fifo_wr_data,       
    output reg [ADDR_WIDTH-1:0] frag_fifo_wr_addr,
    output reg frag_fifo_wr_en, 

    //fifo control (unused for the moment) TODO: use these flags to control output
    input wire fifo_full, 
    input wire fifo_empty, 
    input wire fifo_threshold, 
    input wire fifo_overflow, 
    input wire fifo_underflow,

    // flags
    input  wire noPerspective,
    input  wire flat,
    input  wire provokeMode,
    input wire windingOrder,
    input wire origin_location,
    input  wire [ADDR_WIDTH-1:0] vertexSize //index of last element of vertex so vertexSize(xyzrgb) = 5, vertexSize(xyzrgbst) = 7
);



    reg [2:0] state;
    localparam IDLE = 'b000;
    localparam P_GEN = 'b001;
    localparam P_SAMPLE = 'b011;
    localparam X_WRITE = 'b010;
    localparam Y_WRITE = 'b110;
    localparam FRAGINTERP_WRITEOUT = 'b111; //fill one side of buffer with interp and write out other side of buffer

    
    reg [31:0] xmax, xmin, ymax, ymin;
    reg [31:0] xcount, ycount;
    reg [65:0] PaReg, PbReg, PcReg;

    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            PaReg <= 'b0;
            PbReg <= 'b0;
            PcReg <= 'b0;

        end else begin
            if(state == IDLE) begin
                if(start) begin
                    PaReg <= Pa;
                    PbReg <= Pb;
                    PcReg <= Pc;
                end
            end
        end
    end

    reg x_write, y_write;
    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            state <= 'b0;
            fragInterp_start <= 1'b0;
            fragment_interpolator_resetn <= 1'b1;
            x_write <= 1'b0;
            y_write <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    if(start) begin
                        state <= P_GEN;
                        
                    end
                end
                P_GEN: begin
                    state <= P_SAMPLE;
                    fragment_interpolator_resetn <= 1'b0; //reset frag interp
                    
                end
                P_SAMPLE: begin
                    state <= X_WRITE;  
                    fragment_interpolator_resetn <= 1'b1;              
                    
                end
                X_WRITE: begin
                    
                    if(inside) begin
                        x_write <= 1'b1;
                        state <= Y_WRITE;
                    end else begin
                        if ((xcount == (xmax - 'b1)) && (ycount == (ymax - 'b1))) begin
                            state <= IDLE;
                        end else begin
                            state <= P_GEN;
                        end
                    end
                    
                end
                Y_WRITE: begin
                    //$display("Y_WRITE");
                    if(inside) begin
                        x_write <= 1'b0;
                        y_write <= 1'b1;
                    end
                    state <= FRAGINTERP_WRITEOUT;
                    if(fragInterp_ready && ~fragInterp_done) begin
                        fragInterp_start <= 1'b1;
                    end
                end
                FRAGINTERP_WRITEOUT: begin
                    //$display("FRAGINTERP_WRITEOUT");
                    x_write <= 1'b0;
                    y_write <= 1'b0;
                    if(fragInterp_done) begin
                        if ((xcount == (xmax - 'b1)) && (ycount == (ymax - 'b1))) begin
                            
                            state <= IDLE;
                            
                        end else begin
                            state <= P_GEN;    
                        end
                    end
    
                    fragInterp_start <= 1'b0;
                end
            endcase
        end
    end

    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            xmax  <= 'b0;
            xmin  <= 'b0;
            ymax  <= 'b0;
            ymin  <= 'b0;
            xcount<= 'b0;
            ycount<= 'b0;
            done  <= 'b0;
        end else begin
            case(state)
                IDLE: begin
                    if(start) begin
                        xmax  <= bb_r;
                        xmin  <= bb_l;
                        ymax  <= bb_b;
                        ymin  <= bb_t;
                        xcount<= bb_l;
                        ycount<= bb_t;
                        
                    end
                    done <= 1'b0;
                end
                X_WRITE: begin
                    if(~inside) begin
                        if ((xcount == (xmax - 'b1)) && (ycount == (ymax - 'b1))) begin
                            //$display("XWRITE im done, %h, %h, %h, %h",xcount,xmax, ycount, ymax);
                            done <= 1'b1;
                        end else if (xcount == (xmax - 'b1)) begin
                            xcount <= xmin;
                            ycount <= ycount + 'b1; 
                        end else if (xcount < xmax) begin
                            xcount <= xcount + 'b1; 
                        end else if (ycount == (ymax - 'b1)) begin
                            ycount <= ymin; 
                        end
                    end
                end
                FRAGINTERP_WRITEOUT: begin
                    if(fragInterp_done) begin
                        if ((xcount == (xmax - 'b1)) && (ycount == (ymax - 'b1))) begin
                            //$display("FRAGINTERP_WRITEOUT im done");
                            done <= 1'b1;
                        end else if (xcount == (xmax - 'b1)) begin
                            xcount <= xmin;
                            ycount <= ycount + 'b1; 
                        end else if (xcount < xmax) begin
                            xcount <= xcount + 'b1; 
                        end else if (ycount == (ymax - 'b1)) begin
                            ycount <= ymin; 
                        end
                    end
                end
            endcase     
        end
    end

   
    
    wire [65:0] P;
    wire [31:0] xcountFP, ycountFP;
    wire [32:0] xcountRecFP, ycountRecFP;

    localparam HALF_RecFn = 33'h07f800000;
    //not signed since pixel cood space starts at 0,0 in the top left
    int2fp32 xcount2FN(xcount,xcountFP);
    fNToRecFN#(8,24) xcountFP2xcountRecFP (xcountFP, xcountRecFP);
    addRecFN #(8,24) x_plus_half (.control(1'b0), .subOp(1'b0), .a(xcountRecFP), .b(HALF_RecFn), .roundingMode(`round_min), .out(P[65:33]), .exceptionFlags());

    int2fp32 ycount2FN(ycount,ycountFP);
    fNToRecFN#(8,24) ycountFP2ycountRecFP (ycountFP, ycountRecFP);
    addRecFN #(8,24) y_plus_half (.control(1'b0), .subOp(1'b0), .a(ycountRecFP), .b(HALF_RecFn), .roundingMode(`round_min), .out(P[32:0]), .exceptionFlags());


    wire inside;
    wire [65:0] P_pointSamp_fragInterp;
    pointSampler pointSampler_inst (
        .Pa(PaReg),
        .Pb(PbReg),
        .Pc(PcReg),
        .Pin(P),
        .Pout(P_pointSamp_fragInterp),
        .inside(inside),
        .windingOrder(windingOrder),
        .origin_location(origin_location)
    );


    
    reg fragInterp_start, fragment_interpolator_resetn;
    wire fragInterp_done, fragInterp_ready;
    wire [DATA_WIDTH-1:0] frag_attr_wr_data;       
    wire [ADDR_WIDTH-1:0] frag_attr_wr_addr;
    wire frag_attr_wr_en;

    fragment_interpolator #(
        DATA_WIDTH, ADDR_WIDTH, CYCLES_WAIT_FOR_RECIEVE
    ) fragment_interpolator_inst (
        .clk(clk),
        .resetn(resetn && fragment_interpolator_resetn),
        .en(en),

        .frag_attr_wr_data(frag_attr_wr_data),       
        .frag_attr_wr_addr(frag_attr_wr_addr), 
        .frag_attr_wr_en(frag_attr_wr_en),  
        
        .vert_attr_rd_data(vert_attr_rd_data),       
        .vert_attr_rd_addr(vert_attr_rd_addr), 
        .vert_attr_rd_en(vert_attr_rd_en),    

        .Pin(P_pointSamp_fragInterp),

        .start(fragInterp_start),
        .ready(fragInterp_ready),
        .done(fragInterp_done),   
        
        .noPerspective(noPerspective),
        .flat(flat),
        .provokeMode(provokeMode),
        .vertexSize(vertexSize) 
    );

    always @(*) begin
        if(~x_write && ~y_write) begin
            frag_fifo_wr_data = frag_attr_wr_data;
            frag_fifo_wr_addr = frag_attr_wr_addr;
            frag_fifo_wr_en = frag_attr_wr_en;
        end else if(x_write && ~y_write) begin
            frag_fifo_wr_data = xcount;
            frag_fifo_wr_addr = 'b0;
            frag_fifo_wr_en = 1'b1;
        end else if(~x_write && y_write) begin
            frag_fifo_wr_data = ycount;
            frag_fifo_wr_addr = 'b1;
            frag_fifo_wr_en = 1'b1; 
        end else begin
            frag_fifo_wr_data = 'b0;
            frag_fifo_wr_addr = 'b0;
            frag_fifo_wr_en = 1'b1; 
        end
    end


endmodule