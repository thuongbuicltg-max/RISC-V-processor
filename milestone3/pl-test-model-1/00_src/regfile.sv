/* module regfile (
		input logic 			i_reset, i_wren, i_clk, 
		input logic  [4:0] 	i_rs1_addr, i_rs2_addr, i_rd_addr, 
		input logic  [31:0] 	i_rd_data,
		output logic [31:0] 	o_rs1_data, o_rs2_data
);

logic [31:0] EN_mask; 
logic [31:0] EN;

DECODER532 dec5_32_reg(
		.en(i_wren),
		.a(i_rd_addr),
		.y(EN_mask)
);
assign EN = EN_mask & ~32'h0000_0001; // ko cho ghi vao x0
wire [31:0] r0 = 32'b0; 
logic [31:0] r [31:1]; 

	genvar i; 
	generate 
		for (i=1; i<32; i=i+1) begin: G_RF
			register u_register32_reg(.clk(i_clk), .rst(i_reset), .en(EN[i]), .d(i_rd_data), .q(r[i]));
		end 
	endgenerate 

// Mảng trung gian cho MUX đọc: bank[0]=r0, bank[1..31]=r[1..31]
logic [31:0] bank [31:0];
assign bank[0] = r0;
generate
  for (i = 1; i < 32; i = i + 1) begin : G_BANK
    assign bank[i] = r[i];
  end
endgenerate	
	
MUX321_32 muxrs1_reg(.d(bank), .s(i_rs1_addr), .y(o_rs1_data));
MUX321_32 muxrs2_reg(.d(bank), .s(i_rs2_addr), .y(o_rs2_data));

endmodule */
module regfile (
		input logic 			i_reset, i_wren, i_clk, 
		input logic  [4:0] 	i_rs1_addr, i_rs2_addr, i_rd_addr, 
		input logic  [31:0] 	i_rd_data,
		output logic [31:0] 	o_rs1_data, o_rs2_data
);

logic [31:0] r [31:0]; 
logic [31:0] EN;
DECODER532 dec5_32_reg(
		.en(i_wren),
		.a(i_rd_addr),
		.y(EN)
);

register u_reg0(.clk(i_clk), .rst(i_reset), .en(1'b0), .d(32'h0000_0000), .q(r[0])); // x0=0 

 
	generate 
	genvar i;
		for (i=1; i<32; i++) begin: G_RF
			register u_register32_reg(.clk(i_clk), .rst(i_reset), .en(EN[i]), .d(i_rd_data), .q(r[i]));
		end 
	endgenerate 

// doc rs1, rs2 RAW 
logic [31:0] rs1_raw, rs2_raw;	
	MUX321_32 u_rs1_raw( .d(r), .s(i_rs1_addr), .y(rs1_raw));
	MUX321_32 u_rs2_raw( .d(r), .s(i_rs2_addr), .y(rs2_raw));
	
  // WRITE-FIRST, READ-AFTER: bypass trong cùng chu kỳ
  always_comb begin
    o_rs1_data = rs1_raw;
    o_rs2_data = rs2_raw;

    // nếu đang ghi 1 thanh ghi khác x0
    if (i_wren && (i_rd_addr != 5'd0)) begin
      if (i_rd_addr == i_rs1_addr)
        o_rs1_data = i_rd_data;
      if (i_rd_addr == i_rs2_addr)
        o_rs2_data = i_rd_data;
    end
  end

endmodule

