//testbench for the adder module

`timescale 1ns / 1ps

module tb_fp4_adder;

    // Inputs
    reg [3:0] a;
    reg [3:0] b;
    reg sub; //sub=0 for addition, sub=1 for subtraction

    // Outputs
    wire [3:0] out;

    // Instantiate the Unit Under Test (UUT)
    fp4_add_sub uut (
        .a(a), 
        .b(b), 
        .sub(sub), 
        .out(out)
    );

    initial begin
        // Initialize Inputs
        a = 4'b0000; // 0
        b = 4'b0000; // 0
        sub = 0;     // addition

        // Wait 10 ns for global reset to finish
        #10;
        
        // Test addition
        a = 4'b0101;  
        b = 4'b0011; 
        sub = 0;     // addition
        #10;
        $display("A: %b, B: %b, Sub: %b => Out: %b", a, b, sub, out);
        
        // Test subtraction
        a = 4'b1101; 
        b = 4'b0011; 
        sub = 1;     // subtraction
        #10;
        $display("A: %b, B: %b, Sub: %b => Out: %b", a, b, sub, out);
        
        // Finish simulation
        $finish;
    end
endmodule