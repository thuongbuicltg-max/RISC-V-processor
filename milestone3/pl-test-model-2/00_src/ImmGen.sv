module ImmGen (
  input  logic [31:0] instr,
  output logic [31:0] imm
);
logic R, I, I_load, S, B, J, U, JALR;
logic [6:0]  op ; 
logic [31:0] in;
assign op  = instr[6:0];   
assign in  = instr[31:0];
// op -> enable 1bit 
// R-format: 0110011
assign R = (~op[6]) & ( op[5]) & ( op[4]) & (~op[3]) &(~op[2]) & ( op[1]) & ( op[0]);
// I-format (ALU): 0010011
assign I = (~op[6]) & (~op[5]) & ( op[4]) & (~op[3]) & (~op[2]) & ( op[1]) & ( op[0]);
// I_load-format (LW): 0000011
assign I_load = (~op[6]) & (~op[5]) & (~op[4]) & (~op[3]) & (~op[2]) & ( op[1]) & ( op[0]);
// S-format (SW): 0100011
assign S = (~op[6]) & ( op[5]) & (~op[4]) & (~op[3]) & (~op[2]) & ( op[1]) & ( op[0]);
// B-format (BEQ/BNE...): 1100011
assign B = ( op[6]) & ( op[5]) & (~op[4]) & (~op[3]) & (~op[2]) & ( op[1]) & ( op[0]);
// J-format (JAL): 1101111
assign J = ( op[6]) & ( op[5]) & (~op[4]) & ( op[3]) & ( op[2]) & ( op[1]) & ( op[0]);
// U-format AUIPC: 0010111
//assign auipc = ((~op[6]) & ~(op[5]) & ( op[4]) & (~op[3]) &( op[2]) & ( op[1]) & ( op[0]))  ;   
//assign lui = ((~op[6]) & (op[5]) & ( op[4]) & (~op[3]) &( op[2]) & ( op[1]) & ( op[0]))  ;  
// tai ImmGen lui va auipc giong nhau nen gop lai thanh U 
assign U =  ((~op[6]) & ( op[4]) & (~op[3]) &( op[2]) & ( op[1]) & ( op[0]))  ;
// I-jalr: 1100111
assign JALR = ( op[6]) & ( op[5]) & (~op[4]) & (~op[3]) &( op[2]) & ( op[1]) & ( op[0]);

//imm0 = (selI & a) | (S & b); 
imm_bit0 u_bit0(.selI(I | I_load | JALR), .S(S), .a(in[20]), .b(in[7]), .imm0(imm[0]));

// imm_1_4[i] = ((selI | J) & a[i]) | ((S | B) & b[i]) ;
imm_bit1_4 u_bit1_4(.selI(I | I_load | JALR),    .S(S), .B(B), .J(J), .a(instr[24:21]), .b(in[11:8]), .imm1_4(imm[4:1])); 

// imm_5_10[5+i] = (selI | S | B | J) & a[i];
imm_bit5_10 u_bit5_10 (.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .a(instr[30:25]), .imm5_10(imm[ 10:5])); 

// imm11 = ((selI | S) & a) | (B & b) | (J & c);
imm_bit11 u_bit11(.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .a(in[31]), .b(in[7]), .c(in[20]), .imm11(imm[11]));

// imm12 = ((selI | B) & a) | (J | U) & b;
imm_bit12 u_bit12(.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .U(U), .a(in[31]), .b(in[12]), .imm12(imm[12]) );

// imm_13_19[13+i] = ((selI | S | B) & a) | (J | U & b[i]) ;
imm_bit13_19 u_bit13_19(.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .U(U), .a(in[31]), .b(in[19:13]), .imm13_19(imm[19:13]));

// imm20 = ((selI | S | B | J) & a) | (U & b);
imm_bit20 u_bit20(.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .U(U), .a(in[31]), .b(in[20]), .imm20(imm[20]));

// imm_21_31[21+i] = (selI | S | B | J) &a | (U & b[i]);
imm_bit21_31 u_bit21_31(.selI(I | I_load | JALR), .S(S), .B(B), .J(J), .U(U), .a(in[31]), .b(in[31:21]), .imm21_31(imm[31:21]));


endmodule 

module imm_bit0 (
  input  logic       selI, S,
  input logic 			a, b,
  output logic       imm0
);
  assign imm0 = (selI & a) | (S & b);
endmodule


module imm_bit1_4 (
  input  logic       selI, S, B, J,
  input  logic [3:0] a, b,
  output logic [4:1] imm1_4
);
  genvar i;
  generate
    for (i = 0; i < 4; i++) begin : G14
      always_comb imm1_4[i+1] = ((selI | J) & a[i]) | ((S | B) & b[i]) ;
    end
  endgenerate
endmodule


module imm_bit5_10 (
  input  logic       selI, S, B, J,
  input  logic [5:0] a,
  output logic [10:5] imm5_10
);

  genvar i;
  generate
    for (i = 0; i < 6; i++) begin : G510
      always_comb imm5_10[5+i] = (selI | S | B | J) & a[i];
    end
  endgenerate
endmodule


module imm_bit11 (
  input  logic       selI, S, B, J,
  input  logic			a, b, c,
  output logic       imm11
);
  assign imm11 = ((selI | S) & a) | (B & b) | (J & c);
endmodule


module imm_bit12 (
  input  logic       selI, S, B, J, U,
  input  logic 		a, b,
  output logic       imm12
);
  assign imm12 = ((selI | B) & a) | ((J | U) & b);
endmodule


module imm_bit13_19 (
  input  logic      	selI, S, B, J, U,
  input  logic 		a,
  input logic [6:0]	b,
  output logic [19:13] imm13_19
);

  genvar i;
  generate
    for (i = 0; i < 7; i++) begin : G1314
      always_comb imm13_19[13+i] = ((selI | S | B) & a) | ((J | U) & b[i]) ;
    end
  endgenerate
endmodule


module imm_bit20 (
  input  logic       selI, S, B, J, U,
  input  logic 		a, b,
  output logic       imm20
);
  assign imm20 = ((selI | S | B | J) & a) | (U & b);
endmodule


module imm_bit21_31 (
  input  logic       selI, S, B, J, U,
  input  logic 		a,
  input  logic [10:0] b,
  output logic [31:21] imm21_31
);

  genvar i;
  generate
    for (i = 0; i < 11; i++) begin : G2124
      always_comb imm21_31[21+i] = ((selI | S | B | J) &a) | (U & b[i]);
    end
  endgenerate
endmodule 