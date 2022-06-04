module delaySignal_Test();
    localparam OneFP = 32'h3f800000;
    localparam ZeroFP = 32'h00000000;
    localparam HalfFP = 32'h3f000000;
    localparam QuarterFP = 32'h3e800000;
    localparam PERIOD = 20;
    localparam TIMEOUT = PERIOD*1000;
    reg in, clk,resetn;
    wire out;
    delaySignal#(4,1) DUT (clk,resetn,in,out);
    
    initial
        begin
            resetn = 1'b1;
            #(PERIOD/2);
            resetn = 1'b0; 
            #(PERIOD/2);
            resetn = 1'b1;
        end
    always 
        begin
            clk = 1'b1; 
            #(PERIOD/2);
            clk = 1'b0;
            #(PERIOD/2);
        end
    
    initial // initial block executes only once
        begin
            // values for a and b
            in = 1;
            
        
    end
    //Timeout
    initial begin
        #TIMEOUT;
        $display("Simulation Timed Out :(");
        $finish;
    end
    initial
        begin
            $dumpfile("delaySignal_Test.vcd");
            $dumpvars(0,delaySignal_Test);
            #1;
        end
endmodule