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

  1 `ifndef __GUARD_BASE_TEST_SV__
  2 `define __GUARD_BASE_TEST_SV__
  3 
  4 virtual class base_test extends uvm_test;
  5 
  6   // +--- Fields ---+
  7   protected all_vif                    all_if;
  8   protected system_configuration       cfg;
  9   protected system_environment         env;
 10   protected system_virtual_sequencer   sequencer;
 11   protected system_demoter             demoter;
 12 
 13   // +--- Constructor ---+
 14   function new(string name="base_test", uvm_component parent=null);
 15     super.new(name, parent);
 16   endfunction: new
 17 
 18   // +--- Constraints ---+
 19   constraint base_test_c {
 20   } // base_test_c
 21 
 22   // +--- UVM Phases ---+
 23   virtual function void build_phase(uvm_phase phase);
 24 
 25     `uvm_info("build_phase", $sformatf("%0s::build_phase() --> Start", get_type_name()), UVM_DEBUG)
 26 
 27     super.build_phase(phase);
 28     cfg     = system_configuration::type_id::create("cfg");
 29     env     = system_environment::type_id::create("env", this);
 30     demoter = system_demoter::type_id::create("demoter", this);
 31 
 32     if (! uvm_config_db#(all_vif)::get(this, "", "vif", all_if)) begin
 33       `uvm_fatal("VIF_ERR", $sformatf("Failed to get vif for %0s.", get_type_name()))
 34     end
 35 
 36     // NOTE: if do cfg.randomize() then no constraint from test class will be applied
 37     if (! randomize(cfg)) begin
 38       cfg.print();
 39       `uvm_fatal("RAND_ERR", $sformatf("Failed to randomize %0s.", cfg.get_name()))
 40     end
 41     cfg.print();
 42 
 43 `ifdef SNPS_APB_VIP_EN
 44     uvm_config_db#(uvm_object_wrapper)::set(this, "env.apb_slave_env.slave*.sequencer.run_phase", "default_sequence", apb_slave_random_response_sequence::type_id::get());
 45 `endif // SNPS_APB_VIP_EN
 46 
 47     uvm_report_cb::add(null, demoter);
 48 
 49     env.set_if(all_if);
 50     env.set_cfg(cfg);
 51 
 52     `uvm_info("build_phase", $sformatf("%0s::build_phase() --> End", get_type_name()), UVM_DEBUG)
 53 
 54   endfunction: build_phase
 55 
 56   virtual function void connect_phase(uvm_phase phase);
 57     `uvm_info("connect_phase", $sformatf("%0s::connect_phase() --> Start", get_type_name()), UVM_DEBUG)
 58 
 59     super.connect_phase(phase);
 60 
 61     sequencer = env.get_sequencer();
 62 
 63     `uvm_info("connect_phase", $sformatf("%0s::connect_phase() --> End", get_type_name()), UVM_DEBUG)
 64   endfunction: connect_phase
 65 
 66   virtual function void end_of_elaboration_phase(uvm_phase phase);
 67     uvm_table_printer printer = new();
 68 
 69     `uvm_info("end_of_elaboration_phase", $sformatf("%0s::end_of_elaboration_phase() --> Start", get_type_name()), UVM_DEBUG)
 70 
 71     printer.knobs.depth     = 3;
 72     printer.knobs.indent    = 2;
 73     printer.knobs.bin_radix = "0b";
 74     printer.knobs.hex_radix = "0x";
 75     super.end_of_elaboration_phase(phase);
 76     uvm_top.print_topology(printer);
 77 
 78     `uvm_info("end_of_elaboration_phase", $sformatf("%0s::end_of_elaboration_phase() --> End", get_type_name()), UVM_DEBUG)
 79   endfunction: end_of_elaboration_phase
 80 
 81   virtual function void report_phase(uvm_phase phase);
 82     int warning_cnt, error_cnt;
 83     uvm_report_server server;
 84 
 85     `uvm_info("report_phase", $sformatf("%0s::report_phase() --> Start", get_type_name()), UVM_DEBUG)
 86 
 87     super.report_phase(phase);
 88 
 89     server = uvm_report_server::get_server();
 90     error_cnt = server.get_severity_count(UVM_FATAL) + server.get_severity_count(UVM_ERROR);
 91     warning_cnt = server.get_severity_count(UVM_WARNING);
 92 
 93     if (error_cnt > 0) begin
 94       `uvm_info("TEST_RESULT", "\n******** UVM TEST FAIL ********\n", UVM_NONE)
 95     end
 96     else begin
 97       if (warning_cnt > 0) begin
 98         `uvm_info("TEST_RESULT", "\n******** UVM TEST PASS (with UVM_WARNING) ********\n", UVM_NONE)
 99       end
100       else begin
101         `uvm_info("TEST_RESULT", "\n******** UVM TEST PASS ********\n", UVM_NONE)
102       end
103     end
104 
105     `uvm_info("report_phase", $sformatf("%0s::report_phase() --> End", get_type_name()), UVM_DEBUG)
106   endfunction: report_phase
107 
108 endclass: base_test
109 
110 `endif // __GUARD_BASE_TEST_SV__
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
~                                                                                                                                                                                           
