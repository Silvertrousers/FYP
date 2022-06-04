module triangle_pipe_Test#(
    parameter NOPERSPECTIVE = 'b0,
    parameter FLAT = 'b0,
    parameter PROVOKEMODE = 'b0,
    parameter VERTEXSIZE = 4'd7,
    parameter WINDINGORDER = 1'b0, //ACW
    parameter ORIGIN_LOCATION = 1'b0, //TL
    parameter FACE_CULLER_ENABLE = 1'b1,
    parameter MODE = 'b00, //Back
    parameter RESX = 32'd1920,
    parameter RESY = 32'd1080
)();
    
    
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 4;
    localparam FRAG_FIFODEPTH = (2**ADDR_WIDTH)*20; //fits 4 fragments
    localparam TRI_FIFODEPTH = (2**ADDR_WIDTH)*3*1; //fits 1 triangle

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
    wire done, ready;

    //ports from vertex attribute mem       
    wire [DATA_WIDTH-1:0] tri_fifo_rd_data;
    wire tri_fifo_rd_en;   
    reg [DATA_WIDTH-1:0] tri_fifo_wr_data;
    reg tri_fifo_wr_en; 
    
    wire tri_fifo_full; 
    wire tri_fifo_empty;
    wire tri_fifo_threshold; 
    wire tri_fifo_overflow; 
    wire tri_fifo_underflow;

    //ports to write to fragment fifo
    wire [DATA_WIDTH-1:0] frag_fifo_wr_data;
    wire frag_fifo_wr_en; 

    wire frag_fifo_full; 
    wire frag_fifo_empty;
    wire frag_fifo_threshold; 
    wire frag_fifo_overflow; 
    wire frag_fifo_underflow;

    reg noPerspective, flat, provokeMode, windingOrder, faceCullerEnable, origin_location;
    reg [ADDR_WIDTH-1:0] vertexSize;
    reg [1:0] Mode;
    reg [31:0] resx,resy;

triangle_pipe#(
    DATA_WIDTH,
    ADDR_WIDTH,      
    CYCLES_WAIT_FOR_RECIEVE
) DUT (
    clk, resetn, en, start, ready, done,

    //ports to write to fragment fifo
    frag_fifo_wr_data,
    frag_fifo_wr_en, 

    //fragment fifo control (unused for the moment) TODO: use these flags to control output
    frag_fifo_full, 
    frag_fifo_empty, 
    frag_fifo_threshold, 
    frag_fifo_overflow, 
    frag_fifo_underflow,

    //ports to read from triangle  fifo
    tri_fifo_rd_data,
    tri_fifo_rd_en, 

    //triangle fifo control (unused for the moment) TODO: use these flags to control output
    tri_fifo_full, 
    tri_fifo_empty, 
    tri_fifo_threshold, 
    tri_fifo_overflow, 
    tri_fifo_underflow,

    //flags
    noPerspective, flat, provokeMode, 
    windingOrder, vertexSize, faceCullerEnable, 
    Mode, origin_location,
    resx, resy
);

FIFO #(
    DATA_WIDTH,
    TRI_FIFODEPTH
) tri_FIFO (
    .data_out(tri_fifo_rd_data),
    .fifo_full(tri_fifo_full), 
    .fifo_empty(tri_fifo_empty), 
    .fifo_threshold(tri_fifo_threshold), 
    .fifo_overflow(tri_fifo_overflow), 
    .fifo_underflow(tri_fifo_underflow),
    .clk(clk), 
    .resetn(resetn), 
    .wr(tri_fifo_wr_en), 
    .rd(tri_fifo_rd_en), 
    .data_in(tri_fifo_wr_data)
);  

FIFO #(
    DATA_WIDTH,
    FRAG_FIFODEPTH
) frag_FIFO (
    .data_out(),
    .fifo_full(frag_fifo_full), 
    .fifo_empty(frag_fifo_empty), 
    .fifo_threshold(frag_fifo_threshold), 
    .fifo_overflow(frag_fifo_overflow), 
    .fifo_underflow(frag_fifo_underflow),
    .clk(clk), 
    .resetn(resetn), 
    .wr(frag_fifo_wr_en), 
    .rd(), 
    .data_in(frag_fifo_wr_data)
);  
    initial
        begin
            $display("{\"sim_log\": [");
            en = 1'b1;
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            #(PERIOD/2);
            
            // Pa = {ZeroFP, ZeroFP}; 
            // Pb = {ZeroFP, TwoFP};  
            // Pc = {FourFP, ZeroFP}; 
            
            tri_fifo_wr_en = 1'b1;
            tri_fifo_wr_data = ZeroFP;//v0.x
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v0.y
            #(PERIOD) tri_fifo_wr_data = OneFP;//v0.z
            #(PERIOD) tri_fifo_wr_data = OneFP;//v0.r
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v0.g
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v0.b
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v0.s
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v0.t

            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.x
            #(PERIOD) tri_fifo_wr_data = TwoFP;//v1.y
            #(PERIOD) tri_fifo_wr_data = OneFP;//v1.z
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.r
            #(PERIOD) tri_fifo_wr_data = OneFP;//v1.g
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.b
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.s
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.t

            #(PERIOD) tri_fifo_wr_data = FourFP;//v2.x
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v2.y
            #(PERIOD) tri_fifo_wr_data = OneFP;//v2.z
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v2.r
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v2.g
            #(PERIOD) tri_fifo_wr_data = OneFP;//v2.b
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.s
            #(PERIOD) tri_fifo_wr_data = ZeroFP;//v1.t


            #(PERIOD) start = 1'b1;
            tri_fifo_wr_en = 1'b0;
            

            noPerspective = NOPERSPECTIVE;
            flat = FLAT;
            provokeMode = PROVOKEMODE;
            vertexSize = VERTEXSIZE;
            windingOrder = WINDINGORDER;
            faceCullerEnable = FACE_CULLER_ENABLE;
            Mode = MODE;
            origin_location = ORIGIN_LOCATION;
            resx = RESX;
            resy = RESY;
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
    
    always @(posedge clk) begin
        if(frag_fifo_wr_en) begin
            $display("{\"label\":\"[fragment_write]\", \"data\":\"0x%0h\"},", frag_fifo_wr_data);
        end
    end
    always @(posedge clk) begin
        if(tri_fifo_rd_en) begin
            $display("{\"label\":\"[triangle_read]\", \"data\":\"0x%0h\"},", tri_fifo_rd_data);
        end
    end
    always@(negedge clk) begin
        if (done == 1'b1) begin
            $display("{\"label\":\"[message]\", \"data\":\"test finished for input combination\"}");
            $display("]}");
            $finish;
        end
    end

    initial 
        begin
            #TIMEOUT;
            $display("{\"label\":\"[message]\", \"data\":\"Simulation Timed Out :(\"}");
            $display("]}");
            $finish;
        end
    initial
        begin
            $dumpfile("triangle_pipe_Test.vcd");
            $dumpvars(0,triangle_pipe_Test);
            #1;
        end
endmodule
