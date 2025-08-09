`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09.08.2025 12:19:10
// Design Name: 
// Module Name: Verification_of_Asyn_FIFO
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

/// interface module 
interface intf# ( parameter integer wr_width = 16,
                      parameter integer rd_width = 8 )
                      (input logic wr_clk, input logic wr_rst, input logic rd_clk, input logic rd_rst);
    logic wr_en;
    logic [wr_width-1:0] wr_data;
    logic rd_en;
    logic full;
    logic empty;
    logic [rd_width-1:0] rd_data;
    logic rd_valid;
endinterface

////// transaction module
class transaction # ( parameter integer wr_width = 16,
                      parameter integer rd_width = 8 );
    
    rand bit  wr_en;
    rand bit [wr_width-1:0] wr_data;
    rand bit  rd_en;
    bit  full;
    bit empty;
    bit [rd_width-1:0] rd_data;
    bit rd_valid;
    
    function display();
        $display(" wr_en=%0d, wr_data = %0d, rd_en=%0d",wr_en, wr_data, rd_en);
    endfunction
endclass

/////////////generator module 
class generator;
    mailbox gen2dri;
    transaction trans;
    int wr_count = 256;
    int rd_count = 512;
    int idle = 2;
    int total_count = wr_count + rd_count +idle;
    
    function new(mailbox gen2dri);
        this.gen2dri = gen2dri;
    endfunction
    
    task run();
        int i,j,k,s;
        for(i=0; i<total_count; i++) begin
            trans = new();
            ////write opertion generation logic 
            if(j<wr_count) begin
                trans.randomize() with {wr_en == 1 && rd_en==0;};
                j=j+1;
            end else if(k<idle) begin
                trans.wr_en = 0;
                trans.rd_en=0;
                trans.wr_data =0;
                k=k+1;
            end else if(s<rd_count) begin
                trans.wr_en = 0;
                trans.rd_en=1;
                trans.wr_data =0;
                s=s+1;
            end
            gen2dri.put(trans);
            trans.display();
       end
    endtask
endclass


////////// Driver module 
class driver;
    mailbox gen2dri;
    virtual intf vif;
    transaction trans;
    
    function new( mailbox gen2dri,virtual intf vif);
        this.gen2dri = gen2dri;
        this.vif = vif;
    endfunction
    
    task run();
        forever begin
            @(posedge vif.wr_clk);
            if (vif.wr_rst) begin
                vif.wr_en = 0;
                vif.wr_data = 0;
            end else begin
                gen2dri.get(trans);
                trans.display();
                vif.wr_en = trans.wr_en;
                vif.wr_data = trans.wr_data;
            end
            @(posedge vif.rd_clk);
            if (vif.rd_rst) begin
                vif.rd_en =0;
            end else begin
                gen2dri.get(trans);
                trans.display();
                vif.rd_en = trans.rd_en;      
            end
        end
    endtask
endclass

////// Environment module
class environment;
    virtual intf vif;
    generator gen;
    driver dri;
    mailbox gen2dri;
    
    function new(virtual intf vif);
        this.vif = vif;
        gen2dri = new();
        gen = new(gen2dri);
        dri = new(gen2dri, vif);
    endfunction
    
    task run();
        fork
        gen.run();
        dri.run();
        join_none
   endtask
endclass

//// test module 
class test;
    environment env;
    virtual intf vif;
    
    function new(virtual intf vif);
        this.vif = vif;
        env = new(vif);
    endfunction
    
    task run();
        env.run();
    endtask
endclass


////// Top module
module Verification_of_Asyn_FIFO(

    );
    reg wr_clk;
    reg wr_rst;
    reg rd_clk;
    reg rd_rst;
    test t0;
    intf vif(wr_clk,wr_rst, rd_clk, rd_rst);
    FIFO DUT (.wr_clk(wr_clk),
              .wr_rst(wr_rst),
              .wr_en(vif.wr_en),
              .wr_data(vif.wr_data),
              .rd_clk(rd_clk),
              .rd_rst(rd_rst),
              .rd_en(vif.rd_en),
              .full(vif.full),
              .empty(vif.empty),
              .rd_data(vif.rd_data),
              .rd_valid(vif.rd_valid)
              );
    initial begin
        wr_clk = 0; wr_rst = 1;
        rd_clk = 0; rd_rst = 1;
        #10 wr_rst =0; rd_rst=0;
        
        t0 = new(vif);
        t0.run();
        #100 $finish;
    end          
    always #5 wr_clk = ~wr_clk;        
    always #7 rd_clk = ~rd_clk;       
endmodule

