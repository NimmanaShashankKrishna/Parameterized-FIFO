# ⚙️ Parameterized FIFO — Verilog Implementation

[![Language](https://img.shields.io/badge/Language-Verilog-blue)](https://en.wikipedia.org/wiki/Verilog)
[![Tool](https://img.shields.io/badge/Tool-Xilinx%20Vivado%202025.1-orange)](https://www.xilinx.com/products/design-tools/vivado.html)
[![FPGA](https://img.shields.io/badge/Target-xc7vx485tffg1157--1-green)](https://www.xilinx.com)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

---

## 📌 Overview

A **Parameterized FIFO** is a configurable, reusable FIFO design where the **data width** and **depth** can be set at elaboration time using Verilog `parameter` statements. This is the **industry-standard approach** for writing reusable RTL IP — the same module can be instantiated as an 8-bit × 16-deep FIFO in one block, and a 32-bit × 256-deep FIFO in another.

This design is ideal as a **reusable IP block** in SoC design flows and demonstrates real-world RTL coding practices.

---

## 🏗️ Architecture

```
     ┌────────────────────────────────────────────────────────┐
     │              PARAMETERIZED FIFO                         │
     │                                                          │
     │   Parameters:  DATA_WIDTH = configurable                 │
     │                DEPTH      = configurable                 │
     │                PTR_WIDTH  = $clog2(DEPTH)  [auto]       │
     │                                                          │
     │   clk ──►  ┌───────────────────────────────┐            │
     │   rst_n──► │                               │            │
     │            │   mem[DEPTH-1:0][DATA_WIDTH-1:0]           │
     │   w_en ──► │                               │ ──► data_out│
     │   data_in─►│     wr_ptr [PTR_WIDTH:0]      │            │
     │            │     rd_ptr [PTR_WIDTH:0]       │            │
     │            └───────────────────────────────┘            │
     │                                              ──► full    │
     │                                              ──► empty   │
     └────────────────────────────────────────────────────────┘

  Instantiation examples:
  param_fifo #(.DATA_WIDTH(8),  .DEPTH(16))  u1 (...);  // 8-bit  × 16 deep
  param_fifo #(.DATA_WIDTH(32), .DEPTH(256)) u2 (...);  // 32-bit × 256 deep
  param_fifo #(.DATA_WIDTH(64), .DEPTH(8))   u3 (...);  // 64-bit × 8 deep
```

---

## 📐 Module Description

| Module | Description |
|--------|-------------|
| `param_fifo` | Top-level parameterized FIFO — width and depth configurable at instantiation |
| `tb_param_fifo` | Testbench — tests multiple configurations using the same testbench |

---

## ⚙️ Parameters & Port Description

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DATA_WIDTH` | 8 | Width of each data entry — **override at instantiation** |
| `DEPTH` | 8 | Number of FIFO entries — **override at instantiation** |
| `PTR_WIDTH` | `$clog2(DEPTH)` | Auto-computed pointer width — do not override |

### Ports

| Port | Direction | Width | Description |
|------|-----------|-------|-------------|
| `clk` | Input | 1 | System clock |
| `rst_n` | Input | 1 | Active-low reset |
| `w_en` | Input | 1 | Write enable |
| `r_en` | Input | 1 | Read enable |
| `data_in` | Input | `DATA_WIDTH` | Data input (width is parameterized) |
| `data_out` | Output | `DATA_WIDTH` | Data output (width is parameterized) |
| `full` | Output | 1 | Full flag |
| `empty` | Output | 1 | Empty flag |

---

## 🔑 Key Design Concepts

### 1. `$clog2` for Automatic Pointer Width
```verilog
parameter DATA_WIDTH = 8;
parameter DEPTH      = 8;
localparam PTR_WIDTH = $clog2(DEPTH);  // e.g., DEPTH=8 → PTR_WIDTH=3
```
This ensures the pointer is always the **minimum necessary width** for any depth value, avoiding wasted logic.

### 2. Parameterized Memory Array
```verilog
reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
```
The memory is declared using the parameters — it expands or shrinks automatically at synthesis time.

### 3. Overflow/Underflow Protection
```verilog
always @(posedge clk) begin
    if (w_en && !full)
        mem[wr_ptr] <= data_in;   // Guarded write
    if (r_en && !empty)
        data_out <= mem[rd_ptr];  // Guarded read
end
```

### 4. Full/Empty Using Extra MSB Trick
Using `PTR_WIDTH+1` wide pointers (extra MSB) allows full/empty to be distinguished even when lower bits are equal:
```
FULL  when: wr_ptr[PTR_WIDTH] != rd_ptr[PTR_WIDTH]
            AND wr_ptr[PTR_WIDTH-1:0] == rd_ptr[PTR_WIDTH-1:0]

EMPTY when: wr_ptr == rd_ptr (all bits equal)
```

---

## 🧪 Testbench & Test Cases

The testbench validates the FIFO across **multiple parameter configurations** to prove design reusability.

---

### Test Case 1 — Default Configuration (8-bit × 8-deep)
**Configuration:** `DATA_WIDTH=8`, `DEPTH=8`

**What this tests:**
- Basic write/read operation with default parameters
- `full` flag after 8 writes
- `empty` flag after 8 reads
- Pointer wrap-around at depth=8

> 📸 Add your waveform screenshot here:
> `![TC1 - Default Config](images/tc1_default_8x8.png)`

---

### Test Case 2 — Wider Data (16-bit × 8-deep)
**Configuration:** `DATA_WIDTH=16`, `DEPTH=8`

**What this tests:**
- 16-bit data written and read back correctly
- `data_in[15:0]` and `data_out[15:0]` are both 16 bits wide
- Confirms parameterization scales the data path correctly

> 📸 Add your waveform screenshot here:
> `![TC2 - 16-bit Data](images/tc2_16bit_data.png)`

---

### Test Case 3 — Deeper FIFO (8-bit × 16-deep)
**Configuration:** `DATA_WIDTH=8`, `DEPTH=16`

**What this tests:**
- FIFO accepts 16 entries before asserting `full`
- `PTR_WIDTH` automatically becomes 4 bits (log₂(16))
- Pointer rolls over at 16 correctly

> 📸 Add your waveform screenshot here:
> `![TC3 - Deep FIFO](images/tc3_depth_16.png)`

---

### Test Case 4 — Boundary & Edge Cases
**What this tests:**
- Write to full FIFO → ignored (no overflow, `full` stays HIGH)
- Read from empty FIFO → ignored (no underflow, `empty` stays HIGH)
- Back-to-back write/read at full capacity
- Reset mid-operation: `rst_n` pulsed LOW during write — pointers reset cleanly

> 📸 Add your waveform screenshot here:
> `![TC4 - Edge Cases](images/tc4_edge_cases.png)`

---

## 📁 Repository Structure

```
Parameterized-FIFO/
├── README.md                   ← This file
├── src/
│   └── param_fifo.v            ← Parameterized FIFO design
├── testbench/
│   └── tb_param_fifo.v         ← Testbench (multi-config)
├── images/
│   ├── tc1_default_8x8.png     ← Waveform: 8-bit × 8-deep
│   ├── tc2_16bit_data.png      ← Waveform: 16-bit data width
│   ├── tc3_depth_16.png        ← Waveform: 16-deep FIFO
│   └── tc4_edge_cases.png      ← Waveform: Boundary conditions
└── docs/
    └── design_notes.md
```

---

## 🚀 How to Simulate (Xilinx Vivado)

1. Open **Vivado 2025.1**
2. Create a new project → Add `src/param_fifo.v` as design source
3. Add `testbench/tb_param_fifo.v` as simulation source
4. To test different configurations, change the `#(.DATA_WIDTH(), .DEPTH())` in the testbench
5. Click **Run Simulation → Run Behavioral Simulation**

---

## 🔄 How to Reuse This FIFO in Your Design

```verilog
// 8-bit × 16-deep FIFO instance
param_fifo #(
    .DATA_WIDTH (8),
    .DEPTH      (16)
) fifo_inst (
    .clk      (sys_clk),
    .rst_n    (sys_rst_n),
    .w_en     (write_enable),
    .r_en     (read_enable),
    .data_in  (tx_data),
    .data_out (rx_data),
    .full     (tx_full),
    .empty    (rx_empty)
);
```

---

## 📚 References

- Ciletti, M. D. — *Advanced Digital Design with the Verilog HDL*
- Xilinx UG901 — Vivado Design Suite User Guide: Synthesis
- IEEE Std 1364-2001 — Verilog HDL Standard

---

## 👤 Author

Nimmana Shashank Krishna 
B.E / B.Tech — EEE  
nimmanashashankkrishna@gmail.com
🔗 [LinkedIn](https://linkedin.com/in/yourprofile) | [GitHub](https://github.com/yourusername)

---

*This project was designed and simulated using Xilinx Vivado 2025.1 on xc7vx485tffg1157-1 FPGA target.*
