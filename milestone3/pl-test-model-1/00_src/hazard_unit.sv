module hazard_unit (
    input  logic [31:0] instr_id,   // ID  stage (Decode)
    input  logic [31:0] instr_ex,   // EX  stage
    input  logic [31:0] instr_mem,  // MEM stage
    input  logic [31:0] instr_wb,   // WB  stage
    output logic        stall       // stall_raw đưa lên top
);

    //================ OPCODE CONSTANTS =================
    localparam [6:0] OPC_ALU    = 7'b0110011; // R-type
    localparam [6:0] OPC_ALUI   = 7'b0010011; // I-type ALU
    localparam [6:0] OPC_LOAD   = 7'b0000011; // LB/LH/LW
    localparam [6:0] OPC_STORE  = 7'b0100011; // SB/SH/SW
    localparam [6:0] OPC_BRANCH = 7'b1100011; // BEQ/BNE/...
    localparam [6:0] OPC_JAL    = 7'b1101111;
    localparam [6:0] OPC_JALR   = 7'b1100111;
    localparam [6:0] OPC_LUI    = 7'b0110111;
    localparam [6:0] OPC_AUIPC  = 7'b0010111;
    localparam [6:0] OPC_SYSTEM = 7'b1110011; // CSR (nếu chưa dùng thì cũng không sao)

    //================ LẤY OPCODE / REGISTER FIELD ==========
    logic [6:0] op_id, op_ex, op_mem, op_wb;
    assign op_id  = instr_id [6:0];
    assign op_ex  = instr_ex [6:0];
    assign op_mem = instr_mem[6:0];
    assign op_wb  = instr_wb [6:0];

    // ID stage: rs1, rs2
    logic [4:0] rs1D, rs2D;
    assign rs1D = instr_id[19:15];
    assign rs2D = instr_id[24:20];

    // EX/MEM/WB stage: rd (write-back addr)
    logic [4:0] rdE, rdM, rdW;
    assign rdE = instr_ex [11:7];
    assign rdM = instr_mem[11:7];
    assign rdW = instr_wb [11:7];

    //================= ID: lệnh có đọc rs1/rs2? =============
    logic aluD, aluiD, lwD, swD, brD, jalD, jalrD;
    assign aluD  = (op_id == OPC_ALU);
    assign aluiD = (op_id == OPC_ALUI);
    assign lwD   = (op_id == OPC_LOAD);
    assign swD   = (op_id == OPC_STORE);
    assign brD   = (op_id == OPC_BRANCH);
    assign jalD  = (op_id == OPC_JAL);
    assign jalrD = (op_id == OPC_JALR);

    // dec_rs1_oen / dec_rs2_oen
    logic rs1_oen, rs2_oen;
    always_comb begin
        rs1_oen = 1'b0;
        rs2_oen = 1'b0;

        // rs1 dùng bởi: ALU, ALUI, LOAD, STORE, BRANCH, JALR
        if (aluD || aluiD || lwD || swD || brD || jalrD)
            rs1_oen = 1'b1;

        // rs2 dùng bởi: ALU, STORE, BRANCH
        if (aluD || swD || brD)
            rs2_oen = 1'b1;
    end

    //================= EX/MEM/WB: cờ "ghi RF?" ===============
    // exe_reg_ctrl_rf_wen, mem_reg_ctrl_rf_wen, wb_reg_ctrl_rf_wen
    logic rf_wen_E, rf_wen_M, rf_wen_W;
    logic ex_is_load, ex_is_csr;

    // EX stage
    always_comb begin
        ex_is_load = (op_ex == OPC_LOAD);
        ex_is_csr  = (op_ex == OPC_SYSTEM);

        rf_wen_E = (op_ex == OPC_ALU)   ||
                   (op_ex == OPC_ALUI)  ||
                   (op_ex == OPC_LOAD)  ||
                   (op_ex == OPC_JAL)   ||
                   (op_ex == OPC_JALR)  ||
                   (op_ex == OPC_AUIPC) ||
                   (op_ex == OPC_LUI)   ||
                   (op_ex == OPC_SYSTEM);
    end

    // MEM stage
    always_comb begin
        rf_wen_M = (op_mem == OPC_ALU)   ||
                   (op_mem == OPC_ALUI)  ||
                   (op_mem == OPC_LOAD)  ||
                   (op_mem == OPC_JAL)   ||
                   (op_mem == OPC_JALR)  ||
                   (op_mem == OPC_AUIPC) ||
                   (op_mem == OPC_LUI)   ||
                   (op_mem == OPC_SYSTEM);
    end

    // WB stage
    always_comb begin
        rf_wen_W = (op_wb == OPC_ALU)   ||
                   (op_wb == OPC_ALUI)  ||
                   (op_wb == OPC_LOAD)  ||
                   (op_wb == OPC_JAL)   ||
                   (op_wb == OPC_JALR)  ||
                   (op_wb == OPC_AUIPC) ||
                   (op_wb == OPC_LUI)   ||
                   (op_wb == OPC_SYSTEM);
    end

    //================= HAZARD TỪNG NGUỒN ====================
    logic hazard_ex_rs1, hazard_mem_rs1, hazard_wb_rs1;
    logic hazard_ex_rs2, hazard_mem_rs2, hazard_wb_rs2;
    logic hazard_load_rs1, hazard_load_rs2;
    logic hazard_csr;

    // ((exe_reg_wbaddr === dec_rs1_addr) && (dec_rs1_addr != 0)
    //     && exe_reg_ctrl_rf_wen && dec_rs1_oen)
    assign hazard_ex_rs1 =
        (rdE  == rs1D) &&
        (rs1D != 5'd0) &&
        rf_wen_E       &&
        rs1_oen;

    assign hazard_mem_rs1 =
        (rdM  == rs1D) &&
        (rs1D != 5'd0) &&
        rf_wen_M       &&
        rs1_oen;

    assign hazard_wb_rs1  =
        (rdW  == rs1D) &&
        (rs1D != 5'd0) &&
        rf_wen_W       &&
        rs1_oen;

    // rs2 tương tự
    assign hazard_ex_rs2 =
        (rdE  == rs2D) &&
        (rs2D != 5'd0) &&
        rf_wen_E       &&
        rs2_oen;

    assign hazard_mem_rs2 =
        (rdM  == rs2D) &&
        (rs2D != 5'd0) &&
        rf_wen_M       &&
        rs2_oen;

    assign hazard_wb_rs2  =
        (rdW  == rs2D) &&
        (rs2D != 5'd0) &&
        rf_wen_W       &&
        rs2_oen;

    // (exe_inst_is_load) && (exe_reg_wbaddr === dec_rs*_addr)
    //   && (exe_reg_wbaddr != 0) && dec_rs*_oen
    assign hazard_load_rs1 =
        ex_is_load      &&
        rs1_oen         &&
        (rdE  != 5'd0)  &&
        (rdE  == rs1D);

    assign hazard_load_rs2 =
        ex_is_load      &&
        rs2_oen         &&
        (rdE  != 5'd0)  &&
        (rdE  == rs2D);

    // ((exe_reg_is_csr))
    assign hazard_csr = ex_is_csr;

    //================= OUTPUT STALL =========================
    always_comb begin
        stall =
            hazard_ex_rs1   ||
            hazard_mem_rs1  ||
            hazard_wb_rs1   ||
            hazard_ex_rs2   ||
            hazard_mem_rs2  ||
            hazard_wb_rs2   ||
            hazard_load_rs1 ||
            hazard_load_rs2 ||
            hazard_csr;
    end


endmodule 