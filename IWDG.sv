module IWDG 
#(

parameter IWDG_KR_SIZE   = 16,                      // IWDG_KR  Last valid bit
parameter IWDG_PR_SIZE   = 3,                       // IWDG_PR  Last valid bit
parameter IWDG_RLR_SIZE  = 12,                      // IWDG_RLR Last valid bit
parameter IWDG_ST_SIZE   = 2,                       // IWDG_ST  Last valid bit

parameter BASE_ADR     = 32'h0100_0000,             // Memory base address of the registries.
parameter IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,  // Memory address of IWDG_KR register
parameter IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,  // Memory address of IWDG_PR register
parameter IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,  // Memory address of IWDG_RLR register
parameter IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C   // Memory address of IWDG_ST register

)
(
    input clk_lsi,              // LSI clock from a RC oscillator 
      
    input clk_m2s,              // Wishbone SYSCON module clock. The clock of the bus used to coordinate the activities on the interfaces
    input rst_m2s,              // Wishbone SYSCON module reset signal. It forces the Wishbone interface to reset. ALL WISHBONE interfaces must have one.
    
    input [IWDG_KR_SIZE - 1:0] dat_m2s,       // Wishbone interface binary array used to pass data arriving from the bus.
    input [31:0] adr_m2s,       // Wishbone interface binary array used to pass address arriving from the bus.
        
    input cyc_m2s,              // Wishbone interface signal which indicates that a valid bus cycle is in progress.
    input we_m2s,               // Wishbone interface signal which indicates is a WRITE or READ bus cycle
    
    input stb_m2s,              // Wishbone interface signal used to qualify other signal in a valid cycle.
    
    // output tgd_s2m,          // Wishbone data tag signal qualified by stb_m2s. 
    output reg [IWDG_KR_SIZE - 1:0] dat_s2m,  // Wishbone interface binary array used to pass data to the bus.
    output reg ack_s2m,         // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
    
    output reg rst_iwdg             // IWDG reset signal
);
                                                      // TOP FSA MOORE MACHINE: WISHBONE INTERFACE
                                                      // - REGISTERS:

/*reg [IWDG_KR_SIZE - 1:0]  iwdg_kr,  iwdg_kr_next;     // IWDG Key Register. Key word changes the state of LOWER FSA MOORE MACHINE.
reg [IWDG_PR_SIZE - 1:0]  iwdg_pr,  iwdg_pr_next;     // IWDG Prescale Register. It changes how many clk cycle to count to change the countdown.
reg [IWDG_RLR_SIZE- 1:0]  iwdg_rlr, iwdg_rlr_next;    // IWDG Reload Register. It stores the IWDG countdown.
reg [IWDG_ST_SIZE - 1:0]  iwdg_st,  iwdg_st_next;     // IWDG Status Register. It is set when a RELOAD or PRESCALE operation is done.
*/
                                                      // - MOORE STATES:
reg [1:0] s, ss_next;                                 // 3 states codified in 2 bits. One is unused.


                                                      // LOWER FSA MOORE MACHINE: COUNTDOWN
                                                      // - REGISTERS:

reg [IWDG_RLR_SIZE- 1:0] cnt_rlr, cnt_rlr_next;       // RLR-Sized bit counter register. The downcount is performed here. 
reg [7:0] cnt_pr, cnt_pr_next;                        // 8-bit counter register. Counts how many lsi-clock transition before donwcount the cnt_rlr
reg [5:0] thr_pr, thr_pr_next;                        // 8-bit threshold register. Constant value needed to compare the cnt_pr register.
reg [IWDG_ST_SIZE - 1:0] sts, sts_next;

reg sts_pr,  sts_pr_next;                             // 1-bit signal. Is set when a PRESCALE operation is done.
reg sts_rlr, sts_rlr_next;                            // 1-bit signal. Is set when a RELOAD operation is done

                                                      // - MOORE STATES:
reg [IWDG_KR_SIZE - 1:0] t, tt_next;                  // the state is equal to IWDG Key Register.

                                                      // PARAMETERS:
                                                      // - PRESCALE TRUTH TABLE
localparam PR_0 = 3'b000;                             
localparam PR_1 = 3'b001;
localparam PR_2 = 3'b010;
localparam PR_3 = 3'b011;
localparam PR_4 = 3'b100;
localparam PR_5 = 3'b101;
localparam PR_6 = 3'b110;

/*localparam PR_DIV_4   =  9'b0_0000_0100 - 1;
localparam PR_DIV_8   =  9'b0_0000_1000 - 1;
localparam PR_DIV_16  =  9'b0_0001_0000 - 1;
localparam PR_DIV_32  =  9'b0_0010_0000 - 1;
localparam PR_DIV_64  =  9'b0_0100_0000 - 1;
localparam PR_DIV_128 =  9'b0_1000_0000 - 1;
localparam PR_DIV_256 =  9'b1_0000_0000 - 1;
*/

localparam PR_DIV_2   =  2'b11;
localparam PR_DIV_4   =  7'b000_0000;
localparam PR_DIV_8   =  7'b000_0010 - 1;
localparam PR_DIV_16  =  7'b000_0100 - 1;
localparam PR_DIV_32  =  7'b000_1000 - 1;
localparam PR_DIV_64  =  7'b001_0000 - 1;
localparam PR_DIV_128 =  7'b010_0000 - 1;
localparam PR_DIV_256 =  7'b100_0000 - 1;


                                                    // - TOP FSA MOORE MACHINE states decodification
localparam IDLE  = 2'b00;   
localparam READ  = 2'b01;   
localparam WRITE = 2'b10;   

                                                    // - LOWER FSA MOORE MACHINE states decodification
localparam IDLE_KEY   = 16'h0000;
localparam COUNT_KEY  = 16'hCCCC; 
localparam RELOAD_KEY = 16'hAAAA;  
localparam ACCESS_KEY = 16'h5555;  
            
localparam ADR_HEADER_SIZE = 2;            
localparam KR_HEADER  = 2'b00;
localparam RLR_HEADER = 2'b01;
localparam PR_HEADER  = 2'b10;
localparam ST_HEADER  = 2'b11;

localparam OPR_HEADER_SIZE  = 1;
localparam RD_HEADER  = 0;
localparam WR_HEADER  = 1;

localparam PAYLOAD_SIZE = IWDG_KR_SIZE;
localparam ZERO_MASK    = 16'h0000;
                       
                                        // FIFO
localparam ALMOST_OFFSET = 9'h080;
localparam DATA_WIDTH = OPR_HEADER_SIZE + ADR_HEADER_SIZE + PAYLOAD_SIZE;
localparam DEVICE = "7SERIES";
localparam FIFO_SIZE = "18Kb";
localparam FIRST_WORD_FALL_THROUGH = "TRUE";


localparam PAYLOAD_STR    = 0;
localparam PAYLOAD_END    = PAYLOAD_SIZE - 1;
localparam ADR_HEADER_STR = PAYLOAD_SIZE;
localparam ADR_HEADER_END = PAYLOAD_SIZE + ADR_HEADER_SIZE - 1;
localparam OPR_HEADER_STR = PAYLOAD_SIZE + ADR_HEADER_SIZE;
localparam OPR_HEADER_END = DATA_WIDTH - 1;
                                                   
wire [DATA_WIDTH - 1:0]  do_t2d,  do_d2t; 
wire [DATA_WIDTH - 1:0]  di_t2d,  di_d2t;

wire      empty_t2d,    empty_d2t;
wire       full_t2d,    full_d2t;
wire       rden_t2d,    rden_d2t;
wire       wren_t2d,    wren_d2t;

wire      rdclk_t2d,    rdclk_d2t;
wire      wrclk_t2d,    wrclk_d2t;
wire        rst_t2d,      rst_d2t;

reg [DATA_WIDTH - 1:0]  di_t2d_tmp,  di_d2t_tmp;

reg       rden_t2d_tmp,    rden_d2t_tmp;
reg       wren_t2d_tmp,    wren_d2t_tmp;
 
reg [OPR_HEADER_SIZE - 1:0] opr_header_t2d; 
reg [OPR_HEADER_SIZE - 1:0] opr_header_d2t;  
reg [ADR_HEADER_SIZE - 1:0] adr_header_t2d; 
reg [ADR_HEADER_SIZE - 1:0] adr_header_d2t;  
reg [DATA_WIDTH - ADR_HEADER_SIZE - 1:0] payload_t2d;
reg [DATA_WIDTH - ADR_HEADER_SIZE - 1:0] payload_d2t;

assign wrclk_t2d = clk_m2s; 
assign rdclk_t2d = clk_lsi;
assign rst_t2d   = rst_m2s; 
assign di_t2d    = di_t2d_tmp;
assign rden_t2d  = rden_t2d_tmp;
assign wren_t2d  = wren_t2d_tmp;

assign wrclk_d2t = clk_lsi;
assign rdclk_d2t = clk_m2s;
assign rst_d2t   = rst_m2s;
assign di_d2t    = di_d2t_tmp;
assign rden_d2t  = rden_d2t_tmp;
assign wren_d2t  = wren_d2t_tmp;

assign opr_header_t2d  = do_t2d [OPR_HEADER_END : OPR_HEADER_STR];
assign opr_header_d2t  = do_d2t [OPR_HEADER_END : OPR_HEADER_STR];
assign adr_header_t2d  = do_t2d [ADR_HEADER_END : ADR_HEADER_STR];
assign adr_header_d2t  = do_d2t [ADR_HEADER_END : ADR_HEADER_STR];
assign payload_t2d     = do_t2d [   PAYLOAD_END : PAYLOAD_STR];
assign payload_d2t     = do_d2t [   PAYLOAD_END : PAYLOAD_STR];

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),               // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET),                // Sets almost full threshold
  .DATA_WIDTH(DATA_WIDTH),                           // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DEVICE(DEVICE),                                   // Target device: "7SERIES" 
  .FIFO_SIZE (FIFO_SIZE),                            // Target BRAM: "18Kb" or "36Kb" 
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) // Sets the FIFO FWFT to "TRUE" or "FALSE" 
) FIFO_DUALCLOCK_MACRO_t2d (
  .DO(do_t2d),                                       // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(empty_t2d),                                 // 1-bit output empty
  .FULL(full_t2d),                                   // 1-bit output full
  .DI(di_t2d),                                       // Input data, width defined by DATA_WIDTH parameter
  .RDCLK(rdclk_t2d),                                 // 1-bit input read clock
  .RDEN(rden_t2d),                                   // 1-bit input read enable
  .RST(rst_t2d),                                     // 1-bit input reset
  .WRCLK(wrclk_t2d),                                 // 1-bit input write clock
  .WREN(wren_t2d)                                    // 1-bit input write enable
);

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),               // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET),                // Sets almost full threshold
  .DATA_WIDTH(DATA_WIDTH),                           // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DEVICE(DEVICE),                                   // Target device: "7SERIES" 
  .FIFO_SIZE (FIFO_SIZE),                            // Target BRAM: "18Kb" or "36Kb" 
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) // Sets the FIFO FWFT to "TRUE" or "FALSE" 
) FIFO_DUALCLOCK_MACRO_d2t (
  .DO(do_d2t),                                       // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(empty_d2t),                                 // 1-bit output empty
  .FULL(full_d2t),                                   // 1-bit output full
  .DI(di_d2t),                                       // Input data, width defined by DATA_WIDTH parameter
  .RDCLK(rdclk_d2t),                                 // 1-bit input read clock
  .RDEN(rden_d2t),                                   // 1-bit input read enable
  .RST(rst_d2t),                                     // 1-bit input reset
  .WRCLK(wrclk_d2t),                                 // 1-bit input write clock
  .WREN(wren_d2t)                                    // 1-bit input write enable
);

                                                    // TOP FSA MOORE: Sequential part 
always @(posedge clk_m2s)
begin
    if (rst_m2s)               
        begin
            s <= IDLE;
        end
    else 
        begin
            s <= ss_next;
        end
end
                                                    // LOWER FSA MOORE: Sequential part
always @(posedge clk_lsi)                            
begin    
    if (rst_m2s) 
        begin
            t <= IDLE_KEY;       
            cnt_rlr  <= 12'h001; //12'hFFF
            cnt_pr   <= {PR_DIV_4, PR_DIV_2};
            thr_pr   <= PR_DIV_4;
            sts_rlr  <= 0;
            sts_pr   <= 0;                        
        end
    else
        begin
            t <= tt_next;          
            cnt_rlr  <= cnt_rlr_next;
            cnt_pr   <= cnt_pr_next;
            thr_pr   <= thr_pr_next;
            sts_rlr  <= sts_rlr_next;
            sts_pr   <= sts_pr_next;
        
        end
end

                                                    // TOP FSA MOORE: Combinatorial part
always @(*)
begin
    ss_next = s;
    dat_s2m = 0;
    ack_s2m = 0;    
    
    wren_t2d_tmp = 0;
    rden_d2t_tmp = 0;  
    
    if(!empty_d2t)
        begin
            rden_d2t_tmp = 1;
            dat_s2m = 0 + do_d2t;
        end
        
    case (s)
        IDLE: 
            begin 
                if(we_m2s == 0 && cyc_m2s == 1) 
                    ss_next = READ;
                if(we_m2s == 1 && cyc_m2s == 1) 
                    ss_next = WRITE;
            end
        READ:
            begin
                ss_next = IDLE;
                ack_s2m = cyc_m2s & stb_m2s;
                wren_t2d_tmp = 1;
                    
                case (adr_m2s)
                IWDG_KR_ADR:    di_t2d_tmp = {RD_HEADER, KR_HEADER,  ZERO_MASK};
                IWDG_RLR_ADR:   di_t2d_tmp = {RD_HEADER, RLR_HEADER, ZERO_MASK};
                IWDG_PR_ADR:    di_t2d_tmp = {RD_HEADER, PR_HEADER,  ZERO_MASK};
                IWDG_ST_ADR:    di_t2d_tmp = {RD_HEADER, ST_HEADER,  ZERO_MASK};
                endcase;
            end 
        WRITE:
            begin
                ss_next = IDLE;
                ack_s2m = cyc_m2s & stb_m2s;
                wren_t2d_tmp = 1;
                
                case (adr_m2s)
                IWDG_KR_ADR:    di_t2d_tmp = {WR_HEADER, KR_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                IWDG_RLR_ADR:   di_t2d_tmp = {WR_HEADER, RLR_HEADER, dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                IWDG_PR_ADR:    di_t2d_tmp = {WR_HEADER, PR_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                IWDG_ST_ADR:    di_t2d_tmp = {WR_HEADER, ST_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                endcase;    
            end       
    endcase
end

                                                    // LOWER FSA MOORE: Combinatorial part
always @(*)
begin
    tt_next = t;    
    cnt_rlr_next  = cnt_rlr;
    cnt_pr_next   = cnt_pr;
    thr_pr_next   = thr_pr;
    sts_rlr_next  = 0;
    sts_pr_next   = 0;
    rst_iwdg      = 0;
    
    rden_t2d_tmp = 0;
    wren_d2t_tmp = 0;
    
    if(!empty_t2d)
        begin
            rden_t2d_tmp = 1;
            
            case (opr_header_t2d)
            
            RD_HEADER:
                begin
                wren_d2t_tmp = 1;

                case(adr_header_t2d)
                    KR_HEADER:  di_d2t_tmp = 0 + tt_next;
                    PR_HEADER:
                        begin
                            case(thr_pr_next)
                            PR_DIV_4:     di_d2t_tmp = 0 + PR_0;
                            PR_DIV_8:     di_d2t_tmp = 0 + PR_1;
                            PR_DIV_16:    di_d2t_tmp = 0 + PR_2;
                            PR_DIV_32:    di_d2t_tmp = 0 + PR_3;
                            PR_DIV_64:    di_d2t_tmp = 0 + PR_4;
                            PR_DIV_128:   di_d2t_tmp = 0 + PR_5;
                            PR_DIV_256:   di_d2t_tmp = 0 + PR_6;
                            endcase
                        end
                    RLR_HEADER: di_d2t_tmp = 0 + cnt_rlr_next;
                    ST_HEADER:  di_d2t_tmp = 0 + {sts_rlr_next, sts_pr_next};
                 endcase
                 end              
            WR_HEADER:
                case (adr_header_t2d)
                    KR_HEADER:  tt_next  = payload_t2d;
                    PR_HEADER:    
                        begin
                            if(tt_next == ACCESS_KEY)
                                begin
                                    case (payload_t2d [IWDG_PR_SIZE - 1:0])
                                        PR_0: thr_pr_next = PR_DIV_4;
                                        PR_1: thr_pr_next = PR_DIV_8;
                                        PR_2: thr_pr_next = PR_DIV_16;
                                        PR_3: thr_pr_next = PR_DIV_32;
                                        PR_4: thr_pr_next = PR_DIV_64;
                                        PR_5: thr_pr_next = PR_DIV_128;
                                        PR_6: thr_pr_next = PR_DIV_256;
                                    endcase   
                                
                                    cnt_pr_next = {thr_pr_next, PR_DIV_2};
                                    sts_pr_next = 1;
                                end 
                        end
                        
                    RLR_HEADER:   
                        begin
                            if(tt_next == ACCESS_KEY)
                                    cnt_rlr_next = payload_t2d[IWDG_RLR_SIZE - 1:0];
                        end     
                    
                    ST_HEADER:
                        begin
                            sts_pr_next  = payload_t2d[0];
                            sts_rlr_next = payload_t2d[1];
                        end
                endcase
           endcase            
        end
    
        
    case (t)    //  TO-DO: default
        IDLE_KEY:;
        COUNT_KEY:
            begin
                if(cnt_pr_next == 0)
                begin
                    if(cnt_rlr_next == 0) 
                    begin
                        rst_iwdg = 1;
                        cnt_rlr_next = 12'hFFF; 
                    end
                    else 
                        cnt_rlr_next = cnt_rlr - 1;
                        cnt_pr_next = {thr_pr, PR_DIV_2};
                end
                else 
                    cnt_pr_next = cnt_pr - 1;
            end
        RELOAD_KEY:
            begin
                cnt_pr_next = {thr_pr, PR_DIV_2};
                cnt_rlr_next = 12'hFFF;
                sts_rlr_next = 1;            
            end
        ACCESS_KEY:;      
    endcase
end

endmodule