`timescale 1ns/100ps
module tb_WWDG
#(

localparam CLK_PERIOD = 10,
localparam END_TEST = 300,

 parameter WWDG_CR_SIZE  = 8,
 parameter WWDG_CFG_SIZE = 10,
 parameter WWDG_ST_SIZE  = 1,

 parameter BASE_ADR     = 32'h0110_0000,          
 parameter WWDG_CR_ADR  = BASE_ADR + 32'h0000_0000,
 parameter WWDG_CFG_ADR = BASE_ADR + 32'h0000_0004,
 parameter WWDG_ST_ADR  = BASE_ADR + 32'h0000_0008
)
();

reg clk;                                 
reg rst;                                
reg [WWDG_CFG_SIZE - 1:0] dat_m2s;
reg [31:0] adr_m2s;                   
reg cyc_m2s;       
reg we_m2s;   
reg stb_m2s; 
    
reg [WWDG_CFG_SIZE - 1:0] dat_s2m;    
reg ack_s2m;                          
reg wwdg_rst;                        
reg wwdg_ewi;

always #(CLK_PERIOD / 2) clk = ~clk;

initial begin
    clk <= 0;
    rst = 1;    
            
    dat_m2s = 0;
    adr_m2s = 0;
    we_m2s  = 0;
    cyc_m2s = 0;        
    stb_m2s = 0;    
    
    // RESET operation   
    repeat(2) @(posedge clk);
    rst <= 0;         
     
    // READ operation
    @(posedge clk); 
    
    adr_m2s <= WWDG_CR_ADR;
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
     
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1111_1111;
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // PAUSE 
    repeat(10) @(posedge clk);
    rst <= 0;         
 
    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CFG_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 10'b00_1111_1111; // change prescale threshold
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1100_0001;
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // PAUSE 
    repeat(5) @(posedge clk);
    rst <= 0;         
 
    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1111_1111;
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CFG_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 10'b00_1111_0000; // change prescale threshold
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

   // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1111_1111;
           
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;

    // RESET operation
    rst <= 1;   
    repeat(2) @(posedge clk);
    rst <= 0;         
    
    // WRITE operation COUNT_KEY
    @(posedge clk);
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1111_1111;
       
    while(ack_s2m == 0) begin 
        @(posedge clk); 
    end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // READ operation
    @(posedge clk); 
    
    adr_m2s <= WWDG_CR_ADR;
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
     
    adr_m2s <= WWDG_CFG_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 10'b11_0111_1110;
    
    while(ack_s2m == 0) begin 
           @(posedge clk); 
        end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    repeat(2) @(posedge clk);
    // WRITE operation COUNT_KEY
    @(posedge clk);
     
    adr_m2s <= WWDG_CR_ADR;
    we_m2s  <= 1;
    cyc_m2s <= 1;
    stb_m2s <= 1;
    dat_m2s <= 8'b1100_0001;
    
    while(ack_s2m == 0) begin 
           @(posedge clk); 
        end   
    cyc_m2s <= 0;  
    stb_m2s <= 0;
       
#END_TEST $finish;
end

WWDG
    dut(
        .clk(clk),
        .rst(rst),
        .dat_m2s(dat_m2s),
        .adr_m2s(adr_m2s),
        .cyc_m2s(cyc_m2s),
        .we_m2s(we_m2s),
        .stb_m2s(stb_m2s),

        .dat_s2m(dat_s2m),
        .ack_s2m(ack_s2m),
        .wwdg_rst(wwdg_rst),
        .wwdg_ewi(wwdg_ewi)
    );
endmodule
