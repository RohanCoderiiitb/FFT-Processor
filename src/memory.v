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

    reg [7:0] bank0_mem [0:31];
    reg [7:0] bank1_mem [0:31];

    integer i;
    
    //write logic: port 1 writes to opposite bank of bank_sel
    always @(posedge clk or negedge rst) begin
        if (!rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                bank0_mem[i] <= 8'b0;
                bank1_mem[i] <= 8'b0;
            end
        end else begin
            if (wr_en_1) begin
                if (bank_sel) begin
                    //bank_sel=1: reading from bank1, so write to bank0
                    bank0_mem[wr_addr_1] <= wr_data_1;
                end else begin
                    //bank_sel=0: reading from bank0, so write to bank1
                    bank1_mem[wr_addr_1] <= wr_data_1;
                end
            end
        end
    end

    //read logic: port 0 reads from same bank as bank_sel
    assign rd_data_0 = bank_sel ? bank1_mem[rd_addr_0] : bank0_mem[rd_addr_0];

endmodule


//alternative memory implementation without dffs (using reg arrays)
//commented out as we're using dff-based design for fp4 fft

// module fp4_fft_memory (
//     input wire clk,
//     input wire rst,
    
//     //bank select line: bank 0 and bank 1
//     input wire bank_sel,

//     //read ports
//     // each bank has 32 8-bit words, with [0:3] representing real part and [4:7] representing imaginary part
//     //port 0
//     input wire [4:0] rd_addr_0, 
//     output wire [7:0] rd_data_0, 

//     input wire wr_en_0,
//     input wire [4:0] wr_addr_0,
//     input wire [7:0] wr_data_0,

//     //port 1
//     input wire [4:0] rd_addr_1,
//     output wire [7:0] rd_data_1,

//     input wire wr_en_1,
//     input wire [4:0] wr_addr_1,
//     input wire [7:0] wr_data_1,

//     input wire swap_banks // new signal to swap banks
// );

//     //memory bank: 32 x 8 bit registers, with real and imaginary support
//     reg [3:0] bank0_mem_real [0:31]; //bank 0 real part
//     reg [3:0] bank0_mem_imag [0:31]; //bank 0 imaginary part

//     reg [3:0] bank1_mem_real [0:31]; //bank 1 real part
//     reg [3:0] bank1_mem_imag [0:31]; //bank 1 imaginary part

//     //internal signals for bank selection
//     wire read_from_0, write_to_1;

//     assign read_from_0 = ~bank_sel; // Read 0 when sel is 0
//     assign write_to_1 = ~bank_sel;  // Write 1 when sel is 0 (Inverse of read)

//     //read logic for dual port read
//     always @ (posedge clk or negedge rst) begin
//         if (!rst) begin
//             rd_data_0 <= 8'b0;
//             rd_data_1 <= 8'b0;
//         end else begin
//             //port 0 read
//             if (read_from_0) begin //if bank_sel is 0 read from bank0
//                 rd_data_0[3:0] <= bank0_mem_real[rd_addr_0]; //real part of bank0 
//                 rd_data_0[7:4] <= bank0_mem_imag[rd_addr_0]; //imaginary part of bank0
//             end else begin //if bank_sel is 1 read from bank1
//                 rd_data_0[3:0] <= bank1_mem_real[rd_addr_0]; //real part of bank1
//                 rd_data_0[7:4] <= bank1_mem_imag[rd_addr_0]; //imaginary part of bank1
//             end

//             //port 1 read
//             if (read_from_0) begin //if bank_sel is 0 read from bank0
//                 rd_data_1[3:0] <= bank0_mem_real[rd_addr_1];
//                 rd_data_1[7:4] <= bank0_mem_imag[rd_addr_1];
//             end else begin //if bank_sel is 1 read from bank1
//                 rd_data_1[3:0] <= bank1_mem_real[rd_addr_1];
//                 rd_data_1[7:4] <= bank1_mem_imag[rd_addr_1];
//             end
//         end
//     end

//     //write logic for dual port write
//     always @ (posedge clk or negedge rst) begin
//         if (!rst) begin
//             //reset memory banks
//             integer i;
//             for (i = 0; i < 32; i = i + 1) begin
//                 bank0_mem_real[i] <= 4'b0;
//                 bank0_mem_imag[i] <= 4'b0;
//                 bank1_mem_real[i] <= 4'b0;
//                 bank1_mem_imag[i] <= 4'b0;
//             end
//         end else begin
//             //port 0 write
//             if (wr_en_0) begin
//                 if (write_to_1) begin //if bank_sel is 1 write to bank1
//                     bank1_mem_real[wr_addr_0] <= wr_data_0[3:0];
//                     bank1_mem_imag[wr_addr_0] <= wr_data_0[7:4];
//                 end else begin //if bank_sel is 0 write to bank0
//                     bank0_mem_real[wr_addr_0] <= wr_data_0[3:0];
//                     bank0_mem_imag[wr_addr_0] <= wr_data_0[7:4];
//                 end
//             end

//             //port 1 write
//             if (wr_en_1) begin
//                 if (write_to_1) begin //if bank_sel is 1 write to bank1
//                     bank1_mem_real[wr_addr_1] <= wr_data_1[3:0];
//                     bank1_mem_imag[wr_addr_1] <= wr_data_1[7:4];
//                 end else begin //if bank_sel is 0 write to bank0
//                     bank0_mem_real[wr_addr_1] <= wr_data_1[3:0];
//                     bank0_mem_imag[wr_addr_1] <= wr_data_1[7:4];
//                 end
//             end
//         end
//     end

// endmodule