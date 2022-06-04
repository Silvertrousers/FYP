//http://www.mathcs.emory.edu/~cheung/Courses/255/Syl-ARM/5-repr/IntFloatConv.html
module int2fp32(
    input wire [31:0] int,
    output wire [31:0] float
);
    wire [4:0] first_set_bit;
    wire intEq0;
    wire [22:0] mantissa;
    wire [7:0] exp;
    first_set_bit32 first_set_bit32_inst(int, first_set_bit, intEq0);

    assign exp = {3'b000,first_set_bit} + 8'b01111111;
    wire [31:0] shifted_int;
    wire [5:0] shamt, fsb6bit;
    assign fsb6bit = {1'b0,first_set_bit};
    assign shamt = 6'd32 - fsb6bit;
    shift32 shift32_inst(int,shamt,shifted_int);

    assign mantissa = shifted_int[31:9]; 

    assign float = intEq0 ? 32'b0 : {1'b0,exp,mantissa};
endmodule

module shift32(
    input wire [31:0] in, 
    input wire [5:0] shamt,
    output reg [31:0] out
);
    always @(*) begin
        case(shamt)
            6'd0: out = in<<0;
            6'd1: out = in<<1;
            6'd2: out = in<<2;
            6'd3: out = in<<3;
            6'd4: out = in<<4;
            6'd5: out = in<<5;
            6'd6: out = in<<6;
            6'd7: out = in<<7;
            6'd8: out = in<<8;
            6'd9: out = in<<9;
            6'd10: out = in<<10;
            6'd11: out = in<<11;
            6'd12: out = in<<12;
            6'd13: out = in<<13;
            6'd14: out = in<<14;
            6'd15: out = in<<15;
            6'd16: out = in<<16;
            6'd17: out = in<<17;
            6'd18: out = in<<18;
            6'd19: out = in<<19;
            6'd20: out = in<<20;
            6'd21: out = in<<21;
            6'd22: out = in<<22;
            6'd23: out = in<<23;
            6'd24: out = in<<24;
            6'd25: out = in<<25;
            6'd26: out = in<<26;
            6'd27: out = in<<27;
            6'd28: out = in<<28;
            6'd29: out = in<<29; 
            6'd30: out = in<<30;
            6'd31: out = in<<31;
            6'd32: out = in<<32;
            default: out = in<<0;
        endcase
    end

endmodule
module int2fp32_tb();
    reg [31:0] int;
    wire [31:0] float;
    int2fp32 int2fp32_inst(int,float);  
    initial begin
        int = 32'd4;
        #10 int = 32'd546;
        #10 int = 32'd1231506;
        #10 int = 32'd52540036;
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("int2fp32_tb.vcd");
            $dumpvars(0,int2fp32_tb);
            #1;
        end
    
endmodule

module first_set_bit32(
    input wire [31:0] x,
    output wire [4:0] q,
    output wire aOut
);
    wire [3:0] z0,z1;
    wire [1:0] a;
    
    first_set_bit16 lzc0(x[15:0],z0,a[0]);
    first_set_bit16 lzc1(x[31:16],z1,a[1]);
    assign aOut = a[1] && a[0];
    assign q = (a[1]) ? {1'b0,z0} : {1'b1,z1};
endmodule


module first_set_bit16_tb();
    reg [15:0] x;
    wire [3:0] q;
    wire aOut;
    first_set_bit16 DUT(x,q,aOut);  
    initial begin
        x = 16'b0000_0000_0000_0000;
        #10 x = 16'b0000_0000_0000_1000;
        #10 x = 16'b0000_0000_1000_0000;
        #10 x = 16'b0001_0000_0000_0000;
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("first_set_bit16_tb.vcd");
            $dumpvars(0,first_set_bit16_tb);
            #1;
        end
    
endmodule


module first_set_bit16(
    input wire [15:0] x,
    output wire [3:0] q,
    output wire aOut
);
    wire [2:0] z0,z1;
    wire [1:0] a;
    
    first_set_bit8 lzc0(x[7:0],z0,a[0]);
    first_set_bit8 lzc1(x[15:8],z1,a[1]);
    assign aOut = a[1] && a[0];
    assign q = (a[1]) ? {1'b0,z0} : {1'b1,z1};
endmodule

module first_set_bit8(
    input wire [7:0] x,
    output wire [2:0] q,
    output wire aOut
);
    wire [1:0] z0,z1;
    wire [1:0] a;
    
    first_set_bit4 lzc0(x[3:0],z0,a[0]);
    first_set_bit4 lzc1(x[7:4],z1,a[1]);
    assign aOut = a[1] && a[0];
    assign q = (a[1]) ? {1'b0,z0} : {1'b1,z1};
endmodule


module first_set_bit8_tb();
    reg [7:0] x;
    wire [2:0] q;
    wire aOut;
    first_set_bit8 DUT(x,q,aOut);  
    initial begin
        x = 8'b0000_0100; //010
        #10 x = 8'b0000_1000; //011
        #10 x = 8'b0010_0000; //101
        #10 x = 8'b1000_0000; //111
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("first_set_bit8_tb.vcd");
            $dumpvars(0,first_set_bit8_tb);
            #1;
        end
    
endmodule

module first_set_bit4_tb();
    reg [3:0] x;
    wire [1:0] q;
    wire aOut;
    first_set_bit4 DUT(x,q,aOut);  
    initial begin
        x = 16'b0000;
        #10 x = 16'b1000;
        #10 x = 16'b0000;
        #10 x = 16'b0000;
        #10
        $finish;
    end
    initial
        begin
            $dumpfile("first_set_bit4_tb.vcd");
            $dumpvars(0,first_set_bit4_tb);
            #1;
        end
    
endmodule
//Leading zero count
//https://digitalsystemdesign.in/leading-zero-counter/


module first_set_bit4(
    input wire [3:0] x,
    output wire [1:0] q,
    output wire a
);
    assign a = ~x[3] && ~x[2] && ~x[1] && ~x[0]; 
    assign q = 2'b11 - {~(x[3] || x[2]),(~x[3] && x[2]) || (~x[3] && ~x[1])};
    
endmodule
