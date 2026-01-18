// Thanh ghi pipeline tổng quát, có stall & flush
module pipe_reg #(
    parameter WIDTH = 32
)(
    input                  clk,
    input                  reset,   // reset toàn pipeline
    input                  stall,   // =1: giữ giá trị cũ
    input                  flush,   // =1: ghi 0 (bubble)
    input      [WIDTH-1:0] d_in,
    output reg [WIDTH-1:0] d_out
);

    always @(posedge clk) begin
        if (reset || flush) begin
            d_out <= {WIDTH{1'b0}};
        end else if (!stall) begin // stall =0 la chay
            d_out <= d_in;
        end
        // nếu stall = 1 -> giữ nguyên d_out
    end

endmodule 

module if_id_reg (
    input         clk,
    input         reset,
    input         stall_ifid,
    input         flush_ifid,   // có thể dùng reset

    input  [31:0] pc_if,
    input  [31:0] instr_if,

    output [31:0] pc_id,
    output [31:0] instr_id
);

    pipe_reg #(.WIDTH(32)) u_pc_ifid (
        .clk   (clk),
        .reset (reset),
        .stall (stall_ifid),
        .flush (flush_ifid),
        .d_in  (pc_if),
        .d_out (pc_id)
    );

    pipe_reg #(.WIDTH(32)) u_instr_ifid (
        .clk   (clk),
        .reset (reset),
        .stall (stall_ifid),
        .flush (flush_ifid),
        .d_in  (instr_if),
        .d_out (instr_id)
    );

endmodule 

module id_ex_reg (
    input         clk,
    input         reset,
    input         stall_idex,
    input         flush_idex,
	 input 			i_insn_vld_id,
	 input 			i_ctrl_id,
	 
	 //week2
	 input 	[2:0]	funct3_id,
	 input 			B_id,
	 input 			J_id,
	 input			JALR_id,
    // dữ liệu từ ID stage
    input  [31:0] pc_id,
    input  [31:0] rs1_data_id,
    input  [31:0] rs2_data_id,
    input  [31:0] imm_id,
	 input  [31:0] instr_id,
	 
    input  [4:0]  rd_id,
    // control từ Decoder
    input  [3:0]  alu_op_id,
    input         mem_wren_id,
    input  [1:0]  wb_sel_id,
    input         rd_wren_id,
	 input         opa_sel_id,   
    input         opb_sel_id,   
    input         br_un_id,     

    // output sang EX stage
	 output 			o_insn_vld_ex,
	 output			o_ctrl_ex,
	 
	 //week2
	 output [2:0] 	funct3_ex,
	 output 			B_ex,
	 output 			J_ex,
	 output 			JALR_ex, 
	 
    output [31:0] pc_ex,
    output [31:0] rs1_data_ex,
    output [31:0] rs2_data_ex,
    output [31:0] imm_ex,
	 output [31:0] instr_ex,
	 
    output [4:0]  rd_ex,
    output [3:0]  alu_op_ex,
    output        mem_wren_ex,
    output [1:0]  wb_sel_ex,
    output        rd_wren_ex,
	 output        opa_sel_ex,   
    output        opb_sel_ex,   
    output        br_un_ex      
);

   // PC
    pipe_reg #(.WIDTH(32)) u_pc_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (pc_id),
        .d_out (pc_ex)
    );

    // rs1_data
    pipe_reg #(.WIDTH(32)) u_rs1_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (rs1_data_id),
        .d_out (rs1_data_ex)
    );

    // rs2_data
    pipe_reg #(.WIDTH(32)) u_rs2_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (rs2_data_id),
        .d_out (rs2_data_ex)
    );

    // imm
    pipe_reg #(.WIDTH(32)) u_imm_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (imm_id),
        .d_out (imm_ex)
    );
	 
	 //instr
	     pipe_reg #(.WIDTH(32)) u_instr_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (instr_id),
        .d_out (instr_ex)
    );

	 pipe_reg #(.WIDTH(1)) u_i_insn_vld_id_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (i_insn_vld_id), .d_out(o_insn_vld_ex)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_i_ctrl_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (i_ctrl_id), .d_out(o_ctrl_ex)
    );
	 
	 pipe_reg #(.WIDTH(3)) u_funct3_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (funct3_id), .d_out(funct3_ex)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_B_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (B_id), .d_out(B_ex)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_J_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (J_id), .d_out(J_ex)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_JALR_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (JALR_id), .d_out(JALR_ex)
    );
    // rd
    pipe_reg #(.WIDTH(5)) u_rd_idex (
        .clk   (clk),
        .reset (reset),
        .stall (stall_idex),
        .flush (flush_idex),
        .d_in  (rd_id),
        .d_out (rd_ex)
    );

    // các control bit (1-bit hoặc 4-bit)
    pipe_reg #(.WIDTH(4)) u_alu_op_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (alu_op_id), .d_out(alu_op_ex)
    );

    pipe_reg #(.WIDTH(1)) u_mem_wren_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (mem_wren_id), .d_out(mem_wren_ex)
    );

    pipe_reg #(.WIDTH(2)) u_wb_sel_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (wb_sel_id), .d_out(wb_sel_ex)
    );

    pipe_reg #(.WIDTH(1)) u_rd_wren_idex (
        .clk   (clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in  (rd_wren_id), .d_out(rd_wren_ex)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_opa_sel_idex (
        .clk(clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in(opa_sel_id), .d_out(opa_sel_ex)
    );

    pipe_reg #(.WIDTH(1)) u_opb_sel_idex (
        .clk(clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in(opb_sel_id), .d_out(opb_sel_ex)
    );

    pipe_reg #(.WIDTH(1)) u_br_un_idex (
        .clk(clk), .reset(reset), .stall(stall_idex), .flush(flush_idex),
        .d_in(br_un_id), .d_out(br_un_ex)
    );


endmodule 

module ex_mem_reg (
    input         clk,
    input         reset,
    input         stall_exmem,
    input         flush_exmem,
	 input  [31:0] instr_ex,
	 input  [31:0] pc_ex,
    input  [31:0] alu_result_ex,
    input  [31:0] rs2_data_ex,
	 input  			pc_sel_ex,
	 

	 output [31:0] instr_mem,
	 output [31:0] pc_mem,
    output [31:0] alu_result_mem,
    output [31:0] rs2_data_mem,
	 output 			pc_sel_mem,
	 // khong dung
	 input 			i_insn_vld_ex,
	 input 			i_ctrl_ex,
	 input 			i_mispred_ex,
	 input  [2:0]	funct3_ex,
    input  [4:0]  rd_ex,
    input         mem_wren_ex,
    input  [1:0]  wb_sel_ex,
    input         rd_wren_ex,
	 
	 output 			o_insn_vld_mem,
	 output 			o_ctrl_mem,
	 output 			o_mispred_mem,	 
	 output [2:0]	funct3_mem,
    output [4:0]  rd_mem,
    output        mem_wren_mem,
    output [1:0]  wb_sel_mem,
    output        rd_wren_mem
);

	 pipe_reg #(.WIDTH(32)) u_instr_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(instr_ex), .d_out(instr_mem)
    );
	 
	 pipe_reg #(.WIDTH(32)) u_pc_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(pc_ex), .d_out(pc_mem)
    );
	 
    pipe_reg #(.WIDTH(32)) u_alu_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(alu_result_ex), .d_out(alu_result_mem)
    );

    pipe_reg #(.WIDTH(32)) u_rs2_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(rs2_data_ex), .d_out(rs2_data_mem)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_pc_sel_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(pc_sel_ex), .d_out(pc_sel_mem)
    );

	 pipe_reg #(.WIDTH(1)) u_insn_vld_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(i_insn_vld_ex), .d_out(o_insn_vld_mem)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_ctrl_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(i_ctrl_ex), .d_out(o_ctrl_mem)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_mispred_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(i_mispred_ex), .d_out(o_mispred_mem)
    );
	 
	 pipe_reg #(.WIDTH(3)) u_funct3_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(funct3_ex), .d_out(funct3_mem)
    );


    pipe_reg #(.WIDTH(5)) u_rd_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(rd_ex), .d_out(rd_mem)
    );

    pipe_reg #(.WIDTH(1)) u_mem_wren_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(mem_wren_ex), .d_out(mem_wren_mem)
    );

    pipe_reg #(.WIDTH(2)) u_wb_sel_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(wb_sel_ex), .d_out(wb_sel_mem)
    );

    pipe_reg #(.WIDTH(1)) u_rd_wren_exmem (
        .clk(clk), .reset(reset), .stall(stall_exmem), .flush(flush_exmem),
        .d_in(rd_wren_ex), .d_out(rd_wren_mem)
    );

endmodule 

module mem_wb_reg (
    input         clk,
    input         reset,
    input         stall_memwb,
    input         flush_memwb,
	 input 			i_insn_vld_mem,
	 input 			i_ctrl_mem,
	 input 			i_mispred_mem,
	 input  [31:0] instr_mem,
	 input  [31:0] pc_mem,
	 input  [31:0] pc_four_mem,
	 input  [31:0] alu_result_mem,  
    input  [31:0] ld_data,   
    input  [4:0]  rd_mem,
    input         rd_wren_mem, 
	 input  [1:0]  wb_sel_mem,
	 
	 output 			o_insn_vld_wb,
	 output 			o_ctrl_wb,
	 output 			o_mispred_wb,
	 
	 output [31:0] instr_wb,
	 output [31:0] pc_wb,
	 output [31:0] pc_four_wb,
    output [31:0] alu_result_wb,
	 output [31:0] ld_data_wb,
    output [4:0]  rd_wb,
    output        rd_wren_wb, 
	 output [1:0]  wb_sel_wb
);

	 pipe_reg #(.WIDTH(1)) u_insn_vld_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(i_insn_vld_mem), .d_out(o_insn_vld_wb)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_ctrl_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(i_ctrl_mem), .d_out(o_ctrl_wb)
    );
	 
	 pipe_reg #(.WIDTH(1)) u_mispred_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(i_mispred_mem), .d_out(o_mispred_wb)
    );
	 
	 pipe_reg #(.WIDTH(32)) u_instr_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(instr_mem), .d_out(instr_wb)
    );
	 
	 pipe_reg #(.WIDTH(32)) u_pc__memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(pc_mem), .d_out(pc_wb)
    );

	 pipe_reg #(.WIDTH(32)) u_pc_four_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(pc_four_mem), .d_out(pc_four_wb)
    );

    pipe_reg #(.WIDTH(32)) u_alu_result_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(alu_result_mem), .d_out(alu_result_wb)
    );
	 
	 pipe_reg #(.WIDTH(32)) u_ld_data_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(ld_data), .d_out(ld_data_wb)
    );

    pipe_reg #(.WIDTH(5)) u_rd_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(rd_mem), .d_out(rd_wb)
    );

    pipe_reg #(.WIDTH(1)) u_rd_wren_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(rd_wren_mem), .d_out(rd_wren_wb)
    );
	 
	 pipe_reg #(.WIDTH(2)) u_wb_sel_memwb (
        .clk(clk), .reset(reset), .stall(stall_memwb), .flush(flush_memwb),
        .d_in(wb_sel_mem), .d_out(wb_sel_wb)
    );

endmodule 