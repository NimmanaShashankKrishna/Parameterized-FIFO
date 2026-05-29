// ============================================================
//  Parameterized FIFO
//  - Configurable DATA_WIDTH and DEPTH at instantiation
//  - PTR_WIDTH auto-computed using $clog2
//  - Extra MSB trick for full/empty distinction
//  - Active-low synchronous reset
// ============================================================

module param_fifo #
(
  parameter DATA_WIDTH = 8,
  parameter DEPTH      = 8
)
(
  input                        clk,
  input                        rst_n,
  input                        w_en,
  input                        r_en,
  input  [DATA_WIDTH-1:0]      data_in,
  output reg [DATA_WIDTH-1:0]  data_out,
  output wire                  full,
  output wire                  empty
);

  // Auto-compute pointer width
  localparam PTR_WIDTH = $clog2(DEPTH);

  // ---- Memory Array ----
  reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // ---- Pointers (extra MSB for full/empty distinction) ----
  reg [PTR_WIDTH:0] wr_ptr;
  reg [PTR_WIDTH:0] rd_ptr;

  // ---- Full / Empty Flags ----
  // EMPTY : all bits equal
  // FULL  : MSBs differ, lower bits equal
  assign empty = (wr_ptr == rd_ptr);
  assign full  = (wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]) &&
                 (wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]);

  // ---- Write Logic ----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      wr_ptr <= 0;
    else if (w_en && !full) begin
      mem[wr_ptr[PTR_WIDTH-1:0]] <= data_in;
      wr_ptr                     <= wr_ptr + 1;
    end
  end

  // ---- Read Logic ----
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rd_ptr   <= 0;
      data_out <= {DATA_WIDTH{1'b0}};
    end
    else if (r_en && !empty) begin
      data_out <= mem[rd_ptr[PTR_WIDTH-1:0]];
      rd_ptr   <= rd_ptr + 1;
    end
  end

endmodule
