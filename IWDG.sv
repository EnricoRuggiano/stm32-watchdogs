module IWDG 
#(

parameter GRL  = 1,                                 // Granularity of the data

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
    
    input [31:0] dat_m2s,       // Wishbone interface binary array used to pass data arriving from the bus.
    input [31:0] adr_m2s,       // Wishbone interface binary array used to pass address arriving from the bus.
    input [GRL:0] sel_m2s,      // Wishbone interface signal used to indicate valid data on dat_m2s during READ or dat_s2m on WRITE cycle.
        
    input cyc_m2s,              // Wishbone interface signal which indicates that a valid bus cycle is in progress.
    input we_m2s,               // Wishbone interface signal which indicates is a WRITE or READ bus cycle
    
    input lok_m2s,              // Wishbone interface signal used to indicate that current bus cycle is uninterruptible
    input stb_m2s,              // Wishbone interface signal used to qualify other signal in a valid cycle.
/*    
    input tga_m2s,              // Wishbone address tag signal qualified by stb_m2s.    
    input tgc_m2s,              // Wishbone cycle tag signal qualified by cyc_m2s.  
    input tgd_m2s,              // Wishbone data tag signal qualified by stb_m2s.  
*/  
    output err_s2m,             // Wishbone interface signal used by SLAVE to indicate an abnormal cycle termination.
    output rty_s2m,             // Wishbone interface signal used by SLAVE to indicate that it is not ready to accept or send data.
    
    // output tgd_s2m,          // Wishbone data tag signal qualified by stb_m2s. 
    output reg [31:0] dat_s2m,  // Wishbone interface binary array used to pass data to the bus.
    output reg ack_s2m,         // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
    
    output rst_iwdg             // IWDG reset signal
);
                                                      // TOP FSA MOORE MACHINE: WISHBONE INTERFACE
                                                      // - REGISTERS:

reg [IWDG_KR_SIZE - 1:0]  iwdg_kr,  iwdg_kr_next;     // IWDG Key Register. Key word changes the state of LOWER FSA MOORE MACHINE.
reg [IWDG_PR_SIZE - 1:0]  iwdg_pr,  iwdg_pr_next;     // IWDG Prescale Register. It changes how many clk cycle to count to change the countdown.
reg [IWDG_RLR_SIZE- 1:0]  iwdg_rlr, iwdg_rlr_next;    // IWDG Reload Register. It stores the IWDG countdown.
reg [IWDG_ST_SIZE - 1:0]  iwdg_st,  iwdg_st_next;     // IWDG Status Register. It is set when a RELOAD or PRESCALE operation is done.

                                                      // - MOORE STATES:
reg [1:0] s, ss_next;                                 // 3 states codified in 2 bits. One is unused.


                                                      // LOWER FSA MOORE MACHINE: COUNTDOWN
                                                      // - REGISTERS:

reg [IWDG_RLR_SIZE- 1:0] cnt_rlr, cnt_rlr_next;       // RLR-Sized bit counter register. The downcount is performed here. 
reg [7:0] cnt_pr, cnt_pr_next;                        // 8-bit counter register. Counts how many lsi-clock transition before donwcount the cnt_rlr
reg [7:0] thr_pr, thr_pr_next;                        // 8-bit threshold register. Constant value needed to compare the cnt_pr register.
reg sts_pr,  sts_pr_next;                             // 1-bit signal. Is set when a PRESCALE operation is done.
reg sts_rlr, sts_rlr_next;                            // 1-bit signal. Is set when a RELOAD operation is done

                                                      // - MOORE STATES:
reg [IWDG_KR_SIZE - 1:0] t, tt_next;                  // the state is equal to IWDG Key Register.


reg rst_iwdg_tmp;
wire read_cyc, write_cyc;

                                                      // PARAMETERS:
                                                      // - PRESCALE TRUTH TABLE
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

                                                    // - TOP FSA MOORE MACHINE states decodification
localparam IDLE  = 2'b00;   
localparam READ  = 2'b01;   
localparam WRITE = 2'b10;   

                                                    // - LOWER FSA MOORE MACHINE states decodification
localparam IDLE_KEY   = 16'h0000;
localparam COUNT_KEY  = 16'hCCCC; 
localparam RELOAD_KEY = 16'hAAAA;  
localparam ACCESS_KEY = 16'h5555;  


                                                    // TOP FSA MOORE: Sequential part 
always @(posedge clk_m2s)
begin
    if (rst_m2s)               
        begin
            s <= IDLE;
            iwdg_kr  <= 16'h0000;
            iwdg_rlr <= 12'hfff;
            iwdg_pr  <= 3'b000;
            iwdg_st  <= 2'b00;            
        end
    else 
        begin
            s <= ss_next;
            iwdg_kr  <= iwdg_kr_next;
            iwdg_rlr <= cnt_rlr_next;
//            iwdg_rlr <= iwdg_rlr_next;
            iwdg_pr  <= iwdg_pr_next;
            
            iwdg_st[0]  <= sts_pr_next;
            iwdg_st[1]  <= sts_rlr_next;

        end
end
                                                    // LOWER FSA MOORE: Sequential part
always @(posedge clk_lsi)                            
begin    
    if (rst_m2s) 
        begin
            t <= IDLE_KEY;       
            cnt_rlr  <= 12'h001; //12'hFFF
            cnt_pr   <= PR_DIV_4;
            thr_pr   <= PR_DIV_4;
            sts_rlr  <= 0;
            sts_pr   <= 0;
        end
    else
        begin
            t <= iwdg_kr;          
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
    iwdg_kr_next  = iwdg_kr;
    iwdg_rlr_next = iwdg_rlr;
    iwdg_pr_next  = iwdg_pr;   
    iwdg_st_next  = iwdg_st;
    
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
                    IWDG_RLR_ADR:   iwdg_rlr_next = dat_m2s; 
                    IWDG_ST_ADR:    iwdg_st_next  = dat_m2s;
                endcase         
                ack_s2m = cyc_m2s & stb_m2s;
                ss_next = IDLE;
            end
        default: 
            ss_next = IDLE;        
    endcase
end

                                                    // LOWER FSA MOORE: Combinatorial part
always @(*)
begin
    tt_next = iwdg_kr_next;    
    cnt_rlr_next  = cnt_rlr;
    cnt_pr_next   = cnt_pr;
    thr_pr_next   = thr_pr;
    sts_rlr_next  = 0;
    sts_pr_next   = 0;
    rst_iwdg_tmp  = 0;
        
    case (t)    //  TO-DO: default
        IDLE_KEY:;
        COUNT_KEY:
            begin
                if(cnt_pr_next == 0)
                begin
                    if(cnt_rlr_next == 0) 
                    begin
                        rst_iwdg_tmp = 1;
                        cnt_rlr_next = 12'hFFF; 
                    end
                    else 
                        cnt_rlr_next = cnt_rlr - 1;
                        cnt_pr_next = thr_pr;
                end
                else 
                    cnt_pr_next = cnt_pr - 1;
            end
        RELOAD_KEY:
            begin
                cnt_pr_next = thr_pr;
                cnt_rlr_next = 12'hFFF;
                sts_rlr_next = 1;            
            end
        ACCESS_KEY:
            begin
                cnt_rlr_next = iwdg_rlr_next;
                sts_pr_next = 1;
                case (iwdg_pr_next)
                    PR_0: thr_pr_next = PR_DIV_4;
                    PR_1: thr_pr_next = PR_DIV_8;
                    PR_2: thr_pr_next = PR_DIV_16;
                    PR_3: thr_pr_next = PR_DIV_32;
                    PR_4: thr_pr_next = PR_DIV_64;
                    PR_5: thr_pr_next = PR_DIV_128;
                    PR_6: thr_pr_next = PR_DIV_256;
                endcase
            end      
    endcase
end

assign read_cyc  = (we_m2s == 0 && cyc_m2s == 1)? 1 : 0;
assign write_cyc = (we_m2s == 1 && cyc_m2s == 1)? 1 : 0;
assign  rst_iwdg = rst_iwdg_tmp;

endmodule