`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 27.06.2025 18:38:06
// Design Name: 
// Module Name: FIFO
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
module FIFO # ( parameter integer wr_width = 16,
                      parameter integer rd_width = 8,
                      parameter integer depth= 512,
                      parameter integer width = (wr_width < rd_width)? wr_width : rd_width  )
    (
    input wr_clk,
    input wr_rst,
    input wr_en,
    input [wr_width-1:0] wr_data,
    input rd_clk,
    input rd_rst,
    input rd_en,
    output reg full,
    output reg empty,
    output reg [rd_width-1:0] rd_data,
    output reg rd_valid
    );
    reg [8:0] wr_addr, rd_addr;
    integer i;
    reg [width-1:0] mem [depth-1:0] ;
    integer w,r;
    localparam k1= wr_width / width;   
    localparam k2= rd_width / width;  
    
    // write operation
    always@(posedge wr_clk) begin
        if (wr_rst) begin
            for (i=0; i<512; i=i+1) 
                mem[i] <= 0;
            wr_addr <= 0;
            
            full <=0;
        end else if (wr_addr - rd_addr == depth - k1 && wr_en) begin
            for (w=0; w<k1; w=w+1) begin
                mem[wr_addr+w] <= wr_data[(w+1)*width-1 -: width];
            end
            wr_addr <= wr_addr+k1;
            full <= 1;
        end else if (rd_addr - wr_addr == k1 && wr_en) begin
            for (w=0; w<k1; w=w+1) begin
                mem[wr_addr+w] <= wr_data[(w+1)*width-1 -: width];
            end
            wr_addr <= wr_addr+k1;
            full <= 1;
        end else if (!full && wr_en) begin
            for (w=0; w<k1; w=w+1) begin
                mem[wr_addr+w] <= wr_data[(w+1)*width-1 -: width];
            end
            wr_addr <= wr_addr+k1;
            full <= 0;
       end else if ( wr_addr == rd_addr && rd_en)
                full <= 0;
       end
       
       // read operation
       always@(posedge rd_clk) begin
        if (rd_rst) begin
            rd_addr <= 0;
            rd_data <= 0;
            empty <=1;
            rd_valid <= 0;
        end else if (wr_addr - rd_addr  == depth-k2 && rd_en) begin
            for (r=0; r<k2; r=r+1) begin
                rd_data[(r+1)*width-1 -: width] <= mem[rd_addr+r];
            end
            rd_addr <= rd_addr+k2;
            rd_valid <=1;
            empty <= 1;
        end else if (wr_addr - rd_addr == k2 && rd_en) begin
            for (r=0; r<k2; r=r+1) begin
                rd_data[(r+1)*width-1 -: width] <= mem[rd_addr+r];
            end
            rd_addr <= rd_addr+k2;
            empty <= 1;
            rd_valid <=1;
        end else if (!empty && rd_en) begin
            for (r=0; r<k2; r=r+1) begin
                rd_data[(r+1)*width-1 -: width] <= mem[rd_addr+r];
            end
            rd_addr <= rd_addr+k2;
            empty <= 0;
            rd_valid <=1;
       end else if ( wr_addr == rd_addr && wr_en)
            empty <= 0;
       end
endmodule