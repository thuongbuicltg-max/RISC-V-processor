/* module CTU 
(
  input  logic        i_br_less, i_br_equal,
  input  logic [31:0] i_instr,
  output logic        o_pc_sel, o_rd_wren, o_insn_vld, o_br_un, o_opa_sel, o_opb_sel, o_mem_wren,
  output logic [1:0]  o_wb_sel,
  output logic [3:0]  o_alu_op,
  
  output logic [2:0]  funct3_id,
  output logic o_ctrl, B_id, J_id, JALR_id,
  // hazard unit 
  output logic        use_rs1_id,
  output logic        use_rs2_id
);
logic [3:0] o_bmask; 
  // Trích trường
  logic [6:0] op;       assign op    = i_instr[6:0];
  logic [2:0] func3;    assign func3 = i_instr[14:12];
  assign funct3_id = func3;
  logic [6:0] func7;    assign func7 = i_instr[31:25];

  // Opcode groups
  logic R, I, I_load, S, auipc, lui;
  // R-format: 0110011
  assign R      = (~op[6]) &  op[5]  &  op[4]  & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // I-format (ALU): 0010011
  assign I      = (~op[6]) & (~op[5])&  op[4]  & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // I-load: 0000011
  assign I_load = (~op[6]) & (~op[5])& (~op[4])& (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // S-format: 0100011
  assign S      = (~op[6]) &  op[5]  & (~op[4])& (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // B-format: 1100011
  assign B      =  op[6]   &  op[5]  & (~op[4])& (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  assign B_id = B;
  // J-format (JAL): 1101111
  assign J      =  op[6]   &  op[5]  & (~op[4])&  op[3]   &  op[2]   &  op[1]  &  op[0];
  assign J_id = J;
  // AUIPC: 0010111
  assign auipc  = (~op[6]) & (~op[5])&  op[4]  & (~op[3]) &  op[2]   &  op[1]  &  op[0];
  // LUI:   0110111
  assign lui    = (~op[6]) &  op[5]  &  op[4]  & (~op[3]) &  op[2]   &  op[1]  &  op[0];
  // JALR:  1100111
  assign JALR   =  op[6]   &  op[5]  & (~op[4])& (~op[3]) &  op[2]   &  op[1]  &  op[0];
  assign JALR_id = JALR; 

  // ===== B-format: tạo bit cho từng funct3 =====
  logic beq, bne, blt, bge, bltu, bgeu;
  assign beq  = B & (~func3[2]) & (~func3[1]) & (~func3[0]); // 000
  assign bne  = B & (~func3[2]) & (~func3[1]) & ( func3[0]); // 001
  assign blt  = B & ( func3[2]) & (~func3[1]) & (~func3[0]); // 100 (signed)
  assign bge  = B & ( func3[2]) & (~func3[1]) & ( func3[0]); // 101 (signed)
  assign bltu = B & ( func3[2]) & ( func3[1]) & (~func3[0]); // 110 (unsigned)
  assign bgeu = B & ( func3[2]) & ( func3[1]) & ( func3[0]); // 111 (unsigned)

  // ===== Quyết định nhánh theo từng bit =====
  wire take_branch =
       (beq &  i_br_equal) |
       (bne & ~(i_br_equal)) |
       (blt &  i_br_less)   |
		 (bltu &  i_br_less)  |
       (bge & ~(i_br_less)) | 
		 (bgeu & ~(i_br_less));

  assign o_pc_sel = J | JALR | take_branch;

  assign o_rd_wren = R | I | I_load | J | JALR | auipc | lui;
	 
  assign o_br_un =  B & func3[2] & ~func3[1]; // blt(100), bge9101 => br_un=1 khi func3 = 10x

  // ===== chọn toán hạng cho ALU =====
  assign o_opa_sel = J | auipc | B; // PC as op_a cho J/AUIPC/Branch
  assign o_opb_sel = ~R;            // R dùng rs2, còn lại dùng imm

  // ===== mã lệnh cho ALU =====
  // Yêu cầu: LUI = 4'b0011; R/I = {funct7[5] (SRA/SUB), funct3}
  // Bổ sung SRAI: I & (func3=101) dùng func7[5] (instr[30])
  logic [3:0]alu_tempt;
  wire srai_like = I & (func3[2] & ~func3[1] & func3[0]); // 101
  assign alu_tempt [3:1] = (func3[2:0] & {3{R | I}}) ; 
  assign alu_tempt [0] = (func7[5] & (R | srai_like)) ;
  assign o_alu_op = lui ? 4'b0011 : alu_tempt;

  // ===== ghi/mem/wb =====
  assign o_mem_wren = S;



  // wb_sel: 00=MEM, 01=ALU, 10=PC+4 (ví dụ)
  assign o_wb_sel[1] = J | JALR;               // PC+4
  assign o_wb_sel[0] = R | I | auipc | lui;    // ALU

  // ===== Byte mask cho LOAD (gate bằng I_load) =====
  // func3: LB=000, LH=001, LW=010, LBU=100, LHU=101
  logic [4:0] mask;
  assign mask[0] = (~func3[2]) & (~func3[1]) & (~func3[0]); // 000
  assign mask[1] = (~func3[2]) & (~func3[1]) & ( func3[0]); // 001
  assign mask[2] = (~func3[2]) & ( func3[1]) & (~func3[0]); // 010
  assign mask[3] = ( func3[2]) & (~func3[1]) & (~func3[0]); // 100
  assign mask[4] = ( func3[2]) & (~func3[1]) & ( func3[0]); // 101

  assign o_bmask[0] = I_load & (mask[0] | mask[1] | mask[2] | mask[3] | mask[4]);
  assign o_bmask[1] = I_load & (mask[1] | mask[2] | mask[4]);
  assign o_bmask[2] = I_load &  mask[2];
  assign o_bmask[3] = I_load & (mask[2] | mask[3] | mask[4]);
  // ===== Tín hiệu dùng cho hazard: lệnh có thực sự đọc rs1/rs2 không? =====
  //
  // R-type:    dùng rs1 + rs2
  // I-type ALU: dùng rs1 + imm
  // I_load:    rs1 là base, rs2 không dùng
  // S-type:    rs1 (base) + rs2 (data)
  // B-type:    rs1 + rs2
  // JALR:      rs1 (base), không dùng rs2
  // J, AUIPC, LUI: không đọc rs1/rs2
  //
  //
  assign use_rs1_id = R | I | I_load | S | B | JALR;
  assign use_rs2_id = R | S | B;
  // ===== hợp lệ lệnh =====
  assign o_insn_vld = R | I | I_load | S | B | J | auipc | lui | JALR;
  assign o_ctrl = B | J | JALR;
endmodule */
//===================================ControlUnit===================================
module CTU (
  input  logic        i_br_less, i_br_equal,
  input  logic [31:0] i_instr,
  output logic        o_pc_sel, o_rd_wren, o_insn_vld, o_br_un,
  output logic        o_opa_sel, o_opb_sel, o_mem_wren,
  output logic [1:0]  o_wb_sel,
  output logic [3:0]  o_alu_op,
  output logic o_mispred
);

  // --- Instruction fields ---
  logic [6:0] op;     assign op    = i_instr[6:0];
  logic [2:0] func3;  assign func3 = i_instr[14:12];
  logic       bit30;  assign bit30 = i_instr[30]; // funct7[5]

  // --- Opcode classification (RV32I) ---
  logic r, i, i_load, s, b, j, i_jalr, lui, auipc;

  // R-type: 0110011
  assign r      = (~op[6]) &  op[5]  &  op[4]  & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // I-ALU: 0010011
  assign i      = (~op[6]) & (~op[5]) &  op[4]  & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // LOAD: 0000011
  assign i_load = (~op[6]) & (~op[5]) & (~op[4]) & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // STORE: 0100011
  assign s      = (~op[6]) &  op[5]  & (~op[4]) & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // BRANCH: 1100011
  assign b      =  op[6]   &  op[5]  & (~op[4]) & (~op[3]) & (~op[2]) &  op[1]  &  op[0];
  // JAL: 1101111
  assign j      =  op[6]   &  op[5]  &  ~op[4]  &  op[3]   &  op[2]   &  op[1]  &  op[0];
  // JALR: 1100111
  assign i_jalr =  op[6]   &  op[5]  & (~op[4]) & (~op[3]) &  op[2]   &  op[1]  &  op[0];
  // LUI: 0110111
  assign lui    = (~op[6]) &  op[5]  &  op[4]   &  ~op[3]  &  op[2]   &  op[1]  &  op[0];
  // AUIPC: 0010111
  assign auipc  = (~op[6]) & (~op[5]) &  op[4]  &  ~op[3]  &  op[2]   &  op[1]  &  op[0];

  // --- Branch comparator mode: 1 = signed / 0 = unsigned ---
  assign o_br_un = b & func3[2] & ~func3[1]; // func3 = 10x

  // --- Branch decision logic ---
  logic beq, bne, blt, bge, bltu, bgeu;

  // func3 = 000 → BEQ
  assign beq  = (~func3[2]) & (~func3[1]) & (~func3[0]) &  i_br_equal;
  // func3 = 001 → BNE
  assign bne  = (~func3[2]) & (~func3[1]) &  func3[0]   & (~i_br_equal);
  // func3 = 100 → BLT (signed)
  assign blt  =  func3[2]  & (~func3[1]) & (~func3[0])  &  i_br_less;
  // func3 = 101 → BGE (signed)
  assign bge  =  func3[2]  & (~func3[1]) &  func3[0]    & (~i_br_less);
  // func3 = 110 → BLTU (unsigned)
  assign bltu =  func3[2]  &  func3[1]   & (~func3[0])  &  i_br_less;
  // func3 = 111 → BGEU (unsigned)
  assign bgeu =  func3[2]  &  func3[1]   &  func3[0]    & (~i_br_less);
	
  logic br_take; 
  assign br_take = b & (beq | bne | blt | bge | bltu | bgeu);
  assign o_mispred = br_take;
  // --- PC select: choose J/JALR or branch-taken path ---
  assign o_pc_sel = j | i_jalr | br_take;

  // --- Writeback select: 00 = LOAD, 01 = ALU, 10 = PC+4 ---
  assign o_wb_sel[1] = (j | i_jalr) & ~i_load;
  assign o_wb_sel[0] = (~i_load & ~j & ~i_jalr);

  // --- Register write enable ---
  assign o_rd_wren = r | i | i_load | j | i_jalr | auipc | lui;

  // --- Operand selection ---
  // A = PC for BRANCH / JAL / AUIPC (JALR uses rs1)
  assign o_opa_sel = b | j | auipc;
  // B = immediate for I / LOAD / STORE / BR / J / JALR / AUIPC / LUI
  assign o_opb_sel = i | i_load | s | b | j | i_jalr | auipc | lui;

  // --- Memory write enable ---
  assign o_mem_wren = s;

  // --- Valid instruction flag ---
  assign o_insn_vld = r | i | i_load | s | b | j | i_jalr | auipc | lui;

  // --- ALU operation encoding: {funct3, bit0_for_SUB/SRA} ---
  logic is_add_class;
  assign is_add_class = i_load | s | b | j | i_jalr | auipc | lui;

  // bit0 = 1 only when SUB (R,f3=000,bit30=1) or SRA/SRAI (f3=101,bit30=1)
  logic bit0_sel;
  assign bit0_sel =
      ( r       & (~func3[2]) & (~func3[1]) & (~func3[0]) & bit30 ) |
      ((r | i)  &  func3[2]   & (~func3[1]) &  func3[0]   & bit30);

  logic [3:0] temp;

  // If is_add_class = 1 → 0000
  // Else → {i_instr[14:12], bit0_sel}
  assign temp[3] = (~is_add_class) &  i_instr[14];
  assign temp[2] = (~is_add_class) &  i_instr[13];
  assign temp[1] = (~is_add_class) &  i_instr[12];
  assign temp[0] = (~is_add_class) &  bit0_sel;

  // --- LUI special case override ---
  mux21_4bit check_lui (
    .a   (temp),
    .b   (4'b0011),
    .sel (lui),
    .y   (o_alu_op)
  );

endmodule 

module mux21_4bit(
  input  logic [3:0] a,
  input  logic [3:0] b,
  input  logic       sel,
  output logic [3:0] y
);
  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : G_MUX
      mux21 u_mux21 (.a(a[i]), .b(b[i]), .sel(sel), .y(y[i]));
    end
  endgenerate
endmodule

module mux21(
  input  logic a,
  input  logic b,
  input  logic sel,
  output logic y
);
  assign y = sel ? b : a;
endmodule
