module branch_predict (
    // Các flag đã được decode và pipeline sang EX
    input  logic        i_is_branch,   // lệnh B-type (BEQ, BNE, BLT, BGE, BLTU, BGEU)
    input  logic        i_is_jal,      // JAL
    input  logic        i_is_jalr,     // JALR
    input  logic [2:0]  i_funct3,      // funct3 của branch (chỉ dùng khi i_is_branch = 1)

    // Kết quả so sánh từ BRC (Branch Comparator) ở EX
    input  logic        i_br_less,     // rs1 < rs2 ? (signed/unsigned tuỳ i_br_un, đã xử lý trong BRC)
    input  logic        i_br_equal,    // rs1 == rs2 ?

    // Output
    output logic        o_take_branch  // lệnh này có thực sự "taken" không
);

    // Quyết định taken
    always_comb begin
        // Mặc định: không nhảy
        o_take_branch = 1'b0;

        // JAL / JALR là unconditional jump -> luôn taken
        if (i_is_jal || i_is_jalr) begin
            o_take_branch = 1'b1;
        end
        // Branch có điều kiện (B-type)
        else if (i_is_branch) begin
            unique case (i_funct3)
                3'b000:  // BEQ
                    o_take_branch = i_br_equal;

                3'b001:  // BNE
                    o_take_branch = ~i_br_equal;

                3'b100,  // BLT  (signed)
                3'b110:  // BLTU (unsigned)
                    o_take_branch = i_br_less;

                3'b101,  // BGE  (signed)
                3'b111:  // BGEU (unsigned)
                    o_take_branch = ~i_br_less;

                default:
                    o_take_branch = 1'b0;
            endcase
        end
    end

endmodule 


 1 `ifndef __GUARD_SANITY_TEST_SV__
  2 `define __GUARD_SANITY_TEST_SV__
  3 
  4 class sanity_test extends base_test;
  5 
  6   // +--- Factory Registration ---+
  7   `uvm_component_utils(sanity_test)
  8 
  9   // +--- Constructor ---+
 10   function new(string name="sanity_test", uvm_component parent=null);
 11     super.new(name, parent);
 12   endfunction: new
 13 
 14   // +--- UVM Phases ---+
 15   virtual task run_phase(uvm_phase phase);
 16     super.run_phase(phase);
 17     phase.raise_objection(this);
 18     `uvm_info("TEST", $sformatf("Test --> Start"), UVM_NONE)
 19 
 20     #100ns;
 21 
 22     `uvm_info("TEST", $sformatf("Test --> End"), UVM_NONE)
 23     phase.drop_objection(this);
 24   endtask: run_phase
 25 
 26 endclass: sanity_test
 27 
 28 `endif // __GUARD_SANITY_TEST_SV__
