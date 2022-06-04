module fragment_interpolator_Test#(
    parameter PIN = {QuarterFP,QuarterFP},
    parameter NOPERSPECTIVE = 'b0,
    parameter FLAT = 'b0,
    parameter PROVOKEMODE = 'b0,
    parameter VERTEXSIZE = 4'd15
)();
    
    localparam DATA_WIDTH = 32;
    localparam ADDR_WIDTH = 4;
    localparam CYCLES_WAIT_FOR_RECIEVE = 4'b0001;
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*1000;
    reg clk;
    reg resetn, en;

    wire [2:0][ADDR_WIDTH-1:0] vert_attr_rd_addr;
    wire [2:0][0:0]            vert_attr_rd_en;
    wire [2:0][DATA_WIDTH-1:0] vert_attr_rd_data; 

    wire [DATA_WIDTH-1:0] frag_attr_wr_data;       
    wire [ADDR_WIDTH-1:0] frag_attr_wr_addr;
    wire                  frag_attr_wr_en;

    wire [65:0] PinRecFN;
    reg [63:0] Pin;
    reg start;
    wire done;
    reg noPerspective, flat, provokeMode;
    reg [ADDR_WIDTH-1:0] vertexSize;

v0ROM #(DATA_WIDTH, ADDR_WIDTH)v0ROM_inst(
    vert_attr_rd_addr[0], 
    clk,   
    vert_attr_rd_en[0],        
    vert_attr_rd_data[0]
);
v1ROM #(DATA_WIDTH, ADDR_WIDTH)v1ROM_inst(
    vert_attr_rd_addr[1], 
    clk,   
    vert_attr_rd_en[1],        
    vert_attr_rd_data[1]
);
v2ROM #(DATA_WIDTH, ADDR_WIDTH)v2ROM_inst(
    vert_attr_rd_addr[2], 
    clk,   
    vert_attr_rd_en[2],        
    vert_attr_rd_data[2]
);

fNToRecFN#(8,24) fNToRecFNx (Pin[63:32], PinRecFN[65:33]);
fNToRecFN#(8,24) fNToRecFNy (Pin[31:0], PinRecFN[32:0]);


wire [32:0] halfrecfp;
fNToRecFN#(8,24) fNToRecFNtest (HalfFP, halfrecfp);

fragment_interpolator #(
    DATA_WIDTH, ADDR_WIDTH, CYCLES_WAIT_FOR_RECIEVE
) DUT (
    clk,resetn,en,
    frag_attr_wr_data,       
    frag_attr_wr_addr, 
    frag_attr_wr_en,  

    vert_attr_rd_data,       
    vert_attr_rd_addr, 
    vert_attr_rd_en,    

    PinRecFN,

    start, done,   
    
    noPerspective,
    flat, provokeMode,
    vertexSize 
);

simple_ram_dual_clock#(
    DATA_WIDTH,                 //width of data bus
    ADDR_WIDTH                  //width of addresses buses
) frag_mem (
    .data(frag_attr_wr_data),       //data to be written
    .read_addr(),  //address for read operation
    .write_addr(frag_attr_wr_addr), //address for write operation
    .we(frag_attr_wr_en),
    .read_clk(clk),
    .write_clk(clk),
    .re(),
    .q()
);
    initial
        begin
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
            #(PERIOD/2);
            en = 1'b1;
            start = 1'b1;
            Pin = PIN;
            noPerspective = NOPERSPECTIVE;
            flat = FLAT;
            provokeMode = PROVOKEMODE;
            vertexSize = VERTEXSIZE;
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
    
    always @(frag_attr_wr_en, frag_attr_wr_data, frag_attr_wr_addr) begin
        if(frag_attr_wr_en) begin
            $display("[fragment_write] data:0x%0h, addr:0x%0h ", frag_attr_wr_data, frag_attr_wr_addr);
        end
    end
    // always@(negedge clk) begin
    //     if (done == 1'b1) begin
    //         $display("test finished for input combination");
    //         $finish;
    //     end
    // end

    initial 
        begin
            #TIMEOUT;
            $display("Simulation Timed Out :(");
            $finish;
        end
    initial
        begin
            $dumpfile("fragment_interpolator_Test.vcd");
            $dumpvars(0,fragment_interpolator_Test);
            #1;
        end
endmodule

module v0ROM #(
    parameter DATA_WIDTH=32,                 //width of data bus
    parameter ADDR_WIDTH=4                  //width of addresses buses
)(
    input      [ADDR_WIDTH-1:0] read_addr,  //address for read operation
    input                       read_clk,   //clock signal for read operation
    input                       re,         //read enable signal
    output reg [DATA_WIDTH-1:0] q           //read data
);
    
    reg [DATA_WIDTH-1:0] rom [0:2**ADDR_WIDTH-1]; // ** is exponentiation
    initial begin
        $readmemh ("v0ROM.mem", rom); // this IS synthesizable on Xilinx
    end

    always @(posedge read_clk) begin //READ
        if (re) begin
            q <= rom[read_addr];
        end
    end
    
endmodule

module v1ROM #(
    parameter DATA_WIDTH=32,                 //width of data bus
    parameter ADDR_WIDTH=4                  //width of addresses buses
)(
    input      [ADDR_WIDTH-1:0] read_addr,  //address for read operation
    input                       read_clk,   //clock signal for read operation
    input                       re,         //read enable signal
    output reg [DATA_WIDTH-1:0] q           //read data
);
    
    reg [DATA_WIDTH-1:0] rom [0:2**ADDR_WIDTH-1]; // ** is exponentiation
    initial begin
        $readmemh ("v1ROM.mem", rom); // this IS synthesizable on Xilinx
    end

    always @(posedge read_clk) begin //READ
        if (re) begin
            q <= rom[read_addr];
        end
    end
    
endmodule
module v2ROM #(
    parameter DATA_WIDTH=32,                 //width of data bus
    parameter ADDR_WIDTH=4                  //width of addresses buses
)(
    input      [ADDR_WIDTH-1:0] read_addr,  //address for read operation
    input                       read_clk,   //clock signal for read operation
    input                       re,         //read enable signal
    output reg [DATA_WIDTH-1:0] q           //read data
);
    
    reg [DATA_WIDTH-1:0] rom [0:2**ADDR_WIDTH-1]; // ** is exponentiation
    initial begin
        $readmemh ("v2ROM.mem", rom); // this IS synthesizable on Xilinx
    end

    always @(posedge read_clk) begin //READ
        if (re) begin
            q <= rom[read_addr];
        end
    end
    
endmodule