//====================================================
module hazard_unit (
  input  logic [31:0] instr_ex,
  input  logic [31:0] instr_id,
  input  logic        pc_sel,
  output logic        flushD,
  output logic        flushE,
  output logic        stall
);

  logic [6:0] op_id, op_ex;
  assign op_id = instr_id[6:0];
  assign op_ex = instr_ex[6:0];

  logic id_r, id_i, id_ld, id_s, id_b, id_j, id_jalr, id_lui, id_auipc, id_sys;
  logic ex_r, ex_i, ex_ld, ex_s, ex_b, ex_j, ex_jalr, ex_lui, ex_auipc, ex_sys;

  op_decode dec_id(.op(op_id), .r(id_r), .i(id_i), .i_load(id_ld), .s(id_s), .b(id_b),
                   .j(id_j), .jalr(id_jalr), .lui(id_lui), .auipc(id_auipc), .sys(id_sys));

  op_decode dec_ex(.op(op_ex), .r(ex_r), .i(ex_i), .i_load(ex_ld), .s(ex_s), .b(ex_b),
                   .j(ex_j), .jalr(ex_jalr), .lui(ex_lui), .auipc(ex_auipc), .sys(ex_sys));

  logic rs1_oen, rs2_oen;
  assign rs1_oen = id_r | id_i | id_ld | id_s | id_b | id_jalr;
  assign rs2_oen = id_r | id_s | id_b;

  logic [4:0] rs1D, rs2D, rdE;
  assign rs1D = instr_id[19:15];
  assign rs2D = instr_id[24:20];
  assign rdE  = instr_ex[11:7];

  logic hz1, hz2;
  assign hz1 = rs1_oen & (|rs1D) & ~(|(rs1D ^ rdE));
  assign hz2 = rs2_oen & (|rs2D) & ~(|(rs2D ^ rdE));

  logic load_use;
  assign load_use = ex_ld & (hz1 | hz2);

  assign flushD = pc_sel;
  assign stall  = load_use & ~pc_sel;
  assign flushE = pc_sel | (load_use & ~pc_sel);

endmodule



//==================================== FW unit=====================
module fw_unit (
  input  logic [31:0] instr_ex,
  input  logic [31:0] instr_mem,
  input  logic [31:0] instr_wb,
  output logic [1:0]  fwA,
  output logic [1:0]  fwB,
  output logic        fwM
);

	logic [6:0] op_ex, op_mem, op_wb;
	assign op_ex  = instr_ex [6:0];
	assign op_mem = instr_mem[6:0];
	assign op_wb  = instr_wb [6:0];

	logic ex_r, ex_i, ex_ld, ex_s, ex_b, ex_j, ex_jalr, ex_lui, ex_auipc, ex_sys;
	logic m_r,  m_i,  m_ld,  m_s,  m_b,  m_j,  m_jalr,  m_lui,  m_auipc,  m_sys;
	logic w_r,  w_i,  w_ld,  w_s,  w_b,  w_j,  w_jalr,  w_lui,  w_auipc,  w_sys;

	op_decode dec_ex  (.op(op_ex ), .r(ex_r), .i(ex_i), .i_load(ex_ld), .s(ex_s), .b(ex_b), .j(ex_j), .jalr(ex_jalr), .lui(ex_lui), .auipc(ex_auipc), .sys(ex_sys));
	op_decode dec_mem (.op(op_mem), .r(m_r ), .i(m_i ), .i_load(m_ld ), .s(m_s ), .b(m_b ), .j(m_j ), .jalr(m_jalr ), .lui(m_lui ), .auipc(m_auipc ), .sys(m_sys ));
	op_decode dec_wb  (.op(op_wb ), .r(w_r ), .i(w_i ), .i_load(w_ld ), .s(w_s ), .b(w_b ), .j(w_j ), .jalr(w_jalr ), .lui(w_lui ), .auipc(w_auipc ), .sys(w_sys ));

	logic [4:0] rs1E, rs2E, rdM, rdW;
	assign rs1E = instr_ex [19:15];
	assign rs2E = instr_ex [24:20];
	assign rdM  = instr_mem[11:7];
	assign rdW  = instr_wb [11:7];

	logic rs1_oen, rs2_oen;
	assign rs1_oen = ex_r | ex_i | ex_ld | ex_s | ex_b | ex_jalr;
	assign rs2_oen = ex_r | ex_s | ex_b;

	logic RegWriteM, RegWriteW;
	assign RegWriteM = m_r | m_i | m_j | m_jalr | m_auipc | m_lui | m_sys;
	assign RegWriteW = w_r | w_i | w_ld | w_j | w_jalr | w_auipc | w_lui | w_sys;

	logic rs1_nz, rs2_nz;
	assign rs1_nz = |rs1E;
	assign rs2_nz = |rs2E;

	logic hitM1, hitW1, hitM2, hitW2;
	assign hitM1 = RegWriteM & rs1_oen & rs1_nz & ~(|(rs1E ^ rdM));
	assign hitW1 = RegWriteW & rs1_oen & rs1_nz & ~(|(rs1E ^ rdW));
	assign hitM2 = RegWriteM & rs2_oen & rs2_nz & ~(|(rs2E ^ rdM));
	assign hitW2 = RegWriteW & rs2_oen & rs2_nz & ~(|(rs2E ^ rdW));

	logic hitLW1, hitLW2;
	assign hitLW1 = w_ld & rs1_oen & rs1_nz & ~(|(rs1E ^ rdW));
	assign hitLW2 = w_ld & rs2_oen & rs2_nz & ~(|(rs2E ^ rdW));
	// fwA: 01: Mem,LW1:11, W1:10 
	assign fwA[0] =  hitM1 | hitLW1;
	assign fwA[1] = ~hitM1 & (hitLW1 | hitW1);

	assign fwB[0] =  hitM2 | hitLW2;
	assign fwB[1] = ~hitM2 & (hitLW2 | hitW2);
	assign fwM = hitLW1 | hitLW2;

endmodule

module op_decode (
  input  logic [6:0] op,
  output logic       r,
  output logic       i,
  output logic       i_load,
  output logic       s,
  output logic       b,
  output logic       j,
  output logic       jalr,
  output logic       lui,
  output logic       auipc,
  output logic       sys
);

  // R-type: 0110011
  assign r =
    ~op[6] &  op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // I-type ALU: 0010011
  assign i =
    ~op[6] & ~op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // LOAD: 0000011
  assign i_load =
    ~op[6] & ~op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // STORE: 0100011
  assign s =
    ~op[6] &  op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // BRANCH: 1100011
  assign b =
     op[6] &  op[5] & ~op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

  // JAL: 1101111
  assign j =
     op[6] &  op[5] & ~op[4] &
     op[3] &  op[2] &  op[1] & op[0];

  // JALR: 1100111
  assign jalr =
     op[6] &  op[5] & ~op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // LUI: 0110111
  assign lui =
    ~op[6] &  op[5] &  op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // AUIPC: 0010111
  assign auipc =
    ~op[6] & ~op[5] &  op[4] &
    ~op[3] &  op[2] &  op[1] & op[0];

  // SYSTEM: 1110011
  assign sys =
     op[6] &  op[5] &  op[4] &
    ~op[3] & ~op[2] &  op[1] & op[0];

endmodule 