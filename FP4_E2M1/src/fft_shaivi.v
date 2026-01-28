//the fft module utilizes the butterfly unit, agu, and memory modules to perform an N-point FFT on FP4 complex inputs
//uses decimation-in-time (DIT) Cooley-Tukey algorithm with ping-pong memory architecture
//maximum N is 32 points

module fp4_fft_core #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [ADDR_WIDTH-1:0] N, //number of points in the FFT (must be power of 2)
    output reg done,

    //memory interface
    output wire [7:0] rd_data_0,

    //external write interface for input data loading
    input wire ext_wr_en, //external write enable for input data
    input wire [ADDR_WIDTH-1:0] ext_wr_addr, //external write address for input data
    input wire [7:0] ext_wr_data, //external write data (input samples)
    input wire ext_bank_sel, //external bank selection for loading data

    //external read interface for results
    input wire [ADDR_WIDTH-1:0] ext_rd_addr, //external read address for results
    input wire ext_reading, //flag to indicate external read mode

    output reg error
);

    //state machine definitions
    localparam IDLE = 3'd0; //waiting for start signal
    localparam INIT = 3'd1; //initialization state
    localparam READ_A = 3'd2; //read butterfly input A from memory
    localparam READ_B = 3'd3; //read butterfly input B from memory
    localparam COMPUTE = 3'd4; //perform butterfly computation
    localparam WRITE_X = 3'd5; //write butterfly output X back to memory
    localparam WRITE_Y = 3'd6; //write butterfly output Y back to memory
    localparam DONE = 3'd7; //FFT complete

    reg [2:0] state, next_state;

    //agu control signals
    reg agu_next_step; //pulse to advance agu to next butterfly
    wire [ADDR_WIDTH-1:0] idx_a, idx_b; //memory addresses for butterfly inputs
    wire [ADDR_WIDTH-1:0] k; //twiddle factor index
    wire [7:0] twiddle; //twiddle factor W_N^k
    wire agu_done_stage; //signals when a stage completes (time to swap banks)
    wire agu_done_fft; //signals when entire FFT is complete
    wire [2:0] curr_stage; //current stage number

    //butterfly computation registers
    reg [7:0] A_reg, B_reg; //butterfly inputs from memory
    wire [7:0] X_wire, Y_wire; //butterfly outputs (combinational)
    reg [7:0] X_reg, Y_reg; //registered butterfly outputs for writing

    //internal memory control signals for FFT computation
    reg [ADDR_WIDTH-1:0] int_rd_addr; //internal read address during FFT
    wire [7:0] int_rd_data; //internal read data during FFT
    reg int_wr_en; //internal write enable for FFT results
    reg [ADDR_WIDTH-1:0] int_wr_addr; //internal write address for FFT results
    reg [7:0] int_wr_data; //internal write data for FFT results

    //mux between external writes (input loading) and internal writes (FFT computation)
    wire final_wr_en = ext_wr_en | int_wr_en;
    wire [ADDR_WIDTH-1:0] final_wr_addr = ext_wr_en ? ext_wr_addr : int_wr_addr;
    wire [7:0] final_wr_data = ext_wr_en ? ext_wr_data : int_wr_data;

    //mux for read address - external for result readout, internal for FFT computation
    wire [ADDR_WIDTH-1:0] final_rd_addr = ext_reading ? ext_rd_addr : int_rd_addr;

    //bank selection for ping-pong memory
    //now bank_sel directly controls which bank to access (simplified memory model)
    //during loading: always use bank 0 (bank_sel=0) to write input data
    //during FFT: read from one bank, write to the SAME bank (in-place butterfly)
    //after each stage: toggle to other bank for next stage
    //during readout: read from the final bank where results are stored
    reg fft_bank_sel; //internal bank control during FFT processing
    //during FFT processing (not IDLE, not DONE, not reading), use fft_bank_sel
    //otherwise use ext_bank_sel (which is 0 during loading and calculated during reading)
    wire active_bank_sel = (ext_reading) ? ext_bank_sel : 
                          (state == IDLE) ? ext_bank_sel : 
                          fft_bank_sel;

    //address generation unit instance with variable N support
    fft_agu_dit_variable #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) agu_inst (
        .clk(clk),
        .reset(rst),
        .N(N), //pass runtime N to AGU
        .next_step(agu_next_step),
        .idx_a(idx_a),
        .idx_b(idx_b),
        .k(k),
        .done_stage(agu_done_stage),
        .done_fft(agu_done_fft),
        .curr_stage(curr_stage),
        .twiddle_output(twiddle)
    );

    //butterfly unit instance
    fp4_butterfly butterfly_inst (
        .A(A_reg),
        .B(B_reg),
        .W(twiddle),
        .X(X_wire),
        .Y(Y_wire)
    );

    //memory instance with ping-pong architecture
    fp4_fft_memory_reg memory_inst (
        .clk(clk),
        .rst(rst),
        .bank_sel(active_bank_sel),
        .rd_addr_0(final_rd_addr),
        .rd_data_0(int_rd_data),
        .wr_en_1(final_wr_en),
        .wr_addr_1(final_wr_addr),
        .wr_data_1(final_wr_data)
    );

    //output read data for external access
    assign rd_data_0 = int_rd_data;

    //stage done detection to swap banks
    //swap banks at the END of a stage (when done_stage pulses)
    //but BEFORE starting the next stage
    reg prev_done_stage;
    wire stage_complete = agu_done_stage && !prev_done_stage; //rising edge detect

    //state machine sequential logic
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            A_reg <= 8'b0;
            B_reg <= 8'b0;
            X_reg <= 8'b0;
            Y_reg <= 8'b0;
            int_rd_addr <= 0;
            int_wr_en <= 1'b0;
            int_wr_addr <= 0;
            int_wr_data <= 8'b0;
            agu_next_step <= 1'b0;
            fft_bank_sel <= 1'b0;
            prev_done_stage <= 1'b0;
        end else begin
            state <= next_state;

            //default control signals
            int_wr_en <= 1'b0;
            agu_next_step <= 1'b0;
            prev_done_stage <= agu_done_stage;

            //swap banks when stage completes
            //this happens AFTER the last butterfly of a stage is written
            //and BEFORE we start processing the next stage
            if (stage_complete && state != IDLE && state != DONE) begin
                fft_bank_sel <= ~fft_bank_sel;
            end

            //state-dependent register updates
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    fft_bank_sel <= 1'b0; //start FFT with bank 0
                    if (start) begin
                        //validate N - must be power of 2 and within range
                        if (N == 0 || N > MAX_N || (N & (N - 1)) != 0) begin
                            error <= 1'b1; //invalid N
                        end
                    end
                end
                
                INIT: begin
                    //initialization for FFT computation
                    //agu is reset and ready
                end

                READ_A: begin
                    //set read address for butterfly input A
                    int_rd_addr <= idx_a;
                end

                READ_B: begin
                    //capture A from previous read (1 cycle latency)
                    A_reg <= int_rd_data;
                    //set read address for butterfly input B
                    int_rd_addr <= idx_b;
                end

                COMPUTE: begin
                    //capture B from memory read
                    B_reg <= int_rd_data;
                    //butterfly computation happens combinationally
                    //outputs X_wire and Y_wire are ready immediately
                end

                WRITE_X: begin
                    //register butterfly outputs
                    X_reg <= X_wire;
                    Y_reg <= Y_wire;
                    //write X to address idx_a
                    int_wr_en <= 1'b1;
                    int_wr_addr <= idx_a;
                    int_wr_data <= X_wire;
                end

                WRITE_Y: begin
                    //write Y to address idx_b
                    int_wr_en <= 1'b1;
                    int_wr_addr <= idx_b;
                    int_wr_data <= Y_reg;
                    
                    //advance agu to next butterfly only if not done with entire FFT
                    if (!agu_done_fft) begin
                        agu_next_step <= 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
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
                next_state = READ_A;
            end

            READ_A: begin
                next_state = READ_B;
            end

            READ_B: begin
                next_state = COMPUTE;
            end

            COMPUTE: begin
                next_state = WRITE_X;
            end

            WRITE_X: begin
                next_state = WRITE_Y;
            end

            WRITE_Y: begin
                if (agu_done_fft) begin
                    next_state = DONE; //entire FFT complete
                end else begin
                    next_state = READ_A; //process next butterfly
                end
            end

            DONE: begin
                next_state = IDLE; //return to idle
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end
endmodule

//top level FFT module with data I/O interface
module fp4_fft #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N)
)(
    input wire clk,
    input wire rst,
    input wire start,
    input wire [ADDR_WIDTH-1:0] N, //number of points in the FFT
    output wire done,
    output wire error,

    //data I/O interface
    input wire [7:0] data_in, //time domain input sample
    input wire data_in_valid, //indicates valid input data
    output reg [7:0] data_out, //frequency domain output sample
    output reg data_out_valid, //indicates valid output data
    output reg fft_ready //indicates FFT module is ready for new input
);

    //internal signals
    reg [ADDR_WIDTH-1:0] wr_addr; //write address for memory
    reg wr_en; //write enable for memory
    reg [ADDR_WIDTH-1:0] rd_addr; //read address for memory
    wire [7:0] rd_data; //data read from memory

    wire fft_done;
    
    //bank selection control
    //always write input data to bank 0
    //read output data from the bank where final results are (based on number of stages)
    reg read_bank_sel; //bank to read output data from
    reg ext_reading; //flag indicating we're in external read mode

    //bit reversal for DIT FFT input
    //DIT requires bit-reversed input order
    wire [ADDR_WIDTH-1:0] wr_addr_reversed;
    bit_reverse #(
        .MAX_N(MAX_N),
        .WIDTH(ADDR_WIDTH)
    ) bit_rev_inst (
        .in(wr_addr),
        .out(wr_addr_reversed)
    );

    //memory interface FSM states
    localparam MEM_IDLE = 2'd0; //waiting for input data
    localparam MEM_WRITE = 2'd1; //writing input data to memory
    localparam MEM_PROCESS = 2'd2; //FFT processing
    localparam MEM_READ = 2'd3; //reading output data from memory

    reg [1:0] mem_state, mem_next_state;
    reg [ADDR_WIDTH-1:0] input_count; //counts number of input samples received
    reg [ADDR_WIDTH-1:0] output_count; //counts number of output samples read

    reg fft_start;
    reg fft_start_issued; //track if we've issued the start

    //track number of stages to know final bank
    wire [2:0] num_stages = $clog2(N);

    //bank control for external access
    //during loading: always bank 0
    //during reading: use calculated read_bank_sel
    wire core_bank_sel = (mem_state == MEM_READ) ? read_bank_sel : 1'b0;

    //FFT core instance
    fp4_fft_core #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) fft_core_inst (
        .clk(clk),
        .rst(rst),
        .start(fft_start),
        .N(N),
        .done(fft_done),
        .error(error),
        .ext_wr_en(wr_en),
        .ext_wr_addr(wr_addr_reversed), //write to bit-reversed address
        .ext_wr_data(data_in),
        .ext_bank_sel(core_bank_sel),
        .ext_rd_addr(rd_addr),
        .ext_reading(ext_reading),
        .rd_data_0(rd_data)
    );

    //next state logic
    always @(*) begin
        mem_next_state = mem_state;
        case (mem_state)
            MEM_IDLE: begin
                if (data_in_valid) mem_next_state = MEM_WRITE;
            end

            MEM_WRITE: begin
                if (input_count >= N) begin
                    mem_next_state = MEM_PROCESS;
                end
                //stay in MEM_WRITE while loading
            end

            MEM_PROCESS: begin
                if (fft_done) begin
                    mem_next_state = MEM_READ;
                end
            end

            MEM_READ: begin
                if (output_count >= N) begin
                    mem_next_state = MEM_IDLE;
                end
            end
        endcase
    end

    //FIXED: output and control logic
    //the key fix is to ensure wr_en is asserted in the SAME cycle as data_in_valid
    //not the next cycle, so that data_in is written correctly
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            mem_state <= MEM_IDLE;
            input_count <= 0;
            output_count <= 0;
            wr_en <= 1'b0;
            wr_addr <= 0;
            rd_addr <= 0;
            fft_ready <= 1'b1;
            data_out_valid <= 1'b0;
            data_out <= 8'b0;
            fft_start <= 1'b0;
            fft_start_issued <= 1'b0;
            read_bank_sel <= 1'b0;
            ext_reading <= 1'b0;
        end else begin
            //assign next state
            mem_state <= mem_next_state;

            //default: fft_start is a single-cycle pulse
            fft_start <= 1'b0;

            case (mem_state)
                MEM_IDLE: begin
                    fft_ready <= 1'b1;
                    input_count <= 0;
                    output_count <= 0;
                    data_out_valid <= 1'b0;
                    fft_start_issued <= 1'b0;
                    ext_reading <= 1'b0;
                    
                    //FIXED: when data_in_valid goes high in IDLE, immediately write first sample
                    //this ensures the write happens in the same cycle as data_in_valid
                    if (data_in_valid) begin
                        wr_en <= 1'b1;
                        wr_addr <= 0;
                        input_count <= 1;
                        fft_ready <= 1'b0;
                    end else begin
                        wr_en <= 1'b0;
                    end
                end

                MEM_WRITE: begin
                    //FIXED: keep writing while in WRITE state and data_in_valid is high
                    //this fixes the timing issue where wr_en was being deasserted too early
                    if (input_count < N && data_in_valid) begin
                        wr_en <= 1'b1;
                        wr_addr <= input_count;
                        input_count <= input_count + 1;
                    end else if (input_count >= N) begin
                        //all input samples received
                        wr_en <= 1'b0;
                        //issue start pulse once
                        if (!fft_start_issued) begin
                            fft_start <= 1'b1;
                            fft_start_issued <= 1'b1;
                        end
                    end else begin
                        //waiting for next valid sample
                        wr_en <= 1'b0;
                    end
                end

                MEM_PROCESS: begin
                    wr_en <= 1'b0;
                    if (fft_done) begin
                        //set up for reading - address 0
                        rd_addr <= 0;
                        output_count <= 0;
                        //calculate which bank has the final result
                        //with the new simplified memory model:
                        //- input loaded into bank 0
                        //- FFT starts reading/writing bank 0 (fft_bank_sel=0)
                        //- after stage 0 completes: swap to bank 1, process stage 1 in bank 1
                        //- after stage 1 completes: swap to bank 0, process stage 2 in bank 0
                        //- pattern: after N stages, data is in bank (N % 2)
                        //for 2 stages (N=4): final data in bank 0
                        //for 3 stages (N=8): final data in bank 1
                        //for 4 stages (N=16): final data in bank 0
                        //for 5 stages (N=32): final data in bank 1
                        read_bank_sel <= num_stages[0]; //bit 0 tells us if odd (1) or even (0)
                        ext_reading <= 1'b1;
                    end else begin
                        ext_reading <= 1'b0;
                    end
                end

                MEM_READ: begin
                    ext_reading <= 1'b1;
                    if (output_count < N) begin
                        //memory has 1-cycle latency, so data_out gets updated next cycle
                        //but we set valid immediately and increment address
                        data_out <= rd_data; //this gets data from previous cycle's address
                        data_out_valid <= 1'b1;
                        rd_addr <= rd_addr + 1; //this sets up next read
                        output_count <= output_count + 1;
                    end else begin
                        data_out_valid <= 1'b0;
                        ext_reading <= 1'b0;
                    end
                end
            endcase
        end
    end

    //output done signal
    assign done = fft_done;

endmodule