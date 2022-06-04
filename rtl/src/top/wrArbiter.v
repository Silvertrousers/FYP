module wrArbiter#(
    parameter NUM_T_PIPES = 1,
    parameter FIFO_MAX_FRAGMENTS = 4,
    parameter DATA_WIDTH = 32,
    parameter MAIN_MEM_ADDR_WIDTH = 32,
    parameter LOCAL_VERTEX_MEM_ADDR_WIDTH = 4   
)(
    input wire clk,
    input wire resetn,
    input wire en,

    input wire [NUM_T_PIPES-1:0] t_pipe_done,
    //ports to write to fragment fifo
    input wire [NUM_T_PIPES-1:0][DATA_WIDTH-1:0] frag_fifo_rd_data,
    output reg [NUM_T_PIPES-1:0]                 frag_fifo_rd_en, 

    input wire [NUM_T_PIPES-1:0] frag_fifo_full, 
    input wire [NUM_T_PIPES-1:0] frag_fifo_empty, 
    input wire [NUM_T_PIPES-1:0] frag_fifo_threshold, 
    input wire [NUM_T_PIPES-1:0] frag_fifo_overflow, 
    input wire [NUM_T_PIPES-1:0] frag_fifo_underflow,

    output reg [DATA_WIDTH-1:0] frag_wr_data,
    output reg [MAIN_MEM_ADDR_WIDTH-1:0] frag_wr_addr,
    output reg frag_wr_en,

    input wire [MAIN_MEM_ADDR_WIDTH-1:0] f_array_ptr,
    input wire [LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] vertexSize
);
    reg we; //frag_wr_en = we but delayed by 1 cycle
    //NB: done count max need to be increased to match fifo size
    reg [NUM_T_PIPES-1:0][7:0] done_count;
    reg [LOCAL_VERTEX_MEM_ADDR_WIDTH-1:0] fragOffs;
    reg [MAIN_MEM_ADDR_WIDTH-1:0] frag_base_addr;
   
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            done_count <= 'b0;
            frag_fifo_rd_en <= 'b0;
        end else if(en) begin
            if(frag_fifo_rd_en[t_pipe_select] == 'b0) begin 
                if(frag_fifo_threshold[t_pipe_select]) begin
                    
                    frag_fifo_rd_en[t_pipe_select] <= 1'b1;
                    we <= 1'b1;
                end
            end
            frag_wr_en <= we;
        end
    end 
    
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            fragOffs <= 'b0;
            frag_fifo_rd_en[t_pipe_select] <= 'b0;
            frag_base_addr <= 'b0;
        end else if(en) begin
            if(frag_fifo_rd_en[t_pipe_select] == 1'b1) begin 
                frag_wr_data <= frag_fifo_rd_data[t_pipe_select];
                frag_wr_addr <= fragOffs + (frag_base_addr * (vertexSize + 'b1)) + f_array_ptr;

                if(fragOffs < vertexSize) begin
                    fragOffs <= fragOffs + 'b1;
                    
                end
                if(fragOffs == vertexSize) begin
                    fragOffs <= 'b0;
                    frag_base_addr <= frag_base_addr + 'b1;
                    frag_fifo_rd_en[t_pipe_select] <= 1'b0;
                    we <= 1'b0;
                    
                end
            end
        end
    end 
 

        // t_pipe_select
        // if frag_fifo_threshold

    

    reg [7:0] t_pipe_select;
    always @(posedge clk or negedge resetn) begin
        if(~resetn) begin
            t_pipe_select <= 'b0;
        end else begin
            if((fragOffs == vertexSize) || ((t_pipe_select == (NUM_T_PIPES-1)) && (frag_fifo_empty[t_pipe_select]))) begin // this works if assume that can write 1 frag to mem faster than 1 frag can be created
                if(t_pipe_select < (NUM_T_PIPES-1)) begin
                    t_pipe_select <= t_pipe_select + 'b1; 
                end
                if(t_pipe_select == (NUM_T_PIPES-1)) begin
                    t_pipe_select <= 'b0;
                end
            end 
        end
    end
    

// when a given t-pipe is done, read a full fragment from fifo
// first come first serve

// when t pipe is done, done count ++ for that t-pipe

// for t-pipe[i] in t-pipes: runs constantly
//     if( done count > 0):
//         read 1 whole fragment from fifo
//         t-pipe[i] done count --

endmodule