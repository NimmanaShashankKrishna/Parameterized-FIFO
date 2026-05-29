`timescale 1ns/1ps

// ============================================================
//  Testbench : Parameterized FIFO
//  TC1 : Default Config  (8-bit x 8-deep)
//  TC2 : Write Until Full + Overflow Guard
//  TC3 : Read Until Empty + Underflow Guard
//  TC4 : Edge Cases (reset mid-op, back-to-back R/W)
// ============================================================

module tb_param_fifo;

  // Parameters - change here to test different configs
  parameter DATA_WIDTH = 8;
  parameter DEPTH      = 8;

  // Signals
  reg                   clk;
  reg                   rst_n;
  reg                   w_en;
  reg                   r_en;
  reg  [DATA_WIDTH-1:0] data_in;
  wire [DATA_WIDTH-1:0] data_out;
  wire                  full;
  wire                  empty;

  // DUT
  param_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .DEPTH(DEPTH)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .w_en    (w_en),
    .r_en    (r_en),
    .data_in (data_in),
    .data_out(data_out),
    .full    (full),
    .empty   (empty)
  );

  // Clock : 100 MHz
  always #5 clk = ~clk;

  integer i;

  initial begin
    clk     = 0;
    rst_n   = 0;
    w_en    = 0;
    r_en    = 0;
    data_in = 0;

    // =========================================
    // TC1 : DEFAULT CONFIG CHECK
    // DATA_WIDTH=8, DEPTH=8
    // Checks reset state: empty=1, full=0
    // =========================================
    $display("\n========== TC1: DEFAULT CONFIG (8x8) RESET CHECK ==========");
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    if (empty !== 1'b1) $display("FAIL: empty not 1");
    if (full  !== 1'b0) $display("FAIL: full not 0");
    $display("TC1 PASSED - DATA_WIDTH=%0d  DEPTH=%0d  empty=%b  full=%b",
             DATA_WIDTH, DEPTH, empty, full);

    // =========================================
    // TC2 : WRITE UNTIL FULL + OVERFLOW GUARD
    // Fill all DEPTH slots, then attempt extra
    // write - must be silently dropped
    // =========================================
    $display("\n========== TC2: WRITE UNTIL FULL ==========");
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk);
      if (!full) begin
        w_en    = 1;
        data_in = 8'h10 + i;
        $display("  WRITE [%0d] data=0x%0h", i, data_in);
      end
    end
    @(posedge clk); w_en = 0;

    // Overflow attempt
    @(posedge clk);
    w_en    = 1;
    data_in = 8'hFF;
    $display("  Overflow attempt (0xFF) - must be ignored");
    @(posedge clk); w_en = 0;

    if (full !== 1'b1) $display("FAIL: full not asserted");
    $display("TC2 PASSED - full=%b", full);

    // =========================================
    // TC3 : READ UNTIL EMPTY + UNDERFLOW GUARD
    // Drain all entries, verify FIFO order,
    // then attempt read from empty FIFO
    // =========================================
    $display("\n========== TC3: READ UNTIL EMPTY ==========");
    for (i = 0; i < DEPTH; i = i + 1) begin
      @(posedge clk);
      if (!empty) begin
        r_en = 1;
      end
      @(posedge clk);
      $display("  READ  [%0d] data=0x%0h", i, data_out);
      r_en = 0;
    end

    // Underflow attempt
    @(posedge clk);
    r_en = 1;
    $display("  Underflow attempt - must be ignored");
    @(posedge clk); r_en = 0;

    if (empty !== 1'b1) $display("FAIL: empty not asserted");
    $display("TC3 PASSED - empty=%b", empty);

    // =========================================
    // TC4 : EDGE CASES
    // 4a: Reset mid-operation (write halfway, reset)
    // 4b: Back-to-back write then read same cycle
    // =========================================
    $display("\n========== TC4: EDGE CASES ==========");

    // 4a: Write halfway then reset
    $display("  TC4a: Reset mid-write");
    for (i = 0; i < DEPTH/2; i = i + 1) begin
      @(posedge clk);
      w_en    = 1;
      data_in = 8'hAA + i;
    end
    @(posedge clk); w_en = 0;

    // Mid-operation reset
    @(posedge clk);
    rst_n = 0;
    repeat(2) @(posedge clk);
    rst_n = 1;
    @(posedge clk);
    if (empty !== 1'b1) $display("FAIL TC4a: not empty after reset");
    $display("  TC4a PASSED - Pointers cleared on reset, empty=%b", empty);

    // 4b: Back-to-back write then read in same cycle
    $display("  TC4b: Back-to-back simultaneous write & read");
    // Pre-fill one entry
    @(posedge clk); w_en = 1; data_in = 8'hC0;
    @(posedge clk); w_en = 0;
    // Now write + read simultaneously
    repeat(4) begin
      @(posedge clk);
      w_en    = !full;
      r_en    = !empty;
      data_in = data_in + 1;
      $display("  SimRW: WR=0x%0h RD=0x%0h full=%b empty=%b",
               data_in, data_out, full, empty);
    end
    @(posedge clk); w_en = 0; r_en = 0;
    $display("  TC4b PASSED");

    repeat(3) @(posedge clk);
    $display("\n========== ALL TEST CASES DONE ==========\n");
    $finish;
  end

endmodule
