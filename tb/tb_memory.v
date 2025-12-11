`timescale 1ns / 1ps

module tb_fp4_fft_memory_dff;

    //=== testbench signals ===//
    reg clk;
    reg rst;
    reg bank_sel;
    
    //port 0: read from processing bank
    reg [4:0] rd_addr_0;
    wire [7:0] rd_data_0;
    
    //port 1: write to filling bank
    reg wr_en_1;
    reg [4:0] wr_addr_1;
    reg [7:0] wr_data_1;
    
    //test counters
    integer test_pass_count;
    integer test_fail_count;

    //=== instantiate memory module ===//
    fp4_fft_memory_dff uut (
        .clk(clk),
        .rst(rst),
        .bank_sel(bank_sel),
        .rd_addr_0(rd_addr_0),
        .rd_data_0(rd_data_0),
        .wr_en_1(wr_en_1),
        .wr_addr_1(wr_addr_1),
        .wr_data_1(wr_data_1)
    );

    //=== clock generation (100mhz) ===//
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    //=== waveform dump ===//
    initial begin
        $dumpfile("tb_fp4_fft_memory_dff.vcd");
        $dumpvars(0, tb_fp4_fft_memory_dff);
    end

    //=== test tasks ===//
    
    //task to write to filling bank
    task write_memory;
        input [4:0] addr;
        input [7:0] data;
        begin
            wr_en_1 = 1;
            wr_addr_1 = addr;
            wr_data_1 = data;
            @(posedge clk);
            #1;
            wr_en_1 = 0;
        end
    endtask

    //task to read from processing bank and verify
    task read_memory;
        input [4:0] addr;
        input [7:0] expected_data;
        begin
            rd_addr_0 = addr;
            @(posedge clk);
            #1;
            if (rd_data_0 === expected_data) begin
                $display("read pass: addr %0d data %0h", addr, rd_data_0);
                test_pass_count = test_pass_count + 1;
            end else begin
                $display("read fail: addr %0d expected %0h got %0h", 
                         addr, expected_data, rd_data_0);
                test_fail_count = test_fail_count + 1;
            end
        end
    endtask

    //=== test sequence ===//
    initial begin
        //initialize counters
        test_pass_count = 0;
        test_fail_count = 0;

        $display("========================================");
        $display("  fp4 fft ping-pong memory testbench");
        $display("========================================");
        $display("clock period: 10ns (100mhz)");
        $display("memory size: 32 x 8-bit per bank");
        $display("========================================\n");

        //test 1: reset memory
        $display("test 1: reset memory");
        rst = 0;
        bank_sel = 0;
        rd_addr_0 = 0;
        wr_en_1 = 0;
        #20;
        rst = 1;
        #20;
        $display("reset complete.\n");

        //test 2: write to bank 0
        $display("test 2: write to bank 0");
        bank_sel = 1; //write to bank 0 (opposite of bank_sel)
        write_memory(5'd0, 8'b01100101);  //addr 0: real=6, imag=5
        #10;
        write_memory(5'd1, 8'b10001001);  //addr 1: real=8, imag=9
        #10;
        write_memory(5'd2, 8'b00110100);  //addr 2: real=3, imag=4
        #10;
        write_memory(5'd3, 8'b11110000);  //addr 3: real=15, imag=0
        #10;
        write_memory(5'd31, 8'b00011110); //addr 31: real=1, imag=14
        #10;
        $display("write operations complete.\n");

        //test 3: read from bank 0
        $display("test 3: read from bank 0");
        bank_sel = 0; //read from bank 0
        read_memory(5'd0, 8'b01100101);  //addr 0
        #5;
        read_memory(5'd1, 8'b10001001);  //addr 1
        #5;
        read_memory(5'd2, 8'b00110100);  //addr 2
        #5;
        read_memory(5'd3, 8'b11110000);  //addr 3
        #5;
        read_memory(5'd31, 8'b00011110); //addr 31
        #5;
        $display("read operations complete.\n");

        //test 4: write to bank 1
        $display("test 4: write to bank 1");
        bank_sel = 0; //write to bank 1 (opposite of bank_sel)
        write_memory(5'd0, 8'b01010110);  //addr 0: real=5, imag=6
        #10;
        write_memory(5'd1, 8'b10011000);  //addr 1: real=9, imag=8
        #10;
        write_memory(5'd2, 8'b01000011);  //addr 2: real=4, imag=3
        #10;
        write_memory(5'd3, 8'b00001111);  //addr 3: real=0, imag=15
        #10;
        write_memory(5'd31, 8'b11100001); //addr 31: real=14, imag=1
        #10;
        $display("write operations complete.\n");

        //test 5: read from bank 1
        $display("test 5: read from bank 1");
        bank_sel = 1; //read from bank 1
        read_memory(5'd0, 8'b01010110);  //addr 0
        #5;
        read_memory(5'd1, 8'b10011000);  //addr 1
        #5;
        read_memory(5'd2, 8'b01000011);  //addr 2
        #5;
        read_memory(5'd3, 8'b00001111);  //addr 3
        #5;
        read_memory(5'd31, 8'b11100001); //addr 31
        #5;
        $display("read operations complete.\n");

        //test 6: ping-pong bank swap test
        $display("test 6: ping-pong bank swap test");
        
        //re-establish known state in bank 0
        bank_sel = 1; //write to bank 0
        write_memory(5'd0, 8'b01100101);  //write to bank 0 addr 0
        #10;
        write_memory(5'd1, 8'b10001001);  //write to bank 0 addr 1
        #10;
        
        //now test ping-pong
        bank_sel = 0; //read from bank 0
        read_memory(5'd0, 8'b01100101);  //read from bank 0
        #5;
        
        bank_sel = 0; //write to bank 1
        write_memory(5'd4, 8'b11111111);  //write to bank 1 addr 4
        #10;
        
        bank_sel = 0; //read from bank 0 again
        read_memory(5'd1, 8'b10001001);  //read from bank 0
        #5;
        
        bank_sel = 0; //write to bank 1
        write_memory(5'd5, 8'b00000000);  //write to bank 1 addr 5
        #10;
        $display("ping-pong operations complete.\n");

        //test 7: simultaneous read-write test
        $display("test 7: simultaneous read-write test");
        
        //ensure bank 0 has expected data
        bank_sel = 1; //write to bank 0
        write_memory(5'd2, 8'b00110100);  //re-write to bank 0 addr 2
        #10;
        write_memory(5'd3, 8'b11110000);  //re-write to bank 0 addr 3
        #10;
        
        //now read from bank 0 while writing to bank 1
        bank_sel = 0; //read from bank 0, write to bank 1
        rd_addr_0 = 5'd2; //set read address
        
        //set up write (will go to bank 1)
        wr_en_1 = 1;
        wr_addr_1 = 5'd6;
        wr_data_1 = 8'b10101010;
        
        @(posedge clk);
        #1;
        wr_en_1 = 0;
        
        //verify read was correct while write happened
        if (rd_data_0 === 8'b00110100) begin
            $display("simultaneous r/w pass: read %0h while writing to other bank", rd_data_0);
            test_pass_count = test_pass_count + 1;
        end else begin
            $display("simultaneous r/w fail: expected %0h got %0h", 8'b00110100, rd_data_0);
            test_fail_count = test_fail_count + 1;
        end
        
        //verify the write to bank 1 worked
        bank_sel = 1; //read from bank 1
        read_memory(5'd6, 8'b10101010);  //should see what we wrote
        #5;

        //final test summary
        $display("========================================");
        $display("test summary:");
        $display("total passed: %0d", test_pass_count);
        $display("total failed: %0d", test_fail_count);
        $display("========================================");
        $finish;
    end

    //timeout to avoid infinite simulation
    initial begin
        #10000;
        $display("testbench timeout: simulation ended after 10000ns.");
        $finish;
    end
endmodule
