module loadBalancer#(
    parameter NUM_T_PIPES = 1,
    parameter FIFO_MAX_TRIANGLES = 1,
    parameter DATA_WIDTH = 32,
    parameter MAIN_MEM_ADDR_WIDTH = 32,
    parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 4,
    parameter MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE = 8'd1
    
)(
    input wire clk,
    input wire resetn,
    input wire en,
    input wire start,
    output reg done,
    output reg ready,

    input wire [DATA_WIDTH-1:0] v_array_ptr,
    input wire [DATA_WIDTH-1:0] i_array_ptr,

    input wire [LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] vertexSize,
    input wire [MAIN_MEM_ADDR_WIDTH-1:0] total_num_tris,

    input  wire [DATA_WIDTH-1:0] main_mem_rd_data,       
    output reg  [MAIN_MEM_ADDR_WIDTH-1:0] main_mem_rd_addr, 
    output reg  [0:0]            main_mem_rd_en,

    output reg [2:0][DATA_WIDTH-1:0]                  v_mem_wr_data,
    output reg [2:0][LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] v_mem_wr_addr,
    output reg [2:0][0:0]                             v_mem_wr_en,

    input wire [2:0][DATA_WIDTH-1:0]                  v_mem_rd_data,
    output reg [2:0][LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] v_mem_rd_addr,
    output reg [2:0][0:0]                             v_mem_rd_en,

    //ports to read from triangle  fifo
    output reg  [NUM_T_PIPES-1:0][DATA_WIDTH-1:0] tri_fifo_wr_data,
    output reg [NUM_T_PIPES-1:0]                 tri_fifo_wr_en, 

    input wire [NUM_T_PIPES-1:0] tri_fifo_full, 
    input wire [NUM_T_PIPES-1:0] tri_fifo_empty, 
    input wire [NUM_T_PIPES-1:0] tri_fifo_threshold, 
    input wire [NUM_T_PIPES-1:0] tri_fifo_overflow, 
    input wire [NUM_T_PIPES-1:0] tri_fifo_underflow,

    input wire poly_storage_structure
);

    localparam INDIVIDUAL_TRIANGLES = 1'b0;
    localparam TRIANGLE_STRIP = 1'b1;

    reg [3:0] state;
    localparam IDLE = 'd0;

    localparam FETCH_T0_I_ARRAY_RD = 'd1;
    localparam FETCH_T0_I_ARRAY_WAIT = 'd2;
    localparam FETCH_T0_I_RECIEVE_V_RD = 'd3;
    localparam FETCH_T0_V_ARRAY_WAIT = 'd4;
    localparam FETCH_T0_V_ARRAY_RECIEVE = 'd5;

    localparam FETCH_TN_I_ARRAY_RD = 'd6;
    localparam FETCH_TN_I_ARRAY_WAIT = 'd7;
    localparam FETCH_TN_I_RECIEVE_V_RD = 'd8;
    localparam FETCH_TN_V_ARRAY_WAIT = 'd9;
    localparam FETCH_TN_V_ARRAY_RECIEVE = 'd10;

    localparam LOAD_T_2_FIFO_LOCAL_V_READ = 'd11;
    localparam LOAD_T_2_FIFO_FIFO_V_WRITE = 'd12;
    
    reg [MAIN_MEM_ADDR_WIDTH-1:0] tri_count;
    reg [LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] vertex_attr_offset;
     
    reg [7:0] cycle_wait_count;
    reg [DATA_WIDTH-1:0] vertex_base_addr;
    reg [MAIN_MEM_ADDR_WIDTH-1:0] i_offset;


    localparam ABC = 3'b000;
    localparam ACB = 3'b001;
    localparam CAB = 3'b010;
    localparam CBA = 3'b011;
    localparam BCA = 3'b100;
    localparam BAC = 3'b101;
    reg [2:0] read_order_state;
    reg [1:0] vertex_wr_num;
    reg [1:0] vertex_rd_count;
    

    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            state <= IDLE;
            tri_count <= 'b0;
            cycle_wait_count <= 'b0;
            vertex_attr_offset <= 'b0;
            i_offset <= 'b0;
            v_mem_rd_addr <= 'b0;
            v_mem_rd_en <= 'b0;
            main_mem_rd_addr <= 'b0;
            main_mem_rd_en   <= 'b0;
            vertex_base_addr <= 'b0;
            tri_fifo_wr_data <= 'b0;
            tri_fifo_wr_en <= 'b0;
            vertex_wr_num <= 'b0;
            vertex_rd_count <= 'b0;
            read_order_state <= ABC;
        end else begin
            if(poly_storage_structure == TRIANGLE_STRIP) begin                 
                case(state)
                    IDLE: begin 
                        if(start) begin
                            state <= FETCH_T0_I_ARRAY_RD; 
                            ready <= 1'b0;
                            
                            //$display("{\"time\":\"%0t\",\"label\":\"[starting]\", \"data\":\"moving to FETCH_T0_I_ARRAY_RD\"},", $time);
                        end     
                        done <= 1'b0;
                    end                 
                    
                    FETCH_T0_I_ARRAY_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_ARRAY_RD\"},", $time);
                        tri_fifo_wr_en <= 'b0;
                        v_mem_wr_en <= 1'b0;
                        if(tri_count == total_num_tris) begin
                            state <= IDLE;
                            done <= 1'b1;
                            ready <= 1'b1;
                            tri_count <= 'b0;
                        end else begin
                            state <= FETCH_T0_I_ARRAY_WAIT;
                            //$display("{\"time\":\"%0t\",\"label\":\"[index_read_addr]\", \"data\":\"[0x%0h]\"},", $time, main_mem_rd_addr);
                            main_mem_rd_addr <= i_offset + i_array_ptr;
                            main_mem_rd_en <= 1'b1;
                        end
                    
                    end
                    FETCH_T0_I_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[FETCH_T0_I_ARRAY_WAIT]\", \"data\":\"0x%0d\"},", $time, cycle_wait_count);
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_T0_I_RECIEVE_V_RD;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_T0_I_RECIEVE_V_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_RECIEVE_V_RD\"},", $time);
                        
                    
                        state <= FETCH_T0_V_ARRAY_WAIT;
                        
                        if(vertex_attr_offset == 'b0) begin
                            vertex_base_addr <= main_mem_rd_data;
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * main_mem_rd_data) + vertex_attr_offset;
                        end else begin
                        
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * vertex_base_addr) + vertex_attr_offset;
                        end 
                        
                        main_mem_rd_en <= 1'b1;
                        v_mem_wr_en <= 'b0;
                    end
                    FETCH_T0_V_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_WAIT\"},", $time);
                        
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_T0_V_ARRAY_RECIEVE;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_T0_V_ARRAY_RECIEVE: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_RECIEVE\"},", $time);
                        
                        if(vertex_attr_offset < vertexSize) begin
                            state <= FETCH_T0_I_RECIEVE_V_RD;
                            //$display("{\"time\":\"%0t\",\"label\":\"[vertex_attr_offset]\", \"data\":\"[%0h]\"},", $time, (vertex_attr_offset + 'b1));
                            vertex_attr_offset <= vertex_attr_offset + 'b1; 
                        end
                        if(vertex_attr_offset == vertexSize) begin
                            
                            vertex_attr_offset <= 'b0;

                            if(i_offset < (total_num_tris + 'd1)) begin
                                i_offset <= i_offset + 'b1;
                            end
                            if(i_offset == (total_num_tris + 'd1)) begin
                                i_offset <= 'b0;
                            end
                            if(vertex_wr_num < 'd2) begin
                                vertex_wr_num <= vertex_wr_num + 'b1;
                            end
                            if(vertex_wr_num == 'd2) begin
                                vertex_wr_num <= 'b0; 
                                state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                                v_mem_wr_en <= 1'b0;
                            end else begin
                                state <= FETCH_T0_I_ARRAY_RD;
                            end
                        end

                        v_mem_wr_data[vertex_wr_num] <= main_mem_rd_data;   //vertex_wr_num is chosen elsewhere, this is 0,1,2 for T0 and then is chosen using the table otherwise
                        v_mem_wr_addr[vertex_wr_num] <= vertex_attr_offset; 
                        v_mem_wr_en[vertex_wr_num] <= 1'b1;
                                            
                        
                    end
                
                    
                    FETCH_TN_I_ARRAY_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_ARRAY_RD\"},", $time);
                        tri_fifo_wr_en <= 'b0;
                        v_mem_wr_en <= 1'b0;
                        if(tri_count == total_num_tris) begin
                            state <= IDLE;
                            done <= 1'b1;
                            ready <= 1'b1;
                            tri_count <= 'b0;
                            
                        end else begin
                            state <= FETCH_TN_I_ARRAY_WAIT;
                            //$display("{\"time\":\"%0t\",\"label\":\"[index_read_addr]\", \"data\":\"[0x%0h]\"},", $time, main_mem_rd_addr);
                            main_mem_rd_addr <= i_offset + i_array_ptr;
                            main_mem_rd_en <= 1'b1;
                        end
                    end
                    FETCH_TN_I_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_ARRAY_WAIT\"},", $time);
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_TN_I_RECIEVE_V_RD;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_TN_I_RECIEVE_V_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_RECIEVE_V_RD\"},", $time);
                        
                        state <= FETCH_TN_V_ARRAY_WAIT;
                        
                        if(vertex_attr_offset == 'b0) begin
                            //$display("{\"time\":\"%0t\",\"label\":\"[index_read_data]\", \"data\":\"[0x%0h]\"},", $time, main_mem_rd_data);
                            //$display("{\"time\":\"%0t\",\"label\":\"[v_read_addr]\", \"data\":\"[0x%0h]\"},", $time, (v_array_ptr + ((vertexSize + 1) * main_mem_rd_data) + vertex_attr_offset));
                            vertex_base_addr <= main_mem_rd_data;
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * main_mem_rd_data) + vertex_attr_offset;
                        end else begin
                            //$display("{\"time\":\"%0t\",\"label\":\"[index_read_data]\", \"data\":\"[0x%0h]\"},", $time, vertex_base_addr);
                            //$display("{\"time\":\"%0t\",\"label\":\"[v_read_addr]\", \"data\":\"[0x%0h]\"},", $time, (v_array_ptr + ((vertexSize + 1) * vertex_base_addr) + vertex_attr_offset));
                            
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * vertex_base_addr) + vertex_attr_offset;
                        end 
                        
                        main_mem_rd_en <= 1'b1;
                        v_mem_wr_en <= 'b0;
                    end
                    FETCH_TN_V_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_WAIT\"},", $time);
                        
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_TN_V_ARRAY_RECIEVE;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_TN_V_ARRAY_RECIEVE: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_RECIEVE\"},", $time);

                        if(vertex_attr_offset < vertexSize) begin
                            state <= FETCH_TN_I_RECIEVE_V_RD;
                            vertex_attr_offset <= vertex_attr_offset + 'b1;
                            //$display("{\"time\":\"%0t\",\"label\":\"[vertex_attr_offset]\", \"data\":\"[%0h]\"},", $time, (vertex_attr_offset + 'b1));
                        end
                        if(vertex_attr_offset == vertexSize) begin
                            state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                            vertex_attr_offset <= 'b0;

                            if(i_offset < (total_num_tris + 'd1)) begin
                                i_offset <= i_offset + 'b1;
                            end
                            if(i_offset == (total_num_tris + 'd1)) begin
                                i_offset <= 'b0;
                            end
                            if(vertex_wr_num < 'd2) begin
                                vertex_wr_num <= vertex_wr_num + 'b1;
                            end
                            if(vertex_wr_num == 'd2) begin
                                vertex_wr_num <= 'b0; 
                                v_mem_wr_en <= 1'b0;
                            end
                        end
                    
                        
                        v_mem_wr_data[vertex_wr_num] <= main_mem_rd_data;   //vertex_wr_num is chosen elsewhere, this is 0,1,2 for T0 and then is chosen using the table otherwise
                        v_mem_wr_addr[vertex_wr_num] <= vertex_attr_offset; 
                        v_mem_wr_en[vertex_wr_num] <= 1'b1;
                        
                    end           
                    LOAD_T_2_FIFO_LOCAL_V_READ: begin                    
                        if(~tri_fifo_full) begin
                            v_mem_rd_addr[vertex_rd_num] <= vertex_attr_offset;
                            v_mem_rd_en[vertex_rd_num] <= 1'b1;
                            tri_fifo_wr_en <= 1'b0;
                            state <= LOAD_T_2_FIFO_FIFO_V_WRITE;
                        end
                    end
                    LOAD_T_2_FIFO_FIFO_V_WRITE: begin
                        state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                        tri_fifo_wr_data[t_pipe_select] <= v_mem_rd_data[vertex_rd_num];
                        tri_fifo_wr_en[t_pipe_select] <= 1'b1;
                        v_mem_rd_en <= 'b0;
                    

                        if(vertex_attr_offset < vertexSize) begin
                            vertex_attr_offset <= vertex_attr_offset + 'b1; 
                            state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                        end
                        if(vertex_attr_offset == vertexSize) begin
                            vertex_attr_offset <= 'b0;
                            if(vertex_rd_count < 'd2) begin
                                vertex_rd_count <= vertex_rd_count + 'b1;
                                state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                            end
                            if(vertex_rd_count == 'd2) begin
                                vertex_rd_count <= 'b0;
                                state <= FETCH_TN_I_ARRAY_RD;
                                

                                if(tri_count < total_num_tris) begin
                                    tri_count <= tri_count + 'b1;
                                end
                                case(read_order_state)
                                    ABC: read_order_state <= ACB;
                                    ACB: read_order_state <= CAB;
                                    CAB: read_order_state <= CBA;
                                    CBA: read_order_state <= BCA;
                                    BCA: read_order_state <= BAC;
                                    BAC: read_order_state <= ABC;
                                endcase

                            end
                        end 
                    end
                endcase   
            end 
            if (poly_storage_structure == INDIVIDUAL_TRIANGLES) begin
                case(state)
                    IDLE: begin 
                        if(start) begin
                            state <= FETCH_T0_I_ARRAY_RD; 
                            ready <= 1'b0;
                            
                            //$display("{\"time\":\"%0t\",\"label\":\"[starting]\", \"data\":\"moving to FETCH_T0_I_ARRAY_RD\"},", $time);
                        end     
                        done <= 1'b0;
                    end                 
                    
                    FETCH_T0_I_ARRAY_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_ARRAY_RD\"},", $time);
                        tri_fifo_wr_en <= 'b0;
                        v_mem_wr_en <= 1'b0;
                        tri_fifo_wr_en <= 1'b0;
                        if(tri_count == total_num_tris) begin
                            state <= IDLE;
                            done <= 1'b1;
                            ready <= 1'b1;
                            tri_count <= 'b0;
                        end else begin
                            state <= FETCH_T0_I_ARRAY_WAIT;
                            //$display("{\"time\":\"%0t\",\"label\":\"[index_read_addr]\", \"data\":\"[0x%0h]\"},", $time, main_mem_rd_addr);
                            main_mem_rd_addr <= i_offset + i_array_ptr;
                            main_mem_rd_en <= 1'b1;
                        end
                    
                    end
                    FETCH_T0_I_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[FETCH_T0_I_ARRAY_WAIT]\", \"data\":\"0x%0d\"},", $time, cycle_wait_count);
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_T0_I_RECIEVE_V_RD;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_T0_I_RECIEVE_V_RD: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"I_RECIEVE_V_RD\"},", $time);
                        
                    
                        state <= FETCH_T0_V_ARRAY_WAIT;
                        
                        if(vertex_attr_offset == 'b0) begin
                            vertex_base_addr <= main_mem_rd_data;
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * main_mem_rd_data) + vertex_attr_offset;
                        end else begin
                        
                            main_mem_rd_addr <= v_array_ptr + ((vertexSize + 1) * vertex_base_addr) + vertex_attr_offset;
                        end 
                        
                        main_mem_rd_en <= 1'b1;
                        v_mem_wr_en <= 'b0;
                    end
                    FETCH_T0_V_ARRAY_WAIT: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_WAIT\"},", $time);
                        
                        if(cycle_wait_count < (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            cycle_wait_count <= cycle_wait_count + 'b1; 
                        end
                        if(cycle_wait_count == (MAIN_MEM_CYCLES_WAIT_FOR_RECIEVE)) begin
                            state <= FETCH_T0_V_ARRAY_RECIEVE;
                            cycle_wait_count <= 'b0;
                        end
                        main_mem_rd_en <= 1'b0;
                    end
                    FETCH_T0_V_ARRAY_RECIEVE: begin
                        //$display("{\"time\":\"%0t\",\"label\":\"[fetch_t_sub_state]\", \"data\":\"V_ARRAY_RECIEVE\"},", $time);
                        
                        if(vertex_attr_offset < vertexSize) begin
                            state <= FETCH_T0_I_RECIEVE_V_RD;
                            //$display("{\"time\":\"%0t\",\"label\":\"[vertex_attr_offset]\", \"data\":\"[%0h]\"},", $time, (vertex_attr_offset + 'b1));
                            vertex_attr_offset <= vertex_attr_offset + 'b1; 
                        end
                        if(vertex_attr_offset == vertexSize) begin
                            
                            vertex_attr_offset <= 'b0;

                            if(i_offset < (total_num_tris * 'd3)) begin
                                i_offset <= i_offset + 'b1;
                            end
                            if(i_offset == (total_num_tris * 'd3)) begin
                                i_offset <= 'b0;
                            end
                            if(vertex_wr_num < 'd2) begin
                                vertex_wr_num <= vertex_wr_num + 'b1;
                            end
                            if(vertex_wr_num == 'd2) begin
                                vertex_wr_num <= 'b0; 
                                state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                                v_mem_wr_en <= 1'b0;
                            end else begin
                                state <= FETCH_T0_I_ARRAY_RD;
                            end
                        end

                        v_mem_wr_data[vertex_wr_num] <= main_mem_rd_data;   //vertex_wr_num is chosen elsewhere, this is 0,1,2 for T0 and then is chosen using the table otherwise
                        v_mem_wr_addr[vertex_wr_num] <= vertex_attr_offset; 
                        v_mem_wr_en[vertex_wr_num] <= 1'b1;
                                            
                        
                    end         
                    LOAD_T_2_FIFO_LOCAL_V_READ: begin                    
                        if(~tri_fifo_full) begin
                            v_mem_rd_addr[vertex_rd_num] <= vertex_attr_offset;
                            v_mem_rd_en[vertex_rd_num] <= 1'b1;
                            state <= LOAD_T_2_FIFO_FIFO_V_WRITE;
                        end
                        tri_fifo_wr_en <= 1'b0;
                    end
                    LOAD_T_2_FIFO_FIFO_V_WRITE: begin
                        state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                        tri_fifo_wr_data[t_pipe_select] <= v_mem_rd_data[vertex_rd_num];
                        tri_fifo_wr_en[t_pipe_select] <= 1'b1;
                        v_mem_rd_en <= 'b0;
                    

                        if(vertex_attr_offset < vertexSize) begin
                            vertex_attr_offset <= vertex_attr_offset + 'b1; 
                            state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                        end
                        if(vertex_attr_offset == vertexSize) begin
                            vertex_attr_offset <= 'b0;
                            if(vertex_rd_count < 'd2) begin
                                vertex_rd_count <= vertex_rd_count + 'b1;
                                state <= LOAD_T_2_FIFO_LOCAL_V_READ;
                            end
                            if(vertex_rd_count == 'd2) begin
                                vertex_rd_count <= 'b0;
                                state <= FETCH_T0_I_ARRAY_RD;
                                

                                if(tri_count < total_num_tris) begin
                                    tri_count <= tri_count + 'b1;
                                end
                            end
                        end 
                    end
                endcase
            end
        end
    end

    reg [7:0] t_pipe_select;
    generate
        if(NUM_T_PIPES == 1) begin
            always @(posedge clk or negedge resetn) begin
                if(~resetn) begin
                    t_pipe_select <= 'b0;
                end else begin
                    t_pipe_select <= 'b0;
                end
            end
        end else begin
            always @(posedge clk or negedge resetn) begin
                if(~resetn) begin
                    t_pipe_select <= 'b0;
                end else begin

                    if(tri_count < total_num_tris) begin
                        if((vertex_attr_offset == vertexSize) && (vertex_rd_count == 'd2) && (~tri_fifo_wr_en[t_pipe_select])) begin//condition when LOAD_T_2_FIFO is done
                        
                            if(t_pipe_select < (NUM_T_PIPES - 1)) begin
                                t_pipe_select <= t_pipe_select + 'b1; 
                            end
                        
                        

                            if(t_pipe_select == (NUM_T_PIPES - 1)) begin
                                t_pipe_select <= 'b0;
                            end
                        end
                    end

                    if(tri_count == total_num_tris) begin
                        t_pipe_select <= 'b0;
                    end
                end
            end
        end
    endgenerate

    
    reg [1:0] vertex_rd_num;
    always @(*) begin
        if(~resetn) begin
            vertex_rd_num = 'b0;
        end else begin
            if(poly_storage_structure == TRIANGLE_STRIP) begin 
                case(read_order_state)
                    ABC: begin
                        vertex_rd_num = vertex_rd_count;
                    end
                    ACB: begin
                        case(vertex_rd_count)
                            'd0: vertex_rd_num = 'd0;
                            'd1: vertex_rd_num = 'd2;
                            'd2: vertex_rd_num = 'd1;
                        endcase
                    end
                    CAB: begin
                        case(vertex_rd_count)
                            'd0: vertex_rd_num = 'd2;
                            'd1: vertex_rd_num = 'd0;
                            'd2: vertex_rd_num = 'd1;
                        endcase
                    end
                    CBA: begin
                        case(vertex_rd_count)
                            'd0: vertex_rd_num = 'd2;
                            'd1: vertex_rd_num = 'd1;
                            'd2: vertex_rd_num = 'd0;
                        endcase
                    end
                    BCA: begin
                        case(vertex_rd_count)
                            'd0: vertex_rd_num = 'd1;
                            'd1: vertex_rd_num = 'd2;
                            'd2: vertex_rd_num = 'd0;
                        endcase
                    end
                    BAC: begin
                        case(vertex_rd_count)
                            'd0: vertex_rd_num = 'd1;
                            'd1: vertex_rd_num = 'd0;
                            'd2: vertex_rd_num = 'd2;
                        endcase
                    end
                endcase
            end
            if (poly_storage_structure == INDIVIDUAL_TRIANGLES) begin
                vertex_rd_num = vertex_rd_count;
            end
            
        end
    end

    
    
// t |  va          vb      vc     | write_to          |read from
// 0   x            x       x        v[i[t]]:va v[i[t+1]]:vb v[i[t+2]]:vc
// 1     v[i[t]] v[i[t+1]] v[i[t+2]]  va <-v[i[t+3]]     va,vb,vc  (012)
// 2   v[i[t+3]] v[i[t+1]] v[i[t+2]]  vb <-v[i[t+4]]     va,vc,vb  reversed (ie 321)
// 3   v[i[t+3]] v[i[t+4]] v[i[t+2]]  vc <-v[i[t+5]]     vc,va,vb (234)
// 4   v[i[t+3]] v[i[t+4]] v[i[t+5]]  va <-v[i[t+6]]     vc,vb,va reversed (543)
// 5   v[i[t+6]] v[i[t+4]] v[i[t+5]]  vb <-v[i[t+7]]     vb,vc,va (456)
// 6   v[i[t+6]] v[i[t+7]] v[i[t+5]]  vc <-v[i[t+8]]     vb,va,vc reversed (765)
// 7   v[i[t+6]] v[i[t+7]] v[i[t+8]]  va <-v[i[t+9]]     va,vb,vc (678)


    
endmodule







