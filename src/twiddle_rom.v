//note that each number is represented as an 8-bit value, with the real part in the upper 4 bits and the imaginary part in the lower 4 bits
module twiddle_factor #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
)(
    input [ADDR_WIDTH-1:0] k, //index to select the twiddle factor
    input [ADDR_WIDTH-1:0] n,     //total number of points in the DFT
    output reg [7:0] twiddle_out //8-bit output representing the complex twiddle factor, upper 4 bits are real part, lower 4 bits are imaginary part
);
    // compute normalized angle: theta = 2*pi*k/N
    // for runtime computation, we use a lookup table indexed by k
    // The actual twiddle factor W_N^k depends on N, but we can
    // compute it as W_MaxN^(k*MaxN/N) to use a fixed-size table

    //precomputed twiddle factors for N=32
    //for a given N, the twiddle factor W_N^k = cos(2*pi*k/N) - j*sin(2*pi*k/N)
    //the values are quantized to FP4 format
    //we can select the appropriate twiddle factor based on the index input i.e k%N

    //wire [ADDR_WIDTH-1:0] scaled_k = (k*MAX_N)/n; //scale k based on actual N (won't work because of division in Verilog synthesis tools limitations)

    reg [ADDR_WIDTH-1:0] scaled_k;

    always @(*) begin
        // Since MAX_N is 32, we shift based on how much smaller n is
        case (n)
            32: scaled_k = k;           // No shift
            16: scaled_k = k << 1;      // Multiply by 2
            8:  scaled_k = k << 2;      // Multiply by 4
            4:  scaled_k = k << 3;      // Multiply by 8
            2:  scaled_k = k << 4;      // Multiply by 16
            default: scaled_k = 0;      // Handle invalid input safely
        endcase
    end

    always @(*) begin
        case(scaled_k%MAX_N) 
            5'd0: begin twiddle_out = 8'b00100000; end // 1 + j0
            5'd1: begin twiddle_out = 8'b00100000; end // 0.98 - j0.19 -> approx 1 + j0
            5'd2: begin twiddle_out = 8'b00101001; end // 0.92 - j0.38 -> approx 1 - 0.5j
            5'd3: begin twiddle_out = 8'b00101001; end // 0.83 - j0.55 -> approx 1 - 0.5j
            5'd4: begin twiddle_out = 8'b00011001; end // 0.71 - j0.71 -> approx 0.5 - 0.5j
            5'd5: begin twiddle_out = 8'b00011010; end // 0.55 - j0.83 -> approx 0.5 - 1j
            5'd6: begin twiddle_out = 8'b00011010; end // 0.38 - j0.92 -> approx 0.5 - 1j
            5'd7: begin twiddle_out = 8'b00001010; end // 0.19 - j0.98 -> approx 0 - 1j
            5'd8: begin twiddle_out = 8'b00000010; end // 0 - j1
            5'd9: begin twiddle_out = 8'b10001010; end // -0.19 - j0.98 -> approx -0 - 1j
            5'd10: begin twiddle_out = 8'b10011010; end // -0.38 - j0.92 -> approx -0.5 - 1j
            5'd11: begin twiddle_out = 8'b10011010; end // -0.55 - j0.83 -> approx -0.5 - 1j
            5'd12: begin twiddle_out = 8'b10011001; end // -0.71 - j0.71 -> approx -0.5 - 0.5j
            5'd13: begin twiddle_out = 8'b10101001; end // -0.83 - j0.55 -> approx -1 - 0.5j
            5'd14: begin twiddle_out = 8'b10101001; end // -0.92 - j0.38 -> approx -1 - 0.5j
            5'd15: begin twiddle_out = 8'b10100000; end // -0.98 - j0.19 -> approx -1 + j0
            5'd16: begin twiddle_out = 8'b10100000; end // -1 + j0
            5'd17: begin twiddle_out = 8'b10100000; end // -0.98 + j0.19 -> approx -1 + j0
            5'd18: begin twiddle_out = 8'b10101001; end // -0.92 + j0.38 -> approx -1 + 0.5j
            5'd19: begin twiddle_out = 8'b10101001; end // -0.83 + j0.55 -> approx -1 + 0.5j
            5'd20: begin twiddle_out = 8'b10011001; end // -0.71 + j0.71 -> approx -0.5 + 0.5j
            5'd21: begin twiddle_out = 8'b10011010; end // -0.55 + j0.83 -> approx -0.5 + 1j
            5'd22: begin twiddle_out = 8'b10011010; end // -0.38 + j0.92 -> approx -0.5 + 1j
            5'd23: begin twiddle_out = 8'b10001010; end // -0.19 + j0.98 -> approx -0 + 1j
            5'd24: begin twiddle_out = 8'b00000010; end // 0 + j1
            5'd25: begin twiddle_out = 8'b00001010; end // 0.19 + j0.98 -> approx 0 + 1j
            5'd26: begin twiddle_out = 8'b00011010; end // 0.38 + j0.92 -> approx 0.5 + 1j
            5'd27: begin twiddle_out = 8'b00011010; end // 0.55 + j0.83 -> approx 0.5 + 1j
            5'd28: begin twiddle_out = 8'b00011001; end // 0.71 + j0.71 -> approx 0.5 + 0.5j
            5'd29: begin twiddle_out = 8'b00101001; end // 0.83 + j0.55 -> approx 1 + 0.5j
            5'd30: begin twiddle_out = 8'b00101001; end // 0.92 + j0.38 -> approx 1 + 0.5j
            5'd31: begin twiddle_out = 8'b00100000; end // 0.98 + j0.19 -> approx 1 + j0
            default: begin twiddle_out = 8'b00000000; end //default case
        endcase
    end
endmodule