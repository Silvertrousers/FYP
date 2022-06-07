//works for single fifo
//TODO: see if it works for multi pipe systems
// TODO: still issues with cube since faces are getting culled, time to debug now?



module top_Test#(
    parameter DATA_WIDTH = 32,
    parameter MAIN_MEM_ADDR_WIDTH = 32,
    parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 3,   
    parameter CYCLES_WAIT_FOR_RECIEVE = 4'b0001,
    parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = 'b0,
    
    parameter FIFO_MAX_FRAGMENTS = 16, // must be power of 2
    parameter FIFO_MAX_TRIANGLES = 1, // must be power of 2

    parameter NUM_T_PIPES = 1,
    
    parameter NOPERSPECTIVE = 'b0,
    parameter FLAT = 'b0,
    parameter PROVOKEMODE = 'b0,
    parameter VERTEXSIZE = 4'd7, //number of attributes - 1
    parameter WINDINGORDER = 1'b0, //ACW
    parameter ORIGIN_LOCATION = 1'b0, //TL
    parameter FACE_CULLER_ENABLE = 1'b1,
    parameter MODE = 'b00, //Back
    parameter RESX = 16'd1920,
    parameter RESY = 16'd1080,
    parameter TOTAL_NUM_TRIS = 32'd2,

    parameter I_ARRAY_PTR = 32'd0,
    parameter V_ARRAY_PTR = 32'd4,
    parameter F_ARRAY_PTR = 32'h32,
    parameter POLY_STORAGE_STRUCTURE = 'b1 //anticlockwise by default
)();
    localparam CLOCKWISE =  1'b1;
    localparam ANTICLOCKWISE = 1'b0;
    localparam TwentyFP = 'h41a00000;
    localparam ThirteenFP = 'h41500000;
    localparam TenFP = 32'h41200000;
    localparam NineFP = 32'h41100000;
    localparam FourFP = 32'h40800000;
    localparam TwoFP = 32'h40000000;
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*100000;
    localparam TRI_MEM_FIFODEPTH = (2**LOCAL_VERTEX_MEM_ADDR_WIDTH)*3*5;
    localparam INDIVIDUAL_TRIANGLES = 1'b0;
    localparam TRIANGLE_STRIP = 1'b1;

    reg clk;
    reg resetn; 
    reg en; 
    reg start;
    wire done;
    wire ready;

    wire [DATA_WIDTH-1:0] tri_mem_rd_data;      
    wire [MAIN_MEM_ADDR_WIDTH-1:0] tri_mem_rd_addr; 
    wire [0:0]            tri_mem_rd_en;
    reg [DATA_WIDTH-1:0] tri_mem_wr_data;      
    reg [MAIN_MEM_ADDR_WIDTH-1:0] tri_mem_wr_addr; 
    reg [0:0]            tri_mem_wr_en;

    wire [DATA_WIDTH-1:0] frag_mem_wr_data;       
    wire [MAIN_MEM_ADDR_WIDTH-1:0] frag_mem_wr_addr; 
    wire [0:0]            frag_mem_wr_en;

    //instruction inputs
    reg [DATA_WIDTH-1:0] i_array_ptr;
    reg [DATA_WIDTH-1:0] v_array_ptr;
    reg [DATA_WIDTH-1:0] f_array_ptr;
    reg [31:0] ctrl_reg0; //reg noPerspective, flat, provokeMode, windingOrder, faceCullerEnable, origin_location, [1:0] Mode, [ADDR_WIDTH-1:0] vertexSize;
    reg [31:0] ctrl_reg1;
    reg [DATA_WIDTH-1:0] res_reg; //resx 16 bit, resy 16 bit


    top#(
        DATA_WIDTH,
        MAIN_MEM_ADDR_WIDTH,
        LOCAL_VERTEX_MEM_ADDR_WIDTH, 
        CYCLES_WAIT_FOR_RECIEVE,
        MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE,
        FIFO_MAX_FRAGMENTS,
        FIFO_MAX_TRIANGLES,
        NUM_T_PIPES
    ) DUT (
        clk, resetn, en, 
        start, done, ready,

        tri_mem_rd_data, tri_mem_rd_addr, tri_mem_rd_en,
        frag_mem_wr_data, frag_mem_wr_addr, frag_mem_wr_en,

        //instruction inputs
        i_array_ptr,
        v_array_ptr,
        f_array_ptr,
        ctrl_reg0, //reg noPerspective, flat, provokeMode, windingOrder, faceCullerEnable, origin_location, [1:0] Mode, [ADDR_WIDTH-1:0] vertexSize;
        ctrl_reg1,
        res_reg //resx 16 bit, resy 16 bit
    );

    tri_ram_dual_clock_32_32 tri_mem(
        .data(tri_mem_wr_data),       //data to be written
        .read_addr(tri_mem_rd_addr),  //address for read operation
        .write_addr(tri_mem_wr_addr), //address for write operation
        .we(tri_mem_wr_en),         //write enable signal
        .read_clk(clk),   //clock signal for read operation
        .write_clk(clk),  //clock signal for write operation
        .re(tri_mem_rd_en),         //read enable signal
        .q(tri_mem_rd_data)           //read data
    );
    // FIFO #(
    //     DATA_WIDTH,
    //     TRI_MEM_FIFODEPTH 
    // ) tri_FIFO (
    //     .data_out(tri_mem_rd_data),
    //     .fifo_full(), 
    //     .fifo_empty(), 
    //     .fifo_threshold(), 
    //     .fifo_overflow(), 
    //     .fifo_underflow(),
    //     .clk(clk), 
    //     .resetn(resetn), 
    //     .wr(tri_mem_wr_en), 
    //     .rd(tri_mem_rd_en), 
    //     .data_in(tri_mem_wr_data)
    // );  
    frag_ram_dual_clock_32_32 frag_mem(
        .data(frag_mem_wr_data),       //data to be written
        .read_addr(),  //address for read operation
        .write_addr(frag_mem_wr_addr), //address for write operation
        .we(frag_mem_wr_en),         //write enable signal
        .read_clk(clk),   //clock signal for read operation
        .write_clk(clk),  //clock signal for write operation
        .re(),         //read enable signal
        .q()           //read data
    );
    initial
        begin
            $dumpfile("top_Test.vcd");
            $dumpvars(0,top_Test);
            en = 1'b1;
            resetn = 1'b1;
            #PERIOD;
            $display("{\"sim_log\": [");
            
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            #(PERIOD);
            //instruction inputs
            
    

            
            
`ifdef TWO_TRI_HANDWRITTEN_STRIP
            ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = WINDINGORDER;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = 'd7;
            ctrl_reg1[15:0] = 'd2;
            ctrl_reg1[16] = TRIANGLE_STRIP;

            res_reg = {16'd10,16'd10}; //resx 16 bit, resy 16 bit

            i_array_ptr = 'd0;
            v_array_ptr = 'd4;
            f_array_ptr = 'h24;
            
            #(PERIOD);
            tri_mem_wr_en = 1'b1;
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'h0;
            #(PERIOD);
            tri_mem_wr_data = ZeroFP;//v0.x
            tri_mem_wr_addr = 'h4;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.y
            tri_mem_wr_addr = 'h5;
            #(PERIOD);
            tri_mem_wr_data = OneFP;//v0.z
            tri_mem_wr_addr = 'h6;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v0.r
            tri_mem_wr_addr = 'h7;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.g
            tri_mem_wr_addr = 'h8;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.b
            tri_mem_wr_addr = 'h9;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.s
            tri_mem_wr_addr = 'ha;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v0.t
            tri_mem_wr_addr = 'hb;

            #PERIOD
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'h1;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.x
            tri_mem_wr_addr = 'hc;
            #(PERIOD); 
            tri_mem_wr_data = NineFP;//v1.y
            tri_mem_wr_addr = 'hd;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v1.z
            tri_mem_wr_addr = 'he;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.r
            tri_mem_wr_addr = 'hf;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v1.g
            tri_mem_wr_addr = 'h10;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.b
            tri_mem_wr_addr = 'h11;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.s
            tri_mem_wr_addr = 'h12;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v1.t
            tri_mem_wr_addr = 'h13;

            #PERIOD
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'h2;
            #(PERIOD); 
            tri_mem_wr_data = TenFP;//v2.x
            tri_mem_wr_addr = 'h14;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.y
            tri_mem_wr_addr = 'h15;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v2.z
            tri_mem_wr_addr = 'h16;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.r
            tri_mem_wr_addr = 'h17;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.g
            tri_mem_wr_addr = 'h18;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v2.b
            tri_mem_wr_addr = 'h19;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.s
            tri_mem_wr_addr = 'h1a;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v1.t
            tri_mem_wr_addr = 'h1b;
            #(PERIOD);

            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'h3;
            #(PERIOD);
            tri_mem_wr_data = TenFP;//v0.x
            tri_mem_wr_addr = 'h1c;
            #(PERIOD); 
            tri_mem_wr_data = NineFP;//v0.y
            tri_mem_wr_addr = 'h1d;
            #(PERIOD);
            tri_mem_wr_data = OneFP;//v0.z
            tri_mem_wr_addr = 'h1e;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v0.r
            tri_mem_wr_addr = 'h1f;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.g
            tri_mem_wr_addr = 'h20;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.b
            tri_mem_wr_addr = 'h21;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.s
            tri_mem_wr_addr = 'h22;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v0.t
            tri_mem_wr_addr = 'h23;
            #(PERIOD);
`endif
`ifdef THREE_TRI_HANDWRITTEN_STRIP
            ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = WINDINGORDER;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = VERTEXSIZE;
            ctrl_reg1[15:0] = 'd3;
            ctrl_reg1[16] = TRIANGLE_STRIP;

            res_reg = {16'd20,16'd20}; //resx 16 bit, resy 16 bit

            i_array_ptr = 'h0;
            v_array_ptr = 'h5;
            f_array_ptr = 'h2d;
            
            #(PERIOD);
            tri_mem_wr_en = 1'b1;
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'h0;
            #(PERIOD);
            tri_mem_wr_data = ZeroFP;//v0.x
            tri_mem_wr_addr = 'h5;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.y
            tri_mem_wr_addr = 'h6;
            #(PERIOD);
            tri_mem_wr_data = OneFP;//v0.z
            tri_mem_wr_addr = 'h7;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v0.r
            tri_mem_wr_addr = 'h8;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.g
            tri_mem_wr_addr = 'h9;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.b
            tri_mem_wr_addr = 'ha;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.s
            tri_mem_wr_addr = 'hb;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v0.t
            tri_mem_wr_addr = 'hc;

            #PERIOD
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'h1;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.x
            tri_mem_wr_addr = 'hd;
            #(PERIOD); 
            tri_mem_wr_data = NineFP;//v1.y
            tri_mem_wr_addr = 'he;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v1.z
            tri_mem_wr_addr = 'hf;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.r
            tri_mem_wr_addr = 'h10;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v1.g
            tri_mem_wr_addr = 'h11;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.b
            tri_mem_wr_addr = 'h12;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.s
            tri_mem_wr_addr = 'h13;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v1.t
            tri_mem_wr_addr = 'h14;

            #PERIOD
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'h2;
            #(PERIOD); 
            tri_mem_wr_data = TenFP;//v2.x
            tri_mem_wr_addr = 'h15;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.y
            tri_mem_wr_addr = 'h16;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v2.z
            tri_mem_wr_addr = 'h17;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.r
            tri_mem_wr_addr = 'h18;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v2.g
            tri_mem_wr_addr = 'h19;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v2.b
            tri_mem_wr_addr = 'h1a;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v1.s
            tri_mem_wr_addr = 'h1b;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v1.t
            tri_mem_wr_addr = 'h1c;
            #(PERIOD);

            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'h3;
            #(PERIOD);
            tri_mem_wr_data = TenFP;//v0.x
            tri_mem_wr_addr = 'h1d;
            #(PERIOD); 
            tri_mem_wr_data = NineFP;//v0.y
            tri_mem_wr_addr = 'h1e;
            #(PERIOD);
            tri_mem_wr_data = OneFP;//v0.z
            tri_mem_wr_addr = 'h1f;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v0.r
            tri_mem_wr_addr = 'h20;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.g
            tri_mem_wr_addr = 'h21;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.b
            tri_mem_wr_addr = 'h22;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.s
            tri_mem_wr_addr = 'h23;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v0.t
            tri_mem_wr_addr = 'h24;

            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'h4;
            #(PERIOD);
            tri_mem_wr_data = TwentyFP;//v0.x 
            tri_mem_wr_addr = 'h25;
            #(PERIOD); 
            tri_mem_wr_data = ThirteenFP;//v0.y 
            tri_mem_wr_addr = 'h26;
            #(PERIOD);
            tri_mem_wr_data = OneFP;//v0.z
            tri_mem_wr_addr = 'h27;
            #(PERIOD); 
            tri_mem_wr_data = OneFP;//v0.r
            tri_mem_wr_addr = 'h28;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.g
            tri_mem_wr_addr = 'h29;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.b
            tri_mem_wr_addr = 'h2a;
            #(PERIOD); 
            tri_mem_wr_data = ZeroFP;//v0.s
            tri_mem_wr_addr = 'h2b;
            #(PERIOD); 
            tri_mem_wr_data = 'h123;//v0.t
            tri_mem_wr_addr = 'h2c;
            #(PERIOD);
`endif
`ifdef TWO_TRI_HANDWRITTEN_INDIVIDUAL
        ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = WINDINGORDER;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
        ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = 'd7;
        ctrl_reg1[15:0] = 'd2;
        ctrl_reg1[16] = INDIVIDUAL_TRIANGLES;

        res_reg = {16'd10,16'd10}; //resx 16 bit, resy 16 bit

        i_array_ptr = 'd0;
        v_array_ptr = 'd6;
        f_array_ptr = 'h26;
        
        #(PERIOD);
        tri_mem_wr_en = 1'b1;
        tri_mem_wr_data = 'h0;
        tri_mem_wr_addr = 'h0;
        #(PERIOD);
        tri_mem_wr_data = 'h1;
        tri_mem_wr_addr = 'h1;
        #(PERIOD);
        tri_mem_wr_data = 'h2;
        tri_mem_wr_addr = 'h2;
        #(PERIOD);
        tri_mem_wr_data = 'h2;
        tri_mem_wr_addr = 'h3;
        #(PERIOD);
        tri_mem_wr_data = 'h1;
        tri_mem_wr_addr = 'h4;
        #(PERIOD);
        tri_mem_wr_data = 'h3;
        tri_mem_wr_addr = 'h5;

        #(PERIOD);
        tri_mem_wr_data = ZeroFP;//v0.x
        tri_mem_wr_addr = 'h6;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.y
        tri_mem_wr_addr = 'h7;
        #(PERIOD);
        tri_mem_wr_data = OneFP;//v0.z
        tri_mem_wr_addr = 'h8;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v0.r
        tri_mem_wr_addr = 'h9;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.g
        tri_mem_wr_addr = 'ha;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.b
        tri_mem_wr_addr = 'hb;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.s
        tri_mem_wr_addr = 'hc;
        #(PERIOD); 
        tri_mem_wr_data = 'h123;//v0.t
        tri_mem_wr_addr = 'hd;

        
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v1.x
        tri_mem_wr_addr = 'he;
        #(PERIOD); 
        tri_mem_wr_data = TwoFP;//v1.y
        tri_mem_wr_addr = 'hf;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v1.z
        tri_mem_wr_addr = 'h10;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v1.r
        tri_mem_wr_addr = 'h11;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v1.g
        tri_mem_wr_addr = 'h12;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v1.b
        tri_mem_wr_addr = 'h13;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v1.s
        tri_mem_wr_addr = 'h14;
        #(PERIOD); 
        tri_mem_wr_data = 'h123;//v1.t
        tri_mem_wr_addr = 'h15;

        
        #(PERIOD); 
        tri_mem_wr_data = FourFP;//v2.x
        tri_mem_wr_addr = 'h16;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v2.y
        tri_mem_wr_addr = 'h17;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v2.z
        tri_mem_wr_addr = 'h18;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v2.r
        tri_mem_wr_addr = 'h19;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v2.g
        tri_mem_wr_addr = 'h1a;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v2.b
        tri_mem_wr_addr = 'h1b;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v1.s
        tri_mem_wr_addr = 'h1c;
        #(PERIOD); 
        tri_mem_wr_data = 'h123;//v1.t
        tri_mem_wr_addr = 'h1d;

        
        #(PERIOD);
        tri_mem_wr_data = FourFP;//v0.x
        tri_mem_wr_addr = 'h1e;
        #(PERIOD); 
        tri_mem_wr_data = TwoFP;//v0.y
        tri_mem_wr_addr = 'h1f;
        #(PERIOD);
        tri_mem_wr_data = OneFP;//v0.z
        tri_mem_wr_addr = 'h20;
        #(PERIOD); 
        tri_mem_wr_data = OneFP;//v0.r
        tri_mem_wr_addr = 'h21;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.g
        tri_mem_wr_addr = 'h22;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.b
        tri_mem_wr_addr = 'h23;
        #(PERIOD); 
        tri_mem_wr_data = ZeroFP;//v0.s
        tri_mem_wr_addr = 'h24;
        #(PERIOD); 
        tri_mem_wr_data = 'h123;//v0.t
        tri_mem_wr_addr = 'h25;
`endif
`ifdef GENERATED_CUBE

            ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = CLOCKWISE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = 'd7;
            
            ctrl_reg1[16] = INDIVIDUAL_TRIANGLES;
           ctrl_reg1[15:0] = 'd12;
            res_reg[31:16] = 100;
            res_reg[15:0] = 100;
            i_array_ptr = 'd0;
            v_array_ptr = 'd37;
            f_array_ptr = 'd102;
            #PERIOD;
            tri_mem_wr_en = 1'b1;
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd0;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd1;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd2;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd3;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd4;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd5;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd6;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd7;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd8;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd9;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd10;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd11;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd12;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd13;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd14;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd15;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd16;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd17;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd18;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd19;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd20;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd21;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd22;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd23;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd24;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd25;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd26;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd27;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd28;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd29;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd30;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd31;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd32;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd33;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd34;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd35;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd37;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd38;
            #(PERIOD);
            tri_mem_wr_data = 'h3f800000;
            tri_mem_wr_addr = 'd39;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd40;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd41;
            #(PERIOD);
            tri_mem_wr_data = 'h42280000;
            tri_mem_wr_addr = 'd42;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd43;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd44;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd45;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd46;
            #(PERIOD);
            tri_mem_wr_data = 'h3f800000;
            tri_mem_wr_addr = 'd47;
            #(PERIOD);
            tri_mem_wr_data = 'h42340000;
            tri_mem_wr_addr = 'd48;
            #(PERIOD);
            tri_mem_wr_data = 'h41f00000;
            tri_mem_wr_addr = 'd49;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd50;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd51;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd52;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd53;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd54;
            #(PERIOD);
            tri_mem_wr_data = 'h3f800000;
            tri_mem_wr_addr = 'd55;
            #(PERIOD);
            tri_mem_wr_data = 'h436a0000;
            tri_mem_wr_addr = 'd56;
            #(PERIOD);
            tri_mem_wr_data = 'h42cc0000;
            tri_mem_wr_addr = 'd57;
            #(PERIOD);
            tri_mem_wr_data = 'h42cc0000;
            tri_mem_wr_addr = 'd58;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd59;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd60;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd61;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd62;
            #(PERIOD);
            tri_mem_wr_data = 'hbf800000;
            tri_mem_wr_addr = 'd63;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd64;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd65;
            #(PERIOD);
            tri_mem_wr_data = 'h42540000;
            tri_mem_wr_addr = 'd66;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd67;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd68;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd69;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd70;
            #(PERIOD);
            tri_mem_wr_data = 'hbf800000;
            tri_mem_wr_addr = 'd71;
            #(PERIOD);
            tri_mem_wr_data = 'h42340000;
            tri_mem_wr_addr = 'd72;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd73;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd74;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd75;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd76;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd77;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd78;
            #(PERIOD);
            tri_mem_wr_data = 'h3f800000;
            tri_mem_wr_addr = 'd79;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd80;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd81;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd82;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd83;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd84;
            #(PERIOD);
            tri_mem_wr_data = 'h41c8020c;
            tri_mem_wr_addr = 'd85;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd86;
            #(PERIOD);
            tri_mem_wr_data = 'hbf800000;
            tri_mem_wr_addr = 'd87;
            #(PERIOD);
            tri_mem_wr_data = 'h423c0000;
            tri_mem_wr_addr = 'd88;
            #(PERIOD);
            tri_mem_wr_data = 'h40a00000;
            tri_mem_wr_addr = 'd89;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd90;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd91;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd92;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd93;
            #(PERIOD);
            tri_mem_wr_data = 'h42960083;
            tri_mem_wr_addr = 'd94;
            #(PERIOD);
            tri_mem_wr_data = 'hbf800000;
            tri_mem_wr_addr = 'd95;
            #(PERIOD);
            tri_mem_wr_data = 'h437e0000;
            tri_mem_wr_addr = 'd96;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd97;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd98;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd99;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd100;
`endif
`ifdef GENERATED_CUBE_ROTATED_0_45_45

            ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = CLOCKWISE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
            ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = 'd7;
            
            ctrl_reg1[16] = INDIVIDUAL_TRIANGLES;
            
            ctrl_reg1[15:0] = 'd12;
            res_reg[31:16] = 100;
            res_reg[15:0] = 100;
            i_array_ptr = 'd0;
            v_array_ptr = 'd37;
            f_array_ptr = 'd102;
            #PERIOD;
            tri_mem_wr_en = 1'b1;
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd0;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd1;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd2;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd3;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd4;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd5;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd6;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd7;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd8;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd9;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd10;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd11;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd12;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd13;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd14;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd15;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd16;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd17;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd18;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd19;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd20;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd21;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd22;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd23;
            #(PERIOD);
            tri_mem_wr_data = 'h5;
            tri_mem_wr_addr = 'd24;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd25;
            #(PERIOD);
            tri_mem_wr_data = 'h6;
            tri_mem_wr_addr = 'd26;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd27;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd28;
            #(PERIOD);
            tri_mem_wr_data = 'h3;
            tri_mem_wr_addr = 'd29;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd30;
            #(PERIOD);
            tri_mem_wr_data = 'h1;
            tri_mem_wr_addr = 'd31;
            #(PERIOD);
            tri_mem_wr_data = 'h4;
            tri_mem_wr_addr = 'd32;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd33;
            #(PERIOD);
            tri_mem_wr_data = 'h2;
            tri_mem_wr_addr = 'd34;
            #(PERIOD);
            tri_mem_wr_data = 'h7;
            tri_mem_wr_addr = 'd35;
            #(PERIOD);
            tri_mem_wr_data = 'h42014b16;
            tri_mem_wr_addr = 'd37;
            #(PERIOD);
            tri_mem_wr_data = 'h42875b7b;
            tri_mem_wr_addr = 'd38;
            #(PERIOD);
            tri_mem_wr_data = 'h3fb504f7;
            tri_mem_wr_addr = 'd39;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd40;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd41;
            #(PERIOD);
            tri_mem_wr_data = 'h42280000;
            tri_mem_wr_addr = 'd42;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd43;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd44;
            #(PERIOD);
            tri_mem_wr_data = 'h42b95b7b;
            tri_mem_wr_addr = 'd45;
            #(PERIOD);
            tri_mem_wr_data = 'h42654b16;
            tri_mem_wr_addr = 'd46;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd47;
            #(PERIOD);
            tri_mem_wr_data = 'h42340000;
            tri_mem_wr_addr = 'd48;
            #(PERIOD);
            tri_mem_wr_data = 'h41f00000;
            tri_mem_wr_addr = 'd49;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd50;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd51;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd52;
            #(PERIOD);
            tri_mem_wr_data = 'h42654b16;
            tri_mem_wr_addr = 'd53;
            #(PERIOD);
            tri_mem_wr_data = 'h42b95b7b;
            tri_mem_wr_addr = 'd54;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd55;
            #(PERIOD);
            tri_mem_wr_data = 'h436a0000;
            tri_mem_wr_addr = 'd56;
            #(PERIOD);
            tri_mem_wr_data = 'h42cc0000;
            tri_mem_wr_addr = 'd57;
            #(PERIOD);
            tri_mem_wr_data = 'h42cc0000;
            tri_mem_wr_addr = 'd58;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd59;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd60;
            #(PERIOD);
            tri_mem_wr_data = 'h422ab6f7;
            tri_mem_wr_addr = 'd61;
            #(PERIOD);
            tri_mem_wr_data = 'h40ea58b0;
            tri_mem_wr_addr = 'd62;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd63;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd64;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd65;
            #(PERIOD);
            tri_mem_wr_data = 'h42540000;
            tri_mem_wr_addr = 'd66;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd67;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd68;
            #(PERIOD);
            tri_mem_wr_data = 'h42875b7b;
            tri_mem_wr_addr = 'd69;
            #(PERIOD);
            tri_mem_wr_data = 'h42014b16;
            tri_mem_wr_addr = 'd70;
            #(PERIOD);
            tri_mem_wr_data = 'hbfb504f7;
            tri_mem_wr_addr = 'd71;
            #(PERIOD);
            tri_mem_wr_data = 'h42340000;
            tri_mem_wr_addr = 'd72;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd73;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd74;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd75;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd76;
            #(PERIOD);
            tri_mem_wr_data = 'h42875b7b;
            tri_mem_wr_addr = 'd77;
            #(PERIOD);
            tri_mem_wr_data = 'h42014b16;
            tri_mem_wr_addr = 'd78;
            #(PERIOD);
            tri_mem_wr_data = 'h3fb504f7;
            tri_mem_wr_addr = 'd79;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd80;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd81;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd82;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd83;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd84;
            #(PERIOD);
            tri_mem_wr_data = 'h40ea58b0;
            tri_mem_wr_addr = 'd85;
            #(PERIOD);
            tri_mem_wr_data = 'h422ab6f7;
            tri_mem_wr_addr = 'd86;
            #(PERIOD);
            tri_mem_wr_data = 'h0;
            tri_mem_wr_addr = 'd87;
            #(PERIOD);
            tri_mem_wr_data = 'h423c0000;
            tri_mem_wr_addr = 'd88;
            #(PERIOD);
            tri_mem_wr_data = 'h40a00000;
            tri_mem_wr_addr = 'd89;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd90;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd91;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd92;
            #(PERIOD);
            tri_mem_wr_data = 'h42014b16;
            tri_mem_wr_addr = 'd93;
            #(PERIOD);
            tri_mem_wr_data = 'h42875b7b;
            tri_mem_wr_addr = 'd94;
            #(PERIOD);
            tri_mem_wr_data = 'hbfb504f7;
            tri_mem_wr_addr = 'd95;
            #(PERIOD);
            tri_mem_wr_data = 'h437e0000;
            tri_mem_wr_addr = 'd96;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd97;
            #(PERIOD);
            tri_mem_wr_data = 'h41800000;
            tri_mem_wr_addr = 'd98;
            #(PERIOD);
            tri_mem_wr_data = 'h437f0000;
            tri_mem_wr_addr = 'd99;
            #(PERIOD);
            tri_mem_wr_data = 'h123;
            tri_mem_wr_addr = 'd100;
            
`endif 
            
            $display("{\"time\":\"%0t\",\"label\":\"[res_x]\", \"data\":%0d},", $time,res_reg[31:16]);
            $display("{\"time\":\"%0t\",\"label\":\"[res_y]\", \"data\":%0d},", $time,res_reg[15:0]);
            start = 1'b0;
            #PERIOD;
            tri_mem_wr_en = 1'b0;
            start = 1'b1;
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
    
    // always @(negedge clk) begin
    //     if(frag_mem_wr_en) begin
    //         $display("{\"time\":\"%0t\",\"label\":\"[fragment_write]\", \"data\":\"0x%0h\"},", $time,frag_mem_wr_data);
    //     end
    // end
    reg [31:0] clk_counter; 
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            clk_counter <= 'b0;
        end else begin
            clk_counter <= clk_counter + 'b1;
            if (done == 1'b1) begin
                $display("{\"time\":\"%0t\",\"label\":\"[Total_Cycles]\", \"data\":%0d},", $time, clk_counter);
            end
        end
    end
    always@(negedge clk) begin
        if (done == 1'b1) begin
            $display("{\"time\":\"%0t\",\"label\":\"[message]\", \"data\":\"test finished for input combination\"}", $time);
            $display("]}");
            $finish;
        end
    end
    // reg dump_frag_array;
    // always@(negedge clk) begin
    //     if(~resetn) begin
    //         dump_frag_array <= 1'b1;
    //     end else begin
    //         if (done == 1'b1) begin
    //             dump_frag_array <= 1'b1;
    //         end
    //     end
        
    // end

    initial 
        begin
            #TIMEOUT;
            $display("{\"time\":\"%0t\",\"label\":\"[message]\", \"data\":\"Simulation Timed Out :(\"}",  $time);
            $display("]}");
            $finish;
        end
    initial
        begin
        end

endmodule


module preloaded_ram_dual_clock #(
  parameter DATA_WIDTH=32,                 //width of data bus
  parameter ADDR_WIDTH=32                  //width of addresses buses
)(
  input      [DATA_WIDTH-1:0] data,       //data to be written
  input      [ADDR_WIDTH-1:0] read_addr,  //address for read operation
  input      [ADDR_WIDTH-1:0] write_addr, //address for write operation
  input                       we,         //write enable signal
  input                       read_clk,   //clock signal for read operation
  input                       write_clk,  //clock signal for write operation
  input                       re,         //read enable signal
  output reg [DATA_WIDTH-1:0] q           //read data
);
    
    reg [DATA_WIDTH-1:0] ram [2**ADDR_WIDTH-1:0]; // ** is exponentiation
  
    always @(posedge write_clk) begin //WRITE
        if (we) begin 
            ram[write_addr] <= data;

        end
    end

    always @(posedge read_clk) begin //READ
        if (re) begin
            q <= ram[read_addr];
        end
    end

endmodule

module frag_ram_dual_clock_32_32(
    input      [31:0] data,       //data to be written
    input      [31:0] read_addr,  //address for read operation
    input      [31:0] write_addr, //address for write operation
    input                       we,         //write enable signal
    input                       read_clk,   //clock signal for read operation
    input                       write_clk,  //clock signal for write operation
    input                       re,         //read enable signal
    output reg [31:0] q           //read data
);
    
    reg [(2**16 - 1):0][31:0] ram; 

    initial begin
        ram = 'b0;
        q = 'b0;
    end

    always @(posedge write_clk) begin: WRITE
        if (we) begin 
            ram[write_addr] <= data;
            $display("{\"time\":\"%0t\",\"label\":\"[frag_mem_write]\", \"data\":[\"0x%0h\",\"0x%0h\"]},", $time,write_addr,data);

        end
    end

    always @(posedge read_clk) begin: READ
        if (re) begin
            q <= ram[read_addr];
        end
    end
    
endmodule
module tri_ram_dual_clock_32_32(
    input      [31:0] data,       //data to be written
    input      [31:0] read_addr,  //address for read operation
    input      [31:0] write_addr, //address for write operation
    input                       we,         //write enable signal
    input                       read_clk,   //clock signal for read operation
    input                       write_clk,  //clock signal for write operation
    input                       re,         //read enable signal
    output reg [31:0] q           //read data
);
    
    reg [(2**16 - 1):0][31:0] ram;

    initial begin
        ram = 'b0;
        q = 'b0;
    end

    always @(posedge write_clk) begin: WRITE
        if (we) begin 
            ram[write_addr] <= data;
            $display("{\"time\":\"%0t\",\"label\":\"[mem_write]\", \"data\":\"[0x%0h,0x%0h]\"},", $time,write_addr,data);

        end
    end

    always @(posedge read_clk) begin: READ
        if (re) begin
            q <= ram[read_addr];
        end
    end
    
endmodule
