// Module for complex multiplication

// Main module name is fp4_cmul. Uses 2 helper modules : fp4_mul(multiplying 2 FP4 numbers) and fp4_add_sub(adding or subtracting 2 FP4 numbers)

//E2M1 format is used: 1 sign bit(MSB bit = 3), 2 exponent bits(bits 2 and 1), 1 mantissa bit(LSB bit = 1)

module fp4_mul(
    input [3:0] a,
    input [3:0] b,
    output [3:0] out
);
    //Unpacking the FP4 numbers to extract the sign bit, exponent bits, mantissa bit
    wire sign_a = a[3], sign_b = b[3];
    wire [1:0] exp_a = a[2:1], exp_b = b[2:1];
    wire mant_a = a[0], mant_b = b[0];

    //Sign bit of the output
    wire sign_out = sign_a ^ sign_b;

    //Detecting whether the inputs are 0
    wire a_zero = (exp_a == 2'b00 && mant_a == 1'b0);
    wire b_zero = (exp_b == 2'b00 && mant_b == 1'b0);

    //Temporary exponent bits
    wire [2:0] exp_sum = {1'b0, exp_a} + {1'b0, exp_b};
    wire signed [3:0] exp_temp = $signed({1'b0, exp_sum}) - 4'sd1;

    //Normalization and Rounding off
    wire hidden_a = (exp_a != 2'b00);
    wire hidden_b = (exp_b != 2'b00);
    wire [2:0] sig_a = {1'b0, hidden_a, mant_a};
    wire [2:0] sig_b = {1'b0, hidden_b, mant_b};
    wire [4:0] prod = sig_a * sig_b;
    wire need_norm = (prod >= 5'd8);
    wire [4:0] prod_norm = (need_norm) ? (prod >> 1) : prod;
    wire signed [3:0] exp_norm = (need_norm) ? (exp_temp + 1) : exp_temp;
    wire mant_out = (exp_norm == 0) ? prod_norm[1] : (prod_norm >= 5'd5);

    //Preparing the output
    reg [3:0] output_reg;
    always @(*) begin
        if(a_zero || b_zero || exp_norm<0) begin
            output_reg = 4'b0000;
        end
        else if(exp_norm > 3) begin
            output_reg = {sign_out, 2'b11, 1'b1};
        end
        else begin
            output_reg = {sign_out, exp_norm[1:0], mant_out};
        end
    end
    assign out = output_reg;

endmodule

// Let's consider 2 complex numbers z1 = a + jb and z2 = c + jd
// Inputs have been named following the above nomenclature
// z1*z2 = (ac - bd) + j(ad + bc) => Re(z1*z2) = ac-bd and Im(z1*z2) = ad + bc
// Clearly we require 4 multipliers to compute each of the products above and 2 adder_subtractor modules
// The below fp4_cmul module handles complex multiplication
module fp4_cmul (
    input [3:0] a,
    input [3:0] b,
    input [3:0] c,
    input [3:0] d,
    output [3:0] out_real,
    output [3:0] out_imag
);
    wire [3:0] ac, bd, ad, bc;
    fp4_mul m1(.a(a), .b(c), .out(ac));
    fp4_mul m2(.a(b), .b(d), .out(bd));
    fp4_mul m3(.a(a), .b(d), .out(ad));
    fp4_mul m4(.a(b), .b(c), .out(bc));

    wire [3:0] res_real;
    wire [3:0] res_imag;
    fp4_add_sub s1(.a(ac), .b(bd), .sub(1'b1), .out(res_real));
    fp4_add_sub a1(.a(ad), .b(bc), .sub(1'b0), .out(res_imag));
    assign out_real = res_real;
    assign out_imag = res_imag;
endmodule