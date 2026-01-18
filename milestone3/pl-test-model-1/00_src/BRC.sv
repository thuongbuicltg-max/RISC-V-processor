// BRC 
module BRC (
  input  logic [31:0] i_rs1_data, i_rs2_data,
  input  logic        i_br_un, 
  output logic        o_br_less, o_br_equal
); 
  logic slt, sltu;
  assign o_br_equal = ~|(i_rs1_data ^ i_rs2_data);

  logic [31:0] sub_res;
  logic ovf, cout;

  ADD_SUB_SLT_SLTU asss_brc (
    .a      (i_rs1_data), 
    .b      (i_rs2_data),
    .is_sub (1'b1),            // dùng mạch trừ để tạo slt/sltu
    .result (sub_res),
    .ovf    (ovf),
    .slt    (slt),
    .sltu   (sltu),
    .cout   (cout)
  );
  // chon sltu khi br_un = 0 unsigned, slt khi br_un = 1 signed
  assign o_br_less = i_br_un ? slt : sltu ;
endmodule 