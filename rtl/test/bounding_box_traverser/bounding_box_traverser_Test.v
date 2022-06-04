module bounding_box_traverser_Test#(
    parameter NOPERSPECTIVE = 'b0,
    parameter FLAT = 'b0,
    parameter PROVOKEMODE = 'b0,
    parameter VERTEXSIZE = 4'd15,
    parameter WINDINGORDER = 1'b1
)();
    
    
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 4;
    localparam FIFODEPTH = (2**ADDR_WIDTH)*4; //fits 4 fragments

    localparam CYCLES_WAIT_FOR_RECIEVE = 4'b0001;
    localparam CLOCKWISE =  1'b1;
    localparam ANTICLOCKWISE = 1'b0;
    localparam FourFP = 32'h40800000;
    localparam TwoFP = 32'h40000000;
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*10000;
    reg clk;
    reg resetn, en, start;
    wire done;

    reg [31:0] bb_t, bb_b, bb_l, bb_r;

    reg [63:0] Pa, Pb, Pc;
    wire [65:0] PaRecFN, PbRecFN, PcRecFN;

    //ports from vertex attribute mem       
    wire [2:0][DATA_WIDTH-1:0] vert_attr_rd_data;       
    wire [2:0][ADDR_WIDTH-1:0] vert_attr_rd_addr; 
    wire [2:0][0:0]            vert_attr_rd_en;   

    //ports to write to fragment fifo
    wire [DATA_WIDTH-1:0] frag_fifo_wr_data;       
    wire [ADDR_WIDTH-1:0] frag_fifo_wr_addr;
    wire frag_fifo_wr_en; 

    wire fifo_full; 
    wire fifo_empty;
    wire fifo_threshold; 
    wire fifo_overflow; 
    wire fifo_underflow;
    
    reg noPerspective, flat, provokeMode, windingOrder;
    reg [ADDR_WIDTH-1:0] vertexSize;

v0ROM #(DATA_WIDTH, ADDR_WIDTH)v0ROM_inst(
    vert_attr_rd_addr[0], 
    clk,   
    vert_attr_rd_en[0],        
    vert_attr_rd_data[0]
);
v1ROM #(DATA_WIDTH, ADDR_WIDTH)v1ROM_inst(
    vert_attr_rd_addr[1], 
    clk,   
    vert_attr_rd_en[1],        
    vert_attr_rd_data[1]
);
v2ROM #(DATA_WIDTH, ADDR_WIDTH)v2ROM_inst(
    vert_attr_rd_addr[2], 
    clk,   
    vert_attr_rd_en[2],        
    vert_attr_rd_data[2]
);

fNToRecFN#(8,24) fNToRecFNax (Pa[63:32], PaRecFN[65:33]);
fNToRecFN#(8,24) fNToRecFNay (Pa[31:0], PaRecFN[32:0]);
fNToRecFN#(8,24) fNToRecFNbx (Pb[63:32], PbRecFN[65:33]);
fNToRecFN#(8,24) fNToRecFNby (Pb[31:0], PbRecFN[32:0]);
fNToRecFN#(8,24) fNToRecFNcx (Pc[63:32], PcRecFN[65:33]);
fNToRecFN#(8,24) fNToRecFNcy (Pc[31:0], PcRecFN[32:0]);

wire [32:0] test1, test6, test4, test5;
wire [31:0] test2, test3;
wire [65:0] ptest = 66'h0ff0000007f800000;
fNToRecFN#(8,24) fNToRecFNtest1 (HalfFP, test1);
recFNToFN#(8,24)fNToRecFNtest2(ptest[65:33],test2);
recFNToFN#(8,24)fNToRecFNtest3(ptest[32:0],test3);

fNToRecFN#(8,24)fNToRecFNtest4(ZeroFP,test4);
fNToRecFN#(8,24)fNToRecFNtest5(OneFP,test5);
fNToRecFN#(8,24)fNToRecFNtest6(TwoFP,test6);

bounding_box_traverser#(
    DATA_WIDTH,
    ADDR_WIDTH,      
    CYCLES_WAIT_FOR_RECIEVE
) DUT (
    clk, resetn, en,
    start, done,
    bb_t, bb_b, bb_l, bb_r,
    PaRecFN, PbRecFN, PcRecFN,

    vert_attr_rd_data, vert_attr_rd_addr, vert_attr_rd_en,   
    frag_fifo_wr_data, frag_fifo_wr_addr, frag_fifo_wr_en, 
    fifo_full, fifo_empty, fifo_threshold, fifo_overflow, fifo_underflow,
    noPerspective,
    flat,
    provokeMode,
    windingOrder,
    vertexSize //index of last element of vertex so vertexSize(xyzrgb) = 5, vertexSize(xyzrgbst) = 7
);

FIFO #(
    DATA_WIDTH,
    FIFODEPTH
) frag_FIFO (
    .data_out(),
    .fifo_full(fifo_full), 
    .fifo_empty(fifo_empty), 
    .fifo_threshold(fifo_threshold), 
    .fifo_overflow(fifo_overflow), 
    .fifo_underflow(fifo_underflow),
    .clk(clk), 
    .resetn(resetn), 
    .wr(frag_fifo_wr_en), 
    .rd(), 
    .data_in(frag_fifo_wr_data)
);  
    initial
        begin
            en = 1'b1;
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            #(PERIOD/2);
            
            start = 1'b1;
    
            bb_t = 'b0;
            bb_b = 'b10;
            bb_l = 'b0;
            bb_r = 'b100;
            //clockwise winding order
            Pa = {ZeroFP, ZeroFP}; 
            Pb = {ZeroFP, TwoFP};  
            Pc = {FourFP, ZeroFP}; 

            noPerspective = NOPERSPECTIVE;
            flat = FLAT;
            provokeMode = PROVOKEMODE;
            vertexSize = VERTEXSIZE;
            windingOrder = WINDINGORDER;
            #PERIOD;
            start = 1'b0;

        end
    always 
        begin
            clk = 1'b1; 
            #(PERIOD/2);
            clk = 1'b0;
            #(PERIOD/2);
        end
    
    always @(frag_fifo_wr_en, frag_fifo_wr_data, frag_fifo_wr_addr) begin
        if(frag_fifo_wr_en) begin
            $display("[fragment_write] data:0x%0h, addr:0x%0h ", frag_fifo_wr_data, frag_fifo_wr_addr);
        end
    end
    always@(negedge clk) begin
        if (done == 1'b1) begin
            $display("test finished for input combination");
            $finish;
        end
    end

    initial 
        begin
            #TIMEOUT;
            $display("Simulation Timed Out :(");
            $finish;
        end
    initial
        begin
            $dumpfile("bounding_box_traverser_Test.vcd");
            $dumpvars(0,bounding_box_traverser_Test);
            #1;
        end
endmodule
