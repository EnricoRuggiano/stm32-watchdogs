`timescale 1ns / 100ps

module tb_IWDG 
#(

localparam CLK_PERIOD = 10,
localparam CLK_LSI_PERIOD = 20, 
localparam END_TEST = 400,

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

// TO:DO synch dual clock

reg clk_lsi;
reg clk_m2s; 
reg rst_m2s;       

reg [IWDG_KR_SIZE - 1:0] dat_m2s; 
reg [31:0] adr_m2s;    

reg cyc_m2s;
reg we_m2s;    

reg stb_m2s;                // Wishbone interface signal used to qualify other signal in a valid cycle.

reg [IWDG_KR_SIZE - 1:0] dat_s2m;         // Wishbone interface binary array used to pass data to the bus.
reg ack_s2m;                // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
reg rst_iwdg;               // IWDG reset signal


always #(CLK_PERIOD / 2) clk_m2s = ~clk_m2s;                    // clock generation
always #(CLK_LSI_PERIOD / 2) clk_lsi = ~clk_lsi;                // clock generation

IWDG                                                            // IWDG instance
 #(

    .IWDG_KR_SIZE(IWDG_KR_SIZE),    
    .IWDG_PR_SIZE(IWDG_PR_SIZE),     
    .IWDG_RLR_SIZE(IWDG_RLR_SIZE),    
    .IWDG_ST_SIZE(IWDG_ST_SIZE),   

    .BASE_ADR(BASE_ADR),             
    .IWDG_KR_ADR(IWDG_KR_ADR),  
    .IWDG_PR_ADR(IWDG_PR_ADR),  
    .IWDG_RLR_ADR(IWDG_RLR_ADR),  
    .IWDG_ST_ADR(IWDG_ST_ADR)  

) IWDG (
    .clk_lsi(clk_lsi),
    .clk_m2s(clk_m2s), 
    .rst_m2s(rst_m2s), 
    
    .dat_m2s(dat_m2s), 
    .adr_m2s(adr_m2s), 
    
    .cyc_m2s(cyc_m2s), 
    .we_m2s(we_m2s),   
    
    .stb_m2s(stb_m2s), 
        
    .dat_s2m(dat_s2m), 
    .ack_s2m(ack_s2m), 
    .rst_iwdg(rst_iwdg)
    
);

initial
    begin
        clk_m2s <= 0;
        clk_lsi <= 0; 
        rst_m2s = 1;    
                
        cyc_m2s = 0;        
        stb_m2s = 0;    
                        
        repeat(2) @(posedge clk_m2s);
        rst_m2s <= 0;         
         
         // READ operation
         @(posedge clk_m2s); 
         adr_m2s <= IWDG_RLR_ADR;
         we_m2s  <= 0;
         cyc_m2s <= 1;
         stb_m2s <= 1;
       
        fork
            while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join        
        cyc_m2s <= 0;  
        stb_m2s <= 0;
         
         // WRITE operation COUNT_KEY
         @(posedge clk_m2s);
         
         adr_m2s <= IWDG_KR_ADR;
         we_m2s  <= 1;
         cyc_m2s <= 1;
         stb_m2s <= 1;
         dat_m2s <= 16'hCCCC;
               
        fork
            while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;
    
        // WRITE operation RELOAD_KEY
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_KR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 16'hAAAA;
           
        fork
            while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;
 
        // Pause
        repeat(2) @(posedge clk_m2s);
        rst_m2s <= 0;         
        
        
        // WRITE operation COUNT_KEY
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_KR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 16'hCCCC;
           
        fork
        while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;
        
        // Pause
        repeat(2) @(posedge clk_m2s);
        rst_m2s <= 0;         
        
        
        // WRITE operation  ACCESS_KEY
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_KR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 16'h5555;
           
        fork
        while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;
        
        // WRITE operation RLR register
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_RLR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 12'h001;
           
        fork
        while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;       
        
        // WRITE operation PR register
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_PR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 3'b001;
           
        fork
        while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;        
 
        // WRITE operation COUNT_KEY
        @(posedge clk_m2s);
        
        adr_m2s <= IWDG_KR_ADR;
        we_m2s  <= 1;
        cyc_m2s <= 1;
        stb_m2s <= 1;
        dat_m2s <= 16'hCCCC;
        
        fork
        while(ack_s2m == 0) begin @(posedge clk_m2s); end;
        join   
        cyc_m2s <= 0;  
        stb_m2s <= 0;

    #END_TEST $finish;
    end
endmodule
