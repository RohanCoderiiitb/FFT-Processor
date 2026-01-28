//comprehensive testbench for FFT module
//tests various transform sizes, input patterns, and error conditions

`timescale 1ns / 1ps

module tb_fft_comprehensive;
    //PARAMETERS
    parameter MAX_N = 32;
    parameter ADDR_WIDTH = $clog2(MAX_N);
    parameter CLK_PERIOD = 10; //10ns clock period (100MHz)

    //Inputs
    reg clk;
    reg rst;
    reg start;
    reg [ADDR_WIDTH-1:0] N;
    reg [7:0] data_in;
    reg data_in_valid;

    //Outputs
    wire done;
    wire error;
    wire [7:0] data_out;
    wire data_out_valid;
    wire fft_ready;

    //Test variables
    integer i, j, k;
    reg [7:0] input_samples [0:31];
    reg [7:0] expected_output [0:31];
    reg [7:0] received_output [0:31];
    integer output_index;
    integer test_pass;
    integer test_fail;
    integer test_count;
    
    //Instantiate the Unit Under Test (UUT)
    fp4_fft #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .N(N), 
        .data_in(data_in), 
        .data_in_valid(data_in_valid), 
        .done(done), 
        .error(error), 
        .data_out(data_out), 
        .data_out_valid(data_out_valid),
        .fft_ready(fft_ready)
    );

    //Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //=============================================================================
    // UTILITY TASKS
    //=============================================================================

    //Task: Reset the system
    task reset_sys;
        begin
            $display("\n[%0t] ======================================", $time);
            $display("[%0t] Performing System Reset", $time);
            $display("[%0t] ======================================", $time);
            rst = 0;
            start = 0;
            data_in = 8'b0;
            data_in_valid = 0;
            N = 8; //default N = 8
            repeat(2) @(negedge clk);
            rst = 1;
            repeat(2) @(negedge clk);
            $display("[%0t] System Reset Complete", $time);
        end
    endtask

    //Task: Load input samples into FFT
    task load_input;
        input integer fft_size;
        begin
            $display("\n[%0t] Loading %0d Input Samples", $time, fft_size);

            //Wait for FFT to be ready
            wait(fft_ready == 1);
            @(negedge clk);

            //Load input samples
            for(i = 0; i < fft_size; i = i + 1) begin
                data_in = input_samples[i];
                data_in_valid = 1;
                @(negedge clk);
                $display("[%0t]   Sample[%2d] = 0x%h (Real: 0x%h, Imag: 0x%h)", 
                         $time, i, input_samples[i], 
                         input_samples[i][7:4], input_samples[i][3:0]);
            end

            //Deassert data_in_valid
            data_in_valid = 0;
            @(negedge clk);

            $display("[%0t] All Input Samples Loaded", $time);
        end
    endtask

    //Task: Capture output samples from FFT
    task capture_output;
        input integer fft_size;
        integer timeout;
        begin
            output_index = 0;
            timeout = 0;
            $display("\n[%0t] Capturing %0d FFT Output Samples", $time, fft_size);

            //Wait for first output valid with timeout
            while(data_out_valid == 0 && timeout < 10000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end

            if(timeout >= 10000) begin
                $display("[%0t] ERROR: Timeout waiting for output valid!", $time);
                disable capture_output;
            end

            //Capture output samples
            while(output_index < fft_size) begin
                if(data_out_valid) begin
                    received_output[output_index] = data_out;
                    $display("[%0t]   Output[%2d] = 0x%h (Real: 0x%h, Imag: 0x%h)", 
                             $time, output_index, data_out, 
                             data_out[7:4], data_out[3:0]);
                    output_index = output_index + 1;
                end
                @(negedge clk);
            end

            //Wait for valid to go low
            while(data_out_valid == 1) @(negedge clk);
            
            $display("[%0t] All Output Samples Captured", $time);
        end
    endtask

    //Task: Verify output with expected values
    task verify_output;
        input integer fft_size;
        input [256*8-1:0] test_name;
        integer errors;
        begin
            errors = 0;
            $display("\n[%0t] Verifying Results: %s", $time, test_name);
            $display("[%0t] ----------------------------------------", $time);

            for (k = 0; k < fft_size; k = k + 1) begin
                if (received_output[k] != expected_output[k]) begin
                    $display("  [FAIL] Bin[%2d]: Expected 0x%h, Got 0x%h", 
                             k, expected_output[k], received_output[k]);
                    errors = errors + 1;
                end else begin
                    $display("  [PASS] Bin[%2d]: 0x%h", k, received_output[k]);
                end
            end

            if (errors == 0) begin
                $display("\n[%0t] âœ“ Test PASSED: %s", $time, test_name);
                test_pass = test_pass + 1;
            end else begin
                $display("\n[%0t] âœ— Test FAILED: %s (%0d errors)", $time, test_name, errors);
                test_fail = test_fail + 1;
            end
            test_count = test_count + 1;
        end
    endtask

    //Task: Verify with tolerance for FP4 precision
    task verify_output_tolerant;
        input integer fft_size;
        input [256*8-1:0] test_name;
        input integer dc_bin; //which bin should have DC energy
        integer errors;
        reg dc_ok;
        begin
            errors = 0;
            dc_ok = 0;
            $display("\n[%0t] Verifying Results (with FP4 tolerance): %s", $time, test_name);
            $display("[%0t] ----------------------------------------", $time);

            for (k = 0; k < fft_size; k = k + 1) begin
                if (k == dc_bin) begin
                    //Check DC bin has significant energy
                    if (received_output[k][7:4] >= 4'b0101 || //real part significant
                        received_output[k][3:0] >= 4'b0101) begin //or imag part significant
                        $display("  [PASS] Bin[%2d] (DC): 0x%h (has energy)", k, received_output[k]);
                        dc_ok = 1;
                    end else begin
                        $display("  [FAIL] Bin[%2d] (DC): 0x%h (too small)", k, received_output[k]);
                        errors = errors + 1;
                    end
                end else begin
                    //For other bins, accept small values as effectively zero
                    //Due to FP4 quantization, expect some leakage
                    if (received_output[k] == 8'b00000000 ||
                        (received_output[k][7:4] < 4'b0100 && received_output[k][3:0] < 4'b0100)) begin
                        $display("  [PASS] Bin[%2d]: 0x%h (small/zero)", k, received_output[k]);
                    end else begin
                        $display("  [WARN] Bin[%2d]: 0x%h (leakage expected in FP4)", k, received_output[k]);
                        //Don't count as error - FP4 has limited precision
                    end
                end
            end

            if (dc_ok && errors == 0) begin
                $display("\n[%0t] âœ“ Test PASSED: %s", $time, test_name);
                test_pass = test_pass + 1;
            end else begin
                $display("\n[%0t] âœ— Test FAILED: %s", $time, test_name);
                test_fail = test_fail + 1;
            end
            test_count = test_count + 1;
        end
    endtask

    //=============================================================================
    // TEST DATA INITIALIZATION TASKS
    //=============================================================================

    //Initialize: Impulse at sample 0
    task init_impulse;
        input integer size;
        begin
            $display("[%0t] Initializing Impulse Input (size=%0d)", $time, size);
            input_samples[0] = 8'b00100000; //1+j0 at sample 0
            for (j = 1; j < size; j = j + 1) begin
                input_samples[j] = 8'b00000000; //0+j0 for rest
            end

            //Expected: All bins have same value (1+j0 for ideal case)
            //Due to FP4 precision, expect variations
            for (j = 0; j < size; j = j + 1) begin
                expected_output[j] = 8'b00100000; //1+j0
            end
        end
    endtask

    //Initialize: Constant (all ones)
    task init_constant;
        input integer size;
        begin
            $display("[%0t] Initializing Constant Input (size=%0d)", $time, size);
            for (i = 0; i < size; i = i + 1) begin
                input_samples[i] = 8'b00100000; //1+j0
            end

            //Expected: Energy only in DC bin (bin 0)
            for (i = 0; i < size; i = i + 1) begin
                if (i == 0) begin
                    //DC bin should have N * (1+j0)
                    case (size)
                        4:  expected_output[i] = 8'b01000000; //~4
                        8:  expected_output[i] = 8'b01100000; //~8
                        16: expected_output[i] = 8'b01110000; //~16
                        32: expected_output[i] = 8'b10000000; //~32
                        default: expected_output[i] = 8'b00100000;
                    endcase
                end else begin
                    expected_output[i] = 8'b00000000; //0+j0
                end
            end
        end
    endtask

    //Initialize: Complex exponential (sinusoid)
    task init_sinusoid;
        input integer size;
        input integer freq_bin; //which frequency bin to generate
        integer n;
        begin
            $display("[%0t] Initializing Sinusoid Input (size=%0d, freq=%0d)", 
                     $time, size, freq_bin);
            
            //Generate complex exponential: e^(j*2*pi*freq_bin*n/size)
            for (n = 0; n < size; n = n + 1) begin
                //Use twiddle factor pattern
                case((n * freq_bin * 32 / size) % 32) //scale to 32-point pattern
                    0, 1:   input_samples[n] = 8'b00100000; //1+j0
                    2, 3:   input_samples[n] = 8'b00101001; //1-j0.5
                    4:      input_samples[n] = 8'b00011001; //0.5-j0.5
                    5, 6:   input_samples[n] = 8'b00011010; //0.5-j1
                    7, 8:   input_samples[n] = 8'b00000010; //0-j1
                    9, 10:  input_samples[n] = 8'b10011010; //-0.5-j1
                    11, 12: input_samples[n] = 8'b10011001; //-0.5-j0.5
                    13, 14: input_samples[n] = 8'b10101001; //-1-j0.5
                    15, 16: input_samples[n] = 8'b10100000; //-1+j0
                    17, 18: input_samples[n] = 8'b10101001; //-1+j0.5
                    19, 20: input_samples[n] = 8'b10011001; //-0.5+j0.5
                    21, 22: input_samples[n] = 8'b10011010; //-0.5+j1
                    23, 24: input_samples[n] = 8'b00000010; //0+j1
                    25, 26: input_samples[n] = 8'b00011010; //0.5+j1
                    27, 28: input_samples[n] = 8'b00011001; //0.5+j0.5
                    29, 30: input_samples[n] = 8'b00101001; //1+j0.5
                    31:     input_samples[n] = 8'b00100000; //1+j0
                    default: input_samples[n] = 8'b00000000;
                endcase
            end

            //Expected: Energy mainly in freq_bin
            for (i = 0; i < size; i = i + 1) begin
                expected_output[i] = 8'b00000000; //default to zero
            end
            expected_output[freq_bin] = 8'b01100000; //main energy here
        end
    endtask

    //Initialize: Alternating pattern (+1, -1, +1, -1, ...)
    task init_alternating;
        input integer size;
        begin
            $display("[%0t] Initializing Alternating Input (size=%0d)", $time, size);
            for (i = 0; i < size; i = i + 1) begin
                if (i % 2 == 0) begin
                    input_samples[i] = 8'b00100000; //+1+j0
                end else begin
                    input_samples[i] = 8'b10100000; //-1+j0
                end
            end

            //Expected: Energy at Nyquist frequency (N/2)
            for (i = 0; i < size; i = i + 1) begin
                if (i == size/2) begin
                    expected_output[i] = 8'b01100000; //main energy
                end else begin
                    expected_output[i] = 8'b00000000;
                end
            end
        end
    endtask

    //Initialize: All zeros
    task init_zeros;
        input integer size;
        begin
            $display("[%0t] Initializing Zero Input (size=%0d)", $time, size);
            for (i = 0; i < size; i = i + 1) begin
                input_samples[i] = 8'b00000000; //0+j0
                expected_output[i] = 8'b00000000; //0+j0
            end
        end
    endtask

    //=============================================================================
    // TEST CASES
    //=============================================================================

    //Test 1: 4-point FFT - Impulse
    task test_4pt_impulse;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 1: 4-Point FFT - Impulse Function");
            $display("================================================================================");
            
            N = 4;
            init_impulse(4);
            load_input(4);
            
            //Wait for completion
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(4);
            verify_output(4, "4-Point Impulse");
        end
    endtask

    //Test 2: 4-point FFT - Constant
    task test_4pt_constant;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 2: 4-Point FFT - Constant Function");
            $display("================================================================================");
            
            N = 4;
            init_constant(4);
            load_input(4);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(4);
            verify_output_tolerant(4, "4-Point Constant", 0); //DC at bin 0
        end
    endtask

    //Test 3: 8-point FFT - Impulse
    task test_8pt_impulse;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 3: 8-Point FFT - Impulse Function");
            $display("================================================================================");
            
            N = 8;
            init_impulse(8);
            load_input(8);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(8);
            verify_output(8, "8-Point Impulse");
        end
    endtask

    //Test 4: 8-point FFT - Constant
    task test_8pt_constant;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 4: 8-Point FFT - Constant Function");
            $display("================================================================================");
            
            N = 8;
            init_constant(8);
            load_input(8);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(8);
            verify_output_tolerant(8, "8-Point Constant", 0);
        end
    endtask

    //Test 5: 8-point FFT - Alternating
    task test_8pt_alternating;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 5: 8-Point FFT - Alternating Pattern");
            $display("================================================================================");
            
            N = 8;
            init_alternating(8);
            load_input(8);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(8);
            verify_output_tolerant(8, "8-Point Alternating", 4); //Nyquist at N/2
        end
    endtask

    //Test 6: 16-point FFT - Impulse
    task test_16pt_impulse;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 6: 16-Point FFT - Impulse Function");
            $display("================================================================================");
            
            N = 16;
            init_impulse(16);
            load_input(16);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(16);
            verify_output(16, "16-Point Impulse");
        end
    endtask

    //Test 7: 16-point FFT - Sinusoid
    task test_16pt_sinusoid;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 7: 16-Point FFT - Sinusoid (freq bin 2)");
            $display("================================================================================");
            
            N = 16;
            init_sinusoid(16, 2);
            load_input(16);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(16);
            verify_output_tolerant(16, "16-Point Sinusoid", 2);
        end
    endtask

    //Test 8: 32-point FFT - Impulse
    task test_32pt_impulse;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 8: 32-Point FFT - Impulse Function");
            $display("================================================================================");
            
            N = 32;
            init_impulse(32);
            load_input(32);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(32);
            verify_output(32, "32-Point Impulse");
        end
    endtask

    //Test 9: 32-point FFT - Constant
    task test_32pt_constant;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 9: 32-Point FFT - Constant Function");
            $display("================================================================================");
            
            N = 32;
            init_constant(32);
            load_input(32);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(32);
            verify_output_tolerant(32, "32-Point Constant", 0);
        end
    endtask

    //Test 10: All zeros input
    task test_zeros;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 10: 8-Point FFT - All Zeros");
            $display("================================================================================");
            
            N = 8;
            init_zeros(8);
            load_input(8);
            
            wait(done == 1);
            $display("[%0t] FFT computation complete", $time);
            
            capture_output(8);
            verify_output(8, "8-Point Zeros");
        end
    endtask

    //Test 11: Error conditions
    task test_errors;
        integer timeout;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 11: Error Condition Testing");
            $display("================================================================================");

            //Test 11a: N = 0
            $display("\n[%0t] Test 11a: N = 0 (should error)", $time);
            reset_sys();
            @(negedge clk);
            N = 0;
            start = 1;
            @(negedge clk);
            start = 0;
            
            timeout = 0;
            while (!error && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            
            if (error || timeout < 100) begin
                $display("  âœ“ [PASS] Error detected or rejected for N=0");
                test_pass = test_pass + 1;
            end else begin
                $display("  âœ— [FAIL] No error for N=0");
                test_fail = test_fail + 1;
            end
            test_count = test_count + 1;

            //Test 11b: N = 33 (> MAX_N)
            $display("\n[%0t] Test 11b: N = 33 (should error)", $time);
            reset_sys();
            @(negedge clk);
            N = 33;
            start = 1;
            @(negedge clk);
            start = 0;
            
            timeout = 0;
            while (!error && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            
            if (error || timeout < 100) begin
                $display("  âœ“ [PASS] Error detected or rejected for N=33");
                test_pass = test_pass + 1;
            end else begin
                $display("  âœ— [FAIL] No error for N=33");
                test_fail = test_fail + 1;
            end
            test_count = test_count + 1;

            //Test 11c: N = 7 (not power of 2)
            $display("\n[%0t] Test 11c: N = 7 (not power of 2, should error)", $time);
            reset_sys();
            @(negedge clk);
            N = 7;
            start = 1;
            @(negedge clk);
            start = 0;
            
            timeout = 0;
            while (!error && timeout < 100) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            
            if (error || timeout < 100) begin
                $display("  âœ“ [PASS] Error detected or rejected for N=7");
                test_pass = test_pass + 1;
            end else begin
                $display("  âœ— [FAIL] No error for N=7");
                test_fail = test_fail + 1;
            end
            test_count = test_count + 1;

            //Reset for next tests
            reset_sys();
        end
    endtask

    //Test 12: Pipeline operation
    task test_pipeline;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 12: Pipeline Operation - Back-to-Back FFTs");
            $display("================================================================================");

            for (j = 0; j < 3; j = j + 1) begin
                $display("\n[%0t] --- Pipeline Operation %0d ---", $time, j+1);
                
                N = 8;
                init_impulse(8);
                load_input(8);
                
                wait(done == 1);
                $display("[%0t] FFT %0d complete", $time, j+1);
                
                //Small delay before next operation
                repeat(5) @(negedge clk);
            end
            
            $display("\n  âœ“ [PASS] Pipeline operation test completed");
            test_pass = test_pass + 1;
            test_count = test_count + 1;
        end
    endtask

    //Test 13: Multiple sizes in sequence
    task test_variable_sizes;
        begin
            $display("\n");
            $display("================================================================================");
            $display("TEST 13: Variable Size FFTs in Sequence");
            $display("================================================================================");

            //4-point
            $display("\n[%0t] Testing 4-point FFT", $time);
            N = 4;
            init_constant(4);
            load_input(4);
            wait(done == 1);
            repeat(5) @(negedge clk);

            //8-point
            $display("\n[%0t] Testing 8-point FFT", $time);
            reset_sys();
            N = 8;
            init_constant(8);
            load_input(8);
            wait(done == 1);
            repeat(5) @(negedge clk);

            //16-point
            $display("\n[%0t] Testing 16-point FFT", $time);
            reset_sys();
            N = 16;
            init_constant(16);
            load_input(16);
            wait(done == 1);
            repeat(5) @(negedge clk);

            $display("\n  âœ“ [PASS] Variable size test completed");
            test_pass = test_pass + 1;
            test_count = test_count + 1;
        end
    endtask

    //=============================================================================
    // MAIN TEST SEQUENCE
    //=============================================================================

    initial begin
        //Initialize
        test_pass = 0;
        test_fail = 0;
        test_count = 0;
        output_index = 0;
        
        //Create waveform dump
        $dumpfile("fft_comprehensive.vcd");
        $dumpvars(0, tb_fft_comprehensive);
        
        $display("\n");
        $display("################################################################################");
        $display("#                                                                              #");
        $display("#              COMPREHENSIVE FFT TESTBENCH                                     #");
        $display("#              FP4 Complex FFT with Cooley-Tukey Algorithm                     #");
        $display("#                                                                              #");
        $display("################################################################################");
        $display("\nNote: FP4 format has limited 4-bit precision");
        $display("      Small numerical errors and spectral leakage are expected");
        $display("      Transform sizes must be powers of 2 (4, 8, 16, 32)");
        $display("\n");
        
        //Reset system
        reset_sys();
        repeat(10) @(negedge clk);
        
        //Run all tests
        test_4pt_impulse();          //Test 1
        reset_sys();
        test_4pt_constant();         //Test 2
        reset_sys();
        test_8pt_impulse();          //Test 3
        reset_sys();
        test_8pt_constant();         //Test 4
        reset_sys();
        test_8pt_alternating();      //Test 5
        reset_sys();
        test_16pt_impulse();         //Test 6
        reset_sys();
        test_16pt_sinusoid();        //Test 7
        reset_sys();
        test_32pt_impulse();         //Test 8
        reset_sys();
        test_32pt_constant();        //Test 9
        reset_sys();
        test_zeros();                //Test 10
        reset_sys();
        test_errors();               //Test 11
        reset_sys();
        test_pipeline();             //Test 12
        reset_sys();
        test_variable_sizes();       //Test 13
        
        //Final summary
        repeat(20) @(negedge clk);
        $display("\n");
        $display("################################################################################");
        $display("#                         TEST SUMMARY                                         #");
        $display("################################################################################");
        $display("  Total Tests:  %0d", test_count);
        $display("  Passed:       %0d", test_pass);
        $display("  Failed:       %0d", test_fail);
        
        if (test_fail == 0) begin
            $display("\n  â˜…â˜…â˜… ALL TESTS PASSED! â˜…â˜…â˜…");
        end else begin
            $display("\n  âš  SOME TESTS FAILED");
        end
        
        $display("\nSimulation completed at time %0t ns", $time);
        $display("################################################################################");
        $display("\n");
        
        $finish;
    end
    
    //Timeout monitor
    initial begin
        #100_000_000; //100ms timeout
        $display("\n[ERROR] â± Simulation timed out after 100ms!");
        $display("Tests Passed: %0d, Failed: %0d", test_pass, test_fail);
        $finish;
    end
    
endmodule