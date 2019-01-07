/* 
 * Module: `tb_WWDG` testbench of Window Watchdog.
 *
 * This testbench module performs a sequence of operations to verify
 * the correct behaviour of a Window Watchdog module. 
 *
 * `R` indicates the expected RESULT of the operation.
 * 
 * 1. RESET
 *  the module is initialized and signals are in their default values.
 * R. The state signals are all initialized.
 *
 * 2. READ - WWDG Control Register.
 *  read the value stored in the control register.
 * R. dat_s2m value must be equal to the value of the wwdg_cr.
 *
 * 3. WRITE - WWDG Control Register with `b1111_1111`.
 *  write the value `b1111_1111` on the control register.
 * R. wwdg_cr must be updated with the value of dat_m2s.
 *  wdga is asserted and countdown is started.
 *
 * 4. WRITE - WWDG Configuration Register with `b00_1111_1111`.
 *  write the value `b00_1111_1111` on the configuration register.
 * R. wwdg_cfg must be updated with the value of dat_m2s. 
 *  Prescale threshold is changed and time window is maxed.
 * 
 * 5. WRITE - WWDG Control Register with `b1100_0001`.
 *  write the value `b1100_0001` on the control register.
 * R. wwdg_cr must be updated with the value of dat_m2s. The timer 
 * value is less than window time and no reset is asserted. For next two
 * prescale time unit wwdg_rst is asserted
 * 
 * 6. WRITE - WWDG Control Register with `b1111_1111`.
 *  write the value `b1111_1111` on the control register.
 * R. wwdg_cr is reloaded.
 *
 * 7. WRITE - WWDG Configuration Register with `b00_1111_0000`.
 *  write the value `b00_1111_0000` on the configuration register.
 * R. wwdg_cfg must be updated with the value of dat_m2s. Time window
 * is changed and is really low.
 *
 * 8. WRITE - WWDG Control Register with `b1111_1111`.
 *  write the value `b1111_1111` on the control register.
 * R. wwdg_rst is asserted because time window specified by wwdg_cfg is not passed.
 *
 * 9. RESET
 *  the module is initialized and signals are in their default values.
 * R. The state signals are all initialized.
 *
 * 10. WRITE - WWDG Control Register with `b1111_1111`.
 *  write the value `b1111_1111` on the control register.
 * R. with default time window the wwdg_cr is updated without asserting the wwdg_rst.
 *  
 * 11. READ - WWDG Control Register.
 *  read the value stored in the control register.
 * R. dat_s2m value must be equal to the value of the wwdg_cr.
 *
 * 12. READ - WWDG Configuration Register.
 *  read the value stored in the configuration register.
 * R. dat_s2m value must be equal to the value of the wwdg_cfg.
 *
 * 13. READ - WWDG Status Register.
 *  read the value stored in the status register.
 * R. dat_s2m value must be equal to the value of the status register.
 *    
 * 14. WRITE - WWDG Configuration Register with `b11_0111_1110`.
 *  write the value `b11_0111_1110 on the configuration register.
 * R. wwdg_cfg must be updated with the value of dat_m2s.
 *  early wakeup interrupt is asserted and threshold prescale is changed.
 *
 * 15. WRITE - WWDG Control Register with `b1100_0001`.
 *  write the value `b1100_0001` on the control register.
 * R. wwdg_cr must be updated with the value of dat_m2s. The timer 
 * value is less than window time and no reset is asserted. For next two
 * prescale time unit wwdg_rst is asserted
 *
 * */


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
    
    // 1. RESET operation  
    repeat(2) @(posedge clk);
    rst <= 0;         
     
    // 2. READ operation
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
     
    // 3. WRITE operation
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
 
    // 4. WRITE operation
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

    // 5. WRITE operation
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
 
    // 6. WRITE operation
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

    // 7. WRITE operation
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

   // 8. WRITE operation
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

    // 9. RESET operation
    rst <= 1;   
    repeat(2) @(posedge clk);
    rst <= 0;         
    
    // 10. WRITE operation
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
    
    // 11. READ operation
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
    
    // 12. READ operation
    @(posedge clk); 
    
    adr_m2s <= WWDG_CFG_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
     
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    
    // 13. READ operation
    @(posedge clk); 
    
    adr_m2s <= WWDG_ST_ADR;
    we_m2s  <= 0;
    cyc_m2s <= 1;
    stb_m2s <= 1;
     
    while(ack_s2m == 0) begin 
       @(posedge clk); 
    end
    cyc_m2s <= 0;  
    stb_m2s <= 0;
    

    // 14. WRITE operation
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
    
    // PAUSE
    repeat(2) @(posedge clk);
    
    // 15. WRITE operation
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
