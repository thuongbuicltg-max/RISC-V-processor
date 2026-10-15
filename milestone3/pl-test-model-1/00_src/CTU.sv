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

// clk_rst_if

 1 `ifndef CLK_RST_IF_SV
  2 `define CLK_RST_IF_SV
  3 
  4 `timescale 1ns/1ps
  5 
  6 // verilog_lint: waive-start package-filename
  7 package clk_rst_if_pkg;
  8 
  9   typedef enum bit [1:0] {
 10     SYNC_ASSERT_SYNC_DEASSERT   = 0,
 11     SYNC_ASSERT_ASYNC_DEASSERT  = 1,
 12     ASYNC_ASSERT_SYNC_DEASSERT  = 2,
 13     ASYNC_ASSERT_ASYNC_DEASSERT = 3
 14   } reset_scheme_e;
 15 
 16   typedef virtual interface clk_rst_if clk_rst_vif;
 17 
 18 endpackage: clk_rst_if_pkg
 19 // verilog_lint: waive-end
 20 
 21 interface clk_rst_if #(
 22     parameter string        NAME            = "clk_rst_if",
 23     parameter bit           ACTIVE_CLK      = 1,
 24     parameter int unsigned  NUM_RESET_PORTS = 16
 25 ) ( 
 26     input  logic                        clk_in,
 27     output logic                        clk,
 28     output logic [NUM_RESET_PORTS-1:0]  reset,
 29     output logic [NUM_RESET_PORTS-1:0]  reset_n
 30 );
 31 
 32   import clk_rst_if_pkg::*;
 33 
 34   string                      __name__               = NAME;
 35   bit                         __active_clk__         = ACTIVE_CLK;
 36   int unsigned                __num_reset_ports__    = NUM_RESET_PORTS;
 37   bit                         __clk_enabled__        = 0;
 38   real                        __clk_period_ns__      = 0;
 39   reset_scheme_e              __reset_scheme__       = SYNC_ASSERT_SYNC_DEASSERT;
 40   wire                        __internal_clk__       = 1'bz;
 41   logic [NUM_RESET_PORTS-1:0] __internal_reset__     = {NUM_RESET_PORTS{1'bz}};
 42   bit                         __clk_rise_on_enable__ = 1;
 43 
 44   assign reset            = __internal_reset__;
 45   assign reset_n          = ~reset;
 46   assign __internal_clk__ = (__active_clk__) ? clk : clk_in;
 47 
 48   clocking reset_cb@(posedge __internal_clk__);
 49     output __internal_reset__;
 50   endclocking: reset_cb
 51 
 52   function automatic string get_name();
 53     return __name__;
 54   endfunction: get_name
 55 
 56   function automatic int unsigned get_num_reset_ports();
 57     return __num_reset_ports__;
 58   endfunction: get_num_reset_ports
 59 
 60   function automatic void set_reset_scheme(input reset_scheme_e i_reset_scheme);
 61     $display("[%0s] Setting Reset Scheme to: %0s", __name__, __reset_scheme__.name());
 62     __reset_scheme__ = i_reset_scheme;
 63   endfunction: set_reset_scheme
 64 
 65   function automatic reset_scheme_e get_reset_scheme();
 66     return __reset_scheme__;
 67   endfunction: get_reset_scheme
 68 
 69   function automatic void set_freq_khz(input real i_freq_khz);
 70     if (__active_clk__) begin
 71       $display("[%0s] Setting Clock Frequency to: %0f kHz", __name__, i_freq_khz);
 72       __clk_period_ns__ = get_clk_period_ns(.i_freq_khz(i_freq_khz));
 73       $display("[%0s] Calculated Clock Period: %0f ns", __name__, __clk_period_ns__);
 74     end
 75     else begin
 76       $fatal(1, "[%0s] Cannot set clock frequency since this interface does not have active clock.", __name__);
 77     end
 78   endfunction: set_freq_khz
 79 
 80   function automatic void set_freq_mhz(input real i_freq_mhz);
 81     if (__active_clk__) begin
 82       $display("[%0s] Setting Clock Frequency to: %0f MHz", __name__, i_freq_mhz);
 83       __clk_period_ns__ = get_clk_period_ns(.i_freq_khz(i_freq_mhz*1000));
 84       $display("[%0s] Calculated Clock Period: %0f ns", __name__, __clk_period_ns__);
 85     end
 86     else begin
 87       $fatal(1, "[%0s] Cannot set clock frequency since this interface does not have active clock.", __name__);
 88     end
 89   endfunction: set_freq_mhz
 90 
 91   function automatic void enable_clk();
 92     if (__active_clk__) begin
 93       if (__clk_period_ns__ > 0) begin
 94         $display("[%0s] Enable Clock", __name__);
 95         __clk_enabled__ = 1;
 96       end else begin
 97         $fatal(1, "[%0s] Cannot enable clock when frequency is not set. Please use <clk_rst_if_name>.set_freq_<khz|mhz>() before enable_clk().", __name__);
 98       end
 99     end
100     else begin
101       $fatal(1, "[%0s] Cannot enable clock since this interface does not have active clock.", __name__);
102     end
103   endfunction: enable_clk
104 
105   function automatic void disable_clk();
106     if (__active_clk__) begin
107       $display("[%0s] Disable Clock", __name__);
108       __clk_enabled__ = 0;
109     end
110     else begin
111       $fatal(1, "[%0s] Cannot disable clock since this interface does not have active clock.", __name__);
112     end
113   endfunction: disable_clk
114 
115   function automatic void set_clk_rise_on_enable(bit enable=1);
116     $display("[%0s] Set Clock Rise on Enable: %0d", __name__, enable);
117     __clk_rise_on_enable__ = enable;
118   endfunction: set_clk_rise_on_enable
119 
120   function automatic bit get_clk_rise_on_enable();
121     return __clk_rise_on_enable__;
122   endfunction: get_clk_rise_on_enable
123 
124   task automatic assert_reset(input int reset_port_num = -1);
125     if (reset_port_num >= int'(__num_reset_ports__)) begin
126       $fatal(1, "[%0s] Cannot assert reset to unexistent port number %0d. This interface only has reset port 0-%0d.", __name__, reset_port_num, (__num_reset_ports__ - 1));
127     end
128     $display("[%0s] Assert Reset", __name__);
129     if (get_reset_scheme() inside {ASYNC_ASSERT_SYNC_DEASSERT, ASYNC_ASSERT_ASYNC_DEASSERT}) begin
130       if (reset_port_num != -1) begin
131         __internal_reset__[reset_port_num] <= 1'b1;
132       end else begin
133         __internal_reset__ <= {NUM_RESET_PORTS{1'b1}};
134       end
135     end
136     else begin
137       if (reset_port_num != -1) begin
138         reset_cb.__internal_reset__[reset_port_num] <= 1'b1;
139       end else begin
140         reset_cb.__internal_reset__ <= {NUM_RESET_PORTS{1'b1}};
141       end
142     end
143   endtask: assert_reset
144 
145   task automatic deassert_reset(input int reset_port_num = -1);
146     if (reset_port_num >= int'(__num_reset_ports__)) begin
147       $fatal(1, "[%0s] Cannot deassert reset to unexistent port number %0d. This interface only has reset port 0-%0d.", __name__, reset_port_num, (__num_reset_ports__ - 1));
    end
149     $display("[%0s] Deassert Reset", __name__);
150     if (get_reset_scheme() inside {SYNC_ASSERT_ASYNC_DEASSERT, ASYNC_ASSERT_ASYNC_DEASSERT}) begin
151       if (reset_port_num != -1) begin
152         __internal_reset__[reset_port_num] <= 1'b0;
153       end else begin
154         __internal_reset__ <= {NUM_RESET_PORTS{1'b0}};
155       end
156     end
157     else begin
158       if (reset_port_num != -1) begin
159         reset_cb.__internal_reset__[reset_port_num] <= 1'b0;
160       end else begin
161         reset_cb.__internal_reset__ <= {NUM_RESET_PORTS{1'b0}};
162       end
163     end
164   endtask: deassert_reset
165 
166   task automatic apply_reset(input int reset_port_num = -1, int unsigned reset_cycle = 5);
167     int async_delay = $urandom_range(1, int'(__clk_period_ns__/2));
168 
169     if (__active_clk__ && (!__clk_enabled__)) begin
170       $fatal(1, "[%0s] Cannot apply reset when clock is inactive. Please use <clk_rst_if_name>.enable_clk() before apply_reset().", __name__);
171     end
172 
173     @(posedge __internal_clk__);
174     if (__reset_scheme__ == ASYNC_ASSERT_SYNC_DEASSERT || __reset_scheme__ == ASYNC_ASSERT_ASYNC_DEASSERT) begin
175       #(async_delay * 1ns);
176     end
177 
178     assert_reset(reset_port_num);
179 
180     repeat(reset_cycle) begin
181       @(posedge __internal_clk__);
182     end
183 
184     if (__reset_scheme__ == SYNC_ASSERT_ASYNC_DEASSERT || __reset_scheme__ == ASYNC_ASSERT_ASYNC_DEASSERT) begin
185       #(async_delay * 1ns);
186     end
187 
188     // Deassert reset
189     deassert_reset(reset_port_num);
190 
191   endtask: apply_reset
192 
193   // Clock gen block
194   initial begin
195     if (__active_clk__) begin
196       clk = 1'b0;
197       forever begin
198         if (__clk_enabled__) begin
199           #(__clk_period_ns__ / 2.0) clk = ~clk;
200         end else begin
201           clk = 1'b0;
202           wait(__clk_enabled__);
203           if (get_clk_rise_on_enable()) clk = 1'b1;
204         end
205       end  // forever
206     end // if (__active_clk__)
207     else begin
208       clk = 1'bz;
209     end
210   end  // initial
211 
212   // Reset gen block
213   initial begin
214     __internal_reset__ = {NUM_RESET_PORTS{1'b0}};
215   end
216 
217   function automatic realtime get_clk_period_ns(input real i_freq_khz);
218     return real'((1.0/i_freq_khz) * 1_000_000) * 1ns;
219   endfunction: get_clk_period_ns
220 
221 endinterface: clk_rst_if
222 
223 `endif  // CLK_RST_IF_SV
    end
149     $display("[%0s] Deassert Reset", __name__);
150     if (get_reset_scheme() inside {SYNC_ASSERT_ASYNC_DEASSERT, ASYNC_ASSERT_ASYNC_DEASSERT}) begin
151       if (reset_port_num != -1) begin
152         __internal_reset__[reset_port_num] <= 1'b0;
153       end else begin
154         __internal_reset__ <= {NUM_RESET_PORTS{1'b0}};
155       end
156     end
157     else begin
158       if (reset_port_num != -1) begin
159         reset_cb.__internal_reset__[reset_port_num] <= 1'b0;
160       end else begin
161         reset_cb.__internal_reset__ <= {NUM_RESET_PORTS{1'b0}};
162       end
163     end
164   endtask: deassert_reset
165 
166   task automatic apply_reset(input int reset_port_num = -1, int unsigned reset_cycle = 5);
167     int async_delay = $urandom_range(1, int'(__clk_period_ns__/2));
168 
169     if (__active_clk__ && (!__clk_enabled__)) begin
170       $fatal(1, "[%0s] Cannot apply reset when clock is inactive. Please use <clk_rst_if_name>.enable_clk() before apply_reset().", __name__);
171     end
172 
173     @(posedge __internal_clk__);
174     if (__reset_scheme__ == ASYNC_ASSERT_SYNC_DEASSERT || __reset_scheme__ == ASYNC_ASSERT_ASYNC_DEASSERT) begin
175       #(async_delay * 1ns);
176     end
177 
178     assert_reset(reset_port_num);
179 
180     repeat(reset_cycle) begin
181       @(posedge __internal_clk__);
182     end
183 
184     if (__reset_scheme__ == SYNC_ASSERT_ASYNC_DEASSERT || __reset_scheme__ == ASYNC_ASSERT_ASYNC_DEASSERT) begin
185       #(async_delay * 1ns);
186     end
187 
188     // Deassert reset
189     deassert_reset(reset_port_num);
190 
191   endtask: apply_reset
192 
193   // Clock gen block
194   initial begin
195     if (__active_clk__) begin
196       clk = 1'b0;
197       forever begin
198         if (__clk_enabled__) begin
199           #(__clk_period_ns__ / 2.0) clk = ~clk;
200         end else begin
201           clk = 1'b0;
202           wait(__clk_enabled__);
203           if (get_clk_rise_on_enable()) clk = 1'b1;
204         end
205       end  // forever
206     end // if (__active_clk__)
207     else begin
208       clk = 1'bz;
209     end
210   end  // initial
211 
212   // Reset gen block
213   initial begin
214     __internal_reset__ = {NUM_RESET_PORTS{1'b0}};
215   end
216 
217   function automatic realtime get_clk_period_ns(input real i_freq_khz);
218     return real'((1.0/i_freq_khz) * 1_000_000) * 1ns;
219   endfunction: get_clk_period_ns
220 
221 endinterface: clk_rst_if
222 
223 `endif  // CLK_RST_IF_SV
                                                                                                                                                                                                                                                                                                           223,3         Bot
                                                                                                                                                                                                                                                                                                           223,3         Bot
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         1,3           Top

