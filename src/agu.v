//use bit reversal module in top level FFT 
//When the external world writes data to the FFT (e.g., Wr_Addr = 1), 
//you intercept that address, bit-reverse it (to 10000 / 16), 
//and write the data to the reversed address.
//Since we are using DIT, the data must be pre-scrambled before the FFT even starts.
//You implement this in the Top Level module where you load data into memory.
module bit_reverse #(
    parameter MAX_N = 32,
    parameter WIDTH = $clog2(MAX_N)
)(
    input [WIDTH-1:0] in,
    output reg [WIDTH-1:0] out
);
    integer i;
    always @(*) begin
        for (i=0; i < WIDTH; i=i+1)
            out[i] = in[WIDTH-1-i];
    end
endmodule


module fft_agu_dit #(
    parameter MAX_N = 32,
    parameter ADDR_WIDTH = $clog2(MAX_N),
    parameter total_stages = $clog2(MAX_N)
)(
    input clk,
    input reset,
    input wire next_step, //pulse from core to advance one butterfly

    output [ADDR_WIDTH-1:0] idx_a, //address for input A into butterfly unit
    output [ADDR_WIDTH-1:0] idx_b, //address for input B into butterfly unit
    output [ADDR_WIDTH-1:0] k, //twiddle factor index
    output reg done_stage, //goes high when one stage is finished, used to swap banks
    output reg done_fft, //goes high when fft is done (all stages)
    output reg [2:0] curr_stage, //Current stage (1 to 5 for N=32)

    output [7:0] twiddle_output //output for twiddle ROM
);

    // --- Scalability Logic ---
    // Rounds MAX_N to the next power of 2 (e.g., 30 -> 32)
    // This ensures the math (shifts and divisions) works even if input isn't perfect.
    localparam EFFECTIVE_N = 1 << $clog2(MAX_N);

    //implementing decimation in time (DIT) algorithm
    reg [ADDR_WIDTH-1:0] group;      // Tracks which block we are in
    reg [ADDR_WIDTH-1:0] butterfly;  // Pair index inside the current block
    reg [ADDR_WIDTH-1:0] stride;     // DIT: Starts at 1, goes 1->2->4->8->16

    //address calculation:
    //stride = distance b/w butterfly legs, then groups have a group offset = stride * 2 between them
    wire [ADDR_WIDTH:0] group_size = (stride << 1); //stride * 2
    wire [ADDR_WIDTH-1:0] group_offset = group * group_size;

    assign idx_a = group_offset + butterfly;
    assign idx_b = idx_a + stride;

    //twiddle logic:
    // DIT Twiddle depends on the stage.
    // k_factor scales the loop counter 'butterfly' to the full N range
    // k = butterfly * (N / (2 * stride))
    // We use EFFECTIVE_N here to ensure scaling works for any parameter N
    wire [ADDR_WIDTH-1:0] k_idx = butterfly * (EFFECTIVE_N / group_size);

    assign k = k_idx; // Assign internal wire to output port

    twiddle_factor #(
        .MAX_N(MAX_N),  // Pass the actual parameter
        .ADDR_WIDTH(ADDR_WIDTH)
    ) tw_rom (
        .k(k_idx),
        .n(group_size[ADDR_WIDTH-1:0]), // Truncate to proper width
        .twiddle_out(twiddle_output)
    );

    //fsm:
    //two nested loops, inner one for butterfly operation and outer one for group
    //we want one butterfly operation for every element till of the stride, i.e steps through all the pairs of the group
    //the group loop- once a small group is finished, it moves to the next block in the memory
    //every stage doubles the stride
    always @(posedge clk or negedge reset) begin
        if (!reset) begin
            curr_stage <= 0;
            group <= 0;
            butterfly <= 0;
            stride <= 1; //DIT starts with a distance of 1
            done_fft <= 0;
            done_stage <= 0;
        end
        else if (next_step && !done_fft) begin //if next step pulses high and fft is not done
            done_stage <= 0; //default low

            //1. butterfly loop (innermost)
            if (butterfly < stride - 1) begin // Fixed: Use < for 0-indexed count
                butterfly <= butterfly + 1;
            end else begin
                //end of group, we have to reset butterfly once it has iterated through all the elements of the stride
                butterfly <= 0;

                //now we increment the group
                if (group < (EFFECTIVE_N / group_size) - 1) begin //if group index < total groups
                    group <= group + 1; // advance to next group
                end else begin
                    //end of stage, reset group
                    group <= 0;
                    done_stage <= 1; // Pulse done_stage for bank swap

                    //stage loop, if all groups in this stage have been exhausted, advance to the next stage 
                    if (curr_stage < total_stages - 1) begin
                        //every stage, the group size and hence stride double
                        curr_stage <= curr_stage + 1;
                        stride <= stride << 1; //double stride by left shifting
                    end else begin
                        done_fft <= 1; // All stages finished
                    end
                end
            end
        end else begin 
            done_stage <= 0;
        end
    end
endmodule

//DIF AGU -> not compatible with butterfly unit, which does operations in time domain. Is not used with the Cooley-Tukey Algorithm.
module address_generation_unit_DIF #(
    parameter N = 32,
    parameter total_stages = $clog2(N)
)(
    input clk,
    input reset,
    input wire next_step,  //Has to be high for a cycle to proceed to the next butterfly
    
    //Address outputs
    output [4:0] address_a,
    output [4:0] address_b,

    //Twiddle factor output
    output [7:0] twiddle_output,

    //Status
    output reg done, //Gets high when all the stages are done
    output reg [2:0] curr_stage  //Register to store the current stage
);

    //Essential parameters
    reg [4:0] group;          //Tracks which block of the FFT we are in
    reg [4:0] butterfly;     //Pair index inside the current block
    reg [4:0] stride;          //Span size - Eg: N=32 => (16->8->4->2->1)

    //Address calculation 
    //The twiddle ROM must know the size of the subproblem(N) being solved.
    //Size of the subproblem N = 2*stride, so we basically need to left shift stride by 1
    wire [5:0] rom_N = (stride << 1);
    wire [4:0] grp_offset = group * rom_N; //Calculating the start index of the current group
    assign address_a = grp_offset + butterfly; //Top address = group offset + butterfly index
    assign address_b = address_a + stride; //Bottom address = top address + span

    twiddle_factor #(
        .MAX_N(N),
        .ADDR_WIDTH(5)
    ) tw_rom (
        .k(butterfly),
        .n(rom_N[4:0]), // Truncate to 5 bits to match port width
        .twiddle_out(twiddle_output)
    );

    always @(posedge clk or negedge reset) begin

        //Resetting everything back to the start. Stride is set to N/2 for stage 0
        if(!reset) begin
            curr_stage <= 0;
            group <= 0;
            butterfly <= 0;
            stride <= 5'b10000;
            done <= 0;
        end

        //Otherwise
        else if(next_step && !done) begin
            
            //1. Check if all the butterflies have been generated
            if(butterfly < stride-1) begin
                butterfly <= butterfly + 1;
            end

            //2. Once we are done with butterfly loop, we check if more blocks exist
            //If they do, then we reset the butterfly to 0 and increment the group
            else if(group < (N/(stride << 1)) - 1) begin // Fixed: Use N instead of MAX_N
                butterfly <= 0;
                group <= group + 1;
            end

            //3. If all the blocks are done, we move on to the next state
            else begin
                group <= 0;
                butterfly <= 0;
                //Check if all the stages have been completed or not. Condition i
                if(curr_stage < total_stages-1) begin
                    curr_stage <= curr_stage + 1;
                    stride <= (stride >> 1);
                end
                else begin
                    done <= 1;
                end
            end
        end
    end

endmodule