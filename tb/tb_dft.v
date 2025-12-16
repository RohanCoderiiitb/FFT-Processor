//testbench for dft module

`timescale 1ns / 1ps

module tb_dft;
    //PARAMETERS
    parameter MAX_N = 32;
    parameter ADDR_WIDTH = $clog2(MAX_N);

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
    wire dft_ready;

    //Test variables
    integer i, j;
    reg [7:0] input_samples [0:31];
    reg [7:0] expected_output [0:31];
    reg [7:0] received_output [0:31];
    integer output_index;
    integer test_pass;
    integer test_fail;

    //instantiate the Unit Under Test (UUT)
    fp4_dft #(
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
        .dft_ready(dft_ready)
    );

    //clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; //10ns clock period
    end

    //test tasks
    task reset_sys;
        begin
            rst = 0;
            start = 0;
            data_in = 8'b0;
            data_in_valid = 0;
            N = 8; //default N = 8 for 8 point DFT
            @(negedge clk); //wait for negative edge so that reset is applied for full clock cycle
            rst = 1;
            @(negedge clk);
            $display("System Reset Complete");
        end
    endtask

    task load_input;
        input integer dft_size;
        begin
            $display("[%0t] Loading Input Samples for N=%0d", $time, dft_size);

            //wait for dft to be ready
            wait(dft_ready == 1);

            //load input samples
            for(i = 0; i < dft_size; i = i + 1) begin
                @(negedge clk);
                data_in = input_samples[i];
                data_in_valid = 1;
                @(negedge clk); //wait for one clock cycle
                $display("[%0t] Loaded sample %0d: 0x%h (Real: 0x%h, Imag: 0x%h)", 
                         $time, i, input_samples[i], 
                         input_samples[i][7:4], input_samples[i][3:0]);
                
            end

            //deassert data_in_valid
            @(negedge clk);
            data_in_valid = 0;

            $display("[%0t] All Input Samples Loaded", $time);
        end
    endtask

    task start_dft;
        begin
            @(negedge clk);
            start = 1;
            $display("[%0t] DFT Start Signal Asserted", $time);

            //wait for dft to start (done signal goes low)
            wait(done == 0);

            @(negedge clk);
            start = 0;
        end
    endtask

    task capture_output;
        begin
            output_index = 0;
            $display("[%0t] Capturing DFT Output Samples", $time);

            //wait for first output valid
            wait(data_out_valid == 1);

            //capture output samples
            while(output_index < N) begin
                @(negedge clk);
                if(data_out_valid) begin
                    received_output[output_index] = data_out;
                    $display("[%0t] Captured output sample %0d: 0x%h (Real: 0x%h, Imag: 0x%h)", 
                             $time, output_index, data_out, 
                             data_out[7:4], data_out[3:0]);
                    output_index = output_index + 1;
                end
            end

            //wait for valid to go low
            wait(data_out_valid == 0);
            $display("[%0t] All Output Samples Captured", $time);
        end
    endtask

    task verify_output;
        input integer dft_size;
        input [256*8-1:0] test_name;  //string parameter for test name
        integer k;
        begin
            $display("\n[%0t] Verifying results for test: %s", $time, test_name);

            for (k=0; k<dft_size; k=k+1) begin
                if (received_output[k] != expected_output[k]) begin
                    $display("  [FAIL] Sample %0d: Expected 0x%h, Got 0x%h", 
                             k, expected_output[k], received_output[k]);
                    test_fail = test_fail + 1;
                end else begin
                    $display("  [PASS] Sample %0d: Expected 0x%h, Got 0x%h", 
                             k, expected_output[k], received_output[k]);
                    test_pass = test_pass + 1;
                end
            end
            $display("[%0t] Test %s Completed: %0d Passed, %0d Failed\n", 
                     $time, test_name, test_pass, test_fail);
        end
    endtask

    //test sequence

    //initialise input samples for tests
    task init_test_impulse;
        begin
            //impulse input: x[0] = 1 + j0, rest are 0
            input_samples[0] = 8'b00100000; //1 + j0
            for (j = 1; j < 32; j = j + 1) begin
                input_samples[j] = 8'b00000000; //0 + j0
            end

            //expected output for impulse DFT: all outputs = 1 + j0
            for (j = 0; j < 32; j = j + 1) begin
                expected_output[j] = 8'b00100000; //1 + j0
            end
        end
    endtask

    task init_test_constant;
        //constant function: all samples = 1 + 0j
        //expected DFT: X[0] = N, all others = 0
        input integer dft_size;
        begin
            for (i = 0; i < MAX_N; i = i + 1) begin
                if (i < dft_size) begin
                    input_samples[i] = 8'b00100000; //1 + 0j
                end else begin
                    input_samples[i] = 8'b00000000; //0 + 0j
                end
                
                if (i < dft_size) begin
                    if (i == 0) begin
                        //X[0] should be N (in FP4, we need to represent N)
                        case (dft_size)
                            8: expected_output[i] = 8'b01100000; //approximate 8 in FP4
                            16: expected_output[i] = 8'b01110000; //approximate 16 in FP4
                            default: expected_output[i] = 8'b00100000; //default to 1
                        endcase
                    end else begin
                        expected_output[i] = 8'b00000000; //0 + 0j
                    end
                end
            end
        end
    endtask

    task init_test_sin;
        //single complex sinusoid input
        //expected DFT: peak at corresponding frequency bin
        input integer dft_size;
        integer m;
        begin
            for (m = 0; m < dft_size; m = m + 1) begin
                //x[n] = cos(2*pi*f0*n/N) + j*sin(2*pi*f0*n/N)
                //let f0 = 1 for simplicity
                case(m % 8) //time domain samples for 8-point sinusoid in fp4
                    0: input_samples[m] = 8'b00100000; //1 + 0j
                    1: input_samples[m] = 8'b00101001; //1 - 0.5j
                    2: input_samples[m] = 8'b00011001; //0.5 - 0.5j
                    3: input_samples[m] = 8'b00001010; //0 - 1j
                    4: input_samples[m] = 8'b10100000; //-1 + 0j
                    5: input_samples[m] = 8'b10101001; //-1 + 0.5j
                    6: input_samples[m] = 8'b10011001; //-0.5 + 0.5j
                    7: input_samples[m] = 8'b00000010; //0 + 1j
                endcase
            end

            //initialize expected output
            for (m = 0; m < dft_size; m = m + 1) begin
                //expected output: peak at f = 1
                if (m == 1) begin
                    expected_output[m] = 8'b01100000; //should have energy here
                end else begin
                    expected_output[m] = 8'b00000000; //0 + 0j for all other frequencies
                end
            end
        end
    endtask

    //test sequences
    task test_8point_impulse;
        begin 
            $display("\n========================================");
            $display("Test 1: 8-point DFT of Impulse Function");
            $display("========================================");

            N = 8;
            init_test_impulse();

            load_input(8);

            // start_dft();

            wait(done == 1'b1);
            $display("[%0t] DFT computation complete", $time);

            capture_output();

            verify_output(8, "8-point Impulse");
        end
    endtask

    task test_8point_constant;
        begin
            $display("\n========================================");
            $display("Test 2: 8-point DFT of Constant Function");
            $display("========================================");

            N = 8;
            init_test_constant(8);

            load_input(8);

            // start_dft();

            wait(done == 1'b1);
            $display("[%0t] DFT computation complete", $time);

            capture_output();

            verify_output(8, "8-point Constant");
        end
    endtask

    task test_16point_dft;
        begin
            $display("\n========================================");
            $display("Test 3: 16-point DFT");
            $display("========================================");

            N = 16;
            init_test_sin(16);

            load_input(16);

            // start_dft();

            wait(done == 1);
            $display("[%0t] DFT computation complete", $time);

            capture_output();

            verify_output(16, "16-point Sinusoid");
        end
    endtask

    task test_errors;
        begin 
            $display("\n========================================");
            $display("Test 4: Error Condition Testing");
            $display("========================================");

            //test a: N = 0
            @(negedge clk);
            rst = 0;
            @(negedge clk);
            rst = 1;
            @(negedge clk);
            
            N = 0;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait (done == 1 || error == 1);
            if (error) begin
                $display("[PASS] Error detected for N=0");
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] No error for N=0");
                test_fail = test_fail + 1;
            end

            //reset between tests to clear error state
            @(negedge clk);
            rst = 0;
            @(negedge clk);
            rst = 1;
            @(negedge clk);

            //test b: N > 32
            @(negedge clk);
            N = 33;
            start = 1'b1;
            @(negedge clk);
            start = 1'b0;

            wait (done == 1 || error == 1);
            if (error) begin
                $display("[PASS] Error detected for N=33");
                test_pass = test_pass + 1;
            end else begin
                $display("[FAIL] No error for N=33");
                test_fail = test_fail + 1;
            end

            //reset error state before continuing to other tests
            @(negedge clk);
            rst = 0;
            @(negedge clk);
            rst = 1;
            N = 8;
            start = 0;
        end
    endtask

    task test_pipeline;
        begin
            $display("\n========================================");
            $display("Test 5: Pipeline Operation");
            $display("========================================");

            //test back to back dft operations
            for (j = 0; j < 3; j = j + 1) begin
                $display("[%0t] Starting DFT operation %0d", $time, j+1);

                N = 8;
                init_test_impulse();

                load_input(8);

                // start_dft();

                wait(done == 1);

                //wait a few clock cycles before the next dft
                repeat(5) @(negedge clk);
            end
        
            $display("[PASS] Pipeline operation test completed");
            test_pass = test_pass + 1;
        end
    endtask

    //main test sequence
    initial begin
        //initialize
        clk = 1'b0;
        test_pass = 0;
        test_fail = 0;
        output_index = 0;
        
        //create waveform dump
        $dumpfile("dft_waveform.vcd");
        $dumpvars(0, tb_dft);
        
        $display("\n========================================");
        $display("Starting DFT Testbench");
        $display("========================================");
        
        //reset system
        reset_sys();
        
        //run tests
        test_8point_impulse();
        test_8point_constant();
        test_16point_dft();
        test_errors();
        test_pipeline();
        
        //summary
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests Passed: %0d", test_pass);
        $display("Total Tests Failed: %0d", test_fail);
        
        if (test_fail == 0) begin
            $display("\n*** All tests PASSED!");
        end else begin
            $display("\n*** Some tests FAILED!");
        end
        
        $display("\nSimulation complete at time %0t ns", $time);
        $finish;
    end
    
    //timeout monitor to prevent infinite simulation
    initial begin
        #10000000; //10ms timeout
        $display("\n[ERROR] Simulation timed out!");
        $display("Test Passed: %0d, Failed: %0d", test_pass, test_fail);
        $finish;
    end
    
endmodule