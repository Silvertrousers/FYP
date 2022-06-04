module delaySignal#(
    parameter NUM_CYCLES = 1,
    parameter DATA_WIDTH = 1

)(
    input  wire clk,
    input  wire resetn, 
    input  wire [DATA_WIDTH-1:0] in, 
    output wire  [DATA_WIDTH-1:0] out
);
    reg [NUM_CYCLES-1:0][DATA_WIDTH-1:0] delayedSignal;
   
    genvar i;
    generate
    for (i=0; i < NUM_CYCLES; i=i+1) begin
        always @(posedge clk or negedge resetn) begin
            if (resetn == 1'b0) begin
                delayedSignal[i] <= 'b0;
            end else begin
                delayedSignal[i] <= delayedSignal[i-1];
            end
        end
        
    end
    endgenerate
   
    assign out = delayedSignal[NUM_CYCLES-1];
endmodule