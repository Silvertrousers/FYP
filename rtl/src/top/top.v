//NB: need to round fifo depth to nearest power of two, otherwise the pointers break
module top#(
    parameter DATA_WIDTH = 32,
    parameter MAIN_MEM_ADDR_WIDTH = 32,
    parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 4,   
    parameter CYCLES_WAIT_FOR_RECIEVE = 4'b0001,
    parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = 'b0,
    
    parameter FIFO_MAX_FRAGMENTS = 16, // must be power of 2
    parameter FIFO_MAX_TRIANGLES = 1, // // must be power of 2
    parameter NUM_T_PIPES = 1
)(
    input wire clk,
    input wire resetn, 
    input wire en, 
    input wire start,
    output reg done,
    output reg ready,

    input  wire [DATA_WIDTH-1:0] mem_rd_data,       
    output wire [MAIN_MEM_ADDR_WIDTH-1:0] mem_rd_addr, 
    output wire [0:0]            mem_rd_en,

    output wire [DATA_WIDTH-1:0] mem_wr_data,       
    output wire [MAIN_MEM_ADDR_WIDTH-1:0] mem_wr_addr, 
    output wire [0:0]            mem_wr_en,

    //instruction inputs
    input wire [DATA_WIDTH-1:0] i_array_ptr,
    input wire [DATA_WIDTH-1:0] v_array_ptr,
    input wire [DATA_WIDTH-1:0] f_array_ptr,
    input wire [31:0] ctrl_reg0, //reg noPerspective, flat, provokeMode, windingOrder, faceCullerEnable, origin_location, [1:0] Mode, [ADDR_WIDTH-1:0] vertexSize;
    input wire [31:0] ctrl_reg1,
    input wire [DATA_WIDTH-1:0] res_reg //resx 16 bit, resy 16 bit
);

    
    localparam FRAG_FIFODEPTH = (2**LOCAL_VERTEX_MEM_ADDR_WIDTH)*FIFO_MAX_FRAGMENTS; //fragment size * num fragments, must be power of 2
    localparam TRI_FIFODEPTH = (2**LOCAL_VERTEX_MEM_ADDR_WIDTH)*4*FIFO_MAX_TRIANGLES; //vertex size * num vertices in triangle rounded to nearest pwr of 2 * num triangles, must be power of 2

    reg  [NUM_T_PIPES-1:0] tri_pipe_start;
    wire [NUM_T_PIPES-1:0] tri_pipe_done;
    wire [NUM_T_PIPES-1:0] tri_pipe_ready;

    //ports from vertex attribute mem       
    wire [NUM_T_PIPES-1:0][DATA_WIDTH-1:0] tri_fifo_rd_data;
    wire [NUM_T_PIPES-1:0]tri_fifo_rd_en;   
    wire  [NUM_T_PIPES-1:0][DATA_WIDTH-1:0] tri_fifo_wr_data;
    wire  [NUM_T_PIPES-1:0]tri_fifo_wr_en; 
    
    wire [NUM_T_PIPES-1:0] tri_fifo_full; 
    wire [NUM_T_PIPES-1:0] tri_fifo_empty;
    wire [NUM_T_PIPES-1:0] tri_fifo_threshold; 
    wire [NUM_T_PIPES-1:0] tri_fifo_overflow; 
    wire [NUM_T_PIPES-1:0] tri_fifo_underflow;

    //ports to write to fragment fifo
    wire [NUM_T_PIPES-1:0] [DATA_WIDTH-1:0] frag_fifo_rd_data;
    wire [NUM_T_PIPES-1:0] frag_fifo_rd_en; 
    wire [NUM_T_PIPES-1:0] [DATA_WIDTH-1:0] frag_fifo_wr_data;
    wire [NUM_T_PIPES-1:0] frag_fifo_wr_en; 

    wire [NUM_T_PIPES-1:0]frag_fifo_full; 
    wire [NUM_T_PIPES-1:0]frag_fifo_empty;
    wire [NUM_T_PIPES-1:0]frag_fifo_threshold; 
    wire [NUM_T_PIPES-1:0]frag_fifo_overflow; 
    wire [NUM_T_PIPES-1:0]frag_fifo_underflow;


    reg [DATA_WIDTH-1:0] i_array_ptrReg;
    reg [DATA_WIDTH-1:0] v_array_ptrReg;
    reg [DATA_WIDTH-1:0] f_array_ptrReg;

    reg noPerspective, flat, provokeMode, windingOrder, faceCullerEnable, origin_location, poly_storage_structure;
    reg [1:0] Mode;
    reg [LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] vertexSize;
    wire [$clog2(TRI_FIFODEPTH):0] triangle_size;
    assign triangle_size = (vertexSize +'d1) * 'd3;
    wire [$clog2(FRAG_FIFODEPTH):0] fragment_size;
    assign fragment_size = vertexSize + 'b1;

    reg [31:0] resx,resy; 
    reg [MAIN_MEM_ADDR_WIDTH-1:0] total_num_tris;

    reg  load_balancer_start;
    wire load_balancer_done, load_balancer_ready;

    wire [2:0][DATA_WIDTH-1:0]                  v_mem_wr_data;
    wire [2:0][LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] v_mem_wr_addr;
    wire [2:0][0:0]                             v_mem_wr_en;

    wire [2:0][DATA_WIDTH-1:0]                  v_mem_rd_data;
    wire [2:0][LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] v_mem_rd_addr;
    wire [2:0][0:0]                             v_mem_rd_en;

    reg  [NUM_T_PIPES-1:0] tri_pipe_active;
    always @(posedge clk or negedge resetn) begin: INPUT_CAPTURE
        if(~resetn)begin
            i_array_ptrReg <= 'b0;
            v_array_ptrReg <= 'b0;
            f_array_ptrReg <= 'b0;

            noPerspective <= 'b0;
            flat <= 'b0;
            provokeMode <= 'b0;
            windingOrder <= 'b0;
            faceCullerEnable <= 'b0;
            origin_location <= 'b0;
            Mode <= 'b0;
            vertexSize <= 'b0;
        
            resx <= 'b0;
            resy <= 'b0; 
            total_num_tris <= 'b0;
            
        end else begin
            if(start) begin
                i_array_ptrReg <= i_array_ptr;
                v_array_ptrReg <= v_array_ptr;
                f_array_ptrReg <= f_array_ptr;

                noPerspective    <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+7];
                flat             <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+6];
                provokeMode      <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+5];
                windingOrder     <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+4];
                faceCullerEnable <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+3];
                origin_location  <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+2];
                Mode             <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH+1:LOCAL_VERTEX_MEM_ADDR_WIDTH];
                vertexSize       <= ctrl_reg0[LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0];
                total_num_tris   <= ctrl_reg1[15:0];
                poly_storage_structure  <= ctrl_reg1[16];

                resx <= {16'b0,res_reg[31:16]};
                resy <= {16'b0,res_reg[15:0]}; 
                
            end
        end
    end

    genvar v;
    generate
        for(v=0; v < 3; v=v+1) begin: V_MEM_GEN
            simple_ram_dual_clock #(
                DATA_WIDTH,                 
                LOCAL_VERTEX_MEM_ADDR_WIDTH                  
            ) v_mem (
                .data(v_mem_wr_data[v]),       
                .read_addr(v_mem_rd_addr[v]),  
                .write_addr(v_mem_wr_addr[v]), 
                .we(v_mem_wr_en[v]),         
                .read_clk(clk),  
                .write_clk(clk), 
                .re(v_mem_rd_en[v]),        
                .q(v_mem_rd_data[v])         
            );
        end
    endgenerate
    
loadBalancer#(
    NUM_T_PIPES,
    FIFO_MAX_TRIANGLES,
    DATA_WIDTH,
    MAIN_MEM_ADDR_WIDTH,
    LOCAL_VERTEX_MEM_ADDR_WIDTH,
    MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE
)loadBalancer_i(
    .clk(clk),
    .resetn(resetn),
    .en(en),
    .start(load_balancer_start),
    .done(load_balancer_done),
    .ready(load_balancer_ready),

    .v_array_ptr(v_array_ptrReg),
    .i_array_ptr(i_array_ptrReg),

    .vertexSize(vertexSize),
    .total_num_tris(total_num_tris),

    .main_mem_rd_data(mem_rd_data),       
    .main_mem_rd_addr(mem_rd_addr), 
    .main_mem_rd_en(mem_rd_en),

    .v_mem_wr_data(v_mem_wr_data),
    .v_mem_wr_addr(v_mem_wr_addr),
    .v_mem_wr_en(v_mem_wr_en),

    .v_mem_rd_data(v_mem_rd_data),
    .v_mem_rd_addr(v_mem_rd_addr),
    .v_mem_rd_en(v_mem_rd_en),

    .tri_fifo_wr_data(tri_fifo_wr_data),
    .tri_fifo_wr_en(tri_fifo_wr_en), 

    .tri_fifo_full(tri_fifo_full), 
    .tri_fifo_empty(tri_fifo_empty), 
    .tri_fifo_threshold(tri_fifo_threshold), 
    .tri_fifo_overflow(tri_fifo_overflow), 
    .tri_fifo_underflow(tri_fifo_underflow),
    .poly_storage_structure(poly_storage_structure)
);
    wire all_pipes_ready;
    assign all_pipes_ready = (&tri_pipe_ready); //unary and
    reg tmp_done;
    always @(posedge clk or negedge resetn) begin: START_AND_DONE
        if(~resetn)begin
            done <= 'b0;
            load_balancer_start <= 'b0;
            ready <= 1'b0;
            tmp_done <= 1'b0;
        end else begin
            if(start) begin
                load_balancer_start <= 1'b1;
                ready <= 1'b0;
            end else begin
                load_balancer_start <= 1'b0;
            end
            if((load_balancer_ready) && (tri_fifo_empty) && (frag_fifo_empty) && (all_pipes_ready) && (tri_pipe_active=='b0)) begin
                tmp_done <= 1'b1;
            end 
            if((load_balancer_ready) && (tri_fifo_empty) && (frag_fifo_empty) && (all_pipes_ready) && (tri_pipe_active=='b0) && (tmp_done == 1'b1)) begin
                done <= 1'b1;
                ready <= 1'b1;
                tmp_done <= 1'b0;
            end
            if(done == 1'b1) begin 
                done <= 1'b0;
            end
        end
    end

    genvar t;
    generate
        for(t=0; t < NUM_T_PIPES; t=t+1) begin: T_PIPE_GEN


            always @(posedge clk or negedge resetn) begin: T_PIPE_START
                if(~resetn)begin
                    tri_pipe_start <= 'b0;
                    tri_pipe_active <= 'b0;
                end else begin
                    if(((tri_pipe_ready[t]) && (tri_fifo_threshold[t] || tri_fifo_full[t])) && ~tri_pipe_start[t]) begin
                        tri_pipe_start[t] <= 1'b1;
                        tri_pipe_active[t] <= 1'b1;
                    end else begin
                        tri_pipe_start[t] <= 1'b0;
                    end
                    if(tri_pipe_done[t]) begin
                        tri_pipe_active[t] <= 1'b0;
                    end
                end
            end
            
            FIFO #(
                DATA_WIDTH,
                TRI_FIFODEPTH
            ) tri_FIFO (
                .data_out(tri_fifo_rd_data[t]),
                .fifo_full(tri_fifo_full[t]), 
                .fifo_empty(tri_fifo_empty[t]), 
                .fifo_threshold(tri_fifo_threshold[t]), 
                .fifo_overflow(tri_fifo_overflow[t]), 
                .fifo_underflow(tri_fifo_underflow[t]),
                .clk(clk), 
                .resetn(resetn), 
                .wr(tri_fifo_wr_en[t]), 
                .rd(tri_fifo_rd_en[t]), 
                .data_in(tri_fifo_wr_data[t]),
                .threshold_level(triangle_size)
            );  

            triangle_pipe#(
                DATA_WIDTH,
                LOCAL_VERTEX_MEM_ADDR_WIDTH,      
                CYCLES_WAIT_FOR_RECIEVE
            ) triangle_pipe_i (
                clk, resetn, en, 
                tri_pipe_start[t], 
                tri_pipe_done[t],
                tri_pipe_ready[t],

                //ports to write to fragment fifo
                frag_fifo_wr_data[t],
                frag_fifo_wr_en[t], 

                //fragment fifo control (unused for the moment) TODO: use these flags to control output
                frag_fifo_full[t], 
                frag_fifo_empty[t], 
                frag_fifo_threshold[t], 
                frag_fifo_overflow[t], 
                frag_fifo_underflow[t],

                //ports to read from triangle  fifo
                tri_fifo_rd_data[t],
                tri_fifo_rd_en[t], 

                //triangle fifo control (unused for the moment) TODO: use these flags to control output
                tri_fifo_full[t], 
                tri_fifo_empty[t], 
                tri_fifo_threshold[t], 
                tri_fifo_overflow[t], 
                tri_fifo_underflow[t],

                //flags
                noPerspective, flat, provokeMode, 
                windingOrder, vertexSize, faceCullerEnable, 
                Mode, origin_location,
                resx, resy
            );

            FIFO #(
                DATA_WIDTH,
                FRAG_FIFODEPTH
            ) frag_FIFO (
                .data_out(frag_fifo_rd_data[t]),
                .fifo_full(frag_fifo_full[t]), 
                .fifo_empty(frag_fifo_empty[t]), 
                .fifo_threshold(frag_fifo_threshold[t]), 
                .fifo_overflow(frag_fifo_overflow[t]), 
                .fifo_underflow(frag_fifo_underflow[t]),
                .clk(clk), 
                .resetn(resetn), 
                .wr(frag_fifo_wr_en[t]), 
                .rd(frag_fifo_rd_en[t]), 
                .data_in(frag_fifo_wr_data[t]),
                .threshold_level(fragment_size)
            );  
        end
    endgenerate
   

    wrArbiter#(
        NUM_T_PIPES,
        FIFO_MAX_FRAGMENTS,
        DATA_WIDTH,
        MAIN_MEM_ADDR_WIDTH,
        LOCAL_VERTEX_MEM_ADDR_WIDTH   
    ) wrArbiter_inst (
        .clk(clk),
        .resetn(resetn),
        .en(en),

        .t_pipe_done(tri_pipe_done),
        //ports to write to fragment fifo
        .frag_fifo_rd_data(frag_fifo_rd_data),
        .frag_fifo_rd_en(frag_fifo_rd_en), 

        .frag_fifo_full(frag_fifo_full), 
        .frag_fifo_empty(frag_fifo_empty), 
        .frag_fifo_threshold(frag_fifo_threshold), 
        .frag_fifo_overflow(frag_fifo_overflow), 
        .frag_fifo_underflow(frag_fifo_underflow),

        .frag_wr_data(mem_wr_data),
        .frag_wr_addr(mem_wr_addr),
        .frag_wr_en(mem_wr_en),

        .f_array_ptr(f_array_ptrReg),
        .vertexSize(vertexSize)
    );


`ifdef MEASURE
    always @(posedge clk) begin
        //load balancer activity
        // reading
        // writing
        
        //tri fifo activity
        //frag fifo activity
        //tri pipe activity
        //wr arbiter activity
        if(mem_rd_en) begin
            $display("{\"time\":\"%0t\",\"label\":\"[main_mem_rd_activity]\", \"data\":%0d},", $time, mem_rd_addr);
        end
        if(mem_wr_en) begin
            $display("{\"time\":\"%0t\",\"label\":\"[main_mem_wr_activity]\", \"data\":%0d},", $time, mem_wr_addr);
        end
    end
    // genvar t_pipe;
    // generate
    //     for(t_pipe=0; t_pipe < NUM_T_PIPES; t_pipe=t_pipe+1) begin: T_PIPE_measure
    //         always @(*) begin
    //             $display("{\"time\":\"%0t\",\"label\":\"[tri_fifo_rd_en_%0d]\", \"data\":%0b},", $time, t_pipe, tri_fifo_rd_en[t_pipe]);
    //             $display("{\"time\":\"%0t\",\"label\":\"[tri_fifo_wr_en_%0d]\", \"data\":%0b},", $time, t_pipe, tri_fifo_wr_en[t_pipe]);
    //             $display("{\"time\":\"%0t\",\"label\":\"[frag_fifo_rd_en_%0d]\", \"data\":%0b},", $time, t_pipe, frag_fifo_rd_en[t_pipe]);
    //             $display("{\"time\":\"%0t\",\"label\":\"[frag_fifo_wr_en_%0d]\", \"data\":%0b},", $time, t_pipe, frag_fifo_wr_en[t_pipe]);
    //         //measure empty, measure full, measure threshold, maybe measure how full/empty by looking at wr ptr
    //         end
    //     end
    // endgenerate
`endif
endmodule



