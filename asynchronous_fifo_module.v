`timescale 1ns/1ps

module async_fifo
# (parameter W = 32, D = 16)
  (input rd_en, wt_en, rd_clk, wt_clk, rstn,
  input [W-1:0] data_in,
  output full, empty,
  output reg [W-1:0] data_out);
  
  reg [$clog2(D):0] wt_pt_bi;
  reg [$clog2(D):0] wt_pt_gr;
  reg [$clog2(D):0] rd_pt_bi;
  reg [$clog2(D):0] rd_pt_gr;
  
  always@(posedge wt_clk or negedge rstn)
  begin 
      if (!rstn) begin
          wt_pt_bi  <= 0;
          wt_pt_gr <= 0;
      end
      else if (wt_en & !full) begin
            wt_pt_bi <= wt_pt_bi + 1;
            wt_pt_gr <= (wt_pt_bi + 1)^((wt_pt_bi +1) >> 1);
      end
  end
  
  always@(posedge rd_clk or negedge rstn)
  begin 
      if (!rstn) begin
          rd_pt_bi  <= 0;
          rd_pt_gr <= 0;
      end
      else if (rd_en & !empty) begin
            rd_pt_bi <= rd_pt_bi + 1;
            rd_pt_gr <= (rd_pt_bi + 1)^((rd_pt_bi +1) >> 1);
      end
  end
  
  reg[$clog2(D):0] rd_pt_sync1;
  reg[$clog2(D):0] rd_pt_sync2;
  reg[$clog2(D):0] wt_pt_sync1;
  reg[$clog2(D):0] wt_pt_sync2;
  
  //domain synchroniser block one, passing read pointer to write domain
  always@(posedge wt_clk or negedge rstn) begin 
    if (!rstn) begin
        rd_pt_sync1 <= 0;
        rd_pt_sync2 <= 0;
    end
    else begin
      rd_pt_sync1 <= rd_pt_gr;    // Catch incoming Read pointer
      rd_pt_sync2 <= rd_pt_sync1; // Stabilise for Write domain
    end
  end
  
  //domain synchroniser block two, passing write pointer to read domain
  always@(posedge rd_clk or negedge rstn) begin 
    if (!rstn) begin
        wt_pt_sync1 <= 0;
        wt_pt_sync2 <= 0;
    end
    else begin 
        wt_pt_sync1 <= wt_pt_gr; // Catch incoming write pointer
        wt_pt_sync2 <= wt_pt_sync1; // Stabilise for read domain
    end
  end

  // logic for full and empty flag determination
    assign empty = (rd_pt_gr == wt_pt_sync2); // read domain
    assign full = ((wt_pt_gr[$clog2(D) : $clog2(D)-1] == ~rd_pt_sync2[$clog2(D) : $clog2(D)-1]) 
                 && (wt_pt_gr[$clog2(D)-2 : 0] == rd_pt_sync2[$clog2(D)-2 : 0]));
 
  // memory block
  reg [W-1:0] mem [D-1:0];
  // write logic
  always @(posedge wt_clk) begin 
      if (wt_en && !full) begin
          mem[wt_pt_bi[$clog2(D)-1 : 0]] <= data_in; // lower bits of the ptr for address
      end
  end
  // read logic
  always @(posedge rd_clk) begin
      if (rd_en && !empty) begin
          data_out <= mem[rd_pt_bi[$clog2(D)-1 : 0]];
      end
  end
endmodule
