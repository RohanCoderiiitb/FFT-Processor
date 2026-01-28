`timescale 1ns/1ps

module tb_agu();  // No ports for testbench!
    parameter MAX_N = 32;
    parameter ADDR_WIDTH = $clog2(MAX_N);
    parameter total_stages = $clog2(MAX_N);
    
    // Testbench signals (all reg for inputs, wire for outputs)
    reg clk;
    reg reset;
    reg next_step; //pulse from core to advance one butterfly

    wire [ADDR_WIDTH-1:0] idx_a; //address for input A into butterfly unit
    wire [ADDR_WIDTH-1:0] idx_b; //address for input B into butterfly unit
    wire [ADDR_WIDTH-1:0] k; //twiddle factor index
    wire done_stage; //goes high when one stage is finished, used to swap banks
    wire done_fft; //goes high when fft is done (all stages)
    wire [2:0] curr_stage; //Current stage (1 to 5 for N=32)
    wire [7:0] twiddle_output; //output for twiddle ROM

    // Instantiate DUT
    fft_agu_dit #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH),
        .total_stages(total_stages)
    ) agu_dut (
        .clk(clk),
        .reset(reset),
        .next_step(next_step),
        .idx_a(idx_a),
        .idx_b(idx_b),
        .k(k),
        .done_stage(done_stage),
        .done_fft(done_fft),
        .curr_stage(curr_stage),
        .twiddle_output(twiddle_output)
    );

    // Clock generation
    always #5 clk = ~clk; //10 ns time period -> 100MHz clk

    integer i;

    initial begin
        // Initialize all variables
        clk = 0;
        reset = 0; // active low, we will release it after one clock cycle
        next_step = 0;

        // Apply reset
        $display("Applying Reset...");
        #20;
        reset = 1; // Release reset
        #10;

        // Drive the AGU - looping till FFT done. 
        // AGU advances by 1 everytime next_step is high
        while (!done_fft) begin
            // Pulse next_step for 1 clk cycle to start it off
            next_step = 1;
            @(posedge clk); // Wait for 1 clk cycle to allow AGU to update
            
            // Display Current State (Monitor)
            // We use a small delay #1 to read values AFTER the clock edge update
            #1; 
            $display("Time: %0t | Stage: %0d | A: %2d | B: %2d | Twiddle K: %2d | StgDone: %b", 
                     $time, curr_stage, idx_a, idx_b, k, done_stage);

            // De-assert next_step (simulating calculation wait time)
            next_step = 0;
            
            // Wait a few cycles to simulate butterfly calculation latency
            // (The AGU freezes when next_step is low, as expected)
            #20;
        end
        
        // 4. Wrap Up
        $display("--- FFT Generation Complete ---");
        $display("Final Done Signal: %b", done_fft);
        #50;
        $finish;
    end
endmodule
