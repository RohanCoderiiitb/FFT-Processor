module fp4_butterfly(
    input [7:0] A,
    input [7:0] B,
    input [7:0] W,
    output [7:0] X,
    output [7:0] Y
);
    //step 1: complex multiplication

    wire [7:0] wb_product;

    fp4_cmul complex_mult_inst(
        .a(B[7:4]), //real part of B
        .b(B[3:0]), //imag part of B
        .c(W[7:4]), //real part of W
        .d(W[3:0]), //imag part of W
        .out_real(wb_product[7:4]),
        .out_imag(wb_product[3:0])
    );

    //step 2: complex addition
    fp4_complex_add_sub add_inst(
        .a(A),
        .b(wb_product),
        .sub(1'b0),
        .out(X)
    );

    //step 3: complex subtraction
    fp4_complex_add_sub sub_inst(
        .a(A),
        .b(wb_product),
        .sub(1'b1),
        .out(Y)
    );

endmodule
