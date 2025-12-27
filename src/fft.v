//In this design, two modules are used to compute Radix 2 DIT FFT
//fp4_fft_core module is the main computation engine the processor that is responsible for orchestering math operations(butterfly unit) and the indexing required for each stage of the DIT FFT
//fp4_fft_top module handles I/O, bit reversal and memory instantiation

module fp4_fft_core #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
) (
    //Essential control signals 
    input wire clk,
    input wire rst,
    input wire start,
    
    //Output signal that goes high once all the stages of the FFT are completed
    output reg done_fft,

    //Internal memory interface
    output reg [ADDR_WIDTH-1:0] int_rd_addr,        //Address the core wants to read from
    input wire [7:0] int_rd_data,                   //8 bit complex data returned from the memory
    output reg [ADDR_WIDTH-1:0] int_wr_addr,        //Address the core wants to write the result to
    output reg [7:0] int_wr_data,                   //Data to be written to int_wr_addr in the memory
    output reg int_wr_en

    //Signals from the DIT AGU
    input wire [ADDR_WIDTH-1:0] idx_a,              //Addresses for the input A given by the AGU
    input wire [ADDR_WIDTH-1:0] idx_b,              //Addresses for the input B given by the AGU
    input wire [7:0] twiddle_in,                    //Complex twiddle input for the current butterfly
    input wire done_fft_agu,                        //Signal from AGU indicating that all stages are over
    output reg next_step                            //Signal sent by core to the AGU requesting for the next pair
); 
    
    //FSM state encodings - defines each state and respective encoding
    //Define a sequential flow: fetch -> wait -> compute -> write back
    localparam IDLE = 4'd0;
    localparam FETCH_A = 4'd1;
    localparam WAIT_A = 4'd2;
    localparam FETCH_B = 4'd3;
    localparam WAIT_B = 4'd4;
    localparam COMPUTE = 4'd5;
    localparam WRITE_X = 4'd6;
    localparam WRITE_Y = 4'd7;
    localparam UPDATE_AGU = 4'd8;
    localparam FINISH = 4'd9;

    //Few useful intermediate buffer registers
    //Useful for storing details about the states of the FSM and also the data to be read from memory
    reg [3:0] present_state;
    reg [3:0] next_state;
    reg [7:0] regA;
    reg [7:0] regB;
    wire [7:0] outX;
    wire [7:0] outY;

    //Instantiation of butterfly unit
    fp4_butterfly butterfly_inst(
        .A(regA),
        .B(regB),
        .W(twiddle_in),
        .X(outX),
        .Y(outY)
    );

    //Sequential logic
    always @(posedge clk or negedge rst) begin

        //In case of a reset, we set the state back to IDLE and store 0s in the temporary registers
        if(!rst) begin
            present_state <= 4'd0;
            regA <= 4'd0;
            regB <= 4'd0;
            done_fft <= 4'd0;
        end

        else begin
            present_state <= next_state;
            case(present_state)
                IDLE: done_fft <= 1'b0;
                WAIT_A: regA <= int_rd_data;       //Capturing input A from the memory
                WAIT_B: regB <= int_rd_data;       //Capturing input B from the memory
                FINISH: done_fft <= 1'b1;          //Sets done signal to high asserting that processor is done with FFT computation
            endcase
        end
    end

    //Next state logic
    always @(*) begin

        //Setting up the default values for all outputs to avoid unnecessary latches
        next_state = present_state;
        int_rd_addr = idx_a;
        int_wr_addr = idx_a;
        int_wr_data = 8'b0;
        int_wr_en = 1'b0;
        next_step = 1'b0;

        case(present_state)
            IDLE: begin
                if(start) next_state = FETCH_A; 
            end
            FETCH_A: begin
                int_rd_addr = idx_a;
                next_state = WAIT_A;
            end
            WAIT_A: begin
                next_state = FETCH_B;
            end
            FETCH_B: begin
                int_rd_addr = idx_b;
                next_state = WAIT_B;
            end
            WAIT_B: begin
                next_state = COMPUTE;
            end
            COMPUTE: begin
                next_state = WRITE_X;
            end
            WRITE_X: begin
                //Writing A+BW to the memory
                int_wr_en = 1'b1;
                int_wr_addr = idx_a;
                int_wr_data = outX;
                next_state = WRITE_Y;
            end
            WRITE_Y: begin
                //Writing A-BW to the memory
                int_wr_en = 1'b1;
                int_wr_addr = idx_b;
                int_wr_data = outY;
                next_state = UPDATE_AGU;
            end
            UPDATE_AGU: begin
                next_step = 1'b1;            //Triggering AGU butterfly increment
                if(done_fft_agu) begin        
                    next_state = FINISH;     //If done with all the stages, then jumping to FINISH
                end
                else begin
                    next_state = FETCH_A;    //Else moving back to FETCH_A, to obtain the next pair of datapoints for computing the butterflies
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule

module fp4_fft_top #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
) (
    //Essential signals
    input clk,
    input rst,
    input start,
    output done,

    //External interface for loading data
    input wire ext_wr_en,
    input wire [ADDR_WIDTH-1:0] ext_wr_addr,
    input wire [7:0] ext_wr_data,

    //External interface for reading the results
    input wire [ADDR_WIDTH-1:0] ext_rd_addr,
    output wire [7:0] ext_rd_data
);
    //Essential internal wires
    reg bank_sel;                   //Determines which bank is providing data and which bank receives the computed results

    //Allows core and AGU to interact
    wire next_step;
    wire done_stage;
    wire done_fft_agu;
    wire curr_stage;

    wire [ADDR_WIDTH-1:0] idx_a;
    wire [ADDR_WIDTH-1:0] idx_b;
    wire [ADDR_WIDTH-1:0] k_idx;
    wire [7:0] twiddle_bus;

    //Memory bus wires from the core
    wire [ADDR_WIDTH-1:0] core_rd_addr;
    wire [ADDR_WIDTH-1:0] core_wr_addr;
    wire [7:0] core_wr_data;
    wire core_wr_en;

    //Bit reversal logic - instantiation of bit_reverse module
    //In Radix 2 DIT FFT - the indices of the input samples are bit reversed
    wire [ADDR_WIDTH-1:0] bit_rev_addr;
    bit_reverse #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) bit_reverse_inst(
        .in(ext_wr_addr),
        .out(bit_rev_addr)
    );

    //Instantiating the Address Generation Unit(AGU)
    fft_agu_dit #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) agu_inst(
        .clk(clk),
        .reset(rst),
        .next_step(next_step),
        .idx_a(idx_a),
        .idx_b(idx_b),
        .k(k_idx),
        .done_stage(done_stage),
        .done_fft(done_fft_agu),
        .twiddle_output(twiddle_bus),
        .curr_stage(curr_stage)
    );

    //Creating an instance of the fp4_fft_core
    fp4_fft_core #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) fft_core_inst(
        .clk(clk),
        .rst(rst),
        .start(start),
        .done_fft(done),                     //Global done signal
        .int_rd_addr(core_rd_addr),          //Drives memory read
        .int_rd_data(ext_rd_data),           //Receives data from the memory
        .int_wr_addr(core_wr_addr),          //Drives memory write
        .int_wr_data(core_wr_data),          //Drives result to memory
        .int_wr_en(core_wr_en),              //Write enable

        //Outputs from the AGU
        .idx_a(idx_a),                       
        .idx_b(idx_b),
        .twiddle_in(twiddle_bus),
        .done_fft_agu(done_fft_agu),

        //Output to the AGU
        .next_step(next_step)
    );

    //Defining an is_processing flag that tells whether the processor is in the middle of FFT computation or not
    reg is_processing;
    always @(posedge clk or negedge rst) begin
        if(!rst) begin
            is_processing <= 1'b0;       //Setting the flag to default value of 0 on reset
        end
        else if(start) begin
            is_processing <= 1'b1;       //Computation in progress
        end
        else if(done) begin
            is_processing <= 1'b0;       //Computation complete - processor is free
        end
    end

    //Memory multiplexing
    //Objective is to select between the external loader and the internal processor

    //If FFT computation is going on then choose the core read address else choose the external read address
    wire [ADDR_WIDTH-1:0] final_rd_addr = (is_processing) ? core_rd_addr : ext_rd_addr;

    //Write MUX : During load, bit reverse address is used. During FFT, use core write address
    wire [ADDR_WIDTH-1:0] final_wr_addr = (ext_wr_en) ? bit_rev_addr : core_wr_addr;
    wire [7:0] final_wr_data = (ext_wr_en) ? ext_wr_data : core_wr_data;
    wire final_wr_en = ext_wr_en | core_wr_en;

    //Ping Pong Memory instantiation
    fp4_fft_memory_reg memory_inst(
        .clk(clk),
        .rst(rst),
        .bank_sel(bank_sel),
        .rd_addr_0(final_rd_addr),
        .rd_data_0(ext_rd_data),
        .wr_en_1(final_wr_en),
        .wr_addr_1(final_wr_addr),
        .wr_data_1(final_wr_data)
    );

    //Bank swap logic
    //Toggling the bank_sel once an fft stage is complete
    always @(posedge clk or negedge rst) begin
        //On reset, setting bank_sel signal to 0 by default
        if(!rst) begin
            bank_sel <= 1'b0;
        end
        //If stage is complete, then we swap the processing and writing banks in our Ping-Pong memory
        else if(done_stage) begin
            bank_sel <= ~bank_sel; //Swapping the banks
        end
    end

endmodule