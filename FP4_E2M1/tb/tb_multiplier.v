`timescale 1ns / 1ps

module tb_fp4_cmul;

    // Inputs: z1 = a + jb, z2 = c + jd
    reg [3:0] a, b, c, d;

    // Outputs
    wire [3:0] out_real, out_imag;

    // Instantiate the Complex Multiplier
    fp4_cmul uut (
        .a(a), .b(b), 
        .c(c), .d(d), 
        .out_real(out_real), 
        .out_imag(out_imag)
    );

    // Helper parameters for readable values
    localparam ZERO   = 4'b0000; // 0.0
    localparam ONE    = 4'b0010; // 1.0
    localparam NEG_1  = 4'b1010; // -1.0
    localparam ONE_PT_5 = 4'b0011; // 1.5
    localparam TWO    = 4'b0100; // 2.0

    initial begin
        // Monitor changes automatically
        $monitor("Time=%0t | z1=(%b + j%b) * z2=(%b + j%b) | Out = %b + j%b", 
                 $time, a, b, c, d, out_real, out_imag);

        // 1. Identity: (1 + j0) * (1 + j0)
        // Expect: 1 + j0
        a = ONE; b = ZERO; c = ONE; d = ZERO;
        #10;

        // 2. Imaginary Unit: (0 + j1) * (0 + j1)
        // Expect: -1 + j0 (Remember -1 is 1010)
        a = ZERO; b = ONE; c = ZERO; d = ONE;
        #10;

        // 3. Rotation: (1 + j0) * (0 + j1)
        // Expect: 0 + j1
        a = ONE; b = ZERO; c = ZERO; d = ONE;
        #10;

        // 4. Conjugate: (1 + j1) * (1 - j1)
        // Expect: 2 + j0 (2.0 is 0100)
        a = ONE; b = ONE; c = ONE; d = NEG_1;
        #10;

        // 5. Scaling: (1.5 + j0) * (0 + j2)
        // Expect: 0 + j3 (3.0 is 0101)
        a = ONE_PT_5; b = ZERO; c = ZERO; d = TWO;
        #10;

        $finish;
    end

endmodule