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


// tb.vb

 1 `ifndef __GUARD_TB_SV__
  2 `define __GUARD_TB_SV__
  3 
  4 // +--- Testbench Defines ---+
  5 `include "tb_defines.svh"
  6 
  7 `resetall
  8 `timescale 1ns/1ns
  9 
 10 // +--- UVM ---+
 11 `include "uvm_macros.svh"
 12 
 13 `ifdef VCS_SIMULATOR
 14   `include "uvm_pkg.sv"
 15 `endif // VCS_SIMULATOR
 16 

`endif // VCS_SIMULATOR
 16 
 17 // +--- Synopsys AMBA VIP Package ---+
 18 `ifdef SNPS_VIP_EN
 19   `ifdef XCELIUM_SIMULATOR
 20     `define UVM_PKG_SV // NOTE: Work-around for *E,DLCSMD
 21   `endif // XCELIUM_SIMULATOR
 22 `endif // SNPS_VIP_EN
 23 
 24 `ifdef SNPS_AXI_VIP_EN
 25   `timescale 1 ns/1 ps
 26   `include "svt_axi.uvm.pkg"
 27   `include "svt_axi_if.svi"
 28 `endif // SNPS_AXI_VIP_EN
 29 
 30 `ifdef SNPS_APB_VIP_EN
 31   `timescale 1 ns/1 ps
 32   `include "svt_apb.uvm.pkg"
 33   `include "svt_apb_if.svi"
 34 `endif // SNPS_APB_VIP_EN
 35 
 36 `include "tbr/SV/interfaces/all_if.sv"
 37 
 38 `include "tbr/tb_pkg.svh"
 39 
 40 module tb;
 41 
 42   import uvm_pkg::*;
 43   import tb_pkg::*;
 44   import all_if_pkg::*;
 45 `ifdef SNPS_AXI_VIP_EN
 46   import svt_axi_uvm_pkg::*;
 47 `endif // SNPS_AXI_VIP_EN
 48 `ifdef SNPS_APB_VIP_EN
 49   import svt_apb_uvm_pkg::*;
 50 `endif // SNPS_APB_VIP_EN
 51 
 52   // +--- Parameters ---+
 53 
 54   // +--- Top Interface ---+
 55   all_if all_if();
 56 
 57   // +--- DUT Instantiation & Connection ---+
 58   `include "tbr/tb_dut_connect.sv"
 59 
 60   // +--- VIP Connection ---+
 61 `ifdef SNPS_AXI_VIP_EN
 62   // Global
 63   assign all_if.axi_master_if.master_if[0].aclk    = 1'b0;
 64   assign all_if.axi_master_if.master_if[0].aresetn = 1'b0;
 65 
 66   // VIP Master - DUT Slave
 67   // AW CH
 68   always @(*) all_if.axi_master_if.master_if[0].awready = AWReady;
 69 `ifdef TB_AXI_MST_ID_WIDTH_0
 70 `else
 71   assign AWId    = all_if.axi_master_if.master_if[0].awid;
 72 `endif // TB_AXI_MST_ID_WIDTH_0
 73   assign AWAddr  = all_if.axi_master_if.master_if[0].awaddr;
 74   assign AWValid = all_if.axi_master_if.master_if[0].awvalid;
 75   assign AWLen   = all_if.axi_master_if.master_if[0].awlen;
 76   assign AWSize  = all_if.axi_master_if.master_if[0].awsize;
 77   assign AWBurst = all_if.axi_master_if.master_if[0].awburst;
 78   assign AWCache = all_if.axi_master_if.master_if[0].awcache;
 79   assign AWProt  = all_if.axi_master_if.master_if[0].awprot;
 80   assign AWLock  = all_if.axi_master_if.master_if[0].awlock;
 81 
 82   // W CH
 83   always @(*) all_if.axi_master_if.master_if[0].wready = WReady;
 84 
 85 `ifndef TB_AXI_MST_AXI4
 86 `ifndef TB_AXI_MST_ID_WIDTH_0
 87   assign WId    = all_if.axi_master_if.master_if[0].wid;
 88 `endif // TB_AXI_MST_ID_WIDTH_0
 89 `endif // TB_AXI_MST_AXI4
 90   assign WData  = all_if.axi_master_if.master_if[0].wdata;
 91   assign WStrb  = all_if.axi_master_if.master_if[0].wstrb;
 92   assign WValid = all_if.axi_master_if.master_if[0].wvalid;
 93 
 94   // B CH
 95   assign BReady = all_if.axi_master_if.master_if[0].bready;
 96 
 97   always @(*) all_if.axi_master_if.master_if[0].bid    = BId;
 98   always @(*) all_if.axi_master_if.master_if[0].bvalid = BValid;
 99 
100   // AR CH
101 `ifndef TB_AXI_MST_ID_WIDTH_0
102   assign ARId    = all_if.axi_master_if.master_if[0].arid;
103 `endif // TB_AXI_MST_ID_WIDTH_0
104   assign ARAddr  = all_if.axi_master_if.master_if[0].araddr;
105   assign ARLen   = all_if.axi_master_if.master_if[0].arlen;
106   assign ARSize  = all_if.axi_master_if.master_if[0].arsize;
107   assign ARBurst = all_if.axi_master_if.master_if[0].arburst;
108   assign ARCache = all_if.axi_master_if.master_if[0].arcache;
109   assign ARProt  = all_if.axi_master_if.master_if[0].arprot;
110   assign ARLock  = all_if.axi_master_if.master_if[0].arlock;
111   assign ARValid = all_if.axi_master_if.master_if[0].arvalid;
112 
113   always @(*) all_if.axi_master_if.master_if[0].arready = ARReady;
114 
115   // R CH
116   assign RReady = all_if.axi_master_if.master_if[0].rready;
117 
118   always @(*) all_if.axi_master_if.master_if[0].rdata  = RData;
119 `ifndef TB_AXI_MST_ID_WIDTH_0
120   always @(*) all_if.axi_master_if.master_if[0].rid    = RId;
121 `endif // TB_AXI_MST_ID_WIDTH_0
122   always @(*) all_if.axi_master_if.master_if[0].rresp  = RResp;
123   always @(*) all_if.axi_master_if.master_if[0].rlast  = RLast;
124 `endif // SNPS_AXI_VIP_EN
125 
126 `ifdef SNPS_APB_VIP_EN
127   always @(*) all_if.apb_slave_if.paddr   = PAddr;
128   always @(*) all_if.apb_slave_if.pprot   = PProt;
129   always @(*) all_if.apb_slave_if.pwrite  = PWrite;
130   always @(*) all_if.apb_slave_if.pstrb   = PStrb;
131   always @(*) all_if.apb_slave_if.pwdata  = PWData;
132   always @(*) all_if.apb_slave_if.penable = PEnable;
133   always @(*) all_if.apb_slave_if.psel    = {{31{1'b0}}, PSn_PSel[0]};
134 
135   assign PSn_PRData[0]  = all_if.apb_slave_if.slave_if[0].prdata;
136   assign PSn_PSlverr[0] = all_if.apb_slave_if.slave_if[0].pslverr;
137   assign PSn_PReady[0]  = all_if.apb_slave_if.slave_if[0].pready;
138 
139   generate
140     for (genvar i = 1; i < `TB_APB_NUM_SLAVES; i += 1) begin: APB_SLV_TIE
141       assign PSn_PRData[i]  = {`TB_APB_SLV_DATA_WIDTH{1'b0}};
142       assign PSn_PSlverr[i] = 1'b0;
143       assign PSn_PReady[i]  = 1'b0;
144     end: APB_SLV_TIE
145   endgenerate
146 `endif // SNPS_APB_VIP_EN
147 
148   // +--- Simulation Time Monitor ---+
149   initial begin
150     realtime sim_time;
151     realtime sim_timeout_ms;
152 
153     $timeformat(-9, 2, " ns");
154     sim_time = 0;
155 
156     if (!($value$plusargs("sim_timeout_ms=%f", sim_timeout_ms))) begin
157       sim_timeout_ms = 5ms;
158     end
159     else begin
160       sim_timeout_ms = sim_timeout_ms * 1ms;
161     end
                                                                             

