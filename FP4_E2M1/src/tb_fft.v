`timescale 1ns/1ps

module tb_fft_clean;

    parameter MAX_N = 32;
    parameter ADDR_WIDTH = $clog2(MAX_N);

    reg clk, rst, start;
    reg [ADDR_WIDTH:0] N_config;

    reg ext_wr_en;
    reg [ADDR_WIDTH-1:0] ext_wr_addr;
    reg [7:0] ext_wr_data;

    reg [ADDR_WIDTH-1:0] ext_rd_addr;
    wire [7:0] ext_rd_data;
    wire done;

    integer i;

    // ---------------- DUT ----------------
    fp4_fft_top #(
        .MAX_N(MAX_N),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .N_config(N_config),
        .done(done),
        .ext_wr_en(ext_wr_en),
        .ext_wr_addr(ext_wr_addr),
        .ext_wr_data(ext_wr_data),
        .ext_rd_addr(ext_rd_addr),
        .ext_rd_data(ext_rd_data)
    );

    reg [7:0] sine_lut [0:31];

    initial begin
        sine_lut[ 0] = 8'h00;
        sine_lut[ 1] = 8'h19;
        sine_lut[ 2] = 8'h30;
        sine_lut[ 3] = 8'h45;
        sine_lut[ 4] = 8'h57;
        sine_lut[ 5] = 8'h66;
        sine_lut[ 6] = 8'h70;
        sine_lut[ 7] = 8'h75;
        sine_lut[ 8] = 8'h76;
        sine_lut[ 9] = 8'h71;
        sine_lut[10] = 8'h68;
        sine_lut[11] = 8'h5b;
        sine_lut[12] = 8'h4a;
        sine_lut[13] = 8'h35;
        sine_lut[14] = 8'h1e;
        sine_lut[15] = 8'h07;
        sine_lut[16] = 8'h00;
        sine_lut[17] = 8'hf9;
        sine_lut[18] = 8'he2;
        sine_lut[19] = 8'hcb;
        sine_lut[20] = 8'hb6;
        sine_lut[21] = 8'ha5;
        sine_lut[22] = 8'h98;
        sine_lut[23] = 8'h8f;
        sine_lut[24] = 8'h8a;
        sine_lut[25] = 8'h8f;
        sine_lut[26] = 8'h98;
        sine_lut[27] = 8'ha5;
        sine_lut[28] = 8'hb6;
        sine_lut[29] = 8'hcb;
        sine_lut[30] = 8'he2;
        sine_lut[31] = 8'hf9;
    end

    // ---------------- CLOCK ----------------
    initial clk = 0;
    always #5 clk = ~clk;

    // ---------------- RESET ----------------
    task reset_dut;
    begin
        rst = 0; start = 0; ext_wr_en = 0;
        @(negedge clk);
        rst = 1;
        @(negedge clk);
        $display("[%0t] Reset done", $time);
    end
    endtask

    // ---------------- LOAD SINE WAVE ----------------
    task load_sine;
    begin
        $display("[%0t] Loading sine wave input (k = 3)", $time);
        ext_wr_en = 1;
        for (i = 0; i < N_config; i = i + 1) begin
            @(negedge clk);
            ext_wr_addr = i;
            ext_wr_data = sine_lut[i];
            $display("  x[%0d] = 0x%h", i, ext_wr_data);
        end
        ext_wr_en = 0;
    end
    endtask


    // ---------------- READ OUTPUT ----------------
    task read_output;
    begin
        $display("\n[%0t] FFT Output:", $time);
        for (i = 0; i < N_config; i = i + 1) begin
            @(negedge clk);
            ext_rd_addr = i;
            #1;
            $display("  X[%0d] = 0x%h", i, ext_rd_data);
        end
    end
    endtask

    // ---------------- DEBUG PRINTS ----------------
    always @(posedge clk) begin
        if (dut.next_step) begin
            $display(
              "[%0t] Stage=%0d  stride=%0d  group=%0d  butterfly=%0d  idx_a=%0d idx_b=%0d",
              $time,
              dut.agu_inst.curr_stage,
              dut.agu_inst.stride,
              dut.agu_inst.group,
              dut.agu_inst.butterfly,
              dut.agu_inst.idx_a,
              dut.agu_inst.idx_b
            );
        end
    end

    // ---------------- TEST SEQUENCE ----------------
    initial begin
        $dumpfile("fft_clean.vcd");
        $dumpvars(0, tb_fft_clean);

        N_config = 32;

        reset_dut();
        load_sine();

        $display("[%0t] Starting FFT", $time);
        start = 1;
        @(negedge clk);
        start = 0;

        wait(done);
        $display("[%0t] FFT DONE", $time);

        read_output();

        $finish;
    end

endmodule