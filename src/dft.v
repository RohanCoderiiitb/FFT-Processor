//the dft module utilizes the fp4 multiplier and complex adder/subtractor modules, as well as the memory module to perform an N-point DFT on FP4 complex inputs
//since the memory reaches back to only 32 points, we limit N to a maximum of 32
//`include "multiplier.v"
//`include "adder.v"
//`include "memory.v"

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

module fp4_dft_core #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [ADDR_WIDTH-1:0] N, //number of points in the DFT
    output reg done,

    //memory interface (uses ping pong memory with bank_sel toggling after DFT completion)
    input wire bank_sel, //selects which memory bank to read from/write to
    output wire [7:0] rd_data_0,
    // input wire [ADDR_WIDTH-1:0] rd_addr_0,
    // input wire wr_en_1,
    // input wire [ADDR_WIDTH-1:0] wr_addr_1, //these will be generated internally
    // input wire [7:0] wr_data_1,

    //external write interface
    input wire ext_wr_en, //external write enable for input data
    input wire [ADDR_WIDTH-1:0] ext_wr_addr, //external write address for input data
    input wire [7:0] ext_wr_data, //external write data (input samples)

    //external read interface
    input wire [ADDR_WIDTH-1:0] ext_rd_addr, //external read address for results

    output reg error
    
);

    //state machine definitions
    localparam IDLE = 4'd0; //waiting for start signal
    localparam INIT = 4'd1; //initialization state
    localparam READ_X = 4'd2; //read input sample X[n]
    localparam WAIT_MEM = 4'd3; //wait for memory read
    localparam COMPUTE_W = 4'd4; //compute twiddle factor W_N^(k*n)
    localparam MULTIPLY = 4'd5; //multiply X[n] by W_N^(k*n)
    localparam WAIT_MULT = 4'd6; //wait for multiplication to complete
    localparam ACCUMULATE = 4'd7; //accumulate result into X[k]
    localparam INCREMENT_N = 4'd8; //increment n
    localparam WRITE_XK = 4'd9; //write output X[k] to memory
    localparam INCREMENT_K = 4'd10; //increment k
    localparam DONE = 4'd11; //DFT complete

    reg [3:0] state, next_state;


    //computation registers and counters
    reg [ADDR_WIDTH-1:0] k; //counter for output index k
    reg [ADDR_WIDTH-1:0] n; //counter for input index n

    reg [7:0] Xn; //input sample x[n] from memory
    reg [7:0] twiddle; //twiddle factor W_N^(k*n)
    reg [7:0] product; //result of multiplication X[n] * W_N^(k*n)
    reg [7:0] Xk_accum; //accumulator for output sample X[k]

    //internal memory control signals for DFT computation
    reg [ADDR_WIDTH-1:0] int_rd_addr; //internal read address during DFT
    wire [7:0] int_rd_data; //internal read data during DFT
    reg int_wr_en; //internal write enable for DFT results
    reg [ADDR_WIDTH-1:0] int_wr_addr; //internal write address for DFT results
    reg [7:0] int_wr_data; //internal write data for DFT results

    //between external writes (input loading) and internal writes (DFT results)
    wire final_wr_en = ext_wr_en | int_wr_en; //either external or internal write enable
    wire [ADDR_WIDTH-1:0] final_wr_addr = ext_wr_en ? ext_wr_addr : int_wr_addr; //mux for write address, external for input loading, internal for DFT results
    wire [7:0] final_wr_data = ext_wr_en ? ext_wr_data : int_wr_data; //mux for write data, external for input loading, internal for DFT results
    
    //mux for read address - external for result readout, internal for DFT computation
    wire [ADDR_WIDTH-1:0] final_rd_addr = (state == IDLE || state == DONE) ? ext_rd_addr : int_rd_addr;


    //twiddle factor generator interface
    wire [ADDR_WIDTH-1:0] twiddle_k; //index (k*n) mod N for twiddle factor
    //assign twiddle_k = (k*n)%N;
    wire [7:0] twiddle_out; //twiddle factor output

    //multiplier interface
    wire [3:0] mult_real, mult_imag; //complex multiplier outputs
    wire [7:0] mult_result;  //combined output

    //adder interface
    wire [7:0] accum_next; //next accumulator value

    //twiddle factor generator instance
    //computer W_N^(k*n) = exp(-j*2*pi*k*n/N)
    assign twiddle_k = (k*n)%N; //ensures we stay within bounds of N
    twiddle_factor #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) twiddle_inst (
        .k(twiddle_k),
        .n(N),
        .twiddle_out(twiddle_out)
    );

    //multiplier instance   
    fp4_cmul complex_multiplier(
        .a(Xn[7:4]), //real part of X[n]
        .b(Xn[3:0]), //imag part of X[n]
        .c(twiddle[7:4]), //real part of W_N^(k*n)
        .d(twiddle[3:0]), //imag part of W_N^(k*n)
        .out_real(mult_real),
        .out_imag(mult_imag)
    );

    assign mult_result = {mult_real, mult_imag};

    //adder instance
    fp4_complex_add_sub complex_adder(
        .a(Xk_accum),
        .b(product),
        .sub(1'b0), //always addition for DFT accumulation
        .out(accum_next)
    );

    //memory instances
    fp4_fft_memory_reg memory_inst (
        .clk(clk),
        .rst(rst),
        .bank_sel(bank_sel),
        .rd_addr_0(final_rd_addr), //use final read address mux
        .rd_data_0(int_rd_data), //read data for DFT computation
        .wr_en_1(final_wr_en), //use final write enable mux
        .wr_addr_1(final_wr_addr), //use final write address mux
        .wr_data_1(final_wr_data) //use final write data mux
    );

    //output read data for external access
    assign rd_data_0 = int_rd_data;

    //state machine sequential logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin //reset is active low
            state <= IDLE;
            //initialise various registers
            k <= 0;
            n <= 0;
            done <= 1'b0;
            error <= 1'b0;
            Xn <= 8'b0;
            twiddle <= 8'b0;
            product <= 8'b0;
            Xk_accum <= 8'b0;
            //initialize internal memory control signals
            int_rd_addr <= 0;
            int_wr_en <= 1'b0;
            int_wr_addr <= 0;
            int_wr_data <= 8'b0;
        end else begin
            state <= next_state;

            //default internal write to disabled (important for proper operation as we mux with external writes)
            int_wr_en <= 1'b0;

            //state-dependent register updates
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    k <= 0;
                    if (start) begin
                        //validate N
                        if (N == 0 || N > MAX_N) begin
                            error <= 1'b1; //invalid N, assert error
                        end
                    end
                end
                INIT: begin
                    n <= 0; //start with time index 0
                    Xk_accum <= 8'b0; //clear accumulator
                end
                READ_X: begin
                    //capture input sample, data will be available next cycle
                    //set internal read address to n
                    int_rd_addr <= n;
                end
                WAIT_MEM: begin
                    //wait state for memory read
                    //capture data from internal read data signal
                    Xn <= int_rd_data; 
                end
                COMPUTE_W: begin
                    twiddle <= twiddle_out; //capture twiddle factor
                end
                MULTIPLY: begin
                    //initiate multiplication, result will be ready immediately in this combinational design
                end
                WAIT_MULT: begin
                    product <= mult_result; //capture multiplication result
                end
                ACCUMULATE: begin
                    Xk_accum <= accum_next; //update accumulator with new sum of X[n]*W_N^(k*n)
                end
                INCREMENT_N: begin
                    n <= n + 1; //increment time index
                end
                WRITE_XK: begin
                    //write X[k] to memory handled by memory module interface
                    int_wr_en <= 1'b1; //enable internal write
                    int_wr_addr <= k; //write to address k
                    int_wr_data <= Xk_accum; //data to write is accumulated X[k]
                    
                end
                INCREMENT_K: begin
                    k <= k + 1; //increment frequency bin index
                end
                DONE: begin
                    done <= 1'b1; //assert done signal
                end
            endcase
        end
    end

    //next state logic
    always @(*) begin
        next_state = state; //default to hold state
        case (state)
            IDLE: begin
                if (start && !error) begin
                    next_state = INIT;
                end
            end
            INIT: begin
                next_state = READ_X;
            end
            READ_X: begin
                next_state = WAIT_MEM;
            end
            WAIT_MEM: begin
                next_state = COMPUTE_W;
            end
            COMPUTE_W: begin
                next_state = MULTIPLY;
            end
            MULTIPLY: begin
                next_state = WAIT_MULT;
            end
            WAIT_MULT: begin
                next_state = ACCUMULATE;
            end
            ACCUMULATE: begin
                next_state = INCREMENT_N;
            end
            INCREMENT_N: begin
                if (n + 1 < N) begin
                    next_state = READ_X; //more samples to process for current k
                end else begin
                    next_state = WRITE_XK; //all n processed, write X[k]
                end
            end
            WRITE_XK: begin
                next_state = INCREMENT_K;
            end
            INCREMENT_K: begin
                if (k + 1 < N) begin
                    next_state = INIT; //process next k
                end else begin
                    next_state = DONE; //all k processed, finish DFT
                end
            end
            DONE: begin
                next_state = IDLE; //go back to idle after done
            end
        endcase
    end
endmodule

//output assignments
//dft result X[k] is available in accumulator Xk_accum at the WRITE_XK state
//external logic should handle writing Xk_accum to memory at that point

//top level DFT module with memory interface
module fp4_dft #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [ADDR_WIDTH-1:0] N, //number of points in the DFT
    output wire done,
    output wire error,

    //date I/O interface
    input wire [7:0] data_in, //time domain input sample
    input wire data_in_valid, //indicates valid input data
    output reg [7:0] data_out, //frequency domain output sample
    output reg data_out_valid, //indicates valid output data
    output reg dft_ready //indicates DFT module is ready for new input
);

    //internal signals
    reg bank_sel; //memory bank selector
    reg [ADDR_WIDTH-1:0] wr_addr; //write address for memory
    reg wr_en; //write enable for memory
    reg [ADDR_WIDTH-1:0] rd_addr; //read address for memory
    wire [7:0] rd_data; //data read from memory
    
    wire dft_done;
    wire [7:0] dft_result;

    //memory write FSM states
    localparam MEM_IDLE = 2'd0; //waiting for input data
    localparam MEM_WRITE = 2'd1; //writing input data to memory
    localparam MEM_PROCESS = 2'd2; //DFT processing
    localparam MEM_READ = 2'd3; //reading output data from memory

    reg [1:0] mem_state, mem_next_state;
    reg [ADDR_WIDTH-1:0] input_count; //counts number of input samples received

    reg dft_start;

    //DFT core instance
    fp4_dft_core #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dft_core_inst (
        .clk(clk),
        .rst(rst),
        .start(dft_start),
        .N(N),
        .done(dft_done),
        .error(error),
        .bank_sel(bank_sel),
        //using proper external interface signals
        .ext_wr_en(wr_en),
        .ext_wr_addr(wr_addr),
        .ext_wr_data(data_in),
        .ext_rd_addr(rd_addr),
        .rd_data_0(rd_data)
    );

    //state machine sequential logic
    //handles memory writes and DFT control
    //sequential logic: IDLE -> WRITE -> PROCESS -> READ

    //next state logic
    always @(*) begin
        mem_next_state = mem_state; //default to hold state
        case (mem_state)
            MEM_IDLE: begin
                if (data_in_valid) mem_next_state = MEM_WRITE;
            end
            MEM_WRITE: begin
                //next state logic for writing input samples
                if (input_count >= N) begin //all input samples received
                    mem_next_state = MEM_PROCESS; //move to processing state
                end else begin 
                    if (data_in_valid) begin
                        mem_next_state = MEM_WRITE; //stay in write state
                    end
                end
            end
            MEM_PROCESS: begin //start DFT processing
                if (dft_done) begin
                    mem_next_state = MEM_READ; //move to read state when done
                end
            end
            MEM_READ: begin //read output samples
                if (rd_addr < N) begin
                    mem_next_state = MEM_READ; //stay in read state
                end else begin
                    mem_next_state = MEM_IDLE; //go back to idle
                end
            end
        endcase
    end

    //output and control logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            mem_state <= MEM_IDLE;
            input_count <= 0;
            wr_en <= 1'b0;
            wr_addr <= 0;
            rd_addr <= 0;
            bank_sel <= 1'b0;
            dft_ready <= 1'b1;
            data_out_valid <= 1'b0;
            data_out <= 8'b0;
            dft_start <= 1'b0;
        end else begin
            mem_state <= mem_next_state;
            case (mem_state)
                MEM_IDLE: begin
                    dft_ready <= 1'b1;
                    if (data_in_valid) begin
                        wr_en <= 1'b1;
                        wr_addr <= 0;
                        input_count <= 1;
                        dft_ready <= 1'b0;
                    end else begin
                        wr_en <= 1'b0;
                    end
                end
            MEM_WRITE: begin
                if (input_count < N) begin
                    if (data_in_valid) begin
                        wr_en <= 1'b1;
                        wr_addr <= input_count; //write to next address
                        input_count <= input_count + 1; //increment input count
                    end else begin
                        wr_en <= 1'b0;
                    end
                end else begin //all input samples received
                    wr_en <= 1'b0;
                    bank_sel <= ~bank_sel; //toggle bank for DFT processing
                    dft_start <= 1'b1;  //ADD THIS LINE - start the DFT core
                end
            end
            MEM_PROCESS: begin //start DFT processing
                dft_start <= 1'b0;
                if (dft_done) begin
                    rd_addr <= 0; //reset read address
                    bank_sel <= ~bank_sel; //TOGGLE BANK to read from the bank we just wrote to
                end
            end
            MEM_READ: begin //read output samples
                if (rd_addr < N) begin
                    data_out_valid <= 1'b1; //valid output data
                    data_out <= rd_data; //output data from memory
                    rd_addr <= rd_addr + 1; //increment read address
                end else begin
                    data_out_valid <= 1'b0; //no more valid output
                end
            end
        endcase
        end
    end

    //output done signal
    assign done = dft_done;

endmodule



    

            
