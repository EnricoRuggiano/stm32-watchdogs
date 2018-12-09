`timescale 1ns / 100ps

module tb_IWDG 
#(

localparam CLK_PERIOD = 10,
localparam CLK_LSI_PERIOD = 20, // 31.25 us for 32kHz rc oscillator
localparam END_TEST = 400,

localparam GRL  = 1,  // Granularity of the data    

localparam IWDG_KR_SIZE   = 16,    // IWDG_KR  Last valid bit
localparam IWDG_PR_SIZE   = 3,     // IWDG_PR  Last valid bit
localparam IWDG_RLR_SIZE  = 12,    // IWDG_RLR Last valid bit
localparam IWDG_ST_SIZE   = 2,      // IWDG_ST  Last valid bit

localparam BASE_ADR     = 32'h0100_0000,             // Memory base address of the registries.
localparam IWDG_KR_ADR  = BASE_ADR + 32'h0000_0000,  // Memory address of IWDG_KR register
localparam IWDG_PR_ADR  = BASE_ADR + 32'h0000_0004,  // Memory address of IWDG_PR register
localparam IWDG_RLR_ADR = BASE_ADR + 32'h0000_0008,  // Memory address of IWDG_RLR register
localparam IWDG_ST_ADR  = BASE_ADR + 32'h0000_000C  // Memory address of IWDG_ST register

)();

reg clk_lsi;
reg clk_m2s; 
reg rst_m2s;       

reg [31:0] dat_m2s; 
reg [31:0] adr_m2s;    
reg [GRL:0] sel_m2s;

reg cyc_m2s;
reg we_m2s;    

reg lok_m2s;        // Wishbone interface signal used to indicate that current bus cycle is uninterruptible
reg stb_m2s;        // Wishbone interface signal used to qualify other signal in a valid cycle.

/*
reg tga_m2s;        // Wishbone address tag signal qualified by stb_m2s.    
reg tgc_m2s;        // Wishbone cycle tag signal qualified by cyc_m2s.  
reg tgd_m2s;        // Wishbone data tag signal qualified by stb_m2s.  
*/

reg err_s2m;       // Wishbone interface signal used by SLAVE to indicate an abnormal cycle termination.
reg rty_s2m;       // Wishbone interface signal used by SLAVE to indicate that it is not ready to accept or send data.

// reg tgd_s2m,       // Wishbone data tag signal qualified by stb_m2s.

reg [31:0] dat_s2m;  // Wishbone interface binary array used to pass data to the bus.
reg ack_s2m;         // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
reg rst_iwdg;        // IWDG reset signal


always #(CLK_PERIOD / 2) clk_m2s = ~clk_m2s;   // clock generation
always #(CLK_LSI_PERIOD / 2) clk_lsi = ~clk_lsi;   // clock generation

IWDG   // IWDG instance
 #(
    .GRL(GRL),  // Granularity of the data

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
    .clk_m2s(clk_m2s), // Wishbone SYSCON module clock. The clock of the bus used to coordinate the activities on the interfaces
    .rst_m2s(rst_m2s), // Wishbone SYSCON module reset signal. It forces the Wishbone interface to reset. ALL WISHBONE interfaces must have one.
    
    .dat_m2s(dat_m2s), // Wishbone interface binary array used to pass data arriving from the bus.
    .adr_m2s(adr_m2s), // Wishbone interface binary array used to pass address arriving from the bus.
    .sel_m2s(sel_m2s),
    
    .cyc_m2s(cyc_m2s), // Wishbone interface signal which indicates that a valid bus cycle is in progress.
    .we_m2s(we_m2s),   // Wishbone interface signal which indicates is a WRITE or READ bus cycle
    
    .lok_m2s(lok_m2s),    
    .stb_m2s(stb_m2s), // Wishbone interface signal which is used by the MASTER to poll the SLAVE.
    
    .err_s2m(err_s2m),
    .rty_s2m(rty_s2m),
    
    .dat_s2m(dat_s2m),   // Wishbone interface binary array used to pass data to the bus.
    .ack_s2m(ack_s2m),   // Wishbone interface signal used by the SLAVE to acknoledge a MASTER request. 
    .rst_iwdg(rst_iwdg)  // IWDG reset signal
    
);

initial
    begin
        clk_m2s <= 0;
        clk_lsi <= 0; 
        rst_m2s = 1;    
                
        cyc_m2s = 0;    // must be 0 when rst is 1    
        stb_m2s = 0;    // must be 0 when rst is 1
                        
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
