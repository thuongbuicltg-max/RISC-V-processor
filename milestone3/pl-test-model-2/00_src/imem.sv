module imem (
    input  logic [31:0] i_addr,
    output logic [31:0] o_rdata
);
    parameter MEM_SIZE = 8191;

    logic [31:0] mem [0:MEM_SIZE-1];
    assign o_rdata = mem[i_addr[12:2]];


   initial begin
   integer i;
   for (i=0; i < 3000 ; i++) mem[i] = 32'b0; 
   $readmemh("../02_test/isa_4b.hex",mem);
  end
endmodule 