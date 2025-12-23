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

    //Output signal that goes high once all the stages of the FFT are complete
    output wire done_fft

    //Signals for memory interfacing
    output wire [ADDR_WIDTH-1:0] rd_addr_a, rd_addr_b,  //2 addresses used to fetch the current butterfly pair from the memory
    input wire [7:0] rd_data_a, rd_data_b,              //Corresponding complex data (FP4) returned from the memory
    output wire [ADDR_WIDTH-1:0] wr_addr_a, wr_addr_b,  //Addresses where the new butterfly results will be stored
    output wire [7:0] wr_data_a, wr_data_b,             //Processed results from the butterfly unit
    output wire wr_en,                                  
    output reg bank_sel
);
    //Signals from the DIT AGU 
    wire [ADDR_WIDTH-1:0] idx_a;  //Address for input A calculated by the AGU  
    wire [ADDR_WIDTH-1:0] idx_b;  //Address for input B calculated by the AGU
    wire [ADDR_WIDTH-1:0] k;      //Twiddle factor index
    wire done_stage;              //Pulse that indicates that all the groups of a particular stage are complete, triggering bank swap
    reg next_step;                //Pulse that tells the AGU to move ahead with the next pair of addresses
    wire [7:0] twiddle_factor;          //Twiddle factor fetched from the ROM

    //Instantiation of the DIT AGU
    fft_agu_dit #(
        MAX_N
    ) fft_agu(
        .clk(clk),
        .rst(rst),
        .next_step(next_step),
        .idx_a(idx_a),
        .idx_b(idx_b),
        .k(k),
        .done_stage(done_stage),
        .done_fft(done_fft),
        .twiddle_output(twiddle_factor)
    );
    
    //Instantiation of the Butterfly Unit
    fp4_butterfly butterfly_unit(
        .A(rd_data_a),
        .B(rd_data_b),
        .W(twiddle_factor),
        .X(wr_data_a),
        .Y(wr_data_b)
    );

    //Internal control logic
    always @(posedge clk or negedge rst) begin

        //Resetting the processor to initial state defaulting the bank to 0
        if(!rst) begin
            bank_sel <= 1'b0;
            next_step <= 1'b0;
        end

        //FFT started and ongoing
        else if(start && !done_fft) begin
            next_step <= 1'b1;  //Ensuring next step is high for the AGU to continue moving
            if(done_stage) bank_sel <= ~bank_sel; //Ping pong logic. As a stage completes, memory banks are flipped.
        end


        else begin
            next_step <= 0'b0;
        end

    end

    //Some important assignments
    assign wr_en = next_step;          //Ensuring that memory write control flag is HIGH only when the processor is in active calculation cycle

    //Connecting the AGU to the main memory
    //Here we are using the same indices for reading and writing addresses
    //In Radix2 DIT FFT, once X=A+BW and Y=A-BW have been computed, then original data points A and B won't be needed in that stage
    //Hence, writing the results to the exact same memory locations from where the inputs were fetched from, ensures that the memory remains organized and is ready for the next stage

    assign rd_addr_a = idx_a;
    assign rd_addr_b = idx_b;
    assign wr_addr_a = idx_a;
    assign wr_addr_b = idx_b;

endmodule