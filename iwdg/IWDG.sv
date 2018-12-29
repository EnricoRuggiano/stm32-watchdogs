/* 
 * Module: `IWDG` Indipendent Wantchdog
 *
 * Indipendent Watchdog verilog description from the reference manual of
 * STM32F405/415, STM32F407/417, STM32F427/437 and STM32F429/439 
 * advanced Arm®-based 32-bit MCUs.
 *
 * It implements a Wishbone interface communication from the
 * external systems.
 */

module IWDG 
#(

 //  Parameters.
 //  
 // IWDG_KR_SIZE: Key Register bit size.
 // IWDG_PR_SIZE: Prescale Register bir size.
 // IWDG_RLR_SIZE: Reload Register bit size.
 // IWDG_ST_SIZE: Status Register bit size. 
 // 
 // BASE_ADR: Memory base address of the registries.
 // IWDG_KR_ADR: Memory address of IWDG_KR register.
 // IWDG_PR_ADR: Memory address of IWDG_PR register.
 // IWDG_RLR_ADR: Memory address of IWDG_RLR register.
 // IWDG_ST_ADR: Memory address of IWDG_ST register.

 parameter IWDG_KR_SIZE   = 16,                      
 parameter IWDG_PR_SIZE   = 3,                       
 parameter IWDG_RLR_SIZE  = 12,                     
 parameter IWDG_ST_SIZE   = 2,                     

 parameter BASE_ADR     = 32'h0100_0000,          
 parameter IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,
 parameter IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,
 parameter IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,
 parameter IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C
)
(
 // Input signals:
 //
 // iwdg_clk: Indipendent Clock of the downcounter. 
 // clk: Clock of the system.
 // rst: Reset signal.
 // dat_m2s: binary array used to pass data arriving from outside.
 // adr_m2s: binary array used to pass address arriving from the outside.
 // cyc_m2s: signal which indicates that a valid bus cycle is in progress.
 // we_m2s: signal which indicates is a WRITE or READ bus cycle.
 // stb_m2s: signal used to qualify other signal in a valid cycle.
 //
 // Output signals:
 //
 // dat_s2m: binary array used to pass data to the bus.
 // ack_s2m: signal used by the SLAVE to acknoledge a MASTER request.
 // iwdg_rst: Indipendent Watchdog reset signal

 input iwdg_clk,                             
 input clk,                                 
 input rst,                                
 input [IWDG_KR_SIZE - 1:0] dat_m2s,
 input [31:0] adr_m2s,                   
 input cyc_m2s,       
 input we_m2s,    
 input stb_m2s, 
    
 output reg [IWDG_KR_SIZE - 1:0] dat_s2m,    
 output reg ack_s2m,                           
 output reg iwdg_rst                        
);

// Local Parameters:
// - Wishbone states. 
                                               
localparam IDLE  = 2'b00;   
localparam READ  = 2'b01;   
localparam WRITE = 2'b10;   
localparam SLEEP = 2'b11; 
// - Key Register possible values.

localparam IDLE_KEY   = 16'h0000;
localparam COUNT_KEY  = 16'hCCCC; 
localparam RELOAD_KEY = 16'hAAAA;  
localparam ACCESS_KEY = 16'h5555;  


// - Prescale Register possible values. 
// To each PR_x value is associated a PR_DIV_x prescale threshold.

localparam PR_0 = 3'b000;                             
localparam PR_1 = 3'b001;
localparam PR_2 = 3'b010;
localparam PR_3 = 3'b011;
localparam PR_4 = 3'b100;
localparam PR_5 = 3'b101;
localparam PR_6 = 3'b110;

// - Prescale Register Divider count threshold. 
//
//  The threshold indicates how many Indipendent Clock periods 
//  are needed before downcounting the Reload Register

localparam PR_DIV_2   =  2'b11;               
localparam PR_DIV_4   =  7'b000_0000;         
localparam PR_DIV_8   =  7'b000_0010 - 1;
localparam PR_DIV_16  =  7'b000_0100 - 1;
localparam PR_DIV_32  =  7'b000_1000 - 1;
localparam PR_DIV_64  =  7'b001_0000 - 1;
localparam PR_DIV_128 =  7'b010_0000 - 1;
localparam PR_DIV_256 =  7'b100_0000 - 1;
            
// - Protocol constants and parameters.
//
//  Data is passed from the Wishbone communication interface to the Indipentent Clock
//  downcounter through a DUAL CLOCK FIFO according the following Protocol.
//
//  { OPR_HEADER, ADR_HEADER, PAYLOAD }   
//
//  OPR_HEADER.
//  Operation header. Indicates what type of operation is performed on
//  the indipendent registers. e.g Write or Read operation. 
//
//  ADR_HEADER.
//  Address header, Indicates from which register data is read 
//  or in which register data is written.
//
//  PAYLOAD.
//  bit vector of data that is needed to be written on a register 
//  or is read from a register
                                              
localparam OPR_HEADER_SIZE  = 1;     
localparam ADR_HEADER_SIZE  = 2;            
localparam PAYLOAD_SIZE     = IWDG_KR_SIZE;

localparam OPR_RD_HEADER  = 0;
localparam OPR_WR_HEADER  = 1;                                
localparam ADR_KR_HEADER  = 2'b00;
localparam ADR_RLR_HEADER = 2'b01;
localparam ADR_PR_HEADER  = 2'b10;
localparam ADR_ST_HEADER  = 2'b11;
                       
// - FIFO DUAL CLOCK MACRO parameter:
//
// ALMOST_OFFSET: sets the almost empty threshold.
// DATA_WIDTH: width of the data vector stored in the fifo list.
// DEVICE: target device. used the default "7SERIES"     
// FIFO_SIZE: size of the memory. Possible values are "18Kb" and "36Kb".
// FIRST_WORD_FALL_THROUGH: sets the FIFO FWFT to "TRUE" or "FALSE"

localparam ALMOST_OFFSET           = 9'h080;
localparam DATA_WIDTH              = OPR_HEADER_SIZE + ADR_HEADER_SIZE + PAYLOAD_SIZE;
localparam DEVICE                  = "7SERIES";
localparam FIFO_SIZE               = "18Kb";
localparam FIRST_WORD_FALL_THROUGH = "TRUE";


// - Contstants that helps to access to OPR_HEADER, ADR_HEADER and
// PAYLOAD bits.  

localparam OPR_HEADER_STR = PAYLOAD_SIZE + ADR_HEADER_SIZE;
localparam OPR_HEADER_END = DATA_WIDTH - 1;
localparam ADR_HEADER_STR = PAYLOAD_SIZE;
localparam ADR_HEADER_END = PAYLOAD_SIZE + ADR_HEADER_SIZE - 1;
localparam PAYLOAD_STR    = 0;
localparam PAYLOAD_END    = PAYLOAD_SIZE - 1;

                                                  
// VERILOG VARIABLES - CONVENTION
//                
// prefixes:
//  f_: fifo verilog variable. Is a variable used to pilot signal
//   to fifo dual clock instances. 
// 
//  p_: protocol verilog variable. Is a vector bit variable in which can
//   be identified an OPR, ADR headers and a Payload. Output data from
//   fifo_t2d is a p_ variable.
//
//  w_: wishbone verilog variable. It is refered to the state of the
//  wishbone communication.
//
// iwdg: indipendent watchdog variable. It is refered to the registers and
//  output signal of the indipendent clock downcounter.
//
// postfixes:
//  _m2s: master to slave variable. The signal comes from the master and 
//   goes to the slave. 
//
//  _s2m: slave to master variable. The signal comes from the slave and 
//   goes to the master.
//
//  _t2d: top to down variable. The signal comes from the top master clock domain
//   and goes to down indipendent clock domain. 
//
//  _d2t: down to top variable. The signal comes from the down indipendent
//  clock domain and goes to the top master clock domain.   

// DUAL CLOCK FIFO _t2d and _d2t variables
//
// ALMOSTEMPTY: 1-bit output almost empty.
// ALMOSTFULL: 1-bit output almost full.
// DO: Output data, width defined by DATA_WIDTH parameter.
// EMPTY: 1-bit output empty.
// FULL: 1-bit output full.
// RDCOUNT: Output read count, width determined by FIFO depth.
// RDERR: 1-bit output read error.
// WRCOUNT:  Output write count, width determined by FIFO depth.
// WRERR: 1-bit output write error.
// DI: Input data, width defined by DATA_WIDTH parameter.
// RDRCLK: 1-bit input read clock.
// RDEN: 1-bit input read enable. Assert this to read data in DO,
// RST: 1-bit input reset.
// WRCLK: 1-bit input write clock.
// WREN: 1-bit input write enable. Assert this to write data in DI,

wire [DATA_WIDTH - 1:0] f_do_t2d, f_do_d2t; 
wire [DATA_WIDTH - 1:0] f_di_t2d, f_di_d2t;
wire [8:0] f_rdcount_t2d, f_rdcount_d2t;
wire [8:0] f_wrcount_t2d, f_wrcount_d2t;
wire f_almostempty_t2d, f_almostempty_d2t; 
wire f_almostfull_t2d, f_almostfull_d2t;
wire f_empty_t2d, f_empty_d2t;
wire f_full_t2d, f_full_d2t;
wire f_rderr_t2d, f_rderr_d2t;
wire f_wrerr_t2d, f_wrerr_d2t;
wire f_rdclk_t2d, f_rdclk_d2t;
wire f_rden_t2d, f_rden_d2t;
wire f_rst_t2d, f_rst_d2t;
wire f_wren_t2d, f_wren_d2t;
wire f_wrclk_t2d, f_wrclk_d2t;

// Protocol variables:
//
// p_opr_header: OPR header bits of the protocol bit vector.
// p_adr_header: ADR header bits of the protocol bit vector.
// p_payload: Payload bits of the protocol bit vector.

wire [OPR_HEADER_SIZE - 1:0] p_opr_header_t2d; 
wire [ADR_HEADER_SIZE - 1:0] p_adr_header_t2d; 
wire [DATA_WIDTH - ADR_HEADER_SIZE - 1:0] p_payload_t2d;

// Wishbone variable:
//
// w_state: the state of the wishbone communication.
//  e.g. READ, WRITE, IDLE states.


reg [1:0] w_state, w_state_next;

// Indipendent Wachdog variables:
// 
// iwdg_kr: Key Register value.
// 
// iwdg_rlr: Reload register value. The watchdog start value of the timer is
//  stored in this register.
//
// iwdg_rlr_cnt: Reload counter register. The watchdog downcounter timer is
//  stored in this register. e.g if it is 0 is asserted the reset
//  signal.
//
// iwdg_pr_cnt: Prescale counter register. It counts how many 
//  indipendent clock period are needed to perform a 
//  downcount on the Reload register.
//
// iwdg_pr_thr: Prescale threshold regiter. It stores the number
//  of clock period needed to downcount the Reload register.
// 
// iwdg_pr_sts: Prescale Status. It is asserted when a prescale operation
//  is performed as changing the value of the prescale threshold register.
//
// iwdg_rlr_sts: Reload Status register. It is asserted when the 
//  Reload register is reloaded and the downcounting is resetted.
                                              
reg [IWDG_KR_SIZE - 1:0] iwdg_kr, iwdg_kr_next;
reg [IWDG_RLR_SIZE- 1:0] iwdg_rlr, iwdg_rlr_next;
reg [IWDG_RLR_SIZE- 1:0] iwdg_rlr_cnt, iwdg_rlr_cnt_next;
reg [7:0] iwdg_pr_cnt, iwdg_pr_cnt_next;           
reg [5:0] iwdg_pr_thr, iwdg_pr_thr_next;       

reg iwdg_pr_sts;                        
reg iwdg_rlr_sts;                       

                                                                              
// FIFO DUAL CLOCK variables                                                     
reg [DATA_WIDTH - 1:0]  f_di_t2d_tmp,  f_di_d2t_tmp;
reg       f_rden_t2d_tmp,    f_rden_d2t_tmp;
reg       f_wren_t2d_tmp,    f_wren_d2t_tmp;

 
always @(posedge clk) begin
    if (rst) begin
        w_state <= IDLE;
    end
    else begin
        w_state <= w_state_next;
    end
end

always @(posedge iwdg_clk) begin    
    if (rst) begin
        iwdg_kr      <= IDLE_KEY;       
        iwdg_rlr     <= 12'hFFF;
        iwdg_rlr_cnt <= 12'hFFF;
        iwdg_pr_cnt  <= {PR_DIV_4, PR_DIV_2};
        iwdg_pr_thr  <= PR_DIV_4;
                        
    end
    else begin
        iwdg_kr      <= iwdg_kr_next;          
        iwdg_rlr     <= iwdg_rlr_next;
        iwdg_rlr_cnt <= iwdg_rlr_cnt_next;
        iwdg_pr_cnt  <= iwdg_pr_cnt_next;
        iwdg_pr_thr  <= iwdg_pr_thr_next;
    end
end

always @(*) begin
    w_state_next = w_state;
    dat_s2m = 0;
    ack_s2m = 0;    
    
    f_rden_d2t_tmp = 0;
    f_wren_t2d_tmp = 0;  
    f_di_t2d_tmp   = 0;
            
    case (w_state)
        IDLE: begin 
            if(we_m2s == 0 && cyc_m2s == 1) begin 
                w_state_next = READ;
            end
            if(we_m2s == 1 && cyc_m2s == 1) begin 
                w_state_next = WRITE;
            end
        end
        SLEEP: begin
            if(!f_empty_d2t) begin
                w_state_next = IDLE;
                f_rden_d2t_tmp = 1;
                ack_s2m = cyc_m2s & stb_m2s;                            
                
                if(we_m2s == 0) begin
                    dat_s2m = 0 + f_do_d2t;
                end
            end
            else begin
                w_state_next = SLEEP;
            end    
        end
        READ: begin
            w_state_next = SLEEP;
            f_wren_t2d_tmp = 1;
                
            case (adr_m2s)
                IWDG_KR_ADR: begin
                    f_di_t2d_tmp = {OPR_RD_HEADER, ADR_KR_HEADER,  16'h0000};
                end
                IWDG_RLR_ADR: begin
                   f_di_t2d_tmp = {OPR_RD_HEADER, ADR_RLR_HEADER, 16'h0000};
                end
                IWDG_PR_ADR: begin
                   f_di_t2d_tmp = {OPR_RD_HEADER, ADR_PR_HEADER,  16'h0000};
                end
                IWDG_ST_ADR: begin
                   f_di_t2d_tmp = {OPR_RD_HEADER, ADR_ST_HEADER,  16'h0000};
                end
            endcase
        end 
        WRITE: begin
            w_state_next = SLEEP;
            f_wren_t2d_tmp = 1;
            
            case (adr_m2s)
                IWDG_KR_ADR: begin
                   f_di_t2d_tmp = {OPR_WR_HEADER, ADR_KR_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                end
                IWDG_RLR_ADR: begin
                   f_di_t2d_tmp = {OPR_WR_HEADER, ADR_RLR_HEADER, dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                end
                IWDG_PR_ADR: begin
                   f_di_t2d_tmp = {OPR_WR_HEADER, ADR_PR_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                end
                IWDG_ST_ADR: begin
                   f_di_t2d_tmp = {OPR_WR_HEADER, ADR_ST_HEADER,  dat_m2s[PAYLOAD_END : PAYLOAD_STR]};
                end
            endcase    
        end       
    endcase
end

always @(*) begin
    iwdg_kr_next = iwdg_kr;    
    iwdg_rlr_next = iwdg_rlr;
    iwdg_rlr_cnt_next = iwdg_rlr_cnt;
    iwdg_pr_cnt_next = iwdg_pr_cnt;
    iwdg_pr_thr_next = iwdg_pr_thr;
    iwdg_rlr_sts = 0;
    iwdg_pr_sts = 0;
    iwdg_rst = 0;
    
    f_rden_t2d_tmp = 0;
    f_wren_d2t_tmp = 0;
    f_di_d2t_tmp   = 0;
    
    if(!f_empty_t2d) begin
        f_rden_t2d_tmp = 1;
        f_wren_d2t_tmp = 1;
        
        case (p_opr_header_t2d)
            
            OPR_RD_HEADER: begin
                case(p_adr_header_t2d)
                    ADR_KR_HEADER: begin
                        f_di_d2t_tmp = 0 + iwdg_kr;
                    end
                    ADR_PR_HEADER: begin
                        case(iwdg_pr_thr_next)
                            PR_DIV_4:     f_di_d2t_tmp = 0 + PR_0;
                            PR_DIV_8:     f_di_d2t_tmp = 0 + PR_1;
                            PR_DIV_16:    f_di_d2t_tmp = 0 + PR_2;
                            PR_DIV_32:    f_di_d2t_tmp = 0 + PR_3;
                            PR_DIV_64:    f_di_d2t_tmp = 0 + PR_4;
                            PR_DIV_128:   f_di_d2t_tmp = 0 + PR_5;
                            PR_DIV_256:   f_di_d2t_tmp = 0 + PR_6;
                        endcase
                    end
                    ADR_RLR_HEADER: begin
                        f_di_d2t_tmp = 0 + iwdg_rlr_cnt_next;
                    end
                    ADR_ST_HEADER: begin
                        f_di_d2t_tmp = 0 + {iwdg_rlr_sts, iwdg_pr_sts};
                    end
                endcase
            end              
            
            OPR_WR_HEADER: begin
                f_di_d2t_tmp = 1;
    
                case (p_adr_header_t2d)
                    ADR_KR_HEADER: begin
                      iwdg_kr_next = p_payload_t2d;
                    end
                    ADR_PR_HEADER: begin
                        if(iwdg_kr_next == ACCESS_KEY) begin
                            case (p_payload_t2d [IWDG_PR_SIZE - 1:0])
                                PR_0: iwdg_pr_thr_next = PR_DIV_4;
                                PR_1: iwdg_pr_thr_next = PR_DIV_8;
                                PR_2: iwdg_pr_thr_next = PR_DIV_16;
                                PR_3: iwdg_pr_thr_next = PR_DIV_32;
                                PR_4: iwdg_pr_thr_next = PR_DIV_64;
                                PR_5: iwdg_pr_thr_next = PR_DIV_128;
                                PR_6: iwdg_pr_thr_next = PR_DIV_256;
                            endcase   
                                
                            iwdg_pr_cnt_next = {iwdg_pr_thr_next, PR_DIV_2};
                            iwdg_pr_sts = 1;
                        end 
                    end    
                    ADR_RLR_HEADER: begin
                        if(iwdg_kr_next == ACCESS_KEY) begin
                            iwdg_rlr_next = p_payload_t2d[IWDG_RLR_SIZE - 1:0];
                        end
                    end    
                    ADR_ST_HEADER: begin
                        iwdg_pr_sts  = p_payload_t2d[0];
                        iwdg_rlr_sts = p_payload_t2d[1];
                    end
                endcase
            end
        endcase            
    end    
    
    case (iwdg_kr)
        COUNT_KEY: begin
            if(iwdg_pr_cnt_next == 0) begin
                if(iwdg_rlr_cnt_next == 0) begin
//                    iwdg_rlr_cnt_next = iwdg_rlr;
//                    iwdg_pr_cnt_next = {iwdg_pr_thr, PR_DIV_2};
                    iwdg_rlr_cnt_next = 0;
                    iwdg_pr_cnt_next = 0;

                    iwdg_rst = 1; 
                end
                else begin
                    iwdg_rlr_cnt_next = iwdg_rlr_cnt - 1;
                    iwdg_pr_cnt_next = {iwdg_pr_thr, PR_DIV_2};
                end
            end
            else begin 
                iwdg_pr_cnt_next = iwdg_pr_cnt - 1;
            end
        end
        RELOAD_KEY: begin
                iwdg_pr_cnt_next = {iwdg_pr_thr, PR_DIV_2};
                iwdg_rlr_cnt_next = iwdg_rlr;
                iwdg_rlr_sts = 1;            
        end     
    endcase
end


// Continuos assignments:
//
// - Fifo dual clock t2d assignments
//
// - Fifo dual clock d2t assignments
//
// - Protocol data assignments.

assign f_wrclk_t2d = clk; 
assign f_rdclk_t2d = iwdg_clk;
assign f_rst_t2d   = rst; 
assign f_di_t2d    = f_di_t2d_tmp;
assign f_rden_t2d  = f_rden_t2d_tmp;
assign f_wren_t2d  = f_wren_t2d_tmp;

assign f_wrclk_d2t = iwdg_clk;
assign f_rdclk_d2t = clk;
assign f_rst_d2t   = rst;
assign f_di_d2t    = f_di_d2t_tmp;
assign f_rden_d2t  = f_rden_d2t_tmp;
assign f_wren_d2t  = f_wren_d2t_tmp;

assign p_opr_header_t2d  = f_do_t2d [OPR_HEADER_END : OPR_HEADER_STR];
assign p_adr_header_t2d  = f_do_t2d [ADR_HEADER_END : ADR_HEADER_STR];
assign p_payload_t2d     = f_do_t2d [   PAYLOAD_END : PAYLOAD_STR];


// Instances:
//
// - FIFO DUALCLOCK macro TOP 2 DOWN instance.
//
// - FIFO DUALCLOCK macro DOWN 2 TOP instance

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),               
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET),                
  .DATA_WIDTH(DATA_WIDTH),                           
  .DEVICE(DEVICE),                                   
  .FIFO_SIZE (FIFO_SIZE),                            
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) 
) FIFO_DUALCLOCK_MACRO_t2d (
  .ALMOSTEMPTY(f_almostempty_t2d),                   
  .ALMOSTFULL(f_almostfull_t2d),  
  .DO(f_do_t2d),                  
  .EMPTY(f_empty_t2d),            
  .FULL(f_full_t2d),              
  .RDCOUNT(f_rdcount_t2d),        
  .RDERR(f_rderr_t2d),            
  .WRCOUNT(f_wrcount_t2d),        
  .WRERR(f_wrerr_t2d),            
  .DI(f_di_t2d),                  
  .RDCLK(f_rdclk_t2d),            
  .RDEN(f_rden_t2d),              
  .RST(f_rst_t2d),                
  .WRCLK(f_wrclk_t2d),            
  .WREN(f_wren_t2d)               
);

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET), 
  .DATA_WIDTH(DATA_WIDTH),            
  .DEVICE(DEVICE),                    
  .FIFO_SIZE (FIFO_SIZE),                             
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) 
) FIFO_DUALCLOCK_MACRO_d2t (
  .ALMOSTEMPTY(f_almostempty_d2t),                   
  .ALMOSTFULL(f_almostfull_d2t),                     
  .DO(f_do_d2t),                                     
  .EMPTY(f_empty_d2t),                               
  .FULL(f_full_d2t),                                 
  .RDCOUNT(f_rdcount_d2t),                           
  .RDERR(f_rderr_d2t),                               
  .WRCOUNT(f_wrcount_d2t),                           
  .WRERR(f_wrerr_d2t),                               
  .DI(f_di_d2t),                                     
  .RDCLK(f_rdclk_d2t),                               
  .RDEN(f_rden_d2t),                                 
  .RST(f_rst_d2t),                                     
  .WRCLK(f_wrclk_d2t),                                 
  .WREN(f_wren_d2t)                                    
);

endmodule