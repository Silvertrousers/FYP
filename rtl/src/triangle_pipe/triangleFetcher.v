module triangleFetcher #(
    parameter DATA_WIDTH=32,  
    parameter ADDR_WIDTH=4
)(
    input wire clk,
    input wire resetn,
    input wire en,
    
    input wire startFetch,
    input wire cull,
    output reg startCull,

    //ports from vertex attribute mem       
    output reg [2:0][DATA_WIDTH-1:0] vert_attr_wr_data,       
    output reg [2:0][ADDR_WIDTH-1:0] vert_attr_wr_addr, 
    output reg [2:0][0:0]            vert_attr_wr_en,   

    //ports to read from triangle  fifo
    input wire [DATA_WIDTH-1:0] tri_fifo_rd_data,
    output reg tri_fifo_rd_en, 

    //fifo control (unused for the moment) TODO: use these flags to control output
    input wire tri_fifo_full, 
    input wire tri_fifo_empty, 
    input wire tri_fifo_threshold, 
    input wire tri_fifo_overflow, 
    input wire tri_fifo_underflow,

    output reg [63:0] Pa,
    output reg [63:0] Pb,
    output reg [63:0] Pc,

    input  wire [ADDR_WIDTH-1:0] vertexSize
);
    reg [ADDR_WIDTH-1:0] vertexSizeReg;

    localparam V0 = 2'b00;
    localparam V1 = 2'b01;
    localparam V2 = 2'b10;
    reg [1:0] vertex_being_processed;
    reg [ADDR_WIDTH-1:0] wr_addr;

    localparam IDLE = 2'b0;
    localparam WAIT_FOR_FIFO_THRESHOLD = 2'b01;
    localparam WRITING = 2'b11;
    reg [1:0] state;
    
    always @(posedge clk or negedge resetn) begin
        if (resetn == 1'b0) begin
            vertex_being_processed <= V0;
            state <= IDLE;
            wr_addr <= 'b0;
            startCull <= 'b0;
            Pa <= 'b0;
            Pb <= 'b0;
            Pc <= 'b0;
            vertexSizeReg<= 'b0;
            vert_attr_wr_data <= 'b0;
            vert_attr_wr_addr <= 'b0;
            vert_attr_wr_en   <= 'b0;
            tri_fifo_rd_en <= 'b0;

        end else begin
            case(state)
                IDLE: begin
                    vert_attr_wr_en      <= 3'b000;
                    startCull <= 'b0;
                    if(startFetch) begin
                        state <= WAIT_FOR_FIFO_THRESHOLD;
                        vertexSizeReg <= vertexSize;
                    end 
                end
                WAIT_FOR_FIFO_THRESHOLD: begin
                    if(tri_fifo_threshold || tri_fifo_full) begin
                        state <= WRITING;
                        tri_fifo_rd_en<=1'b1; 
                    end
                end
                WRITING: begin
                    case(vertex_being_processed)
                        V0: begin
                            if(wr_addr == 'd0) Pa[63:32] <= tri_fifo_rd_data;
                            if(wr_addr == 'd1) Pa[31:0] <= tri_fifo_rd_data;
                            vert_attr_wr_data[0] <= tri_fifo_rd_data;
                            vert_attr_wr_addr[0] <= wr_addr;
                            vert_attr_wr_en      <= 3'b001;
                        end
                        V1: begin
                            if(wr_addr == 'd0) Pb[63:32] <= tri_fifo_rd_data;
                            if(wr_addr == 'd1) Pb[31:0] <= tri_fifo_rd_data;
                            vert_attr_wr_data[1] <= tri_fifo_rd_data;
                            vert_attr_wr_addr[1] <= wr_addr;
                            vert_attr_wr_en      <= 3'b010;
                        end
                        V2: begin
                            if(wr_addr == 'd0) Pc[63:32] <= tri_fifo_rd_data;
                            if(wr_addr == 'd1) Pc[31:0] <= tri_fifo_rd_data;
                            if(wr_addr == (vertexSizeReg)) tri_fifo_rd_en <= 1'b0; 
                            vert_attr_wr_data[2] <= tri_fifo_rd_data;
                            vert_attr_wr_addr[2] <= wr_addr;
                            
                            vert_attr_wr_en      <= 3'b100;
                            
                        end
                    endcase
                    if(wr_addr < vertexSizeReg) begin
                        wr_addr <= wr_addr + 1;
                        
                        
                    end
                    if(wr_addr == vertexSizeReg) begin
                        wr_addr <= 'b0;
                        case(vertex_being_processed)
                            V0: vertex_being_processed<= V1;
                            V1: vertex_being_processed<= V2;
                            V2: begin
                                vertex_being_processed<= V0;
                                state<= IDLE;
                                startCull <= 1'b1;
                            end
                        endcase
                    end
                end
            endcase


        end
    end
    
endmodule