/* 
 * Module: `WWDG` Window Watchdog
 *
 * Window Watchdog verilog description from the reference manual of
 * STM32F405/415, STM32F407/417, STM32F427/437 and STM32F429/439 
 * advanced Arm®-based 32-bit MCUs.
 *
 * It implements a Wishbone interface communication from the
 * external systems.
 */

module WWDG 
#(
 
 //  Parameters.
 //  
 // WWDG_CR_SIZE: Control Register bit size.
 // WWDG_CFG_SIZE: Configuration Register bit size.
 // WWDG_ST_SIZE: Status Register bit size. 
 // 
 // BASE_ADR: Memory base address of the registries.
 // WWDG_CR_ADR: Memory address of WWDG_CR register.
 // WWDG_CFG_ADR: Memory address of WWDG_CFG register.
 // WWDG_ST_ADR: Memory address of WWDG_ST register.

 parameter WWDG_CR_SIZE  = 8,
 parameter WWDG_CFG_SIZE = 10,
 parameter WWDG_ST_SIZE  = 1,

 parameter BASE_ADR     = 32'h0110_0000,          
 parameter WWDG_CR_ADR  = BASE_ADR + 32'h0000_0000,
 parameter WWDG_CFG_ADR = BASE_ADR + 32'h0000_0004,
 parameter WWDG_ST_ADR  = BASE_ADR + 32'h0000_0008
)
(
 // Input signals:
 //
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
 // wwdg_rst: Window Watchdog reset signal.
 // wwdg_ewi: Window Watchdog early wakeup interrupt signal.

 input clk,                                 
 input rst,                                
 input [WWDG_CFG_SIZE - 1:0] dat_m2s,
 input [31:0] adr_m2s,                   
 input cyc_m2s,       
 input we_m2s,    
 input stb_m2s, 
    
 output reg [WWDG_CFG_SIZE - 1:0] dat_s2m,    
 output reg ack_s2m,                           
 output reg wwdg_rst,                        
 output reg wwdg_ewi
);

// Local Parameters:
// - Wishbone states. 

localparam IDLE = 2'b00;
localparam READ = 2'b01;
localparam WRITE = 2'b10;

// - Window divider time base possible values. 
// To each WDGTB_x value is associated a WDGTB_DIV_x prescale threshold.

localparam WDGTB_0 = 2'b00;
localparam WDGTB_1 = 2'b01;
localparam WDGTB_2 = 2'b10;
localparam WDGTB_3 = 2'b11;

localparam WDGTB_DIV_0 = 4'b0001 - 1;
localparam WDGTB_DIV_1 = 4'b0010 - 1;
localparam WDGTB_DIV_2 = 4'b0100 - 1;
localparam WDGTB_DIV_3 = 4'b1000 - 1;

// VERILOG VARIABLES - CONVENTION
//                
// prefixes:
//  w_: wishbone verilog variable. It is refered to the state of the
//  wishbone communication.
//
// wwdg: window watchdog variable. It is refered to the registers and
//  output signal of the indipendent clock downcounter.
//
// postfixes:
//  _m2s: master to slave variable. The signal comes from the master and 
//   goes to the slave. 
//
//  _s2m: slave to master variable. The signal comes from the slave and 
//   goes to the master.


// - Wires
//
// wdga: activation bit. 
// ewi: early wakeup interrupt bit flag

wire wdga;
wire ewi;

// - Window Watchdog variables
//
// wwdg_cr: window watchdog control register
//
// wwdg_cfg: window watchdog configuration register
//
// wwdg_st: window watchdog status register
//
// wwdg_pr_thr: window watchdog prescale threshold. How many
//      clk period are needed to perform a downcount.
// 
// wwdg_pr_cnt: window watchdog prescale counter.
//      It counts how many clk period are passed from last downcount.
// 
// wwdg_window_err: window watchdog window error. Flag asserted when
//  the time window is violeted.


reg [WWDG_CR_SIZE - 1:0] wwdg_cr, wwdg_cr_next;
reg [WWDG_CFG_SIZE - 1:0] wwdg_cfg, wwdg_cfg_next;
reg [WWDG_ST_SIZE - 1:0] wwdg_st, wwdg_st_next;

reg [2:0] wwdg_pr_thr, wwdg_pr_thr_next;
reg [2:0] wwdg_pr_cnt, wwdg_pr_cnt_next;
reg wwdg_window_err, wwdg_window_err_next;


// - Wishbone variables:
//
// w_state: the state of the wishbone communication.
//  e.g. READ, WRITE, IDLE states.

reg [1:0] w_state, w_state_next;


always @(posedge clk) begin
    if(rst) begin
        w_state <= IDLE;
        wwdg_cr <= 8'b0111_1111; 
        wwdg_cfg <= 10'b00_0111_1111;
        wwdg_st <= 0;

        wwdg_window_err <= 0; 

        wwdg_pr_cnt <= WDGTB_DIV_0;
        wwdg_pr_thr <= WDGTB_DIV_0;
    end
    else begin
        w_state <= w_state_next;
        wwdg_cr <= wwdg_cr_next;
        wwdg_cfg <= wwdg_cfg_next;
        wwdg_st <= wwdg_st_next;

        wwdg_window_err <= wwdg_window_err_next;
        wwdg_pr_cnt <= wwdg_pr_cnt_next;
        wwdg_pr_thr <= wwdg_pr_thr_next;
    end
end

always @(*) begin
    w_state_next = w_state;
    wwdg_cr_next = wwdg_cr;
    wwdg_cfg_next = wwdg_cfg;
    wwdg_st_next = wwdg_st;
    
    wwdg_window_err_next = wwdg_window_err;
    wwdg_pr_cnt_next = wwdg_pr_cnt;
    wwdg_pr_thr_next = wwdg_pr_thr;

    dat_s2m = 0;
    ack_s2m = 0;
    wwdg_rst = 0;
    wwdg_ewi = 0;

    if(wwdg_window_err) begin
        if(ewi) begin
            wwdg_ewi = 1;
        end
        wwdg_rst = 1;
    end

    if(wdga && !wwdg_window_err) begin
        if(wwdg_cr_next[6] == 0) begin
            if(ewi) begin
                wwdg_ewi = 1;
            end
            wwdg_rst = 1;
            wwdg_pr_cnt_next = 0;
            wwdg_st_next = 1;
        end
        else begin
            if (wwdg_pr_cnt_next == 0) begin
                wwdg_cr_next = wwdg_cr - 1;
                wwdg_pr_cnt_next = wwdg_pr_thr;
            end
            else begin
                wwdg_pr_cnt_next = wwdg_pr_cnt - 1;
            end
        end
    end

    case(w_state)
        IDLE: begin
            if(we_m2s == 0 && cyc_m2s == 1) begin 
                w_state_next = READ;
            end
            if(we_m2s == 1 && cyc_m2s == 1) begin 
                w_state_next = WRITE;
            end
        end
        READ: begin
            w_state_next = IDLE;
            ack_s2m = cyc_m2s & stb_m2s;
            
            case(adr_m2s)
                WWDG_CR_ADR: begin
                    dat_s2m = wwdg_cr; 
                end
                WWDG_CFG_ADR: begin
                    dat_s2m = wwdg_cfg;
                end
                WWDG_ST_ADR: begin
                    dat_s2m = wwdg_st;
                end
            endcase
        end
        WRITE: begin
            w_state_next = IDLE;
            ack_s2m = cyc_m2s & stb_m2s;
            
            case(adr_m2s)
                WWDG_CR_ADR: begin
                    if(wwdg_cr[6:0] > wwdg_cfg[6:0]) begin
                        if(ewi) begin
                            wwdg_ewi = 1;
                        end
                        wwdg_rst = 1;
                        wwdg_window_err_next = 1; 
                    end
                    else begin
                        wwdg_cr_next = dat_m2s;
                        wwdg_pr_cnt_next = wwdg_pr_thr_next;
                        wwdg_window_err_next = 0;
                    end
                end
                WWDG_CFG_ADR: begin
                    wwdg_cfg_next = dat_m2s;
                    case(wwdg_cfg_next[8:7])
                        WDGTB_0: begin
                            wwdg_pr_thr_next = WDGTB_DIV_0;
                        end
                        WDGTB_1: begin
                            wwdg_pr_thr_next = WDGTB_DIV_1;
                        end
                        WDGTB_2: begin
                            wwdg_pr_thr_next = WDGTB_DIV_2;
                        end
                        WDGTB_3: begin
                            wwdg_pr_thr_next = WDGTB_DIV_3;
                        end
                    endcase
                    wwdg_pr_cnt_next = wwdg_pr_thr_next;
                end
                WWDG_ST_ADR: begin
                    wwdg_st_next = dat_m2s;
                end
            endcase
        end
    endcase
end

// Continuos assignments
assign wdga = wwdg_cr[7];
assign ewi = wwdg_cfg[9];

endmodule
