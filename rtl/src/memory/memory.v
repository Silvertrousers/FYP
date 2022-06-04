
// Top level Verilog code for FIFO Memory
module FIFO #(
    parameter DATAWIDTH = 8,
    parameter DEPTH = 16 //must be power of two
)(
    output wire [(DATAWIDTH-1):0] data_out,
    output wire fifo_full, 
    output wire fifo_empty, 
    output wire fifo_threshold, 
    output wire fifo_overflow, 
    output wire fifo_underflow,
    input wire clk, 
    input wire resetn, 
    input wire wr, 
    input wire rd, 
    input wire [(DATAWIDTH-1):0] data_in,
    input wire [$clog2(DEPTH):0] threshold_level
);  
    
    wire [$clog2(DEPTH):0] wptr,rptr;  
    wire fifo_we,fifo_rd;   
    write_pointer #(DATAWIDTH, DEPTH) write_pointer_i (wptr,fifo_we,wr,fifo_full,clk,resetn);  
    read_pointer  #(DATAWIDTH, DEPTH) read_pointer_i (rptr,fifo_rd,rd,fifo_empty,clk,resetn);  
    memory_array  #(DATAWIDTH, DEPTH) memory_array_i (data_out, data_in, clk,fifo_we, wptr,rptr);  
    status_signal #(DATAWIDTH, DEPTH) status_signal_i (fifo_full, fifo_empty, fifo_threshold, fifo_overflow, fifo_underflow, wr, rd, fifo_we, fifo_rd, wptr,rptr,clk,resetn,threshold_level);  
 endmodule  


// Verilog code for Memory Array submodule 
// depth must be power of 2, no since clog2 gives the ciel of the log2 of input 
module memory_array#(
    parameter DATAWIDTH = 8,
    parameter DEPTH = 16
)(
    output wire [(DATAWIDTH-1):0] data_out, 
    input  wire [(DATAWIDTH-1):0] data_in, 
    input  wire clk,
    input  wire fifo_we, 
    input wire [$clog2(DEPTH):0] wptr,
    input wire [$clog2(DEPTH):0] rptr
);  
    reg [(DEPTH-1):0][(DATAWIDTH-1):0] data_out2;  
    
    always @(posedge clk)  begin  
        if(fifo_we) begin
            data_out2[wptr[($clog2(DEPTH)-1):0]] <=data_in ;  
            //$display("{\"time\":\"%0t\",\"label\":\"[fifo_write]\", \"data\":\"[0x%0h]\"},", $time, data_in);
        end
    end  
    assign data_out = data_out2[rptr[($clog2(DEPTH)-1):0]];  
endmodule  


// Verilog code for Read Pointer sub-module 
module read_pointer#(
    parameter DATAWIDTH = 8,
    parameter DEPTH = 16
)(
    output reg [$clog2(DEPTH):0] rptr,
    output wire fifo_rd,
    input  wire rd,
    input  wire fifo_empty,
    input  wire clk,
    input  wire resetn
);  
    assign fifo_rd = (~fifo_empty)& rd;  
    always @(posedge clk or negedge resetn) begin  
        if(~resetn) 
            rptr <= 'b0;  
        else if(fifo_rd)  
            rptr <= rptr + 'b1;  
        else  
            rptr <= rptr;  
    end  
endmodule  

// Verilog code for Write Pointer sub-module 
module write_pointer#(
    parameter DATAWIDTH = 8,
    parameter DEPTH = 16
)(
    output reg [$clog2(DEPTH):0] wptr,
    output wire fifo_we,
    input wire wr,
    input wire fifo_full,
    input wire clk,
    input wire resetn
);  
    assign fifo_we = (~fifo_full) & wr;  
    always @(posedge clk or negedge resetn) begin  
        if(~resetn) 
            wptr <= 'b0;  
        else if(fifo_we)  
            wptr <= wptr + 'b1;  
        else  
            wptr <= wptr;  
    end  
endmodule  


// Verilog code for Status Signals sub-module 
module status_signal#(
    parameter DATAWIDTH = 8,
    parameter DEPTH = 16
)(
    output reg fifo_full, 
    output reg fifo_empty, 
    output reg fifo_threshold, 
    output reg fifo_overflow, 
    output reg fifo_underflow, 
    input wire wr, 
    input wire rd, 
    input wire fifo_we, 
    input wire fifo_rd, 
    input wire [$clog2(DEPTH):0]wptr,
    input wire [$clog2(DEPTH):0]rptr,
    input wire clk,
    input wire resetn,
    input wire [$clog2(DEPTH):0] threshold_level
);  
    wire fbit_comp, overflow_set, underflow_set;  
    wire pointer_equal;  
    wire [$clog2(DEPTH):0] pointer_result;  
    assign fbit_comp = wptr[$clog2(DEPTH)] ^ rptr[$clog2(DEPTH)];  
    assign pointer_equal = ((wptr[$clog2(DEPTH)-1:0] - rptr[$clog2(DEPTH)-1:0]) == 'b0) ? 1:0;  
    assign pointer_result = wptr[$clog2(DEPTH)-1:0] - rptr[$clog2(DEPTH)-1:0];  
    assign overflow_set = fifo_full & wr;  
    assign underflow_set = fifo_empty&rd; 

    always @(*) begin  
        fifo_full = fbit_comp & pointer_equal;  
        fifo_empty = (~fbit_comp) & pointer_equal;  
        fifo_threshold = (pointer_result >= threshold_level[$clog2(DEPTH)-1:0]) ? 1:0;  
    end  

    always @(posedge clk or negedge resetn) begin  
        if(~resetn) 
            fifo_overflow <=0;  
        else if((overflow_set==1)&&(fifo_rd==0))  
            fifo_overflow <=1;  
        else if(fifo_rd)  
            fifo_overflow <=0;  
        else  
            fifo_overflow <= fifo_overflow;  
    end  

    always @(posedge clk or negedge resetn) begin  
        if(~resetn) fifo_underflow <=0;  
        else if((underflow_set==1)&&(fifo_we==0))  
        fifo_underflow <=1;  
        else if(fifo_we)  
        fifo_underflow <=0;  
        else  
        fifo_underflow <= fifo_underflow;  
    end  
endmodule  

module single_port_ram
(
	input [7:0] data,
	input [5:0] addr,
	input we, clk,
	output [7:0] q
);

	// Declare the RAM variable
	reg [7:0] ram[63:0];
	
	// Variable to hold the registered read address
	reg [5:0] addr_reg;
	
	always @ (posedge clk)
	begin
	// Write
		if (we)
			ram[addr] <= data;
		
		addr_reg <= addr;
		
	end
		
	// Continuous assignment implies read returns NEW data.
	// This is the natural behavior of the TriMatrix memory
	// blocks in Single Port mode.  
	assign q = ram[addr_reg];
	
endmodule


module ROM #(
    parameter DATA_WIDTH=8,                 //width of data bus
    parameter ADDR_WIDTH=8                  //width of addresses buses
)(
    input      [ADDR_WIDTH-1:0] read_addr,  //address for read operation
    input                       read_clk,   //clock signal for read operation
    input                       re,         //read enable signal
    output reg [DATA_WIDTH-1:0] q           //read data
);
    
    reg [DATA_WIDTH-1:0] rom [2**ADDR_WIDTH-1:0]; // ** is exponentiation
    initial begin
        $readmemh ("hello_world.hex", rom, 0); // this IS synthesizable on Xilinx
    end

    always @(posedge read_clk) begin //READ
        if (re) begin
            q <= rom[read_addr];
        end
    end
    
endmodule

module simple_ram_dual_clock #(
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
  output wire[DATA_WIDTH-1:0] q           //read data
);
    
    reg [(2**ADDR_WIDTH)-1:0][DATA_WIDTH-1:0] ram; // ** is exponentiation
    // initial begin
    //     ram = 'b0;
    // end
    always @(posedge write_clk) begin //WRITE
        if (we) begin 
            ram[write_addr] <= data;
        end
    end
    assign q = ram[read_addr];
    // always @(posedge read_clk) begin //READ
    //     if (re) begin
    //         q <= ram[read_addr];
    //     end
    // end
    
endmodule



