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


// tb_dut_connect
  1 `ifndef __GUARD_TB_DUT_CONNECT_SV__
  2 `define __GUARD_TB_DUT_CONNECT_SV__
  3 
  4 `define CONNECT_APB_SLAVE(SLV_NUM)\
  5   .PS``SLV_NUM``_PSel    ( PSn_PSel   [``SLV_NUM``] ),\
  6   .PS``SLV_NUM``_PRData  ( PSn_PRData [``SLV_NUM``] ),\
  7   .PS``SLV_NUM``_PSlverr ( PSn_PSlverr[``SLV_NUM``] ),\
  8   .PS``SLV_NUM``_PReady  ( PSn_PReady [``SLV_NUM``] ),
  9 
 10   // +--- Intermediate Wires ---+
 11   wire [0:0]                            AClk;
 12   wire [0:0]                            AResetn;
 13   // DUT Slave AW
 14 `ifndef TB_AXI_MST_ID_WIDTH_0
 15   wire [(`TB_AXI_MST_ID_WIDTH-1):0]     AWId;
 16 `endif // TB_AXI_MST_ID_WIDTH_0
 17   wire [(`TB_AXI_MST_ADDR_WIDTH-1):0]   AWAddr;
 18   wire [(`TB_AXI_MST_LEN_WIDTH-1):0]    AWLen;
 19   wire [(`TB_AXI_MST_SIZE_WIDTH-1):0]   AWSize;
 20   wire [(`TB_AXI_MST_BURST_WIDTH-1):0]  AWBurst;
 21   wire [(`TB_AXI_MST_CACHE_WIDTH-1):0]  AWCache;
 22   wire [(`TB_AXI_MST_PROT_WIDTH-1):0]   AWProt;
 23   wire [(`TB_AXI_MST_LOCK_WIDTH-1):0]   AWLock;
 24   wire [0:0]                            AWValid;
 25   wire [0:0]                            AWReady;
 26 
 27   // DUT Slave AR
 28 `ifndef TB_AXI_MST_ID_WIDTH_0
 29   wire [(`TB_AXI_MST_ID_WIDTH-1):0]     ARId;
 30 `endif // TB_AXI_MST_ID_WIDTH_0
 31   wire [(`TB_AXI_MST_ADDR_WIDTH-1):0]   ARAddr;
 32   wire [(`TB_AXI_MST_LEN_WIDTH-1):0]    ARLen;
 33   wire [(`TB_AXI_MST_SIZE_WIDTH-1):0]   ARSize;
 34   wire [(`TB_AXI_MST_BURST_WIDTH-1):0]  ARBurst;
 35   wire [(`TB_AXI_MST_CACHE_WIDTH-1):0]  ARCache;
 36   wire [(`TB_AXI_MST_PROT_WIDTH-1):0]   ARProt;
 37   wire [(`TB_AXI_MST_LOCK_WIDTH-1):0]   ARLock;
 38   wire [0:0]                            ARValid;
 39 
 40   // DUT Slave W
 41 `ifndef TB_AXI_MST_AXI4
 42 `ifndef TB_AXI_MST_ID_WIDTH_0
 43   wire [(`TB_AXI_MST_ID_WIDTH-1):0]     WId;
 44 `endif // TB_AXI_MST_ID_WIDTH_0
 45 `endif // TB_AXI_MST_AXI4
 46 
 47   wire [(`TB_AXI_MST_DATA_WIDTH-1):0]   WData;
 48   wire [(`TB_AXI_MST_STRB_WIDTH-1):0]   WStrb;
 49   wire [0:0]                            WLast;
 50   wire [0:0]                            WValid;
 51   wire [0:0]                            WReady;
 52 
 53   // DUT Slave B
 54 `ifndef TB_AXI_MST_ID_WIDTH_0
 55   wire [(`TB_AXI_MST_ID_WIDTH-1):0]     BId;
 56 `endif //  TB_AXI_MST_ID_WIDTH_0
 57   wire [(`TB_AXI_MST_RESP_WIDTH-1):0]   BResp;
 58   wire [0:0]                            BValid;
 59   wire [0:0]                            BReady;
 60 
 61   // DUT Slave R
 62 `ifndef TB_AXI_MST_ID_WIDTH_0

 63   wire [(`TB_AXI_MST_ID_WIDTH-1):0]     RId;
 64 `endif
 65   wire [(`TB_AXI_MST_DATA_WIDTH-1):0]   RData;
 66   wire [(`TB_AXI_MST_RESP_WIDTH-1):0]   RResp;
 67   wire [0:0]                            RLast;
 68   wire [0:0]                            RValid;
 69   wire [0:0]                            RReady;
 70   wire [0:0]                            CActive;
 71   wire [0:0]                            CSysAck;
 72 
 73   wire [0:0]                            PClk;
 74   wire [0:0]                            PResetn;
 75   wire [(`TB_APB_MST_ADDR_WIDTH-1):0]   PAddr_reg;
 76   wire [2:0]                            PProt_reg;
 77   wire [0:0]                            PSel_reg;
 78   wire [0:0]                            PEnable_reg;
 79   wire [0:0]                            PWrite_reg;
 80   wire [(`TB_APB_MST_STRB_WIDTH-1):0]   PStrb_reg;
 81   wire [(`TB_APB_MST_DATA_WIDTH-1):0]   PWData_reg;
 82   wire [0:0]                            PReady_reg;
 83   wire [(`TB_APB_MST_DATA_WIDTH-1):0]   PRData_reg;
 84   wire [0:0]                            PSlverr_reg;
 85 
 86   wire [(`TB_APB_SLV_ADDR_WIDTH-1):0]   PAddr;
 87   wire [2:0]                            PProt;
 88   wire [0:0]                            PWrite;
 89   wire [(`TB_APB_SLV_STRB_WIDTH-1):0]   PStrb;
 90   wire [(`TB_APB_SLV_DATA_WIDTH-1):0]   PWData;
 91   wire [0:0]                            PEnable;
 92 
 93   wire [0:0]                            PSn_PSel[`TB_APB_NUM_SLAVES];
 94   wire [(`TB_APB_SLV_DATA_WIDTH-1):0]   PSn_PRData[`TB_APB_NUM_SLAVES];
 95   wire [0:0]                            PSn_PSlverr[`TB_APB_NUM_SLAVES];
 96   wire [0:0]                            PSn_PReady[`TB_APB_NUM_SLAVES];
 97 
 98   wire [0:0]                            DecErrIntr;
 99 
100   // +--- DUT Instantiation ---+
101   FTX2P030 DUT(
102     .AClk    ( AClk    ),
103     .AResetn ( AResetn ),
104 
105     .AWId    ( AWId    ),
106     .AWAddr  ( AWAddr  ),
107     .AWLen   ( AWLen   ),
108     .AWSize  ( AWSize  ),
109     .AWBurst ( AWBurst ),
110     .AWProt  ( AWProt  ),
111     .AWLock  ( AWLock  ),
112     .AWValid ( AWValid ),
113     .AWReady ( AWReady ),
114     // AR Channel
115     .ARId    ( ARId    ),
116     .ARAddr  ( ARAddr  ),
117     .ARLen   ( ARLen   ),
118     .ARSize  ( ARSize  ),
119     .ARBurst ( ARBurst ),
120     .ARProt  ( ARProt  ),
121     .ARLock  ( ARLock  ),
122     .ARValid ( ARValid ),
123     .ARReady ( ARReady ),
124     // W Channel
125 `ifndef TB_AXI_MST_AXI4
126     .WId     ( WId     ),
127 `endif // TB_AXI_MST_AXI4
128     .WData   ( WData  ),
129     .WStrb   ( WStrb  ),
130     .WLast   ( WLast  ),
131     .WValid  ( WValid ),
132     .WReady  ( WReady ),
133     // B Channel
134     .BId     ( BId    ),
135     .BResp   ( BResp  ),
136     .BValid  ( BValid ),
137     .BReady  ( BReady ),
138     // R Channel
139     .RId     ( RId    ),
140     .RData   ( RData  ),
141     .RResp   ( RResp  ),
142     .RLast   ( RLast  ),
143     .RValid  ( RValid ),
144     .RReady  ( RReady ),
145 
146     .CSysReq ( 1'b1    ),
147     .CActive ( CActive ),
148     .CSysAck ( CSysAck ),
149 
150     .PClk    ( PClk    ),
151     .PResetn ( PResetn ),
152 
153     // APB Master Interfaces
154     .PAddr   ( PAddr   ),
155     .PProt   ( PProt   ),
156     .PWrite  ( PWrite  ),
157     .PStrb   ( PStrb   ),
158     .PWData  ( PWData  ),
159     .PEnable ( PEnable ),
160 
161     `CONNECT_APB_SLAVE(0)
162     `ifdef FTX2P030_APB_SLAVE1_ON  `CONNECT_APB_SLAVE(1) `endif
163     `ifdef FTX2P030_APB_SLAVE2_ON  `CONNECT_APB_SLAVE(2) `endif
164     `ifdef FTX2P030_APB_SLAVE3_ON  `CONNECT_APB_SLAVE(3) `endif
165     `ifdef FTX2P030_APB_SLAVE4_ON  `CONNECT_APB_SLAVE(4) `endif
166     `ifdef FTX2P030_APB_SLAVE5_ON  `CONNECT_APB_SLAVE(5) `endif
167     `ifdef FTX2P030_APB_SLAVE6_ON  `CONNECT_APB_SLAVE(6) `endif
168     `ifdef FTX2P030_APB_SLAVE7_ON  `CONNECT_APB_SLAVE(7) `endif
169     `ifdef FTX2P030_APB_SLAVE8_ON  `CONNECT_APB_SLAVE(8) `endif
170     `ifdef FTX2P030_APB_SLAVE9_ON  `CONNECT_APB_SLAVE(9) `endif
171     `ifdef FTX2P030_APB_SLAVE10_ON `CONNECT_APB_SLAVE(10) `endif
172     `ifdef FTX2P030_APB_SLAVE11_ON `CONNECT_APB_SLAVE(11) `endif
173     `ifdef FTX2P030_APB_SLAVE12_ON `CONNECT_APB_SLAVE(12) `endif
174     `ifdef FTX2P030_APB_SLAVE13_ON `CONNECT_APB_SLAVE(13) `endif
175     `ifdef FTX2P030_APB_SLAVE14_ON `CONNECT_APB_SLAVE(14) `endif
176     `ifdef FTX2P030_APB_SLAVE15_ON `CONNECT_APB_SLAVE(15) `endif
177     `ifdef FTX2P030_APB_SLAVE16_ON `CONNECT_APB_SLAVE(16) `endif
178     `ifdef FTX2P030_APB_SLAVE17_ON `CONNECT_APB_SLAVE(17) `endif
179     `ifdef FTX2P030_APB_SLAVE18_ON `CONNECT_APB_SLAVE(18) `endif
180     `ifdef FTX2P030_APB_SLAVE19_ON `CONNECT_APB_SLAVE(19) `endif
181     `ifdef FTX2P030_APB_SLAVE20_ON `CONNECT_APB_SLAVE(20) `endif
182     `ifdef FTX2P030_APB_SLAVE21_ON `CONNECT_APB_SLAVE(21) `endif
183     `ifdef FTX2P030_APB_SLAVE22_ON `CONNECT_APB_SLAVE(22) `endif
184     `ifdef FTX2P030_APB_SLAVE23_ON `CONNECT_APB_SLAVE(23) `endif
185     `ifdef FTX2P030_APB_SLAVE24_ON `CONNECT_APB_SLAVE(24) `endif
186     `ifdef FTX2P030_APB_SLAVE25_ON `CONNECT_APB_SLAVE(25) `endif
187     `ifdef FTX2P030_APB_SLAVE26_ON `CONNECT_APB_SLAVE(26) `endif
188     `ifdef FTX2P030_APB_SLAVE27_ON `CONNECT_APB_SLAVE(27) `endif
189     `ifdef FTX2P030_APB_SLAVE28_ON `CONNECT_APB_SLAVE(28) `endif
190     `ifdef FTX2P030_APB_SLAVE29_ON `CONNECT_APB_SLAVE(29) `endif
191     `ifdef FTX2P030_APB_SLAVE30_ON `CONNECT_APB_SLAVE(30) `endif
192     `ifdef FTX2P030_APB_SLAVE31_ON `CONNECT_APB_SLAVE(31) `endif
193 
194     // APB Slave Interface
195     .PAddr_reg   ( PAddr_reg   ),
196     .PProt_reg   ( PProt_reg   ),
197     .PSel_reg    ( PSel_reg    ),
198     .PEnable_reg ( PEnable_reg ),
199     .PWrite_reg  ( PWrite_reg  ),
200     .PStrb_reg   ( PStrb_reg   ),
201     .PWData_reg  ( PWData_reg  ),
202     .PReady_reg  ( PReady_reg  ),
203     .PRData_reg  ( PRData_reg  ),
204     .PSlverr_reg ( PSlverr_reg ),
205 
206     .DecErrIntr  ( DecErrIntr )
207   );
208 

