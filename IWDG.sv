module IWDG 
#(

parameter GRL  = 1,  // Granularity of the data

parameter IWDG_KR_SIZE   = 16,    // IWDG_KR  Last valid bit
parameter IWDG_PR_SIZE   = 3,     // IWDG_PR  Last valid bit
parameter IWDG_RLR_SIZE  = 12,    // IWDG_RLR Last valid bit
parameter IWDG_ST_SIZE   = 2,     // IWDG_ST  Last valid bit

parameter BASE_ADR     = 32'h0100_0000,             // Memory base address of the registries.
parameter IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,  // Memory address of IWDG_KR register
parameter IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,  // Memory address of IWDG_PR register
parameter IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,  // Memory address of IWDG_RLR register
parameter IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C  // Memory address of IWDG_ST register

)
(
    input clk_lsi, // LSI clock from a RC oscillator 
    
    input clk_m2s, // Wishbone SYSCON module clock. The clock of the bus used to coordinate the activities on the interfaces
    input rst_m2s, // Wishbone SYSCON module reset signal. It forces the Wishbone interface to reset. ALL WISHBONE interfaces must have one.
    
    input [31:0] dat_m2s,  // Wishbone interface binary array used to pass data arriving from the bus.
    input [31:0] adr_m2s,  // Wishbone interface binary array used to pass address arriving from the bus.
    input [GRL:0] sel_m2s, // Wishbone interface signal used to indicate valid data on dat_m2s during READ or dat_s2m on WRITE cycle.
        
    input cyc_m2s,        // Wishbone interface signal which indicates that a valid bus cycle is in progress.
    input we_m2s,         // Wishbone interface signal which indicates is a WRITE or READ bus cycle
    
    input lok_m2s,        // Wishbone interface signal used to indicate that current bus cycle is uninterruptible
    input stb_m2s,        // Wishbone interface signal used to qualify other signal in a valid cycle.
/*    
    input tga_m2s,        // Wishbone address tag signal qualified by stb_m2s.    
    input tgc_m2s,        // Wishbone cycle tag signal qualified by cyc_m2s.  
    input tgd_m2s,        // Wishbone data tag signal qualified by stb_m2s.  
*/  
    output err_s2m,       // Wishbone interface signal used by SLAVE to indicate an abnormal cycle termination.
    output rty_s2m,       // Wishbone interface signal used by SLAVE to indicate that it is not ready to accept or send data.
    
    // output tgd_s2m,       // Wishbone data tag signal qualified by stb_m2s.
    
    output reg [31:0] dat_s2m,  // Wishbone interface binary array used to pass data to the bus.
    output reg ack_s2m,         // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
    output rst_iwdg        // IWDG reset signal
);

reg [IWDG_KR_SIZE - 1:0]  iwdg_kr,  iwdg_kr_next;     // IWDG Key Register. Write here byte words to control the IWDG.
reg [IWDG_PR_SIZE - 1:0]  iwdg_pr,  iwdg_pr_next;     // IWDG Prescale Register. It changes the LSI clock frequency. Initially WRITE PROTECTED
reg [IWDG_RLR_SIZE- 1:0]  iwdg_rlr, iwdg_rlr_next;    // IWDG Reload Register. It stores the watchdog timer countdown. Initially WRITE PROTECTED
reg [IWDG_ST_SIZE - 1:0]  iwdg_st,  iwdg_st_next;     // IWDG Status Register. It sets its bit when a prescale is done or an IWDG reset signal is emitted.

reg [1:0] s, ss_next;       // Moore state machine
reg [IWDG_KR_SIZE - 1:0] t, tt_next;

reg [7:0] pr_cnt, pr_cnt_next;  // prescale divider
reg [7:0] pr_thr, pr_thr_next;  // prescale divider


reg rst_iwdg_tmp;

wire read_cyc, write_cyc, count_cyc;

localparam PR_0 = 3'b000;
localparam PR_1 = 3'b001;
localparam PR_2 = 3'b010;
localparam PR_3 = 3'b011;
localparam PR_4 = 3'b100;
localparam PR_5 = 3'b101;
localparam PR_6 = 3'b110;

localparam PR_DIV_4   =  9'b0_0000_0100 - 1;
localparam PR_DIV_8   =  9'b0_0000_1000 - 1;
localparam PR_DIV_16  =  9'b0_0001_0000 - 1;
localparam PR_DIV_32  =  9'b0_0010_0000 - 1;
localparam PR_DIV_64  =  9'b0_0100_0000 - 1;
localparam PR_DIV_128 =  9'b0_1000_0000 - 1;
localparam PR_DIV_256 =  9'b1_0000_0000 - 1;

localparam IDLE  = 2'b00;   // IDLE  state
localparam READ  = 2'b01;   // READ  state
localparam WRITE = 2'b10;   // WRITE state
localparam COUNT = 2'b11;   // COUNTDOWN state


localparam IDLE_KEY = 16'h0000;
localparam COUNT_KEY  = 16'hCCCC; // start countdown  IWDG_KR value
localparam RELOAD_KEY = 16'hAAAA; // 
localparam ACCESS_KEY = 16'h5555; // 

always @(posedge clk_m2s)
begin
    if (rst_m2s)               
        begin
            s <= IDLE;
            iwdg_kr  <= 16'h0000;
            iwdg_pr  <= 3'b000;
            iwdg_st  <= 2'b00;
            
            // iwdg_rlr_next <= 12'h001;//12'hFFF;
        end
    else 
        begin
            s <= ss_next;
            iwdg_kr  <= iwdg_kr_next;
            iwdg_pr  <= iwdg_pr_next;
            iwdg_st  <= iwdg_st_next;
        end
end

always @(posedge clk_lsi)
begin
    
    if (rst_m2s) 
        begin
            t <= IDLE_KEY;
            
            iwdg_rlr <= 12'h001; //12'hFFF;
            pr_thr   <= PR_DIV_4;
            pr_cnt   <= PR_DIV_4;
        end
    else
        begin
            t <= iwdg_kr;
            
            iwdg_rlr <= iwdg_rlr_next;
            pr_thr   <= pr_thr_next;
            pr_cnt   <= pr_cnt_next;      
        end
        
   /*     
    if(iwdg_kr_next == RELOAD_KEY)
        begin
            iwdg_rlr <= 12'hFFF;
            pr_counter <=  pr_counter_next;                    
        end
    else
        begin
        rst_iwdg_tmp = 0;
        end*/
end
/*
always @(pr_counter)
begin
    pr_counter_next = pr_counter;
    iwdg_rlr_next = iwdg_rlr;

    if(pr_counter_next == prescale)
        begin
             if( iwdg_rlr_next == 0) rst_iwdg_tmp = 1; 
             else iwdg_rlr_next = iwdg_rlr - 1;
             pr_counter_next = 0;
        end
    else pr_counter_next = pr_counter + 1;
end
*/

always @(*)
begin
    tt_next = iwdg_kr_next;
    
    iwdg_rlr_next = iwdg_rlr;
    pr_thr_next   = pr_thr;
    pr_cnt_next   = pr_cnt;
    
    /*case (iwdg_kr_next)
        IDLE_KEY:   tt_next = IDLE_KEY; 
        COUNT_KEY:  tt_next = COUNT_KEY; 
        RELOAD_KEY: tt_next = RELOAD_KEY; 
        ACCESS_KEY: tt_next = ACCESS_KEY; 
    endcase    */
    
    case (t)    //  TO-DO: default
        IDLE_KEY:;
        COUNT_KEY:
            begin
                if(pr_cnt_next == 0)
                    begin
                         if(iwdg_rlr_next == 0) 
                            rst_iwdg_tmp = 1; 
                         else 
                            iwdg_rlr_next = iwdg_rlr - 1;
                         pr_cnt_next = pr_thr;
                    end
                else 
                    pr_cnt_next = pr_cnt - 1;
            end
        RELOAD_KEY:
            begin
                pr_cnt_next = pr_thr;
                iwdg_rlr_next = 12'hFFF;            
            end
        ACCESS_KEY:;      
    endcase
end

always @(*)
begin
    ss_next = s;
    iwdg_kr_next  = iwdg_kr;
    iwdg_pr_next  = iwdg_pr;
    iwdg_st_next  = iwdg_st;

    /*case (iwdg_pr) // TO_DO: default
        PR_0: pr_thr_next = PR_DIV_4 - 1;
        PR_1: pr_thr_next = PR_DIV_8 - 1;
        PR_2: pr_thr_next = PR_DIV_16 - 1;
        PR_3: pr_thr_next = PR_DIV_32 - 1;
        PR_4: pr_thr_next = PR_DIV_64 - 1;
        PR_5: pr_thr_next = PR_DIV_128 - 1;
        PR_6: pr_thr_next = PR_DIV_256 - 1;
    endcase
    */
       
    case (s)
        IDLE: 
            begin 
                if(read_cyc) ss_next = READ;
                else if (write_cyc) ss_next = WRITE;
                ack_s2m = 0;
            end
        READ:
            begin
                case(adr_m2s)
                    IWDG_KR_ADR:    dat_s2m = iwdg_kr_next;
                    IWDG_PR_ADR:    dat_s2m = iwdg_pr_next;  
                    IWDG_RLR_ADR:   dat_s2m = iwdg_rlr_next; 
                    IWDG_ST_ADR:    dat_s2m = iwdg_st_next;
                endcase
                ack_s2m = cyc_m2s & stb_m2s;
                ss_next = IDLE;
            end 
        WRITE:
            begin
                case(adr_m2s)
                    IWDG_KR_ADR:    iwdg_kr_next  = dat_m2s;
                    IWDG_PR_ADR:    iwdg_pr_next  = dat_m2s;  
                    IWDG_RLR_ADR:   ;//iwdg_rlr_next = dat_m2s; 
                    IWDG_ST_ADR:    iwdg_st_next  = dat_m2s;
                endcase
            
                
                //if(iwdg_kr_next == START_KEY) pr_counter_next = 0;
                //if(iwdg_kr_next == RELOAD_KEY) pr_counter_next = 0;
                //if(iwdg_kr_next == START_KEY) pr_counter_next = 0;
                
                ack_s2m = cyc_m2s & stb_m2s;
                ss_next = IDLE;
            end
        default: 
            ss_next = IDLE;        
    endcase
end

//assign ack_s2m = cyc_m2s & stb_m2s;
//assign rty_s2m = (stb_m2s == 0)? 0 : X; // SLAVE automatically negates rty_s2m when stb is negated
//assign err_s2m = (stb_m2s == 0)? 0 : X; // SLAVE automatically negates err_s2m when stb is negated

assign read_cyc  = (we_m2s == 0 && cyc_m2s == 1)? 1 : 0;
assign write_cyc = (we_m2s == 1 && cyc_m2s == 1)? 1 : 0;
//assign count_cyc = (iwdg_kr_next == START)? 1 : 0;

assign  rst_iwdg = rst_iwdg_tmp;
//assign  t = iwdg_kr_next;

endmodule