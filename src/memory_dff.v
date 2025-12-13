// ========================================
// 8-bit D Flip-Flop with Enable
// ========================================
module dff_8bit (
    input wire clk,
    input wire rst,
    input wire en,
    input [7:0] d,
    output reg [7:0] q
);
    always @ (posedge clk or negedge rst) begin
        if (!rst)
            q <= 8'b0;
        else if (en)
            q <= d;
    end
endmodule

// ========================================
// FP4 FFT Memory with Explicit DFF Instantiation
// ========================================
module fp4_fft_memory_dff (
    input wire clk,
    input wire rst,
    input wire bank_sel,
    
    //port 0: read from processing bank
    input wire [4:0] rd_addr_0,
    output wire [7:0] rd_data_0,
    
    //port 1: write to filling bank (ping-pong)
    input wire wr_en_1,
    input wire [4:0] wr_addr_1,
    input wire [7:0] wr_data_1
);

    // Memory Storage: Wire arrays connected to DFF outputs
    wire [7:0] bank0_mem [0:31];
    wire [7:0] bank1_mem [0:31];

    // Generate DFF instances for both banks
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : mem_cells
            
            // Bank 0 DFF: Enabled when bank_sel=1 
            // (writing to bank0 when reading from bank1)
            wire bank0_en;
            assign bank0_en = wr_en_1 && (wr_addr_1 == i) && bank_sel;
            
            dff_8bit bank0_dff (
                .clk(clk),
                .rst(rst),
                .en(bank0_en),
                .d(wr_data_1),
                .q(bank0_mem[i])
            );
            
            // Bank 1 DFF: Enabled when bank_sel=0
            // (writing to bank1 when reading from bank0)
            wire bank1_en;
            assign bank1_en = wr_en_1 && (wr_addr_1 == i) && ~bank_sel;
            
            dff_8bit bank1_dff (
                .clk(clk),
                .rst(rst),
                .en(bank1_en),
                .d(wr_data_1),
                .q(bank1_mem[i])
            );
        end
    endgenerate

    //read logic: port 0 reads from same bank as bank_sel
    assign rd_data_0 = bank_sel ? bank1_mem[rd_addr_0] : bank0_mem[rd_addr_0];

endmodule