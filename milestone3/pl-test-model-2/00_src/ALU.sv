	module ALU(
	input logic [31:0] i_op_a, i_op_b,
	input logic [3:0]		 i_alu_op,
	output logic [31:0] o_alu_data 
);
logic [15:0] dec;
logic [31:0]addsub_res;
logic op_add, is_sub, op_sub, op_slt, op_sltu;

// dec = (16'h0001 << i_alu_op)
	decoder4_16 dec_ALU(
		.a (i_alu_op),
		.en(1'b1),
		.y (dec)
);

// tinh hieu chon cho tung phep 
	logic  op_xor, op_or, op_and, op_sll, op_srl, op_sra, op_lui; // op_sub, op_slt, op_sltu
	assign op_add  = dec[0];  	// ADD  = 4'b0000
	assign op_sub  = dec[1];  	// SUB  = 4'b0001
	assign op_slt  = dec[4];	// SLT  = 4'b0100 
	assign op_sltu = dec[6];	// SLTU = 4'b0110
	assign op_xor  = dec[8];	// XOR  = 4'b1000
	assign op_or   = dec[12];	// OR   = 4'b1100
	assign op_and  = dec[14];	// AND  = 4'b1110
	assign op_sll  = dec[2];	// SLL  = 4'b0010
	assign op_srl  = dec[10];	// SRL  = 4'b1010
	assign op_sra  = dec[11];  // SRA  = 4'b1011
	assign op_lui  = dec[3];	// LUI  = 4'b0011
// ADD, SUB, SLT, SLTU 
//	logic [31:0] addsub_res;
   logic        cout, ovf, slt_s, sltu_s;
	assign is_sub = op_sub | op_slt | op_sltu;

  ADD_SUB_STL_STLU  add_sub_stl_stlu_alu(
    .a      (i_op_a),
    .b      (i_op_b),
    .is_sub (is_sub),
    .result (addsub_res),
    .cout   (cout),
    .ovf    (ovf),
    .slt    (slt_s),     // hợp lệ khi is_sub=1
    .sltu   (sltu_s)     // hợp lệ khi is_sub=1
  );

// SLL, SRL, SRA 

// BARREL SHIFTER 


  logic [31:0] sh_res;
  SLL_SRL_SRA  sll_srl_sra_alu(
    .a         (i_op_a),
    .shamt     (i_op_b[4:0]),
    .is_sll		(op_sll),
    .is_srl    (op_srl),
	 .is_sra 	(op_sra),
    .y         (sh_res)
  );
  
// KET QUA TUNG NHOM MASK-OR 
	logic [31:0] res_addsub, res_slt, res_sltu, res_xor, res_or, res_and, res_shift;

// add/sub dung chung addsub_res
	logic any_addsub;
	assign any_addsub = op_add | op_sub;
   assign res_addsub = {32{any_addsub}} & addsub_res;
/*	logic [31:0]any_addsub_out;
// mo rong dau:
// choose = 1 mo rong fill 
// choose = 0 mo rong 0..0fill[0]
	fill_expansion #(32) FE1_alu(.fill(any_addsub), .fill_out(any_addsub_out));  // nam ben regfile
	assign res_addsub = any_addsub_out & addsub_res; */

// // SLT/SLTU: mở rộng 1 bit thành 32 bit
	assign res_slt   = {32{op_slt }} & {31'b0, slt_s };
	assign res_sltu  = {32{op_sltu}} & {31'b0, sltu_s};

	assign res_xor   = {32{op_xor}} & (i_op_a ^ i_op_b);
	assign res_or    = {32{op_or }} & (i_op_a | i_op_b);
	assign res_and   = {32{op_and}} & (i_op_a & i_op_b);

// Shift (SLL/SRL/SRA dùng chung sh_res)
	logic any_shift;
	assign any_shift = op_sll | op_srl | op_sra;
   assign res_shift = {32{any_shift}} & sh_res;

// LUI U-Format
	logic [31:0]lui_data;	
	mux2 mux_lui (.sel(op_lui), .s0(32'b0), .s1(i_op_b), .y(lui_data)); 
	
// Gộp kết quả cuối
	assign o_alu_data = res_addsub | res_slt | res_sltu | res_xor | res_or | res_and | res_shift | lui_data;
endmodule 

// chuong trinh con 

 module ADD_SUB_STL_STLU (
	input logic [31:0] a, b, 
	input logic 		is_sub, 
	output [31:0] result, 
	output logic 		ovf, slt, sltu, cout
);

logic cin; 
logic [31:0] b_xor, sum;
logic sum_xor; 
logic c_out;

assign cin = is_sub; 
assign b_xor = b^{32{is_sub}};

rca32  chicong_alu(.a(a), .b(b_xor), .cin(cin), .sum(sum), .cout(c_out));
// ovf bit tran khi 
// duong + duong = am   
// am + am = duong
assign ovf = (~a[31]&~b_xor[31]&sum[31])|(a[31]&b_xor[31]&~sum[31]);

// so sanh = phep tru,, is_sub = 1 
// stlu = ~cout
MUX2_1 mux21_alu1(.d0(1'b0), .d1(~c_out), .sel1(is_sub), .z(sltu)); 
// stl = sum[31] xor ovf so sanh co dau ke ca bi tran
assign sum_xor = sum[31]^ovf; 
MUX2_1 mux21_alu2(.d0(1'b0), .d1(sum_xor), .sel1(is_sub), .z(slt));

assign cout = c_out; 
assign result = sum;  

endmodule  


// SLL SRL SRA 
module SLL_SRL_SRA(
	input logic [31:0]a,
	input logic [4:0]shamt, 
	input logic is_sll, is_srl, is_sra, 
	output logic [31:0]y
);
// assign res_addsub = {32{any_addsub}} & addsub_res;
	wire fill = is_sra&a[31]; // bit fill cho dich so hoc 
	wire [31:0] fill_out;
//	fill_expansion #(32) FE_sll_srl_sra_alu(.fill(fill), .fill_out(fill_out)); 
	assign fill_out = {32{fill}};
// stage 1 
	wire [31:0] left1 = {a[30:0], 1'b0}; 
	wire [31:0] srl1 = {1'b0, a[31:1]}; 
	wire [31:0] sra1 = {fill_out[0], a[31:1]}; 
	wire [31:0] right1;
	mux2 #(32) in1_alu(.s0(srl1), .s1(sra1), .sel(is_sra), .y(right1));
	wire [31:0] in1; 
	mux2 #(32) s1_alu(.s0(left1), .s1(right1), .sel(is_srl|is_sra), .y(in1));
	wire [31:0] s1; 
	mux2 #(32) o1_alu(.s0(a), .s1(in1), .sel(shamt[0]), .y(s1));
	
// stage 2
	wire [31:0] left2 = {s1[29:0], 2'b00}; 
	wire [31:0] srl2 = {2'b00, s1[31:2]}; 
	wire [31:0] sra2 = {fill_out[1:0], s1[31:2]}; 
	wire [31:0] right2;
	mux2 #(32) in2_alu(.s0(srl2), .s1(sra2), .sel(is_sra), .y(right2));
	wire [31:0] in2; 
	mux2 #(32) s2_alu(.s0(left2), .s1(right2), .sel(is_srl|is_sra), .y(in2));
	wire [31:0] s2; 
	mux2 #(32) o2_alu(.s0(s1), .s1(in2), .sel(shamt[1]), .y(s2));
	
// stage 4 
	wire [31:0] left4 = {s2[27:0], 4'h0}; 
	wire [31:0] srl4 = {4'h0, s2[31:4]}; 
	wire [31:0] sra4 = {fill_out[3:0], s2[31:4]}; 
	wire [31:0] right4;
	mux2 #(32) in4_alu(.s0(srl4), .s1(sra4), .sel(is_sra), .y(right4));
	wire [31:0] in4; 
	mux2 #(32) s4_alu(.s0(left4), .s1(right4), .sel(is_srl|is_sra), .y(in4));
	wire [31:0] s4; 
	mux2 #(32) o4_alu(.s0(s2), .s1(in4), .sel(shamt[2]), .y(s4));

// stage 8 
	wire [31:0] left8 = {s4[23:0], 8'h00}; 
	wire [31:0] srl8 = {8'h00, s4[31:8]}; 
	wire [31:0] sra8 = {fill_out[7:0], s4[31:8]}; 
	wire [31:0] right8;
	mux2 #(32) in8_alu(.s0(srl8), .s1(sra8), .sel(is_sra), .y(right8));
	wire [31:0] in8; 
	mux2 #(32) s8_alu(.s0(left8), .s1(right8), .sel(is_srl|is_sra), .y(in8));
	wire [31:0] s8; 
	mux2 #(32) o8_alu(.s0(s4), .s1(in8), .sel(shamt[3]), .y(s8));

// stage 16 
	wire [31:0] left16 = {s8[15:0], 16'h0000}; 
	wire [31:0] srl16 = {16'h0000, s8[31:16]}; 
	wire [31:0] sra16 = {fill_out[15:0], s8[31:16]}; 
	wire [31:0] right16;
// mux 2 sang 1 32 bit tu regfile
	mux2 #(32) in16_alu(.s0(srl16), .s1(sra16), .sel(is_sra), .y(right16));
	wire [31:0] in16; 
	mux2 #(32) s16_alu(.s0(left16), .s1(right16), .sel(is_srl|is_sra), .y(in16));
	wire [31:0] s16; 
	mux2 #(32) o16_alu(.s0(s8), .s1(in16), .sel(shamt[4]), .y(s16));
	
// kiem tra cac bit is_sll, is_sra, is_srl co bat hay khong
	mux2 #(32) KT_alu(.s0(a), .s1(s16), .sel(is_sll|is_sra|is_srl), .y(y));
endmodule 
