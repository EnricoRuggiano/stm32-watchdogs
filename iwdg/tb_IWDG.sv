/* 
 * Module: `tb_IWDG` testbench of Indipendent Watchdog.
 *
 * This testbench module performs a sequence of operations to verify
 * the correct behaviour of an Indipendent Watchdog module. 
 *
 * `R` indicates the expected RESULT of the operation.
 * 
 * 1. RESET
 *  to initialize the fifo dual clock macros the rst signal must be high for
 *  at least 5 read and write clock cycle. Also the rden and wren must be low
 *  before rst is asserted.
 * R. The state signals are all initialized.
 *
 * 2. READ - IWDG Reload Register.
 *  read the value stored in the reload register.
 * R. dat_s2m value must be equal to the value of the iwdg_rlr.
 *
 * 3. WRITE - IWDG Key Register with `hCCCC`.
 *  write the value `hCCCC` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and contdown is
 * started.
 *
 * 4. WRITE - IWDG Key Register with `hAAAA`.
 *  write the value `hAAAA` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and iwdg_rlr_cnt must be
 * reloaded.
 * 
 * 5. WRITE - IWDG Key Register with `hCCCC`.
 *  write the value `hCCCC` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and contdown is
 * started.
 * 
 * 6. WRITE - IWDG Key Register with `h5555`.
 *  write the value `h5555` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and iwdg_rlr and
 * iwdg_pr_thr can be modified with a WRITE operation.
 *
 * 7. WRITE - IWDG Reload Register with `h001`.
 *  write the value `h001` on the iwdg_rlr.
 * R. iwdg_rlr must be updated with dat_m2s value.
 *
 * 8. WRITE - IWDG Prescale Register with `b001`.
 *  write the value `b001` and change the iwdg_pr_thr.
 * R. iwdg_pr_thr is updated with the associated value to `b001` and
 * iwdg_pr_sts is asserted.
 *
 * 9. WRITE - IWDG Key Register with `hAAAA`.
 *  write the value `hAAAA` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and iwdg_rlr_cnt must be
 * reloaded.
 *
 * 10. WRITE - IWDG Key Register with `hCCCC`.
 *  write the value `hCCCC` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and contdown is
 * started.
 *   
 * 11. READ - IWDG Status Register.
 *  read the value stored in the status register.
 * R. dat_s2m value must be equal to the value of the status register.
 *
 * 12. READ - IWDG Key Register.
 *  read the value stored in the key register.
 * R. dat_s2m value must be equal to the value of the iwdg_kr.
 *
 * 13. READ - IWDG Prescale Register.
 *  read the value stored in the prescale register.
 * R. dat_s2m value must be equal to the value associated to the iwdg_pr_thr.
 *    
 * 14. READ - IWDG Reload Register.
 *  read the value stored in the reaload counter register.
 * R. dat_s2m value must be equal to the value of iwdg_rlr_cnt.
 *
 * 15. WRITE - IWDG Key Register with `hAAAA`.
 *  write the value `hAAAA` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and iwdg_rlr_cnt must be
 * reloaded.
 *
 * 16. WRITE - IWDG Key Register with `hCCCC`.
 *  write the value `hCCCC` on the key register.
 * R. iwdg_kr must be updated with the value of dat_m2s and contdown is
 * started.

 */

`timescale 1ns / 100ps

module tb_IWDG 
#(

localparam CLK_PERIOD = 10,
localparam CLK_IWDG_PERIOD = 17, 
localparam END_TEST = 500,

parameter IWDG_KR_SIZE   = 16,    
parameter IWDG_PR_SIZE   = 3,     
parameter IWDG_RLR_SIZE  = 12,    
parameter IWDG_ST_SIZE   = 2,     

parameter BASE_ADR     = 32'h0100_0000,             
parameter IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,  
parameter IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,  
parameter IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,  
parameter IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C  

)();

reg iwdg_clk;
reg clk; 
reg rst;       

reg [IWDG_KR_SIZE - 1:0] dat_m2s; 
reg [IWDG_KR_SIZE - 1:0] dat_s2m;         
reg [31:0] adr_m2s;    
reg cyc_m2s;
reg we_m2s;    
reg stb_m2s;                
reg ack_s2m;               
reg iwdg_rst;             

// Clock Initialization
always #(CLK_PERIOD / 2) clk = ~clk;                   
always #(CLK_IWDG_PERIOD / 2) iwdg_clk = ~iwdg_clk;   


initial begin
    clk <= 0;
    iwdg_clk <= 0; 
    rst = 1;    
            
    dat_m2s = 0;
    adr_m2s = 0;
    we_m2s  = 0;
    cyc_m2s = 0;        
    stb_m2s = 0;    
    
    // RESET operation   
    repeat(10) @(posedge clk);
    rst <= 0;         
     
    // READ operation
    @(posedge clk); 
    
    adr_m2s <= IWDG_RLR_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
     
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
     
    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hCCCC;
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation RELOAD_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hAAAA;
       
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // Pause
    repeat(2) @(posedge clk); 
    
    // WRITE operation COUNT_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hCCCC;
       
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // Pause
    repeat(2) @(posedge clk);
    
    // WRITE operation ACCESS_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'h5555;   
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // WRITE operation RLR register
    @(posedge clk);
    
    adr_m2s <= IWDG_RLR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 12'h001;
      
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;       
    
    // WRITE operation PR register
    @(posedge clk);
    
    adr_m2s <= IWDG_PR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 3'b001;
      
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end  
    cyc_m2s <= 0;  
    stb_m2s <= 0;        
    
    // WRITE operation RELOAD_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hAAAA;
       
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation COUNT_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hCCCC;
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

     // READ operation - Status Register
    @(posedge clk); 
    adr_m2s <= IWDG_ST_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end        
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // READ operation - Key Register
    @(posedge clk); 
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
   
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
   
    // READ operation - Prescale Register
    @(posedge clk); 
    adr_m2s <= IWDG_PR_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // READ operation - Reload Register
    @(posedge clk); 
    adr_m2s <= IWDG_RLR_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation RELOAD_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hAAAA;
       
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation COUNT_KEY
    @(posedge clk);
    
    adr_m2s <= IWDG_KR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 16'hCCCC;
    
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

#END_TEST $finish;
end

// IWDG module intance.

 IWDG dut(
    .iwdg_clk(iwdg_clk),
    .clk(clk), 
    .rst(rst), 
    
    .dat_m2s(dat_m2s), 
    .adr_m2s(adr_m2s), 
    
    .cyc_m2s(cyc_m2s), 
    .we_m2s(we_m2s),   
    
    .stb_m2s(stb_m2s), 
        
    .dat_s2m(dat_s2m), 
    .ack_s2m(ack_s2m), 
    .iwdg_rst(iwdg_rst)    
);

endmodule