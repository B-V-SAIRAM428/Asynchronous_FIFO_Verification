
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
    output wire full,
    output wire empty,
    output reg [rd_width-1:0] rd_data,
    output reg rd_valid
    );
    localparam addr_width = $clog2(depth);
    reg [addr_width:0] wr_addr, rd_addr;
    wire [addr_width:0] wr_addr_b2g;
    wire [addr_width:0] rd_addr_b2g;
    reg [addr_width:0] wr_addr_b2g_syn1,wr_addr_b2g_syn2;
    reg [addr_width:0] rd_addr_b2g_syn1,rd_addr_b2g_syn2;
    reg [width-1:0] mem [depth-1:0] ;
    integer w,r;
    localparam k1= wr_width / width;   
    localparam k2= rd_width / width;  
    
    
    // Binary to Gray Convertion
    assign wr_addr_b2g = (wr_addr>>1) ^ wr_addr;
    assign rd_addr_b2g = (rd_addr>>1) ^ rd_addr;
    
    always@(posedge rd_clk) begin
        if(rd_rst) begin
            wr_addr_b2g_syn1 <= 0;
            wr_addr_b2g_syn2 <= 0;
        end else begin 
            wr_addr_b2g_syn1 <= wr_addr_b2g;
            wr_addr_b2g_syn2 <= wr_addr_b2g_syn1;
        end
    end
    always@(posedge wr_clk) begin
        if(wr_rst) begin
            rd_addr_b2g_syn1 <= 0;
            rd_addr_b2g_syn2 <= 0;
        end else begin 
            rd_addr_b2g_syn1 <= rd_addr_b2g;
            rd_addr_b2g_syn2 <= rd_addr_b2g_syn1;
        end
    end
    
    assign full = (wr_addr_b2g =={~rd_addr_b2g_syn2[addr_width],rd_addr_b2g_syn2[addr_width-1:0]});
    assign empty = (wr_addr_b2g_syn2[addr_width:0] == rd_addr_b2g[addr_width:0]) ;
 


    // write operation
    always@(posedge wr_clk) begin
        if (wr_rst) begin
            wr_addr <= 0;
        end else if (wr_en && !full && (wr_addr + k1 <= depth)) begin
            for (w=0; w<k1; w=w+1) begin
                mem[wr_addr+w] <= wr_data[(w+1)*width-1 -: width];
            end
            wr_addr <= wr_addr+k1;
       end
   end
    
    
    
       // read operation
       always@(posedge rd_clk) begin
        if (rd_rst) begin
            rd_addr <= 0;
            rd_data <= 0;
            rd_valid <= 0;
        end else if (!empty && rd_en && (rd_addr + k2 <= depth)) begin
            for (r=0; r<k2; r=r+1) begin
                rd_data[(r+1)*width-1 -: width] <= mem[rd_addr+r];
            end
            rd_addr <= rd_addr+k2;
            rd_valid <=1;
       end
       else 
            rd_valid <=0;
       end
       
endmodule
