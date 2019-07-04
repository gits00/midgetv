/* -----------------------------------------------------------------------------
 * Part of midgetv
 * 2019. Copyright B. Nossum.
 * For licence, see LICENCE
 * -----------------------------------------------------------------------------
 * Microcode program counter
 * 
 * usedinx_or_RST_I-------------------------+
 *                                ____      |
 * dinx[7:2] --------------------| or |     |
 * illegal_or_qualint_or_RST_I --|____|----|1\
 *                                         |  |--- minx[7:2]
 * rinx[7:2] ------------------------------|0/
 * 
 * usedinx_or_RST_I-------------------------+
 *                       ____               |
 * dinx[1] -------------| or |   ___        |
 * illegal_or_qualint_--|____|--| & |------|1\
 * RST_I-----------------------o|___|      |  |--- minx[1]
 * rinx[1] --------------------------------|0/
 * 
 * usedinx_or_RST_I ------------------------+
 *                                          |
 * illegal_or_qualint_or_RST_I --+          |
 * qualint_or_RST_I ------------|1\         |
 *                              |  |-------|1\
 * dinx[0] ---------------------|0/        |  |--- minx[0]
 *                                       +-|0/
 * maybranch -----------+                |
 * takebranch ---------|1\   ____        |
 *                     |  |-|    |-------+
 * rinx[0] ------------|0/  | or |
 * buserror-----------------|____|
 * 
 * When power-on, dinx is used, so a "lb x0,0(x0)" is executed.
 */
module m_ucodepc
  # ( parameter HIGHLEVEL = 1 )
  (
   input        corerunning, //         Control startup
   input [7:0]  rinx, //                From ucode
   input        sa28,sa29,sa30,sa37, // From ucode
   input        sa32,sa15, // == 2'b10 triggers ucode jmp to alternate operand fetch from SRAM
   input        qualint,
   input        is_brcond,
   input [31:0] ADR_O, //                 
   input [31:0] INSTR,
   input [31:0] B,
   input        RST_I, // NMI
   input        buserror,
   output [7:0] minx,
   output       ucodepc_killwarnings
   );
   wire [7:0]   dinx;
   wire         usedinx, illegal, maybranch, takebranch;
   wire         Adr0Mustbe0 = sa29;
   wire         Adr1Mustbe0 = sa30;
   wire         use_brcond  = sa37;
                
`ifdef verilator
   function [1:0] get_branchvariables;
      // verilator public
      get_branchvariables = {is_brcond,use_brcond};
   endfunction
   function [0:0] get_usedinx;
      // verilator public
      get_usedinx = usedinx;
   endfunction
   function [5:0] get_ucodepcinfo;
      // verilator public
      get_ucodepcinfo = {buserror,usedinx,qualint,illegal,maybranch,takebranch};
   endfunction
   function [7:0] get_dinx;
      // verilator public
      get_dinx = dinx;
   endfunction
`endif

   generate
      if ( HIGHLEVEL ) begin
         
         assign usedinx   = sa28 | !corerunning;
         assign maybranch = Adr0Mustbe0 | Adr1Mustbe0 | use_brcond | (sa32 & ~sa15);
         
         
         // Slight mangling of INSTRUCTION to an index. Should require 1 LUT
         assign dinx[0]   = INSTR[2];
         assign dinx[1]   = ((~INSTR[6]&INSTR[5])&INSTR[30]) | ((~(~INSTR[6]&INSTR[5]))&INSTR[3]);
         assign dinx[4:2] = INSTR[6:4];
         assign dinx[7:5] = INSTR[14:12];
         
         
         /* The illegal signal should be realizable in 3 luts?
          *
          * illegal_a = (16'b1100111011000110 >> INSTR[5:2]); previous
          * illegal_a = (16'b1100111011000010 >> INSTR[5:2]); opens up for prefix 0001011, custom-0
          * illegal_b = (16'b1110010011111111 >> INSTR[5:2]);
          * illegal = (~INSTR[6] & illegal_a) | (INSTR[6] & illegal_b ) | ~INSTR[1] | ~INSTR[0];
          */
         
         reg          illegal_a, illegal_b;
         always @(/*AS*/INSTR)
           case ( INSTR[5:2] )
             4'b0000 : {illegal_b,illegal_a} = 2'b10;
             4'b0001 : {illegal_b,illegal_a} = 2'b11;
             4'b0010 : {illegal_b,illegal_a} = 2'b10;
             4'b0011 : {illegal_b,illegal_a} = 2'b10;
             4'b0100 : {illegal_b,illegal_a} = 2'b10;
             4'b0101 : {illegal_b,illegal_a} = 2'b10;
             4'b0110 : {illegal_b,illegal_a} = 2'b11;
             4'b0111 : {illegal_b,illegal_a} = 2'b11;
             4'b1000 : {illegal_b,illegal_a} = 2'b00;
             4'b1001 : {illegal_b,illegal_a} = 2'b01;
             4'b1010 : {illegal_b,illegal_a} = 2'b11;
             4'b1011 : {illegal_b,illegal_a} = 2'b01;
             4'b1100 : {illegal_b,illegal_a} = 2'b00;
             4'b1101 : {illegal_b,illegal_a} = 2'b10;
             4'b1110 : {illegal_b,illegal_a} = 2'b11;
             4'b1111 : {illegal_b,illegal_a} = 2'b11;
           endcase
         assign illegal = (~INSTR[6] & illegal_a) | (INSTR[6] & illegal_b ) | ~INSTR[1] | ~INSTR[0];
         
         
         /* takebranch. Microcode must diverge when we have an alignment error,
          * a taken branch, or an opcode fetch when we read from SRAM
          *                     _              ____
          * Adr0Mustbe0 -------|&|------------|    |--- takebranch
          * B[0] --------------|_|  +---------| or |
          *                     _   | +-------|    |
          * Adr1Mustbe0 -------|&|--+ | +-----|____|
          * B[1] --------------|_|    | |
          *                     _     | |
          * use_brcond --------|&|----+ |
          * is_brcond ---------|_|      |
          *                     _       |
          * read_instr --------|&|------+
          * ADR_O[31] ---------|_|
          */
         wire         qualint_or_RST_I = qualint | RST_I;
         wire         illegal_or_qualint = (illegal | qualint) & corerunning;
         wire         illegal_or_qualint_or_RST_I = (illegal | qualint | RST_I) & corerunning;
         assign takebranch = 
                             (Adr0Mustbe0 & B[0]) |
                             (Adr1Mustbe0 & B[1]) |                
                             (use_brcond & is_brcond) |
                             (sa32 & ~sa15 & B[31] );
         wire         usedinx_or_RST_I = usedinx | RST_I;
         assign minx[7:2] = usedinx_or_RST_I ? (dinx[7:2] | {6{illegal_or_qualint_or_RST_I}}) : rinx[7:2];
         assign minx[1]   = usedinx_or_RST_I ? ( (dinx[1] | illegal_or_qualint) & ~RST_I)     : rinx[1];
         assign minx[0]   = buserror | (usedinx_or_RST_I ? (illegal_or_qualint_or_RST_I ? qualint_or_RST_I : dinx[0]) : (maybranch ? takebranch : rinx[0]));
         
         assign ucodepc_killwarnings = INSTR[31] | &INSTR[29:15] | &INSTR[11:7] | &ADR_O & &B;
         
      end else begin
         wire illegal_a, illegal_b;

         assign usedinx   = sa28 | !corerunning;
         assign maybranch = Adr0Mustbe0 | Adr1Mustbe0 | use_brcond | (sa32 & ~sa15);
         
         
         // Slight mangling of INSTRUCTION to an index. Should require 1 LUT
         assign dinx[0]   = INSTR[2];
         assign dinx[1]   = ((~INSTR[6]&INSTR[5])&INSTR[30]) | ((~(~INSTR[6]&INSTR[5]))&INSTR[3]);
         assign dinx[4:2] = INSTR[6:4];
         assign dinx[7:5] = INSTR[14:12];
         
         
         /* 
          *
          * illegal_a = (16'b1100111011000010 >> INSTR[5:2]); 
          * illegal_b = (16'b1110010011111111 >> INSTR[5:2]);
          * illegal = (~INSTR[6] & illegal_a) | (INSTR[6] & illegal_b ) | ~INSTR[1] | ~INSTR[0];
          */
         SB_LUT4 #(.LUT_INIT(16'hcec2)) illegal_a_cmb( .O(illegal_a), .I3(INSTR[5]), .I2(INSTR[4]), .I1(INSTR[3]), .I0(INSTR[2]));
         SB_LUT4 #(.LUT_INIT(16'he4ff)) illegal_b_cmb( .O(illegal_b), .I3(INSTR[5]), .I2(INSTR[4]), .I1(INSTR[3]), .I0(INSTR[2]));
         assign illegal = (~INSTR[6] & illegal_a) | (INSTR[6] & illegal_b ) | ~INSTR[1] | ~INSTR[0];
         
         
         /* takebranch. Microcode must diverge when we have an alignment error,
          * a taken branch, or an opcode fetch when we read from SRAM
          *                     _              ____
          * Adr0Mustbe0 -------|&|------------|    |--- takebranch
          * B[0] --------------|_|  +---------| or |
          *                     _   | +-------|    |
          * Adr1Mustbe0 -------|&|--+ | +-----|____|
          * B[1] --------------|_|    | |
          *                     _     | |
          * use_brcond --------|&|----+ |
          * is_brcond ---------|_|      |
          *                     _       |
          * read_instr --------|&|------+
          * ADR_O[31] ---------|_|
          */
         wire         qualint_or_RST_I = qualint | RST_I;
         wire         illegal_or_qualint = (illegal | qualint) & corerunning;
         wire         illegal_or_qualint_or_RST_I = (illegal | qualint | RST_I) & corerunning;
         assign takebranch = 
                             (Adr0Mustbe0 & B[0]) |
                             (Adr1Mustbe0 & B[1]) |                
                             (use_brcond & is_brcond) |
                             (sa32 & ~sa15 & B[31] );
         wire         usedinx_or_RST_I = usedinx | RST_I;
         assign minx[7:2] = usedinx_or_RST_I ? (dinx[7:2] | {6{illegal_or_qualint_or_RST_I}}) : rinx[7:2];
         assign minx[1]   = usedinx_or_RST_I ? ( (dinx[1] | illegal_or_qualint) & ~RST_I)     : rinx[1];
         assign minx[0]   = buserror | (usedinx_or_RST_I ? (illegal_or_qualint_or_RST_I ? qualint_or_RST_I : dinx[0]) : (maybranch ? takebranch : rinx[0]));
         
         assign ucodepc_killwarnings = INSTR[31] | &INSTR[29:15] | &INSTR[11:7] | &ADR_O & &B;
         
      end
         
   endgenerate
endmodule


`ifdef THISWORKS_BUT_MUST_BE_WETTED
         /////////////////////////////////////////////////////////////////////////////

         assign usedinx   = sa28 | !corerunning; // Dummy in lowlevel
         assign takebranch = (Adr0Mustbe0 & B[0]) | (Adr1Mustbe0 & B[1]) | (use_brcond & is_brcond) | ((sa32 & ~sa15) & ADR_O[31] ); // Dummy in lowlevel

         
         wire         illegal_a, illegal_b;
         wire         illegal_or_qualint;// = (illegal | qualint) & corerunning;
//         wire         takebranch_a, takebranch_b;
//         wire         minxa,minxb;
         wire         usedinx_or_RST_I;
         wire         qualint_or_RST_I;
         wire         illegal_or_qualint_or_RST_I;
         
         assign dinx[0]   = INSTR[2];
         assign dinx[4:2] = INSTR[6:4];
         assign dinx[7:5] = INSTR[14:12];
         SB_LUT4 #(.LUT_INIT(16'haea2)) cmb_dinx1( .O(dinx[1]), .I3(INSTR[30]), .I2(INSTR[6]), .I1(INSTR[5]), .I0(INSTR[3]));
           
         /* 
          *
          * illegal_a = (16'b1100111011000010 >> INSTR[5:2]); 
          * illegal_b = (16'b1110010011111111 >> INSTR[5:2]);
          * illegal = (~INSTR[6] & illegal_a) | (INSTR[6] & illegal_b ) | ~INSTR[1] | ~INSTR[0];
          */
         SB_LUT4 #(.LUT_INIT(16'hcec2)) illegal_a_cmb( .O(illegal_a), .I3(INSTR[5]), .I2(INSTR[4]), .I1(INSTR[3]), .I0(INSTR[2]));
         SB_LUT4 #(.LUT_INIT(16'he4ff)) illegal_b_cmb( .O(illegal_b), .I3(INSTR[5]), .I2(INSTR[4]), .I1(INSTR[3]), .I0(INSTR[2]));
         SB_LUT4 #(.LUT_INIT(16'hcaff)) illegal_cmb(.O(illegal), .I3(INSTR[1]), .I2(INSTR[6]), .I1(illegal_b), .I0(illegal_a));
         SB_LUT4 #(.LUT_INIT(16'hfd00)) illegal_or_qualint_cmb(.O(illegal_or_qualint), .I3(corerunning), .I2(qualint), .I1(illegal), .I0(INSTR[0]));
         assign illegal_or_qualint_or_RST_I = illegal_or_qualint | RST_I;
         assign qualint_or_RST_I = qualint | RST_I;
         
         /* takebranch. Microcode must diverge when we have an alignment error,
          * a taken branch, or an opcode fetch when we read from SRAM
          *                     _              ____
          * Adr0Mustbe0 -------|&|------------|    |--- takebranch
          * B[0] --------------|_|  +---------| or |
          *                     _   | +-------|    |
          * Adr1Mustbe0 -------|&|--+ | +-----|____|
          * B[1] --------------|_|    | |
          *                     _     | |
          * use_brcond --------|&|----+ |
          * is_brcond ---------|_|      |
          *                     _       |
          * read_instr --------|&|------+
          * ADR_O[31] ---------|_|
          */
         //wire         takebranch = (Adr0Mustbe0 & B[0]) | (Adr1Mustbe0 & B[1]) | (use_brcond & is_brcond) | ((sa32 & ~sa15) & ADR_O[31] );
         wire         sa32_nsa15;
         SB_LUT4 #(.LUT_INIT(16'h4444)) l_sa32_nsa15(.O(sa32_nsa15), .I3(1'b0), .I2(1'b0), .I1(sa32), .I0(sa15));
//         SB_LUT4 #(.LUT_INIT(16'hf888)) takebranch_a_cmb( .O(takebranch_a), .I3(Adr0Mustbe0), .I2(B[0]), .I1(Adr1Mustbe0), .I0(B[1]));
//         SB_LUT4 #(.LUT_INIT(16'hf888)) takebranch_b_cmb( .O(takebranch_b), .I3(use_brcond), .I2(is_brcond), .I1(sa32_nsa15), .I0(ADR_O[31]));

         SB_LUT4 #(.LUT_INIT(16'hfdfd)) usedinx_or_RST_I_cmb( .O(usedinx_or_RST_I), .I3(1'b0), .I2(RST_I), .I1(sa28), .I0(corerunning));
         SB_LUT4 #(.LUT_INIT(16'hfffe)) maybranch_cmb( .O(maybranch), .I3(Adr0Mustbe0), .I2(Adr1Mustbe0), .I1(use_brcond), .I0(sa32_nsa15));
         
         assign minx[0]   = buserror | (usedinx_or_RST_I ? (illegal_or_qualint_or_RST_I ? qualint_or_RST_I : dinx[0]) : (maybranch ? takebranch : rinx[0]));
         //  buserror
         //  |usedinx_or_RST_I
         //  ||illegal_or_qualint_or_RST_I
         //  |||maybranch
         //  ||||
         //  00x0              takebranch
         //  00x1              rinx[0]
         //  010x              dinx[0]
         //  011x              qualint_or_RST_I
         //  1xxx              1
         //
         //
//           
//         SB_LUT4 #(.LUT_INIT(16'hcaca)) minxa_cmb( .O(minxa), .I3(1'b0), .I2(illegal_or_qualint), .I1(qualint), .I0(dinx[0]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minxb_cmb( .O(minxb), .I3(maybranch), .I2(takebranch_a), .I1(takebranch_b), .I0(rinx[0]));
//         SB_LUT4 #(.LUT_INIT(16'hcaca)) minx_cmb0( .O(minx[0]), .I3(1'b0), .I2(usedinx), .I1(minxa), .I0(minxb));
//         
         assign minx[1]   = usedinx_or_RST_I ? ( (dinx[1] | illegal_or_qualint) & ~RST_I)     : rinx[1];
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb1( .O(minx[1]), .I3(usedinx_or_RST_I), .I2(dinx[1]), .I1(illegal_or_qualint_and_nRST_I), .I0(rinx[1]));
         assign minx[7:2] = usedinx_or_RST_I ? (dinx[7:2] | {6{illegal_or_qualint_or_RST_I}}) : rinx[7:2];
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb2( .O(minx[2]), .I3(usedinx_or_RST_I), .I2(dinx[2]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[2]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb3( .O(minx[3]), .I3(usedinx_or_RST_I), .I2(dinx[3]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[3]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb4( .O(minx[4]), .I3(usedinx_or_RST_I), .I2(dinx[4]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[4]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb5( .O(minx[5]), .I3(usedinx_or_RST_I), .I2(dinx[5]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[5]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb6( .O(minx[6]), .I3(usedinx_or_RST_I), .I2(dinx[6]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[6]));
//         SB_LUT4 #(.LUT_INIT(16'hfcaa)) minx_cmb7( .O(minx[7]), .I3(usedinx_or_RST_I), .I2(dinx[7]), .I1(illegal_or_qualint_or_RST_I), .I0(rinx[7]));
         
         
         assign ucodepc_killwarnings = INSTR[31] | &INSTR[29:15] | &INSTR[11:7] | &ADR_O & &B;
      end
`endif
