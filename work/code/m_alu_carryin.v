/* -----------------------------------------------------------------------------
 * Part of midgetv
 * 2019. Copyright B. Nossum.
 * For licence, see LICENCE
 * -----------------------------------------------------------------------------
 * The alu carry input. It must be selectable. raluF is used by slt(u), slti(u)
 * instructions. alu_carryin must be put on the carry chain.
 * 
 * Free resources here give sra_msb and sa12_and_corerunning.
 * Size of module : 2 SB_LUT4s
 * 
 *                                          
 *                    | alu_carryin                      s_alu_carryin[1]           
 *                   /y\     ___                         |s_alu_carryin[0]          
 * ADR_O[31] --------(((----|I0 |                        ||  prealucyin 
 * s_alu_carryin[0] -+((----|I1 |-- sra_msb              00  0          
 * s_alu_carryin[1] --(+----|I2 |                        01  raluF     
 * FUNC7_5 -----------(-----|I3_|                        10  raluF
 *                    | prealucyin                       11  1
 *                   /y\     ___                             
 * corerunning ------(((----|I0 |-- sa12_and_corerunning FUNC7_5 sra_msb
 * raluF ------------+||    |I1 |                        0       0      
 * GND ---------------(+    |I2 |                        1       Q[31]  
 * sa12 --------------(-----|I3_|
 *                    |
 *                    VCC
 * 
 * Experimentation show that iCECube2 inserts a through-carry higher in the
 * ALU carry chain, probably because of router congestion? This is avoided 
 * by the following arrangement, where I gain a LUT otherwise unused. The 
 * effectively 3-input LUT is used for an equation that has a good slack, 
 * Wai[7]. Rather than to move Wai[7] here, I do the opposite, and get 
 * preprealucyin from m_wai. The experiment was not a success, for unknown 
 * reasons. But by making preprealucyin out of the 5-bit shiftcounter instead, 
 * I succeded.
 * 
 *                                          
 *                    | alu_carryin                          s_alu_carryin[1]           
 *                   /y\     ___                             |s_alu_carryin[0]          
 * ADR_O[31] --------(((----|I0 |                            ||  prealucyin 
 * s_alu_carryin[0] -+((----|I1 |-- sra_msb                  00  0          
 * s_alu_carryin[1] --(+----|I2 |                            01  raluF     
 * FUNC7_5 -----------(-----|I3_|                            10  raluF
 *                    | prealucyin                           11  1
 *                   /y\     ___                                 
 * corerunning ------(((----|I0 |-- sa12_and_corerunning     FUNC7_5 sra_msb
 * raluF ------------+||    |I1 |                            0       0      
 * GND ---------------(+    |I2 |                            1       Q[31]  
 * sa12 --------------(-----|I3_|
 *                    |
 *                    | preprealucyin == VCC
 *                    |
 *                    |         +-------- lastshift = ~shcy[4] & sa18. The cycle we are loading the counter is not the last shift..
 *                   /y\  ___   |  ___  
 *             sa18 -(((-|I0 |  | |I0 | ~lastshift     __                
 *              vcc -+(( |I1 |--+-|I1-|---------------|  |-- r_issh0_not
 *              vcc --(+ |I2 |    |I2 |               |  |               
 *                    +--|I3_|    |I3_|               >__|               
 *                    |shcy[4]
 * 
 */
module m_alu_carryin  # ( parameter HIGHLEVEL = 0 )   
   (
    input        raluF,FUNC7_5,
    input [1:0]  s_alu_carryin,
    input        sa12,corerunning,
    /* verilator lint_off UNUSED */
    input        preprealucyin,
    /* verilator lint_on UNUSED */
    input [31:0] ADR_O,
    output reg   alu_carryin,sra_msb,
    output       sa12_and_corerunning,
    output       m_alu_carryin_killwarnings
    );
   
   assign m_alu_carryin_killwarnings = &ADR_O;
   generate
      if ( HIGHLEVEL != 0 ) begin         
         always @(/*AS*/raluF or s_alu_carryin) 
           case ( s_alu_carryin )
             2'b00 : alu_carryin = 1'b0;
             2'b01 : alu_carryin = raluF;
             2'b10 : alu_carryin = raluF;
             2'b11 : alu_carryin = 1'b1;
           endcase
         always @(/*AS*/ADR_O or FUNC7_5) 
           sra_msb = FUNC7_5 ? ADR_O[31] : 1'b0;
         assign sa12_and_corerunning = sa12 & corerunning;

      end else begin
         
         wire prealucyin;
         wire _sra_msb,_alu_carryin;

         SB_LUT4 #(.LUT_INIT(16'haa00))  la(.O(sa12_and_corerunning),.I3(sa12),.I2(1'b0), .I1(raluF),.I0(corerunning));
         SB_CARRY pcy(.CO(prealucyin),                     .CI(preprealucyin), .I1(1'b0), .I0(raluF));
         SB_LUT4 #(.LUT_INIT(16'haa00))  lb(.O(_sra_msb),.I3(FUNC7_5),.I2(s_alu_carryin[1]),.I1(s_alu_carryin[0]),.I0(ADR_O[31]));
         SB_CARRY cya(.CO(_alu_carryin),              .CI(prealucyin),.I1(s_alu_carryin[1]),.I0(s_alu_carryin[0]));
         always @(/*AS*/_alu_carryin or _sra_msb) begin
            alu_carryin = _alu_carryin;
            sra_msb = _sra_msb;
         end

      end
      
   endgenerate
endmodule
