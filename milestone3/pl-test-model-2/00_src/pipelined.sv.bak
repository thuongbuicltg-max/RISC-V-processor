module pipelined (
    input  logic         i_clk     ,
    input  logic         i_reset   ,
    // Input peripherals
    input  logic [31:0]  i_io_sw   ,
    // Output peripherals
    output logic [31:0]  o_io_lcd  ,
    output logic [31:0]  o_io_ledr ,
    output logic [31:0]  o_io_ledg ,
    output logic [ 6:0]  o_io_hex0 ,
    output logic [ 6:0]  o_io_hex1 ,
    output logic [ 6:0]  o_io_hex2 ,
    output logic [ 6:0]  o_io_hex3 ,
    output logic [ 6:0]  o_io_hex4 ,
    output logic [ 6:0]  o_io_hex5 ,	
    output logic [ 6:0]  o_io_hex6 ,
    output logic [ 6:0]  o_io_hex7 ,
    // Debug
    output logic [31:0]  o_pc_debug,
    output logic         o_insn_vld,
    output logic         o_ctrl    ,
    output logic         o_mispred
);
// hazard
logic stall_ifid, flush_ifid, stall_idex, flush_idex;
logic [31:0] instr_wb;
logic [31:0] busy; 
logic [4:0] id_rs1, id_rs2, id_rd;
//assign id_rs1 = instr_id[19:15];
//assign id_rs2 = instr_id[24:20];
//assign id_rd  = instr_id[11:7];
// if stage 
logic [31:0] pc_four_if, pc_next_if, pc_if, instr_if;
logic  pc_en_if; 
//IF/ID STAGE
logic [31:0] pc_id, instr_id;
// ID stage 
 logic [31:0] rs1_data_id, rs2_data_id, imm_id;
// ID/EX STAGE
assign stall_idex = 1'b0; 
logic rd_wren, br_un, lsu_wren, opa_sel, opb_sel,mem_wren;
logic [1:0] wb_sel;
logic [3:0] alu_op, i_bmask;

logic [4:0] rd_wb; // nam o MEM/WB nhung su o day nen khai bao truoc 
logic rd_wren_wb;
logic [2:0] funct3_id;
logic o_ctrl_id, o_insn_vld_id, B_id, J_id, JALR_id;
logic use_rs1_id, use_rs2_id;
// EX stage
logic [31:0] instr_ex, pc_ex, rs1_data_ex, rs2_data_ex, imm_ex, alu_data_ex;
logic br_less_ex, br_equal_ex;
logic  o_insn_vld_ex, rd_wren_ex, br_un_ex, mem_wren_ex,  pc_sel_ex, opa_sel_ex, opb_sel_ex;
logic [1:0] wb_sel_ex;
logic [3:0] alu_op_ex;
logic [31:0] operand_a_ex, operand_b_ex;
// ko dung
logic [4:0]  rd_ex;
logic [2:0] funct3_ex;
logic B_ex, J_ex, JALR_ex, o_ctrl_ex;
logic o_take_branch;
// EX/MEM stage
logic stall_exmem, flush_exmem, o_mispred_mem;
logic [31:0] alu_result_mem, rs2_data_mem, instr_mem, pc_mem; 
assign stall_exmem = 1'b0; // NON_FORWARDING
assign flush_exmem = 1'b0;
logic [1:0] wb_sel_mem;
logic mem_wren_mem, rd_wren_mem;
logic o_insn_vld_mem;
// MEM STAGE
logic [31:0] pc_four_mem; 
logic [31:0] ld_data_mem;
// khong dung 
logic o_ctrl_mem;
logic [4:0] rd_mem;
logic [2:0] funct3_mem;
// MEM/WB STAGE
logic stall_memwb, flush_memwb, o_mispred_wb;
assign flush_memwb = 1'b0; // NON_FORWARDING
assign stall_memwb = 1'b0; // NON_FORWARDING
logic [31:0] pc_wb, alu_result_wb, ld_data_wb, pc_four_wb;
logic [1:0] wb_sel_wb;
// khong dung
logic o_insn_vld_wb, o_ctrl_wb, pc_en_n;
// WB STAGE
logic [31:0] wb_data;
///////////////////////////////////////////////////////////////////////////
// Hazard unit
///////////////////////////////////////////////////////////////////////////	
// hazard
  logic flushD, flushE;
  logic stall_raw;             // từ hazard_unit
  logic stall_eff;             // stall thực sự dùng cho PC/ID
  logic mispred_ex, instr_vld;
  assign flushD = pc_sel_ex;
  assign flushE = pc_sel_ex|stall_eff;
  assign mispred_ex = flushD;

hazard_unit u_hz(.instr_id(instr_id), .instr_ex(instr_ex), .instr_mem(instr_mem), .instr_wb(instr_wb), .stall(stall_raw));
	

// PC enable
//assign pc_en = ~pc_en_n;
assign pc_en_if = ~stall_eff;
assign stall_eff = stall_raw & ~flushD;  // flush thắng stall
//-------------------------------------------------------------------------------
// IF STAGE
//-------------------------------------------------------------------------------

	mux2 #(32) pc_select 
	 (
		.s0(pc_four_if),
		.s1(alu_data_ex),
		.sel(pc_sel_ex),
		.y(pc_next_if)
	 );

	PC pc_pl(
		.d(pc_next_if),
		.clk(i_clk),
		.en(pc_en_if),
		.rs(~i_reset),
		.q(pc_if)
);

	PCADD4 pc4_if(.b(pc_if), .sum(pc_four_if) );	 
	imem 	instmemory(.i_addr(pc_if), .o_rdata(instr_if));						
	 
//-------------------------------------------------------------------------------
// IF/ID STAGE
//-------------------------------------------------------------------------------

	if_id_reg if_id_u
	(
				.clk(i_clk),
				.reset(~i_reset),
				.stall_ifid(stall_eff),
				.flush_ifid(flushD),
				.pc_if(pc_if),
				.instr_if(instr_if),
				.pc_id(pc_id),
				.instr_id(instr_id)
	);
	
 

//-------------------------------------------------------------------------------
// ID STAGE
//-------------------------------------------------------------------------------


	regfile Regfile
	(
		.i_clk(i_clk),
		.i_reset(~i_reset),
		.i_wren(rd_wren_wb),
		.i_rs1_addr(instr_id[19:15]),
		.i_rs2_addr(instr_id[24:20]),
		.i_rd_addr(instr_wb[11:7]),
		.i_rd_data(wb_data),
		.o_rs1_data(rs1_data_id),
		.o_rs2_data(rs2_data_id)
	);

ImmGen immgen_sg(.instr(instr_id),.imm(imm_id));
	 
//-------------------------------------------------------------------------------
// ID/EX STAGE
//-------------------------------------------------------------------------------  
	id_ex_reg id_ex_u
	(
					.clk(i_clk),
					.reset(~i_reset),
					.stall_idex(stall_idex),
					.flush_idex(flushE),
					
					// input
					.pc_id(pc_id),
					.rs1_data_id(rs1_data_id),
					.rs2_data_id(rs2_data_id),
					.imm_id(imm_id),
					.instr_id(instr_id),
							
					// output	
					.pc_ex(pc_ex),
					.rs1_data_ex(rs1_data_ex),
					.rs2_data_ex(rs2_data_ex),
					.imm_ex(imm_ex),
					.instr_ex(instr_ex),

					
					.i_insn_vld_id(), // xu li rieng
					.i_ctrl_id(),		// xu ly rieng
					
					
					.funct3_id(), // bo 
					.B_id(), // bo
					.J_id(), // bo
					.JALR_id(), // bo
					// khong dung nua 
					.rd_id(), 				
					.alu_op_id(),
					.mem_wren_id(),
					.wb_sel_id(),
					.rd_wren_id(),
					.opa_sel_id(),   
					.opb_sel_id(),   
					.br_un_id(), 
					.o_insn_vld_ex(),
					.o_ctrl_ex(),
					.funct3_ex(),
					.B_ex(),
					.J_ex(),
					.JALR_ex(),
					
					.rd_ex(),				
					.alu_op_ex(),
					.mem_wren_ex(),
					.wb_sel_ex(),
					.rd_wren_ex(),
					.opa_sel_ex(),   
					.opb_sel_ex(),   
					.br_un_ex()    
	);
//-------------------------------------------------------------------------------
// EX STAGE
//-------------------------------------------------------------------------------

	CTU ControlUnit
	(
	.i_instr(instr_ex),
	.i_br_less(br_less_ex), 
	.i_br_equal(br_equal_ex), 
	.o_insn_vld(o_insn_vld_ex),
	.o_rd_wren(rd_wren_ex),
	.o_br_un(br_un_ex), 
	.o_mem_wren(mem_wren_ex),
	.o_pc_sel(pc_sel_ex), 
	.o_opa_sel(opa_sel_ex), 	
	.o_opb_sel(opb_sel_ex), 
	.o_wb_sel(wb_sel_ex),
	.o_alu_op(alu_op_ex),
	.o_mispred()
	
/* khong dung toi	
	.funct3_id(),
	.o_ctrl(), // xu ly rieng
	.B_id(),
	.J_id(),
	.JALR_id(),
	.use_rs1_id(),
	.use_rs2_id()*/
);

	 BRC branch_compare(
	.i_rs1_data(rs1_data_ex),
	.i_rs2_data(rs2_data_ex),
	.i_br_un(br_un_ex),
	.o_br_less(br_less_ex),
	.o_br_equal(br_equal_ex)
);
	 
//	assign operand_a = (opa_sel) ? pc : rs1_data;
	mux2 mux2_32_opa (.sel(opa_sel_ex), .s0(rs1_data_ex), .s1(pc_ex), .y(operand_a_ex));
//	assign operand_b = (opb_sel) ? imm : rs2_data;
	mux2 mux2_32_opb (.sel(opb_sel_ex), .s0(rs2_data_ex), .s1(imm_ex), .y(operand_b_ex));

		ALU alu 
	(
			.i_op_a(operand_a_ex), 
			.i_op_b(operand_b_ex),
			.i_alu_op(alu_op_ex),
			.o_alu_data(alu_data_ex)
	);
	
/*	branch_predict brc_predict_ex(
						.i_is_branch(B_ex),
						.i_is_jal(J_ex),
						.i_is_jalr(JALR_ex),
						.i_funct3(funct3_ex),
						.i_br_less(br_less),
						.i_br_equal(br_equal),
						.o_take_branch(o_take_branch)
	);*/
// assign pc_sel_ex = o_take_branch;

//-------------------------------------------------------------------------------
// EX/MEM STAGE
//-------------------------------------------------------------------------------

	ex_mem_reg ex_mem_u
	(
					.clk(i_clk),
					.reset(~i_reset),
					.stall_exmem(stall_exmem),
					.flush_exmem(flush_exmem),
					.i_insn_vld_ex(o_insn_vld_ex),
					.i_mispred_ex(mispred_ex),
					.alu_result_ex(alu_data_ex),
					.rs2_data_ex(rs2_data_ex),
					.instr_ex(instr_ex),
					.pc_ex(pc_ex),
					.wb_sel_ex(wb_sel_ex),
					.mem_wren_ex(mem_wren_ex),
					.rd_wren_ex(rd_wren_ex),
					
					// output 	
					.o_insn_vld_mem(o_insn_vld_mem),	
					.o_mispred_mem(o_mispred_mem),
					.alu_result_mem(alu_result_mem),
					.rs2_data_mem(rs2_data_mem),
					.instr_mem(instr_mem),
					.pc_mem(pc_mem),
					.wb_sel_mem(wb_sel_mem),
					.mem_wren_mem(mem_wren_mem),
					.rd_wren_mem(rd_wren_mem),
					
					// khong dung
					.i_ctrl_ex(o_ctrl_ex),
					.funct3_ex(funct3_ex), // tuan 2
					.rd_ex(rd_ex),
					// output
					.o_ctrl_mem(o_ctrl_mem),
					.funct3_mem(funct3_mem),
					.rd_mem(rd_mem)								
	);
	
//-------------------------------------------------------------------------------
// MEM STAGE
//-------------------------------------------------------------------------------
	PCADD4 pc4_mem(.b(pc_mem), .sum(pc_four_mem));	 
	
	LSU lsu
	(
		.i_clk(i_clk),
		.i_reset(~i_reset),
		.i_lsu_addr(alu_result_mem),
		.i_st_data(rs2_data_mem),	 // 
		.i_lsu_wren(mem_wren_mem),  //
		.i_io_sw(i_io_sw),
		.i_funct3(instr_mem[14:12]),	 // dang sai chua sua
		.o_ld_data(ld_data_mem),
		.o_io_ledr(o_io_ledr),
		.o_io_ledg(o_io_ledg),
		.o_io_lcd(o_io_lcd),
		.o_io_hex0(o_io_hex0),
		.o_io_hex1(o_io_hex1),
		.o_io_hex2(o_io_hex2),
		.o_io_hex3(o_io_hex3),
		.o_io_hex4(o_io_hex4),
		.o_io_hex5(o_io_hex5),
		.o_io_hex6(o_io_hex6),
		.o_io_hex7(o_io_hex7)
	);

//-------------------------------------------------------------------------------
// MEM/WB STAGE
//-------------------------------------------------------------------------------
	mem_wb_reg mem_wb_u
	(
					.clk(i_clk),
					.reset(~i_reset),
					.stall_memwb(stall_memwb),
					.flush_memwb(flush_memwb),
					.i_insn_vld_mem(o_insn_vld_mem),
					.i_mispred_mem(o_mispred_mem),
					.instr_mem(instr_mem),
					.pc_mem(pc_mem),
					.pc_four_mem(pc_four_mem),
					.alu_result_mem(alu_result_mem),
					.ld_data(ld_data_mem),
					.wb_sel_mem(wb_sel_mem),
					.rd_wren_mem(rd_wren_mem),
					//output 
					.o_insn_vld_wb(o_insn_vld_wb),
					.o_mispred_wb(o_mispred_wb),
					.instr_wb(instr_wb),
					.pc_wb(pc_wb),
					.alu_result_wb(alu_result_wb),
					.ld_data_wb(ld_data_wb),
					.pc_four_wb(pc_four_wb),
					.wb_sel_wb(wb_sel_wb),
					.rd_wren_wb(rd_wren_wb),
					// khong dung
					.i_ctrl_mem(o_ctrl_mem),
					.rd_mem(rd_mem),		
					// output 
					.o_ctrl_wb(o_ctrl_wb),
					.rd_wb(rd_wb)		
	);
//-------------------------------------------------------------------------------
// WB STAGE
//-------------------------------------------------------------------------------
	MUX4_32 mux4_32_wb_sel(
		.sel(wb_sel_wb),
		.d0(ld_data_wb),
		.d1(alu_result_wb),
		.d2(pc_four_wb),
		.d3(32'b0),
		.z(wb_data)
);
	assign o_pc_debug= pc_wb;
	assign o_insn_vld = o_insn_vld_wb;
//--------------------------------------------------
//  Control-transfer detector (JAL / JALR / BRANCH)
//--------------------------------------------------

assign o_ctrl = 
    (instr_wb[6:0] == 7'b1101111) || // JAL
    (instr_wb[6:0] == 7'b1100111) || // JALR
    (instr_wb[6:0] == 7'b1100011);   // BRANCH

	assign o_mispred = o_mispred_wb;
	

endmodule 

