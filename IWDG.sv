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
    input iwdg_clk,                            // LSI clock from a RC oscillator 
    input clk,                                 // Wishbone SYSCON module clock. The clock of the bus used to coordinate the activities on the interfaces
    input rst,                                 // Wishbone SYSCON module reset signal. It forces the Wishbone interface to reset. ALL WISHBONE interfaces must have one.
    input [IWDG_KR_SIZE - 1:0] dat_m2s,        // Wishbone interface binary array used to pass data arriving from the bus.
    input [31:0] adr_m2s,                      // Wishbone interface binary array used to pass address arriving from the bus.        
    input cyc_m2s,                             // Wishbone interface signal which indicates that a valid bus cycle is in progress.
    input we_m2s,                              // Wishbone interface signal which indicates is a WRITE or READ bus cycle
    input stb_m2s,                             // Wishbone interface signal used to qualify other signal in a valid cycle.
    
    output reg [IWDG_KR_SIZE - 1:0] dat_s2m,   // Wishbone interface binary array used to pass data to the bus.
    output reg ack_s2m,                        // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request.  
    output reg iwdg_rst                        // IWDG reset signal
);

                                               // PARAMETERS:
                                               
                                               // - Wishbone states
localparam IDLE  = 2'b00;   
localparam READ  = 2'b01;   
localparam WRITE = 2'b10;   

                                               // - FSM states and Key Register possible values.
localparam IDLE_KEY   = 16'h0000;
localparam COUNT_KEY  = 16'hCCCC; 
localparam RELOAD_KEY = 16'hAAAA;  
localparam ACCESS_KEY = 16'h5555;  

                                               // - Prescale Register possible values. 
                                               //    to each PR_X value is associated a PR_DIV_X prescale count threshold
localparam PR_0 = 3'b000;                             
localparam PR_1 = 3'b001;
localparam PR_2 = 3'b010;
localparam PR_3 = 3'b011;
localparam PR_4 = 3'b100;
localparam PR_5 = 3'b101;
localparam PR_6 = 3'b110;
                                            
localparam PR_DIV_2   =  2'b11;               // - Prescale Register Divider count threshold. 
localparam PR_DIV_4   =  7'b000_0000;         //     the threshold indicates how many lsi clock periods are needed before downcounting the rlr register
localparam PR_DIV_8   =  7'b000_0010 - 1;
localparam PR_DIV_16  =  7'b000_0100 - 1;
localparam PR_DIV_32  =  7'b000_1000 - 1;
localparam PR_DIV_64  =  7'b001_0000 - 1;
localparam PR_DIV_128 =  7'b010_0000 - 1;
localparam PR_DIV_256 =  7'b100_0000 - 1;
            
                                              // - Protocol constants and parameters.
                                              //      data is passed from the Wishbone communication interface to the indipentent clock
                                              //  downcounter through a DUAL CLOCK FIFO according the following Protocol:
                                              //
                                              //  { OPR_HEADER, ADR_HEADER, PAYLOAD }   
                                              //
                                              //  OPR_HEADER.
                                              // Operation header. Indicates what type of operation is performed. e.g Write or Read operation. 
                                              //
                                              //  ADR_HEADER
                                              //  Address header, Indicates from which register data is read or in which register data is writtem.
                                              //
                                              //  PAYLOAD
                                              //  data that is needed to be written on a register or is read from a register
                                                
localparam OPR_HEADER_SIZE  = 1;     
localparam ADR_HEADER_SIZE  = 2;            
localparam PAYLOAD_SIZE     = IWDG_KR_SIZE;

localparam OPR_RD_HEADER  = 0;
localparam OPR_WR_HEADER  = 1;                                
localparam ADR_KR_HEADER  = 2'b00;
localparam ADR_RLR_HEADER = 2'b01;
localparam ADR_PR_HEADER  = 2'b10;
localparam ADR_ST_HEADER  = 2'b11;
                       
                                               // - FIFO DUAL CLOCK MACRO parameters

localparam ALMOST_OFFSET           = 9'h080;
localparam DATA_WIDTH              = OPR_HEADER_SIZE + ADR_HEADER_SIZE + PAYLOAD_SIZE;
localparam DEVICE                  = "7SERIES";
localparam FIFO_SIZE               = "18Kb";
localparam FIRST_WORD_FALL_THROUGH = "TRUE";

                                               // - Protocol start and end bit 

localparam OPR_HEADER_STR = PAYLOAD_SIZE + ADR_HEADER_SIZE;
localparam OPR_HEADER_END = DATA_WIDTH - 1;
localparam ADR_HEADER_STR = PAYLOAD_SIZE;
localparam ADR_HEADER_END = PAYLOAD_SIZE + ADR_HEADER_SIZE - 1;
localparam PAYLOAD_STR    = 0;
localparam PAYLOAD_END    = PAYLOAD_SIZE - 1;

                                                  
                                               // VERILOG VARIABLES
                                               
                                               // - DUAL CLOCK FIFO wire variables


wire [DATA_WIDTH - 1:0]  f_do_t2d,  f_do_d2t; 
wire [DATA_WIDTH - 1:0]  f_di_t2d,  f_di_d2t;

wire      f_empty_t2d,    f_empty_d2t;
wire      f_full_t2d,     f_full_d2t;
wire      f_rden_t2d,     f_rden_d2t;
wire      f_wren_t2d,     f_wren_d2t;

wire      f_rdclk_t2d,    f_rdclk_d2t;
wire      f_wrclk_t2d,    f_wrclk_d2t;
wire      f_rst_t2d,      f_rst_d2t;

                                                        // protocol
wire [OPR_HEADER_SIZE - 1:0] p_opr_header_t2d; 
wire [ADR_HEADER_SIZE - 1:0] p_adr_header_t2d; 
wire [DATA_WIDTH - ADR_HEADER_SIZE - 1:0] p_payload_t2d;





// Wishbone state.
                                                      
reg [1:0] w_state, w_state_next;

// key register
// reload counter register
// prescale counter
// prescale threshold

// prescale status bit
// reload status bit
                                              
reg [IWDG_KR_SIZE - 1:0] iwdg_kr, iwdg_kr_next;
reg [IWDG_RLR_SIZE- 1:0] iwdg_rlr, iwdg_rlr_next;
reg [7:0] iwdg_pr_cnt, iwdg_pr_cnt_next;           
reg [5:0] iwdg_pr_thr, iwdg_pr_thr_next;       

reg iwdg_pr_sts,  iwdg_pr_sts_next;                        
reg iwdg_rlr_sts, iwdg_rlr_sts_next;                       

                                                      
                                                      
                                                        // fifo                                                     
reg [DATA_WIDTH - 1:0]  f_di_t2d_tmp,  f_di_d2t_tmp;
reg       f_rden_t2d_tmp,    f_rden_d2t_tmp;
reg       f_wren_t2d_tmp,    f_wren_d2t_tmp;


                                                    // TOP FSA MOORE: Sequential part 
always @(posedge clk) begin
    if (rst) begin
        w_state <= IDLE;
    end
    else begin
        w_state <= w_state_next;
    end
end
                                                    // LOWER FSA MOORE: Sequential part
always @(posedge iwdg_clk) begin    
    if (rst) begin
        iwdg_kr      <= IDLE_KEY;       
        iwdg_rlr     <= 12'h001; //12'hFFF
        iwdg_pr_cnt  <= {PR_DIV_4, PR_DIV_2};
        iwdg_pr_thr  <= PR_DIV_4;
        iwdg_rlr_sts <= 0;
        iwdg_pr_sts  <= 0;                        
    end
    else begin
        iwdg_kr      <= iwdg_kr_next;          
        iwdg_rlr     <= iwdg_rlr_next;
        iwdg_pr_cnt  <= iwdg_pr_cnt_next;
        iwdg_pr_thr  <= iwdg_pr_thr_next;
        iwdg_rlr_sts <= iwdg_rlr_sts_next;
        iwdg_pr_sts  <= iwdg_pr_sts_next;    
    end
end

                                                    // TOP FSA MOORE: Combinatorial part
always @(*) begin
    w_state_next = w_state;
    dat_s2m = 0;
    ack_s2m = 0;    
    
    f_rden_d2t_tmp = 0;
    f_wren_t2d_tmp = 0;  
    f_di_t2d_tmp   = 0;
    
    // READ OPERATION.
    // reads from down layers register through fifo_d2t and put data in output dat_s2m
    if(!f_empty_d2t) begin
        f_rden_d2t_tmp = 1;
        dat_s2m = 0 + f_do_d2t;
    end
        
    case (w_state)
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
            w_state_next = IDLE;
            ack_s2m = cyc_m2s & stb_m2s;
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

                                                    // LOWER FSA MOORE: Combinatorial part
always @(*) begin
    iwdg_kr_next = iwdg_kr;    
    iwdg_rlr_next = iwdg_rlr;
    iwdg_pr_cnt_next = iwdg_pr_cnt;
    iwdg_pr_thr_next = iwdg_pr_thr;
    iwdg_rlr_sts_next = 0;
    iwdg_pr_sts_next = 0;
    iwdg_rst = 0;
    
    f_rden_t2d_tmp = 0;
    f_wren_d2t_tmp = 0;
    f_di_d2t_tmp   = 0;
    
    if(!f_empty_t2d) begin
        f_rden_t2d_tmp = 1;
            
        case (p_opr_header_t2d)
            
            OPR_RD_HEADER: begin
                f_wren_d2t_tmp = 1;
    
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
                        f_di_d2t_tmp = 0 + iwdg_rlr_next;
                    end
                    ADR_ST_HEADER: begin
                        f_di_d2t_tmp = 0 + {iwdg_rlr_sts_next, iwdg_pr_sts_next};
                    end
                endcase
            end              
            
            OPR_WR_HEADER:
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
                            iwdg_pr_sts_next = 1;
                        end 
                    end    
                    ADR_RLR_HEADER: begin
                        if(iwdg_kr_next == ACCESS_KEY) begin
                            iwdg_rlr_next = p_payload_t2d[IWDG_RLR_SIZE - 1:0];
                        end
                    end    
                    ADR_ST_HEADER: begin
                        iwdg_pr_sts_next  = p_payload_t2d[0];
                        iwdg_rlr_sts_next = p_payload_t2d[1];
                    end
                endcase
        endcase            
    end    
    
    case (iwdg_kr)
        COUNT_KEY: begin
            if(iwdg_pr_cnt_next == 0) begin
                if(iwdg_rlr_next == 0) begin
                    iwdg_rlr_next = 12'hFFF;
                    iwdg_rst = 1; 
                end
                else begin
                    iwdg_rlr_next = iwdg_rlr - 1;
                    iwdg_pr_cnt_next = {iwdg_pr_thr, PR_DIV_2};
                end
            end
            else begin 
                iwdg_pr_cnt_next = iwdg_pr_cnt - 1;
            end
        end
        RELOAD_KEY: begin
                iwdg_pr_cnt_next = {iwdg_pr_thr, PR_DIV_2};
                iwdg_rlr_next = 12'hFFF;
                iwdg_rlr_sts_next = 1;            
        end     
    endcase
end

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

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),               // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET),                // Sets almost full threshold
  .DATA_WIDTH(DATA_WIDTH),                           // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DEVICE(DEVICE),                                   // Target device: "7SERIES" 
  .FIFO_SIZE (FIFO_SIZE),                            // Target BRAM: "18Kb" or "36Kb" 
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) // Sets the FIFO FWFT to "TRUE" or "FALSE" 
) FIFO_DUALCLOCK_MACRO_t2d (
  .DO(f_do_t2d),                                       // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(f_empty_t2d),                                 // 1-bit output empty
  .FULL(f_full_t2d),                                   // 1-bit output full
  .DI(f_di_t2d),                                       // Input data, width defined by DATA_WIDTH parameter
  .RDCLK(f_rdclk_t2d),                                 // 1-bit input read clock
  .RDEN(f_rden_t2d),                                   // 1-bit input read enable
  .RST(f_rst_t2d),                                     // 1-bit input reset
  .WRCLK(f_wrclk_t2d),                                 // 1-bit input write clock
  .WREN(f_wren_t2d)                                    // 1-bit input write enable
);

FIFO_DUALCLOCK_MACRO  #(
  .ALMOST_EMPTY_OFFSET(ALMOST_OFFSET),               // Sets the almost empty threshold
  .ALMOST_FULL_OFFSET(ALMOST_OFFSET),                // Sets almost full threshold
  .DATA_WIDTH(DATA_WIDTH),                           // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
  .DEVICE(DEVICE),                                   // Target device: "7SERIES" 
  .FIFO_SIZE (FIFO_SIZE),                            // Target BRAM: "18Kb" or "36Kb" 
  .FIRST_WORD_FALL_THROUGH (FIRST_WORD_FALL_THROUGH) // Sets the FIFO FWFT to "TRUE" or "FALSE" 
) FIFO_DUALCLOCK_MACRO_d2t (
  .DO(f_do_d2t),                                       // Output data, width defined by DATA_WIDTH parameter
  .EMPTY(f_empty_d2t),                                 // 1-bit output empty
  .FULL(f_full_d2t),                                   // 1-bit output full
  .DI(f_di_d2t),                                       // Input data, width defined by DATA_WIDTH parameter
  .RDCLK(f_rdclk_d2t),                                 // 1-bit input read clock
  .RDEN(f_rden_d2t),                                   // 1-bit input read enable
  .RST(f_rst_d2t),                                     // 1-bit input reset
  .WRCLK(f_wrclk_d2t),                                 // 1-bit input write clock
  .WREN(f_wren_d2t)                                    // 1-bit input write enable
);

endmodule