
    module top_test_gen #(
        parameter DATA_WIDTH = 32,
        parameter MAIN_MEM_ADDR_WIDTH = 32,
        parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 3,   
        parameter CYCLES_WAIT_FOR_RECIEVE = 4'd1,
        parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = 'd0,
        
        parameter FIFO_MAX_FRAGMENTS = 16, // must be power of 2
        parameter FIFO_MAX_TRIANGLES = 1, // must be power of 2

        parameter NUM_T_PIPES = 2,
        
        parameter NOPERSPECTIVE = 'b0,
        parameter FLAT = 'b0,
        parameter PROVOKEMODE = 'b0,
        parameter VERTEXSIZE = 4'd7, //number of attributes - 1
        parameter WINDINGORDER = 1'b1, //ACW
        parameter ORIGIN_LOCATION = 1'b1, //TL
        parameter FACE_CULLER_ENABLE = 1'b1,
        parameter MODE = 'b0, //Back
        parameter RESX = 16'd100,
        parameter RESY = 16'd100,
        parameter TOTAL_NUM_TRIS = 32'd3,

        parameter POLY_STORAGE_STRUCTURE = 'b0 //anticlockwise by default
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
            start, /*done*/, ready,

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

                ctrl_reg0[31:LOCAL_VERTEX_MEM_ADDR_WIDTH+8] = 'b0;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7] = NOPERSPECTIVE;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6] = FLAT;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5] = PROVOKEMODE;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4] = WINDINGORDER;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3] = FACE_CULLER_ENABLE;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2] = ORIGIN_LOCATION;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH] = MODE;
                ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] = VERTEXSIZE;
             
                ctrl_reg1[16] = POLY_STORAGE_STRUCTURE;


ctrl_reg1[15:0] = TOTAL_NUM_TRIS;
res_reg[31:16] = RESX;
res_reg[15:0] = RESY;
i_array_ptr = 0;
v_array_ptr = 9;
f_array_ptr = 82;
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
tri_mem_wr_data = 'h3;
tri_mem_wr_addr = 'd3;
#(PERIOD);
tri_mem_wr_data = 'h4;
tri_mem_wr_addr = 'd4;
#(PERIOD);
tri_mem_wr_data = 'h5;
tri_mem_wr_addr = 'd5;
#(PERIOD);
tri_mem_wr_data = 'h6;
tri_mem_wr_addr = 'd6;
#(PERIOD);
tri_mem_wr_data = 'h7;
tri_mem_wr_addr = 'd7;
#(PERIOD);
tri_mem_wr_data = 'h8;
tri_mem_wr_addr = 'd8;
#(PERIOD);
tri_mem_wr_data = 'h428f911b;
tri_mem_wr_addr = 'd9;
#(PERIOD);
tri_mem_wr_data = 'h409922ed;
tri_mem_wr_addr = 'd10;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd11;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd12;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd13;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd14;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd15;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd16;
#(PERIOD);
tri_mem_wr_data = 'h42abe6a6;
tri_mem_wr_addr = 'd17;
#(PERIOD);
tri_mem_wr_data = 'h412607d7;
tri_mem_wr_addr = 'd18;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd19;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd20;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd21;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd22;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd23;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd24;
#(PERIOD);
tri_mem_wr_data = 'h42a100c7;
tri_mem_wr_addr = 'd25;
#(PERIOD);
tri_mem_wr_data = 'h40294d27;
tri_mem_wr_addr = 'd26;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd27;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd28;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd29;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd30;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd31;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd32;
#(PERIOD);
tri_mem_wr_data = 'h42bd2f10;
tri_mem_wr_addr = 'd33;
#(PERIOD);
tri_mem_wr_data = 'h4207ff09;
tri_mem_wr_addr = 'd34;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd35;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd36;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd37;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd38;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd39;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd40;
#(PERIOD);
tri_mem_wr_data = 'h42cfcc02;
tri_mem_wr_addr = 'd41;
#(PERIOD);
tri_mem_wr_data = 'h420259f5;
tri_mem_wr_addr = 'd42;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd43;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd44;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd45;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd46;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd47;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd48;
#(PERIOD);
tri_mem_wr_data = 'h42c89a98;
tri_mem_wr_addr = 'd49;
#(PERIOD);
tri_mem_wr_data = 'h420047f7;
tri_mem_wr_addr = 'd50;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd51;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd52;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd53;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd54;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd55;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd56;
#(PERIOD);
tri_mem_wr_data = 'h416dbfbd;
tri_mem_wr_addr = 'd57;
#(PERIOD);
tri_mem_wr_data = 'h42a22c59;
tri_mem_wr_addr = 'd58;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd59;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd60;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd61;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd62;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd63;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd64;
#(PERIOD);
tri_mem_wr_data = 'h41c53f44;
tri_mem_wr_addr = 'd65;
#(PERIOD);
tri_mem_wr_data = 'h42a4d763;
tri_mem_wr_addr = 'd66;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd67;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd68;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd69;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd70;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd71;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd72;
#(PERIOD);
tri_mem_wr_data = 'h4177a2bf;
tri_mem_wr_addr = 'd73;
#(PERIOD);
tri_mem_wr_data = 'h429420d5;
tri_mem_wr_addr = 'd74;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd75;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd76;
#(PERIOD);
tri_mem_wr_data = 'h0;
tri_mem_wr_addr = 'd77;
#(PERIOD);
tri_mem_wr_data = 'h3f800000;
tri_mem_wr_addr = 'd78;
#(PERIOD);
tri_mem_wr_data = 'h43ac8000;
tri_mem_wr_addr = 'd79;
#(PERIOD);
tri_mem_wr_data = 'h123;
tri_mem_wr_addr = 'd80;
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



    