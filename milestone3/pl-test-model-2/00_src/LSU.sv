/* module LSU
(
  input  logic        i_clk,
  input  logic        i_reset,
  input  logic [31:0] i_lsu_addr,   // byte address
  input  logic [31:0] i_st_data,    // store payload
  input  logic        i_lsu_wren,   // write enable
  input  logic [31:0] i_io_sw,      // external switches (input)
  input  logic [2:0]  i_funct3,     // RISC-V size/extend field for load/store
  output logic [31:0] o_ld_data,    // LSU readback muxed with peripherals
  output logic [31:0] o_io_ledr,    // peripheral: red LEDs
  output logic [31:0] o_io_ledg,    // peripheral: green LEDs
  output logic [31:0] o_io_lcd,     // peripheral: LCD
  output logic [6:0]  o_io_hex0,o_io_hex1,o_io_hex2,o_io_hex3, // 7-seg lower bank
  output logic [6:0]  o_io_hex4,o_io_hex5,o_io_hex6,o_io_hex7  // 7-seg upper bank
);

  // ===== Buffers =====
  // Latched peripheral state (mirrors memory-mapped writes)
  logic [31:0] buf_ledr, buf_ledg, buf_seg_lo, buf_seg_hi, buf_lcd, buf_switch;

  // Peripheral outputs (directly driven by buffers)
  assign o_io_ledr = buf_ledr;
  assign o_io_ledg = buf_ledg;
  assign o_io_lcd  = buf_lcd;

  // Seven-seg (4 digits low) — packed 7-bit glyphs in buf_seg_lo
  assign o_io_hex0 = buf_seg_lo[ 6:0];
  assign o_io_hex1 = buf_seg_lo[14:8];
  assign o_io_hex2 = buf_seg_lo[22:16];
  assign o_io_hex3 = buf_seg_lo[30:24];

  // Seven-seg (4 digits high) — packed 7-bit glyphs in buf_seg_hi
  assign o_io_hex4 = buf_seg_hi[ 6:0];
  assign o_io_hex5 = buf_seg_hi[14:8];
  assign o_io_hex6 = buf_seg_hi[22:16];
  assign o_io_hex7 = buf_seg_hi[30:24];

  // ===== Address decode =====
  // Simple region map for DMEM and peripherals
  logic mem, led_r, led_g, seg03, seg47, lcd, switch, rsv;
  assign mem   = (i_lsu_addr[31:16] == 16'h0000) ;                  													// 0000_0000..0000_FFFF (DMEM window)
  assign led_r =  i_lsu_addr[28] & ~(|i_lsu_addr[27:12]);                                                                // 1000_0000..1000_0FFF (LED R)
  assign led_g =  i_lsu_addr[28] & ~(|i_lsu_addr[27:13]) &  i_lsu_addr[12];                                              // 1000_1000..1000_1FFF (LED G)
  assign seg03 =  i_lsu_addr[28] & ~(|i_lsu_addr[27:14]) &  i_lsu_addr[13];                                              // 1000_2000..1000_2FFF (7-seg low)
  assign seg47 =  i_lsu_addr[28] & ~(|i_lsu_addr[27:14]) &  i_lsu_addr[13] & i_lsu_addr[12];                             // 1000_3000..1000_3FFF (7-seg high)
  assign lcd   =  i_lsu_addr[28] & ~(|i_lsu_addr[27:15]) &  i_lsu_addr[14];                                              // 1000_4000..1000_4FFF (LCD)
  assign switch=  i_lsu_addr[28] & ~(|i_lsu_addr[27:17]) &  i_lsu_addr[16] & ~(|i_lsu_addr[15:12]);                      // 1001_0000..1001_0FFF (switches)
  assign rsv  = ~(mem|led_r|led_g|seg03|seg47|lcd|switch);                                                         // everything else

  // ===== DMEM truy cập bằng địa chỉ đã căn =====
  // Data path signals to/from DMEM
  logic [31:0] read_data;
  logic [31:0] data_write;
  logic [3:0]  bmask;

  // ===== DMEM =====
  // 2 KiB DMEM — supports misaligned access via internal 64-bit windowing
  memory dmem (
    .i_clk   (i_clk),
    .i_reset (i_reset),
    .i_addr    (i_lsu_addr[15:0]),     // start at byte address; misaligned allowed
    .i_wdata (data_write),           // write payload (pre-shifted/packed by LSU)
    .i_bmask (bmask),                // byte enable mask (0001/0011/1111)
    .i_wren  (i_lsu_wren & mem),     // write only within DMEM region
    .o_rdata (read_data)             // read data (32-bit window)
  );

  //=============STORE================
  // Pre-format SB/SH data (dw1) vs SW (dw2), then gate by en_write
  wire [31:0] dw1 = {16'b0, ({8{i_funct3[0]}} & i_st_data[15:8]), i_st_data[7:0]};
  wire [31:0] dw2 = i_st_data;
  wire [31:0] dw3;

  // Enable for SB/SH/SW only, and only when write + DMEM region
  wire en_write = (~i_funct3[2] & (~i_funct3[1] | (i_funct3[1] & ~i_funct3[0]))) 
                  & i_lsu_wren & mem;  // SB/SH/SW & enable

  // Select SB/SH (dw1) when funct3[1]==0, else SW (dw2)
  mux2 #(32) u1(.s0(dw1), .s1(dw2), .sel(i_funct3[1]), .y(dw3));
  // Final gate by en_write (0 → write zeros; 1 → write dw3)
  mux2 #(32) u2(.s0(32'h0), .s1(dw3), .sel(en_write), .y(data_write));

  // Byte-enable mask: SB=0001, SH=0011, SW=1111 (ANDed with write+region)
  assign bmask[3:2] = {2{~i_funct3[2] &  i_funct3[1] & ~i_funct3[0] & i_lsu_wren & mem}}; // SW
  assign bmask[1]   =  ~i_funct3[2] & (i_funct3[1]^ i_funct3[0]) & i_lsu_wren & mem;      // SH, SW
  assign bmask[0]   =  en_write;                                                          // SB, SH, SW

  // ===== LOAD path  =====
  // NOTE: The following selects the *low* byte/half from read_data.
  // If byte/half misaligned selection is required, add offseting by i_lsu_addr[1:0].
  // read_data: 32-bit word window aligned to i_lsu_addr[31:2]
  logic [7:0]  byte_sel;  // selected byte (low 8 bits)
  logic [15:0] half_sel;  // selected halfword (low 16 bits)

  assign  byte_sel = read_data[7:0];        // LB/LBU use low byte
  assign  half_sel = read_data[15:0];       // LH/LHU use low halfword

  // Extend/zero-extend per funct3
  logic [31:0] mem_load;
  always_comb begin
    unique case (i_funct3)
      3'b000: mem_load = {{24{byte_sel[7]}}, byte_sel}; // LB  (sign-extend from 8b)
      3'b100: mem_load = {24'b0,             byte_sel}; // LBU (zero-extend)
      3'b001: mem_load = {{16{half_sel[15]}}, half_sel}; // LH  (sign-extend from 16b)
      3'b101: mem_load = {16'b0,             half_sel};  // LHU (zero-extend)
      3'b010: mem_load = read_data;                      // LW  (32b)
      default: mem_load = read_data;                     // default: pass-through
    endcase
  end

  // ===== Kết quả load tổng hợp =====
  // Final readback mux across DMEM and all peripherals (priority-less OR masking)
  assign o_ld_data = ({32{mem}}    & mem_load)   |
                     ({32{switch}} & buf_switch) |
                     ({32{led_r}}  & buf_ledr)   |
                     ({32{led_g}}  & buf_ledg)   |
                     ({32{seg03}}  & buf_seg_lo) |
                     ({32{seg47}}  & buf_seg_hi) |
                     ({32{lcd}}    & buf_lcd);

  // ===== Ghi vào buffers (ngoại vi) =====
  // Synchronous peripheral writes; switches sampled every cycle
  always_ff @(posedge i_clk or posedge i_reset) begin
    if (i_reset) begin
      buf_ledr   <= 32'b0;
      buf_ledg   <= 32'b0;
      buf_seg_lo <= 32'b0;
      buf_seg_hi <= 32'b0;
      buf_lcd    <= 32'b0;
      buf_switch <= 32'b0;
    end else begin
      buf_switch <= i_io_sw; // sample input each cycle

      if (i_lsu_wren) begin
        if      (led_r)  buf_ledr   <= i_st_data;
        else if (led_g)  buf_ledg   <= i_st_data;
        else if (seg03)  buf_seg_lo <= i_st_data;
        else if (seg47)  buf_seg_hi <= i_st_data;
        else if (lcd)    buf_lcd    <= i_st_data;
      end
    end
  end

endmodule */
//===================================LSU===================================
module LSU
(
  input  logic        i_clk,
  input  logic        i_reset,
  input  logic [31:0] i_lsu_addr,   // byte address
  input  logic [31:0] i_st_data,    // store payload
  input  logic        i_lsu_wren,   // write enable
  input  logic [31:0] i_io_sw,      // external switches (input)
  input  logic [2:0]  i_funct3,     // RISC-V size/extend field for load/store
  output logic [31:0] o_ld_data,    // LSU readback muxed with peripherals
  output logic [31:0] o_io_ledr,    // peripheral: red LEDs
  output logic [31:0] o_io_ledg,    // peripheral: green LEDs
  output logic [31:0] o_io_lcd,     // peripheral: LCD
  output logic [6:0]  o_io_hex0,o_io_hex1,o_io_hex2,o_io_hex3, // 7-seg lower bank
  output logic [6:0]  o_io_hex4,o_io_hex5,o_io_hex6,o_io_hex7  // 7-seg upper bank
);

  // ===== Buffers =====
  // Latched peripheral state (mirrors memory-mapped writes)
  logic [31:0] buf_ledr, buf_ledg, buf_seg_lo, buf_seg_hi, buf_lcd, buf_switch;

  // Peripheral outputs (directly driven by buffers)
  assign o_io_ledr = buf_ledr;
  assign o_io_ledg = buf_ledg;
  assign o_io_lcd  = buf_lcd;

  // Seven-seg (4 digits low) — packed 7-bit glyphs in buf_seg_lo
  assign o_io_hex0 = buf_seg_lo[ 6:0];
  assign o_io_hex1 = buf_seg_lo[14:8];
  assign o_io_hex2 = buf_seg_lo[22:16];
  assign o_io_hex3 = buf_seg_lo[30:24];

  // Seven-seg (4 digits high) — packed 7-bit glyphs in buf_seg_hi
  assign o_io_hex4 = buf_seg_hi[ 6:0];
  assign o_io_hex5 = buf_seg_hi[14:8];
  assign o_io_hex6 = buf_seg_hi[22:16];
  assign o_io_hex7 = buf_seg_hi[30:24];

  // ===== Address decode =====
  // Simple region map for DMEM and peripherals
  logic mem, led_r, led_g, seg03, seg47, lcd, switch, rsv;
  assign mem   = (i_lsu_addr[31:16] == 16'h0000) ;                  																		 // 0000_0000..0000_FFFF (DMEM window)
  assign led_r =  i_lsu_addr[28] & ~(|i_lsu_addr[27:12]);                                                                // 1000_0000..1000_0FFF (LED R)
  assign led_g =  i_lsu_addr[28] & ~(|i_lsu_addr[27:13]) &  i_lsu_addr[12];                                              // 1000_1000..1000_1FFF (LED G)
  assign seg03 =  i_lsu_addr[28] & ~(|i_lsu_addr[27:14]) &  i_lsu_addr[13];                                              // 1000_2000..1000_2FFF (7-seg low)
  assign seg47 =  i_lsu_addr[28] & ~(|i_lsu_addr[27:14]) &  i_lsu_addr[13] & i_lsu_addr[12];                             // 1000_3000..1000_3FFF (7-seg high)
  assign lcd   =  i_lsu_addr[28] & ~(|i_lsu_addr[27:15]) &  i_lsu_addr[14];                                              // 1000_4000..1000_4FFF (LCD)
  assign switch=  i_lsu_addr[28] & ~(|i_lsu_addr[27:17]) &  i_lsu_addr[16] & ~(|i_lsu_addr[15:12]);                      // 1001_0000..1001_0FFF (switches)
  assign rsv  = ~(mem|led_r|led_g|seg03|seg47|lcd|switch);                                                         // everything else

  // ===== DMEM truy cập bằng địa chỉ đã căn =====
  // Data path signals to/from DMEM
  logic [31:0] read_data;
  logic [31:0] data_write;
  logic [3:0]  bmask;

  // ===== DMEM =====

  memory dmem (
    .i_clk   (i_clk),
    .i_reset (i_reset),
    .i_addr  (i_lsu_addr[15:0]),     // start at byte address; misaligned allowed
    .i_wdata (data_write),           // write payload (pre-shifted/packed by LSU)
    .i_bmask (bmask),                // byte enable mask (0001/0011/1111)
    .i_wren  (i_lsu_wren & mem),     // write only within DMEM region
    .o_rdata (read_data)             // read data (32-bit window)
  );

  //=============STORE================
  // Pre-format SB/SH data (dw1) vs SW (dw2), then gate by en_write
  wire [31:0] dw1 = {16'b0, ({8{i_funct3[0]}} & i_st_data[15:8]), i_st_data[7:0]};
  wire [31:0] dw2 = i_st_data;
  wire [31:0] dw3;

  // Enable for SB/SH/SW only, and only when write + DMEM region
  wire en_write = (~i_funct3[2] & (~i_funct3[1] | (i_funct3[1] & ~i_funct3[0]))) & i_lsu_wren;  // SB/SH/SW +dmem

  // Select SB/SH (dw1) when funct3[1]==0, else SW (dw2)
//  mux21_32bit u1(.a(dw1), .b(dw2), .sel(i_funct3[1]), .y(dw3)); //
  // Final gate by en_write (0 → write zeros; 1 → write dw3)
//  mux21_32bit u2(.a(32'h0), .b(dw3), .sel(en_write), .y(data_write));
  mux2 #(32) u1(.s0(dw1), .s1(dw2), .sel(i_funct3[1]), .y(dw3));
  // Final gate by en_write (0 → write zeros; 1 → write dw3)
  mux2 #(32) u2(.s0(32'h0), .s1(dw3), .sel(en_write), .y(data_write));
  // Byte-enable mask: SB=0001, SH=0011, SW=1111 (ANDed with write+region)
  assign bmask[3:2] = {2{~i_funct3[2] &  i_funct3[1] & ~i_funct3[0] & i_lsu_wren }}; // SW
  assign bmask[1]   =  ~i_funct3[2] & (i_funct3[1]^ i_funct3[0]) & i_lsu_wren;      // SH, SW
  assign bmask[0]   =   (~i_funct3[2] & (~i_funct3[1] | (i_funct3[1] & ~i_funct3[0]))) & i_lsu_wren; //

  logic [7:0]  byte_sel;  
  logic [15:0] half_sel;

  assign  byte_sel = read_data[7:0];        // LB/LBU use low byte
  assign  half_sel = read_data[15:0];       // LH/LHU use low halfword


  logic [31:0] mem_load;
  always_comb begin
    unique case (i_funct3)
      3'b000: mem_load = {{24{byte_sel[7]}}, byte_sel}; // LB  (sign-extend from 8b)
      3'b100: mem_load = {24'b0,             byte_sel}; // LBU (zero-extend)
      3'b001: mem_load = {{16{half_sel[15]}}, half_sel}; // LH  (sign-extend from 16b)
      3'b101: mem_load = {16'b0,             half_sel};  // LHU (zero-extend)
      3'b010: mem_load = read_data;                      // LW  (32b)
      default: mem_load = read_data;                     // default: pass-through
    endcase
  end

  // ===== Kết quả load tổng hợp =====
  // Final readback mux across DMEM and all peripherals (priority-less OR masking)
  assign o_ld_data = ({32{mem}}    & mem_load)   |
                     ({32{switch}} & buf_switch) |
                     ({32{led_r}}  & buf_ledr)   |
                     ({32{led_g}}  & buf_ledg)   |
                     ({32{seg03}}  & buf_seg_lo) |
                     ({32{seg47}}  & buf_seg_hi) |
                     ({32{lcd}}    & buf_lcd);

  // ===== Ghi vào buffers (ngoại vi) =====
  // Synchronous peripheral writes; switches sampled every cycle
  always_ff @(posedge i_clk or posedge i_reset) begin
    if (i_reset) begin
      buf_ledr   <= 32'b0;
      buf_ledg   <= 32'b0;
      buf_seg_lo <= 32'b0;
      buf_seg_hi <= 32'b0;
      buf_lcd    <= 32'b0;
      buf_switch <= 32'b0;
    end else begin
      buf_switch <= i_io_sw; // sample input each cycle

      if (i_lsu_wren) begin
        if      (led_r)  buf_ledr   <= i_st_data;
        else if (led_g)  buf_ledg   <= i_st_data;
        else if (seg03)  buf_seg_lo <= i_st_data;
        else if (seg47)  buf_seg_hi <= i_st_data;
        else if (lcd)    buf_lcd    <= i_st_data;
      end
    end
  end

endmodule

module memory
(
  input  logic        i_clk,
  input  logic        i_reset,          // optional clear for sim
  input  logic [15:0] i_addr,           // BYTE address [0..65535]
  input  logic [31:0] i_wdata,          // from LSU (SB/SH/SW packed, unshifted)
  input  logic [3:0]  i_bmask,          // 0001=SB, 0011=SH, 1111=SW
  input  logic        i_wren,
  output logic [31:0] o_rdata
);

  localparam int WORDS = 65536/4;       // 16384 words
  logic [31:0] mem [0:WORDS-1];

  // Word index & byte offset
  wire [13:0] wi   = i_addr[15:2];
  wire [1:0]  off  = i_addr[1:0];
  wire [13:0] wi_n = (wi == WORDS-1) ? wi : (wi + 14'd1);

  // READ: ghép 2 word rồi dịch
  wire [63:0] r64 = {mem[wi_n], mem[wi]} >> (off*8);

  // WRITE: shift payload & mask theo off
  wire [63:0] w64_shift = {32'b0, i_wdata} << (off*8);
  wire [31:0] w_lo      = w64_shift[31:0];
  wire [31:0] w_hi      = w64_shift[63:32];

  wire [7:0]  m8_shift  = {4'b0000, i_bmask} << off;
  wire [3:0]  be_lo     = m8_shift[3:0];
  wire [3:0]  be_hi     = m8_shift[7:4];

  wire [31:0] m_lo = { {8{be_lo[3]}}, {8{be_lo[2]}}, {8{be_lo[1]}}, {8{be_lo[0]}} };
  wire [31:0] m_hi = { {8{be_hi[3]}}, {8{be_hi[2]}}, {8{be_hi[1]}}, {8{be_hi[0]}} };

  // 👉 đơn giản, tin cậy: có byte nào map sang word trên không?
  wire two_word = |be_hi;

  integer k;
  always_ff @(posedge i_clk) begin
    if (i_reset) begin
      for (k = 0; k < WORDS; k++) mem[k] <= '0;
      o_rdata <= '0;
    end else begin
      if (i_wren) begin
        mem[wi] <= (mem[wi] & ~m_lo) | (w_lo & m_lo);
        if (two_word && (m_hi != 32'b0))
          mem[wi_n] <= (mem[wi_n] & ~m_hi) | (w_hi & m_hi);
      end
      o_rdata <= r64[31:0];  // sync read 
    end
  end 

endmodule 