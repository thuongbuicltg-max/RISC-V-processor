module PC_debug_reg
(
	input logic [31:0]pc,
	input logic i_clk,i_reset,
	output logic [31:0]o_pc_debug
);
	a_reg u(.clk(i_clk),.rs(i_reset),.en(1'b1),.d(pc),.q(o_pc_debug));
endmodule 

module FF(
  input  logic d, clk, en, rs,
  output logic q
);
  always_ff @(posedge clk or posedge rs) begin
    if (rs) q <= 1'b0;
    else if (en) q <= d;
  end
endmodule

module a_reg(
  input  logic [31:0] d,
  input  logic        clk, en, rs,
  output logic [31:0] q
);
  generate
    genvar i;
    for (i = 0; i < 32; i++) begin : FF
      FF u_ff (.d(d[i]), .clk(clk), .en(en), .rs(rs), .q(q[i]));
    end
  endgenerate
endmodule
module a_reg_p #(
    parameter WIDTH = 32,
    parameter CLR_VALUE = 32'h0   // ADDI x0,x0,0 (NOP)
)(
    input  logic              clk,
    input  logic              rs,   // async reset, active-high
    input  logic              clr,   // synchronous clear (flush)
    input  logic              en,    // enable (stall control)
    input  logic [WIDTH-1:0]  d,
    output logic [WIDTH-1:0]  q
);

always_ff @(posedge clk or posedge rs) begin
    if (rs)
        q <= '0;                // Reset toàn bộ
    else if (clr)
        q <= CLR_VALUE;         // Ghi NOP vào pipeline (flush)
    else if (en)
        q <= d;                 // Bình thường: ghi dữ liệu mới
    else
        q <= q;                 // Stall: giữ nguyên
end

endmodule






module ADD_SUB_SLT_SLTU (
  input  logic [31:0] a, b, 
  input  logic        is_sub, 
  output logic [31:0] result, 
  output logic        ovf, slt, sltu, cout
);
  logic        cin; 
  logic [31:0] b_xor, sum;
  logic        c_out;

  assign cin   = is_sub; 
  assign b_xor = b ^ {32{is_sub}};

  rca32 u_add (.a(a), .b(b_xor), .cin(cin), .sum(sum), .cout(c_out));

  // Overflow tách theo loại phép (CHỈNH)
  wire ovf_add =  ( a[31] &  b[31] & ~sum[31]) | (~a[31] & ~b[31] &  sum[31]);
  wire ovf_sub =  ( a[31] & ~b[31] & ~sum[31]) | (~a[31] &  b[31] &  sum[31]);
  assign ovf = is_sub ? ovf_sub : ovf_add;

  // stlu = ~cout; slt = sum[31] ^ ovf (hợp lệ khi is_sub=1)
  MUX2_1 mux21_brc1(.d0(1'b0), .d1(~c_out), .sel1(is_sub), .z(sltu)); 
  MUX2_1 mux21_brc2(.d0(1'b0), .d1(sum[31]^ovf), .sel1(is_sub), .z(slt));

  assign cout   = c_out; 
  assign result = sum;  
endmodule 

//-------------------------------------------------------------------------------------
module PC( 			// PC is a resistor 32 bit 
  input  logic [31:0] d,
  input  logic       clk, en, rs,
  output logic [31:0] q
);
  generate
    genvar i;
    for (i = 0; i < 32; i++) begin : FF
      D_FF_RS1bit d_ff_1bit_pc( .d(d[i]), .clk(clk), .en(en), .rs(rs), .q(q[i]) );
    end
  endgenerate
endmodule
//-------------------------------------------------------------------------------------

// bo chi cong 4
module PCADD4(
	input logic [31:0]  b,
	output logic [31:0] sum
);
logic cout; 
logic [31:0]a; 
logic [31:0] s; 
logic [32:0] c;
assign c[0] = 1'b0;
assign a[31:0] = 32'b00000000_00000000_00000000_00000100; 

genvar i; 
generate 
	for (i = 0; i < 32; i++) begin : g_fa 
		FA_ctc U_FA (.x(a[i]), .y(b[i]), .cin(c[i]), .s(s[i]), .cout(c[i+1]));
	end 
endgenerate 

assign sum = s; 
assign cout = c[32]; 

endmodule 

module FA_ctc(
	input logic x, y, cin,
	output logic s, cout
);

assign s = x^y^cin;  
assign cout = (x&y)|(x&cin)|(y&cin);
endmodule 

// bo chi cong cua ALU
module rca32(
	input logic [31:0] a, b,
	input logic 		 cin,
	output logic [31:0] sum, 
	output logic 		  cout
);

logic [31:0] s; 
logic [32:0] c;
assign c[0] = cin;

genvar i; 
generate 
	for (i = 0; i < 32; i++) begin : g_fa 
		FA_ctc U_FA (.x(a[i]), .y(b[i]), .cin(c[i]), .s(s[i]), .cout(c[i+1]));
	end 
endgenerate 

assign sum = s; 
assign cout = c[32];

endmodule 
//---------------------------------------------------------------------------------------

// MUX
module MUX321_32 (
    input  logic [31:0] d [31:0], // 32 ngõ vào, mỗi ngõ 32-bit
    input  logic [4:0]  s,        // 5-bit select
    output logic [31:0] y
);
    // Tầng 0: 32 -> 16
    logic [31:0] L0 [15:0];
    genvar i;
    generate
        for (i=0; i<16; i=i+1) begin: STAGE0
		  // s0 = 0 -> L0 = chan, s0 = 1 -> L0 = le
            mux2 #(32) u_1_reg( .s0(d[2*i]), .s1(d[2*i+1]), .sel(s[0]), .y(L0[i]));
        end
    endgenerate

    // Tầng 1: 16 -> 8
    logic [31:0] L1 [7:0];
    generate
        for (i=0; i<8; i=i+1) begin: STAGE1
				//mux2_32 m  (.s(s[1]), .a(L0[2*i]), .b(L0[2*i+1]), .y(L1[i]));
				mux2 #(32) u_2_reg(.s0(L0[2*i]), .s1(L0[2*i+1]), .sel(s[1]), .y(L1[i]));
        end
    endgenerate

    // Tầng 2: 8 -> 4
    logic [31:0] L2 [3:0];
    generate
        for (i=0; i<4; i=i+1) begin: STAGE2
            // mux2_32 m (.s(s[2]), .a(L1[2*i]), .b(L1[2*i+1]), .y(L2[i]));
				mux2 #(32) u_3_reg(.s0(L1[2*i]), .s1(L1[2*i+1]), .sel(s[2]), .y(L2[i]));
        end
    endgenerate

    // Tầng 3: 4 -> 2
    logic [31:0] L3 [1:0];
    generate
        for (i=0; i<2; i=i+1) begin: STAGE3
            // mux2_32 m (.s(s[3]), .a(L2[2*i]), .b(L2[2*i+1]), .y(L3[i]));
				mux2 #(32) u_4_reg(.s0(L2[2*i]), .s1(L2[2*i+1]), .sel(s[3]), .y(L3[i]));
        end
    endgenerate

    // Tầng 4: 2 -> 1 (kết quả cuối)
    // mux2_32 m_final (.s(s[4]), .a(L3[0]), .b(L3[1]), .y(y));
	 mux2 #(32) u_5_reg(.s0(L3[0]), .s1(L3[1]), .sel(s[4]), .y(y));
endmodule

module MUX8_32 (
    input  logic [31:0] d0, d1, d2, d3, d4, d5, d6, d7,  // 8 ngõ vào, mỗi ngõ 32-bit
    input  logic [2:0]  sel,                             // chọn 1 trong 8
    output logic [31:0] z                                // ngõ ra 32-bit
);

    logic [31:0] y0, y1, y2, y3, y4, y5;  // tín hiệu trung gian giữa các tầng

    // Tầng 1: 8 → 4
    genvar i;
    generate
        for (i = 0; i < 32; i++) begin : MUX1
            MUX2_1 m0 (.d0(d0[i]), .d1(d1[i]), .sel1(sel[0]), .z(y0[i]));
            MUX2_1 m1 (.d0(d2[i]), .d1(d3[i]), .sel1(sel[0]), .z(y1[i]));
            MUX2_1 m2 (.d0(d4[i]), .d1(d5[i]), .sel1(sel[0]), .z(y2[i]));
            MUX2_1 m3 (.d0(d6[i]), .d1(d7[i]), .sel1(sel[0]), .z(y3[i]));
        end
    endgenerate

    // Tầng 2: 4 → 2
    logic [31:0] y4_1, y5_1;
    generate
        for (i = 0; i < 32; i++) begin : MUX2
            MUX2_1 m4 (.d0(y0[i]), .d1(y1[i]), .sel1(sel[1]), .z(y4_1[i]));
            MUX2_1 m5 (.d0(y2[i]), .d1(y3[i]), .sel1(sel[1]), .z(y5_1[i]));
        end
    endgenerate

    // Tầng 3: 2 → 1 (đầu ra cuối cùng)
    generate
        for (i = 0; i < 32; i++) begin : MUX3
            MUX2_1 m6 (.d0(y4_1[i]), .d1(y5_1[i]), .sel1(sel[2]), .z(z[i]));
        end
    endgenerate

endmodule	
	

module MUX4_32 (
  input  logic [1:0]  sel,          // 00->d0, 01->d1, 10->d2, 11->d3
  input  logic [31:0] d0, d1, d2, d3,
  output logic [31:0] z
);
  logic [31:0] y0, y1;

  // tầng 1: chọn từng cặp theo sel[0]
  mux2 m0 (.sel(sel[0]), .s0(d0), .s1(d1), .y(y0));
  mux2 m1 (.sel(sel[0]), .s0(d2), .s1(d3), .y(y1));

  // tầng 2: chọn giữa hai nhánh theo sel[1]
  mux2 m2 (.sel(sel[1]), .s0(y0), .s1(y1), .y(z)); 
endmodule



module MUX2_1 (
		input logic d0, d1, sel1, 
		output logic z
	);
	assign z = (d0&~sel1)|(d1&sel1); 
endmodule 


module mux2 #(parameter WIDTH=32)( // mux2_1 32bit 
  input  logic [WIDTH-1:0] s0, s1,
  input  logic             sel,
  output logic [WIDTH-1:0] y
);
  genvar i;
  generate
    for (i=0;i<WIDTH;i++) begin : g
      assign y[i] = (~sel & s0[i]) | (sel & s1[i]);
    end
  endgenerate
endmodule 


//-----------------------------------------------------------------------------------------------------

//D_FF-resistor 

module register ( // thanh ghi 32 bit 
    input  logic        clk,   // clock
    input  logic        rst,   // reset bất đồng bộ, tích cực mức '1'
    input  logic        en,    // enable ghi toàn word
    input  logic [31:0] d,     // dữ liệu vào 32-bit
    output logic [31:0] q      // dữ liệu ra 32-bit
);
    // Tạo 32 DFF đơn-bit, cùng clk/rst/en; mỗi DFF lưu một bit của word
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : G_DFF32
            D_FF_RS1bit u_bit (
                .clk (clk),
                .rs (rst),
                .en  (en),
                .d   (d[i]),
                .q   (q[i])
            );
        end
    endgenerate
endmodule 

module D_FF_RS1bit (
  input  logic d, clk, en, rs,
  output logic q
);
  always_ff @(posedge clk or posedge rs) begin
    if (rs)            
        q <= 1'b0;
    else if (en)
        q <= d;
end
endmodule 

//-----------------------------------------------------------------------------------------------------------
// DECODER

module DECODER532 (
    input  logic        en,     // enable mức 1
    input  logic [4:0]  a,      // a[4:2] phần cao, a[1:0] phần thấp
    output logic [31:0] y       // one-hot
);
    // Giải mã phần cao (3->8) và thấp (2->4)
    logic [7:0] d_hi;
    logic [3:0] d_lo;

    dec3to8 D_HI (.en(1'b1), .a(a[4:2]), .y(d_hi));
    dec2to4 D_LO (.en(1'b1), .a(a[1:0]), .y(d_lo));

    // Kết hợp ma trận 8x4: y[row*4 + col] = en & d_hi[row] & d_lo[col]
    // Viết tay 32 dòng, không dùng toán tử số học/generate.
    // Hàng 0 (d_hi[0]): y[0..3]
    assign y[0]  = en & d_hi[0] & d_lo[0];
    assign y[1]  = en & d_hi[0] & d_lo[1];
    assign y[2]  = en & d_hi[0] & d_lo[2];
    assign y[3]  = en & d_hi[0] & d_lo[3];

    // Hàng 1 (d_hi[1]): y[4..7]
    assign y[4]  = en & d_hi[1] & d_lo[0];
    assign y[5]  = en & d_hi[1] & d_lo[1];
    assign y[6]  = en & d_hi[1] & d_lo[2];
    assign y[7]  = en & d_hi[1] & d_lo[3];

    // Hàng 2 (d_hi[2]): y[8..11]
    assign y[8]  = en & d_hi[2] & d_lo[0];
    assign y[9]  = en & d_hi[2] & d_lo[1];
    assign y[10] = en & d_hi[2] & d_lo[2];
    assign y[11] = en & d_hi[2] & d_lo[3];

    // Hàng 3 (d_hi[3]): y[12..15]
    assign y[12] = en & d_hi[3] & d_lo[0];
    assign y[13] = en & d_hi[3] & d_lo[1];
    assign y[14] = en & d_hi[3] & d_lo[2];
    assign y[15] = en & d_hi[3] & d_lo[3];

    // Hàng 4 (d_hi[4]): y[16..19]
    assign y[16] = en & d_hi[4] & d_lo[0];
    assign y[17] = en & d_hi[4] & d_lo[1];
    assign y[18] = en & d_hi[4] & d_lo[2];
    assign y[19] = en & d_hi[4] & d_lo[3];

    // Hàng 5 (d_hi[5]): y[20..23]
    assign y[20] = en & d_hi[5] & d_lo[0];
    assign y[21] = en & d_hi[5] & d_lo[1];
    assign y[22] = en & d_hi[5] & d_lo[2];
    assign y[23] = en & d_hi[5] & d_lo[3];

    // Hàng 6 (d_hi[6]): y[24..27]
    assign y[24] = en & d_hi[6] & d_lo[0];
    assign y[25] = en & d_hi[6] & d_lo[1];
    assign y[26] = en & d_hi[6] & d_lo[2];
    assign y[27] = en & d_hi[6] & d_lo[3];

    // Hàng 7 (d_hi[7]): y[28..31]
    assign y[28] = en & d_hi[7] & d_lo[0];
    assign y[29] = en & d_hi[7] & d_lo[1];
    assign y[30] = en & d_hi[7] & d_lo[2];
    assign y[31] = en & d_hi[7] & d_lo[3];
endmodule



module dec2to4 (
    input  logic       en,      // enable mức 1
    input  logic [1:0] a,       // a[1]: MSB, a[0]: LSB
    output logic [3:0] y        // one-hot
);
    // Phủ định các bit địa chỉ
    wire n1 = ~a[1];
    wire n0 = ~a[0];

    // Bảng chân trị (one-hot khi en=1):
    // a==00 -> y=0001
    // a==01 -> y=0010
    // a==10 -> y=0100
    // a==11 -> y=1000
    assign y[0] = en &  n1 &  n0;  // 00
    assign y[1] = en &  n1 & ~n0;  // 01
    assign y[2] = en & ~n1 &  n0;  // 10
    assign y[3] = en & ~n1 & ~n0;  // 11
endmodule


module dec3to8 (
    input  logic       en,       // enable mức 1
    input  logic [2:0] a,        // a[2]: MSB ... a[0]: LSB
    output logic [7:0] y         // one-hot
);
    wire n2 = ~a[2];
    wire n1 = ~a[1];
    wire n0 = ~a[0];

    // a==000 -> y=0000_0001
    // a==001 -> y=0000_0010
    // ...
    // a==111 -> y=1000_0000
    assign y[0] = en &  n2 &  n1 &  n0;  // 000
    assign y[1] = en &  n2 &  n1 & ~n0;  // 001
    assign y[2] = en &  n2 & ~n1 &  n0;  // 010
    assign y[3] = en &  n2 & ~n1 & ~n0;  // 011
    assign y[4] = en & ~n2 &  n1 &  n0;  // 100
    assign y[5] = en & ~n2 &  n1 & ~n0;  // 101
    assign y[6] = en & ~n2 & ~n1 &  n0;  // 110
    assign y[7] = en & ~n2 & ~n1 & ~n0;  // 111
endmodule


module decoder4_16 (
  input  logic [3:0] a,
  input  logic       en,
  output logic [15:0] y
);
  // đặt bí danh cho dễ đọc
  wire a3 = a[3];
  wire a2 = a[2];
  wire a1 = a[1];
  wire a0 = a[0];

  // Mỗi ngõ ra là một minterm của (a3 a2 a1 a0), kèm en
  assign y[0]  = en & ~a3 & ~a2 & ~a1 & ~a0;
  assign y[1]  = en & ~a3 & ~a2 & ~a1 &  a0;
  assign y[2]  = en & ~a3 & ~a2 &  a1 & ~a0;
  assign y[3]  = en & ~a3 & ~a2 &  a1 &  a0;
  assign y[4]  = en & ~a3 &  a2 & ~a1 & ~a0;
  assign y[5]  = en & ~a3 &  a2 & ~a1 &  a0;
  assign y[6]  = en & ~a3 &  a2 &  a1 & ~a0;
  assign y[7]  = en & ~a3 &  a2 &  a1 &  a0;
  assign y[8]  = en &  a3 & ~a2 & ~a1 & ~a0;
  assign y[9]  = en &  a3 & ~a2 & ~a1 &  a0;
  assign y[10] = en &  a3 & ~a2 &  a1 & ~a0;
  assign y[11] = en &  a3 & ~a2 &  a1 &  a0;
  assign y[12] = en &  a3 &  a2 & ~a1 & ~a0;
  assign y[13] = en &  a3 &  a2 & ~a1 &  a0;
  assign y[14] = en &  a3 &  a2 &  a1 & ~a0;
  assign y[15] = en &  a3 &  a2 &  a1 &  a0;
endmodule 