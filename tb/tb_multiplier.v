//Testbench for testing the multiplier
//Right now tests the fp4_mul 

`timescale 1ns / 1ps

module tb_fp4_mul;

    // Inputs
    reg [3:0] a;
    reg [3:0] b;

    // Outputs
    wire [3:0] out;

    // Instantiate the Unit Under Test (UUT)
    fp4_mul uut (
        .a(a), 
        .b(b), 
        .out(out)
    );

    // Variable to help loop through tests if needed
    integer i;

    initial begin
        $dumpfile("fp4_mul.vcd");
        $dumpvars(0, tb_fp4_mul);

        $display("Time |   A (Hex)  |   B (Hex)  | Out (Hex) |");
        $display("--------------------------------------------");

        a = 4'b0010; b = 4'b0010;
        #10;
        $display("%4t | %b (1.0) | %b (1.0) | %b", $time, a, b, out);

        a = 4'b0011; b = 4'b0100;
        #10;
        $display("%4t | %b (1.5) | %b (2.0) | %b", $time, a, b, out);

        a = 4'b0011; b = 4'b0011;
        #10;
        $display("%4t | %b (1.5) | %b (1.5) | %b", $time, a, b, out);

        a = 4'b0000; b = 4'b0111;
        #10;
        $display("%4t | %b (0.0) | %b (6.0) | %b", $time, a, b, out);

        a = 4'b0111; b = 4'b0111;
        #10;
        $display("%4t | %b (6.0) | %b (6.0) | %b", $time, a, b, out);

        a = 4'b1010; b = 4'b0011;
        #10;
        $display("%4t | %b(-1.0) | %b (1.5) | %b", $time, a, b, out);
        
        $finish;
    end
endmodule