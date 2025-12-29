//Testbench for the FFT module

`timescale 1ns / 1ps

module tb_fft;
    // PARAMETERS
    parameter MAX_N = 32;
    parameter ADDR_WIDTH = $clog2(MAX_N);

    // Inputs to UUT
    reg clk;
    reg rst;
    reg start;
    reg [ADDR_WIDTH:0] N_config; // Supports up to 32
    reg ext_wr_en;
    reg [ADDR_WIDTH-1:0] ext_wr_addr;
    reg [7:0] ext_wr_data;
    reg [ADDR_WIDTH-1:0] ext_rd_addr;

    // Outputs from UUT
    wire done;
    wire [7:0] ext_rd_data;

    // Test variables
    integer i, j;
    reg [7:0] input_samples [0:31];
    reg [7:0] expected_output [0:31];
    reg [7:0] received_output [0:31];
    integer output_index;
    integer test_pass;
    integer test_fail;

    // Instantiate the FFT Top Module
    fp4_fft_top #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .N_config(N_config[ADDR_WIDTH-1:0]),
        .done(done), 
        .ext_wr_en(ext_wr_en), 
        .ext_wr_addr(ext_wr_addr), 
        .ext_wr_data(ext_wr_data), 
        .ext_rd_addr(ext_rd_addr),
        .ext_rd_data(ext_rd_data)
    );

    always @(uut.fft_core_inst.present_state) begin
    $display("Time: %0t | State: %d | Bank: %b | Proc: %b | Addr: %d | Data: 0x%h", 
             $time, 
             uut.fft_core_inst.present_state, 
             uut.bank_sel, 
             uut.is_processing, 
             uut.fft_core_inst.int_rd_addr, 
             uut.fft_core_inst.int_rd_data);
    end

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 100MHz clock
    end

    // --- TEST TASKS ---

    task reset_sys;
    begin
        rst = 0;
        start = 0;
        ext_wr_en = 0;
        ext_wr_addr = 0;
        ext_wr_data = 8'b0;
        ext_rd_addr = 0;
        @(negedge clk);
        rst = 1;
        @(negedge clk);
        $display("[%0t] System Reset Complete", $time);
    end
    endtask

    task load_input;
        input integer size;
    begin
        $display("[%0t] Loading %0d Input Samples (Bit-Reversal Active)", $time, size);
        ext_wr_en = 1; 
        for(i = 0; i < size; i = i + 1) begin
            @(negedge clk);
            ext_wr_addr = i;
            ext_wr_data = input_samples[i];
            @(negedge clk); 
            $display("  Loaded sample %0d: 0x%h", i, input_samples[i]);
        end
        ext_wr_en = 0; 
    end
    endtask

    task capture_output;
        input integer size;
    begin
        $display("[%0t] Reading Results from Ping-Pong Memory", $time);
        for(output_index = 0; output_index < size; output_index = output_index + 1) begin
            @(negedge clk);
            ext_rd_addr = output_index; 
            #1; // Wait for combinational logic
            received_output[output_index] = ext_rd_data;
            $display("  Captured bin %0d: 0x%h", output_index, ext_rd_data);
        end
    end
    endtask

    task verify_output;
        input integer size;
        input [256*8-1:0] test_name; 
        integer k;
    begin
        $display("\n[%0t] Verifying: %s", $time, test_name);
        for (k=0; k<size; k=k+1) begin
            if (received_output[k] != expected_output[k]) begin
                $display("  [FAIL] Bin %0d: Expected 0x%h, Got 0x%h", k, expected_output[k], received_output[k]);
                test_fail = test_fail + 1; 
            end else begin
                $display("  [PASS] Bin %0d: 0x%h", k, received_output[k]);
                test_pass = test_pass + 1; 
            end
        end
    end
    endtask

    task init_test_impulse;
    begin
        input_samples[0] = 8'b00100000; // 1 + j0 (FP4: sign=0, exp=01, mant=0)
        for (j = 1; j < 32; j = j + 1) input_samples[j] = 8'b00000000;
        for (j = 0; j < 32; j = j + 1) expected_output[j] = 8'b00100000;
    end
    endtask

    // --- TEST SEQUENCES ---

    initial begin
        test_pass = 0;
        test_fail = 0;
        $dumpfile("fft_sim.vcd");
        $dumpvars(0, tb_fft);
        
        reset_sys();

        // TEST 1: 32-Point FFT Impulse
        $display("\n--- Test 1: 32-point Impulse FFT ---");
        N_config = 32; 
        init_test_impulse();
        load_input(32);
        
        start = 1; 
        @(negedge clk);
        start = 0;
        
        wait(done == 1'b1); 
        capture_output(32);
        verify_output(32, "32-point Impulse");

        // TEST 2: 8-Point FFT Impulse
        $display("\n--- Test 2: 8-point Impulse FFT (Dynamic N) ---");
        reset_sys(); // Reset to clear memory/banks
        N_config = 8;
        init_test_impulse(); 
        load_input(8);
        
        start = 1;
        @(negedge clk);
        start = 0;
        
        wait(done == 1'b1);
        capture_output(8);
        verify_output(8, "8-point Impulse");

        $display("\nFinal Results: %0d Passed, %0d Failed", test_pass, test_fail);
        $finish;
    end
endmodule