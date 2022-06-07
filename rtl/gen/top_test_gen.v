
    module top_test_gen #(
        // parameter DATA_WIDTH = 32,
        // parameter MAIN_MEM_ADDR_WIDTH = 32,
        // parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 3,   
        // parameter CYCLES_WAIT_FOR_RECIEVE = 4'd1,
        // parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = 'd0,
        
        // parameter FIFO_MAX_FRAGMENTS = 16, // must be power of 2
        // parameter FIFO_MAX_TRIANGLES = 1, // must be power of 2

        // parameter NUM_T_PIPES = 2,
        
        // parameter NOPERSPECTIVE = 'b0,
        // parameter FLAT = 'b0,
        // parameter PROVOKEMODE = 'b0,
        // parameter VERTEXSIZE = 4'd7, //number of attributes - 1
        // parameter WINDINGORDER = 1'b1, //ACW
        // parameter ORIGIN_LOCATION = 1'b1, //TL
        // parameter FACE_CULLER_ENABLE = 1'b1,
        // parameter MODE = 'b00, //Back
        // parameter RESX = 16'd20,
        // parameter RESY = 16'd20,
        // parameter TOTAL_NUM_TRIS = 32'd2,

        // parameter I_ARRAY_PTR = 32'd0,
        // parameter V_ARRAY_PTR = 32'd4,
        // parameter F_ARRAY_PTR = 32'h32,
        // parameter POLY_STORAGE_STRUCTURE = 'b1 //anticlockwise by default

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
                $dumpfile("top_test_gen.vcd");
                $dumpvars(0,top_test_gen);
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

//                 ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = WINDINGORDER;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
//                 ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = VERTEXSIZE;
             
//                 ctrl_reg1[16] = POLY_STORAGE_STRUCTURE;


// ctrl_reg1[15:0] = TOTAL_NUM_TRIS;
// res_reg[31:16] = RESX;
// res_reg[15:0] = RESY;
// i_array_ptr = I_ARRAY_PTR;
// v_array_ptr = V_ARRAY_PTR;
// f_array_ptr = F_ARRAY_PTR;

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

// #PERIOD;
// tri_mem_wr_en = 1'b1;
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd0;
// #(PERIOD);
// tri_mem_wr_data = 'h1;
// tri_mem_wr_addr = 'd1;
// #(PERIOD);
// tri_mem_wr_data = 'h2;
// tri_mem_wr_addr = 'd2;
// #(PERIOD);
// tri_mem_wr_data = 'h3;
// tri_mem_wr_addr = 'd3;
// #(PERIOD);
// tri_mem_wr_data = 'h4179e3a6;
// tri_mem_wr_addr = 'd4;
// #(PERIOD);
// tri_mem_wr_data = 'h40f3eeb9;
// tri_mem_wr_addr = 'd5;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd6;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd7;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd8;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd9;
// #(PERIOD);
// tri_mem_wr_data = 'h43ac8000;
// tri_mem_wr_addr = 'd10;
// #(PERIOD);
// tri_mem_wr_data = 'h123;
// tri_mem_wr_addr = 'd11;
// #(PERIOD);
// tri_mem_wr_data = 'h41977606;
// tri_mem_wr_addr = 'd12;
// #(PERIOD);
// tri_mem_wr_data = 'h411e058b;
// tri_mem_wr_addr = 'd13;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd14;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd15;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd16;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd17;
// #(PERIOD);
// tri_mem_wr_data = 'h43ac8000;
// tri_mem_wr_addr = 'd18;
// #(PERIOD);
// tri_mem_wr_data = 'h123;
// tri_mem_wr_addr = 'd19;
// #(PERIOD);
// tri_mem_wr_data = 'h41969882;
// tri_mem_wr_addr = 'd20;
// #(PERIOD);
// tri_mem_wr_data = 'h40c63fc4;
// tri_mem_wr_addr = 'd21;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd22;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd23;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd24;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd25;
// #(PERIOD);
// tri_mem_wr_data = 'h43ac8000;
// tri_mem_wr_addr = 'd26;
// #(PERIOD);
// tri_mem_wr_data = 'h123;
// tri_mem_wr_addr = 'd27;
// #(PERIOD);
// tri_mem_wr_data = 'h41b63fba;
// tri_mem_wr_addr = 'd28;
// #(PERIOD);
// tri_mem_wr_data = 'h4098a67f;
// tri_mem_wr_addr = 'd29;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd30;
// #(PERIOD);
// tri_mem_wr_data = 'h3f800000;
// tri_mem_wr_addr = 'd31;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd32;
// #(PERIOD);
// tri_mem_wr_data = 'h0;
// tri_mem_wr_addr = 'd33;
// #(PERIOD);
// tri_mem_wr_data = 'h43ac8000;
// tri_mem_wr_addr = 'd34;
// #(PERIOD);
// tri_mem_wr_data = 'h123;
// tri_mem_wr_addr = 'd35;
// #(PERIOD);
            
            
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



    