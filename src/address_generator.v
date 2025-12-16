module address_generation_unit #(
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
        .MAX_N(N)
    )tw_rom(
        .k(butterfly),
        .n(rom_N),
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
            else if(group < (32/(stride << 1)) - 1) begin
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