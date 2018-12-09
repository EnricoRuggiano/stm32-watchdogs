`timescale 1ns / 100ps

module tb_IWDG 
#(

localparam CLK_PERIOD = 10,
localparam CLK_LSI_PERIOD = 20, 
localparam END_TEST = 400,

localparam GRL  = 1,      

localparam IWDG_KR_SIZE   = 16,    
localparam IWDG_PR_SIZE   = 3,     
localparam IWDG_RLR_SIZE  = 12,    
localparam IWDG_ST_SIZE   = 2,     

localparam BASE_ADR     = 32'h0100_0000,             
localparam IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,  
localparam IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,  
localparam IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,  
localparam IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C  

)();

reg clk_lsi;
reg clk_m2s; 
reg rst_m2s;       

reg [31:0] dat_m2s; 
reg [31:0] adr_m2s;    
reg [GRL:0] sel_m2s;

reg cyc_m2s;
reg we_m2s;    

reg lok_m2s;                // Wishbone interface signal used to indicate that current bus cycle is uninterruptible
reg stb_m2s;                // Wishbone interface signal used to qualify other signal in a valid cycle.

/*
reg tga_m2s;                // Wishbone address tag signal qualified by stb_m2s.    
reg tgc_m2s;                // Wishbone cycle tag signal qualified by cyc_m2s.  
reg tgd_m2s;                // Wishbone data tag signal qualified by stb_m2s.  
*/

reg err_s2m;                // Wishbone interface signal used by SLAVE to indicate an abnormal cycle termination.
reg rty_s2m;                // Wishbone interface signal used by SLAVE to indicate that it is not ready to accept or send data.

// reg tgd_s2m,             // Wishbone data tag signal qualified by stb_m2s.

reg [31:0] dat_s2m;         // Wishbone interface binary array used to pass data to the bus.
reg ack_s2m;                // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
reg rst_iwdg;               // IWDG reset signal


always #(CLK_PERIOD / 2) clk_m2s = ~clk_m2s;                    // clock generation
always #(CLK_LSI_PERIOD / 2) clk_lsi = ~clk_lsi;                // clock generation

IWDG                                                            // IWDG instance
 #(
    .GRL(GRL),                                                  // Granularity of the data

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
    .sel_m2s(sel_m2s),
    
    .cyc_m2s(cyc_m2s), 
    .we_m2s(we_m2s),   
    
    .lok_m2s(lok_m2s),    
    .stb_m2s(stb_m2s), 
    
    .err_s2m(err_s2m),
    .rty_s2m(rty_s2m),
    
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
         adr_m2s <= IWDG_KR_ADR;
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
