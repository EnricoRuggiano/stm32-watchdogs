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
    output reg rst_iwdg        // IWDG reset signal
);

reg [IWDG_KR_SIZE - 1:0]  IWDG_KR,  IWDG_KR_next;     // IWDG Key Register. Write here byte words to control the IWDG.
reg [IWDG_PR_SIZE - 1:0]  IWDG_PR,  IWDG_PR_next;     // IWDG Prescale Register. It changes the LSI clock frequency. Initially WRITE PROTECTED
reg [IWDG_RLR_SIZE- 1:0]  IWDG_RLR, IWDG_RLR_next;    // IWDG Reload Register. It stores the watchdog timer countdown. Initially WRITE PROTECTED
reg [IWDG_ST_SIZE - 1:0]  IWDG_ST,  IWDG_ST_next;     // IWDG Status Register. It sets its bit when a prescale is done or an IWDG reset signal is emitted.

reg [1:0] s, ss_next;       // Moore state machine

wire read_cyc, write_cyc, count_cyc;

localparam IDLE  = 2'b00;   // IDLE  state
localparam READ  = 2'b01;   // READ  state
localparam WRITE = 2'b10;   // WRITE state
localparam COUNT = 2'b11;   // COUNTDOWN state

localparam START = 16'hCCCC; // start countdown  IWDG_KR value

always @(posedge clk_m2s)
begin
    if (rst_m2s)               
        begin
            s <= IDLE;
            
            IWDG_KR  <= 16'h0000;
            IWDG_PR  <= 3'b000;
            IWDG_RLR <= 12'hFFF;
            IWDG_ST  <= 2'b00;
        end
    else 
        begin
            s <= ss_next;
            IWDG_KR  <= IWDG_KR_next;
            IWDG_PR  <= IWDG_PR_next;
            IWDG_RLR <= IWDG_RLR_next;
            IWDG_ST  <= IWDG_ST_next;
        end
end

always @(*)
begin
    ss_next = s;
    IWDG_KR_next  = IWDG_KR;
    IWDG_PR_next  = IWDG_PR;
    IWDG_RLR_next = IWDG_RLR;
    IWDG_ST_next  = IWDG_ST;
    
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
                    IWDG_KR_ADR:    dat_s2m = IWDG_KR_next;
                    IWDG_PR_ADR:    dat_s2m = IWDG_PR_next;  
                    IWDG_RLR_ADR:   dat_s2m = IWDG_RLR_next; 
                    IWDG_ST_ADR:    dat_s2m = IWDG_ST_next;
                endcase
                ack_s2m = cyc_m2s & stb_m2s;
                ss_next <= IDLE;
            end 
        WRITE:
            begin
                case(adr_m2s)
                    IWDG_KR_ADR:    IWDG_KR_next  = dat_m2s;
                    IWDG_PR_ADR:    IWDG_PR_next  = dat_m2s;  
                    IWDG_RLR_ADR:   IWDG_RLR_next = dat_m2s; 
                    IWDG_ST_ADR:    IWDG_ST_next  = dat_m2s;
                endcase
                ack_s2m = cyc_m2s & stb_m2s;
                if(IWDG_KR_next == START) 
                    ss_next <= COUNT;
                else
                   ss_next <= IDLE;
            end
        COUNT:
            begin
                 if(IWDG_RLR == 12'h000) rst_iwdg = 1;
                 else
                    IWDG_RLR_next = IWDG_RLR - 12'h001; 
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
assign count_cyc = (IWDG_KR_next == START)? 1 : 0;

endmodule