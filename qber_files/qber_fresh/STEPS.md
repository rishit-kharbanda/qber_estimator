# QBER Estimator: fresh build from scratch (ZedBoard, Vivado/Vitis 2023.2)

BB84 only. Keypad on **JA**, 4-pin I2C OLED (128x64, SSD1306) on **JB**, jumper **J18 = 1.8 V**.

## What is in this folder

| Folder | Contents |
|---|---|
| `rtl/` | the 27 Verilog files. `qber_pl.v` is the top module the block design uses. It always builds the real core, so no Verilog defines need to be set in Vivado. |
| `constraints/` | `zedboard.xdc` (LEDs, JD debug pins), `ui_pmods.xdc` (keypad on JA, OLED on JB, switches, buttons) |
| `vitis/main/` | measurement suite: all report data as CSV (16 files) |
| `vitis/demo/` | interactive demo: keypad, OLED, LEDs, buttons (26 files) |
| `vitis/fulltest/` | board self-test: hardware vs model, prints PASS/FAIL (17 files) |
| `vitis/oledtest/` | OLED check: I2C scan and three display set-ups (3 files) |
| `host/` | `live_plot.html` (live graphs in Edge/Chrome, no install), `plot.py` (report figures) |

Copy the whole folder to a short path with no spaces, for example **`C:\qber_fresh\`**.
Everything below assumes that path.

---

## 1. Board set-up (power off)

1. **J18 (VADJ)** on **1V8**.
2. Boot-mode jumpers set for **JTAG**, as before.
3. **Keypad (Pmod KYPD)** plugged straight into **JA**, top row of pins in JA1-JA6.
4. **OLED (4 pins)** on **JB** with jumper wires:

   | OLED pin | JB pin |
   |---|---|
   | GND | 5 |
   | VCC | 6 (3.3 V, never 5 V) |
   | SCL | 1 |
   | SDA | 2 |

   JB pin 1 is the corner marked "1"; pins 1-6 are the top row, with 5 = GND and 6 = 3.3 V.
   Check the order printed on your module: some read GND-VCC-SCL-SDA, others VCC-GND-SCL-SDA.
5. USB cable on **PROG (J17)** and on **UART (J14)**. Power on.

---

## 2. Vivado project

1. Open **Vivado 2023.2** → **Create Project** → Next.
2. Name `qber`, location `C:\qber_fresh\vivado` → Next.
3. **RTL Project**, tick "Do not specify sources at this time" → Next.
4. **Default Part** → **Boards** tab → search `zedboard` → pick **ZedBoard Zynq Evaluation and Development Kit** (Avnet).
   If it is not listed, click the download/refresh icon in the Boards tab and install it.
   Next → Finish.
5. **Add the Verilog**: Flow Navigator → **Add Sources** → **Add or create design sources** → **Add Files**
   → select all 27 files in `C:\qber_fresh\rtl\`.
   Tick **Copy sources into project**. Finish.
6. **Add the constraints**: **Add Sources** → **Add or create constraints** → **Add Files**
   → `zedboard.xdc` and `ui_pmods.xdc` from `C:\qber_fresh\constraints\`.
   Tick **Copy constraints files into project**. Finish.
7. In Sources, right-click → **Hierarchy Update** → **Automatic Update and Compile Order**.

---

## 3. Block design

Flow Navigator → **Create Block Design** → name **`system`** → OK.

### 3.1 Zynq processor
1. **+** (Add IP) → `ZYNQ7 Processing System`.
2. Click **Run Block Automation** (green banner) → leave "Apply Board Preset" ticked → OK.
   This sets up DDR, UART and the clocks, and makes `DDR` and `FIXED_IO` external.
3. Double-click the Zynq block:
   - **PS-PL Configuration** → AXI Non Secure Enablement → GP Master AXI Interface → **M AXI GP0 interface** ticked.
   - **Clock Configuration** → PL Fabric Clocks → **FCLK_CLK0 = 100** MHz.
   - **MIO Configuration** → I/O Peripherals → tick **I2C 0**, set its IO to **EMIO**.
   - OK.

### 3.2 The QBER core
Right-click empty canvas → **Add Module** → **`qber_pl`** → OK. It appears as `qber_pl_0`.

### 3.3 AXI-Stream FIFO (photons to the ARM)
1. **+** → `AXI4-Stream FIFO`. It appears as `axi_fifo_mm_s_0`.
2. Configure it: paste this in the **Tcl Console** and press Enter (or set the same in its GUI):
   ```tcl
   set_property -dict [list CONFIG.C_DATA_INTERFACE_TYPE {0} CONFIG.C_USE_TX_DATA {0} CONFIG.C_USE_TX_CTRL {0} CONFIG.C_RX_FIFO_DEPTH {4096} CONFIG.C_RX_FIFO_PF_THRESHOLD {4091} CONFIG.C_RX_FIFO_PE_THRESHOLD {5}] [get_bd_cells axi_fifo_mm_s_0]
   ```
   This sets an AXI4-Lite interface, receive side only, and a 4096-word receive FIFO.

### 3.4 Keypad GPIO
1. **+** → `AXI GPIO`. Rename it to exactly **`axi_gpio_kypd`** (Block Properties → Name).
2. Configure it:
   ```tcl
   set_property -dict [list CONFIG.C_GPIO_WIDTH {8} CONFIG.C_ALL_INPUTS {0} CONFIG.C_ALL_OUTPUTS {0} CONFIG.C_TRI_DEFAULT {0xFFFFFFFF} CONFIG.C_DOUT_DEFAULT {0x00000000}] [get_bd_cells axi_gpio_kypd]
   ```
   (GUI: width 8, neither All Inputs nor All Outputs, Default Tri State 0xFFFFFFFF.
   If there is a Board tab, set the board interface to **Custom**.)

### 3.5 Switches and buttons GPIO
1. **+** → `AXI GPIO`. Rename it to exactly **`axi_gpio_btnsw`**.
2. Configure it:
   ```tcl
   set_property -dict [list CONFIG.C_GPIO_WIDTH {8} CONFIG.C_ALL_INPUTS {1} CONFIG.C_IS_DUAL {1} CONFIG.C_GPIO2_WIDTH {5} CONFIG.C_ALL_INPUTS_2 {1}] [get_bd_cells axi_gpio_btnsw]
   ```
   (GUI: GPIO all inputs, width 8; Enable Dual Channel; GPIO2 all inputs, width 5. Board interfaces **Custom**.)

### 3.6 Connect the buses
1. Click **Run Connection Automation**. Tick **only** these four, and leave the GPIO interfaces unticked:
   - `axi_fifo_mm_s_0/S_AXI`
   - `axi_gpio_btnsw/S_AXI`
   - `axi_gpio_kypd/S_AXI`
   - `qber_pl_0/s_axi`

   Each should show Master `/processing_system7_0/M_AXI_GP0` and clock `FCLK_CLK0`. OK.
   Vivado adds `ps7_0_axi_periph` (the AXI interconnect) and `rst_ps7_0_100M` (the reset block).
2. Draw a wire from **`qber_pl_0/m_axis`** to **`axi_fifo_mm_s_0/AXI_STR_RXD`**.
3. Check that `qber_pl_0/aclk` goes to **FCLK_CLK0** and `qber_pl_0/aresetn` goes to
   **rst_ps7_0_100M/peripheral_aresetn**. Connect them by hand if not.

### 3.7 External ports (names must match the constraints)
Right-click each pin → **Make External**, then click the new port and rename it
(External Port Properties → Name):

| Pin | Rename the port to |
|---|---|
| `qber_pl_0/led[7:0]` | `led` |
| `qber_pl_0/dbg[7:0]` | `jd` |
| `axi_gpio_kypd/GPIO` | `kypd` |
| `axi_gpio_btnsw/GPIO` | `sws` |
| `axi_gpio_btnsw/GPIO2` | `btns` |
| `processing_system7_0/IIC_0` | `oled_iic` |

### 3.8 Addresses
Open the **Address Editor** tab (Window → Address Editor if hidden). Set:

| Block | Base address | Range |
|---|---|---|
| `qber_pl_0` (s_axi) | **0x43C0_0000** | 4K |
| `axi_fifo_mm_s_0` (S_AXI) | **0x43C1_0000** | 64K |
| `axi_gpio_btnsw` | 0x4120_0000 | 64K |
| `axi_gpio_kypd` | 0x4121_0000 | 64K |

The first two **must** be exactly these: the C code uses them directly. If a row says
"Unassigned", right-click → Assign first, then type the address.

### 3.9 Check and save
Press **F6** (Validate Design). You should get no errors; warnings are fine. **Ctrl+S**.

---

## 4. Wrapper, bitstream, XSA

1. Sources → right-click **`system.bd`** → **Create HDL Wrapper** → **Let Vivado manage wrapper and auto-update** → OK.
   `system_wrapper` becomes the top (bold).
2. Optional check: open `system_wrapper.v`. The port list should have
   `led`, `jd`, `kypd_tri_io`, `sws_tri_i`, `btns_tri_i`, `oled_iic_scl_io`, `oled_iic_sda_io`.
3. **Generate Bitstream** → Yes to synthesis and implementation. This takes about 10-15 min.
4. When it finishes, open the implemented design and check:
   - **Timing**: WNS positive (last build: +0.259 ns), no failing endpoints.
   - **Utilization**: about 5,100 LUTs (9.6 %), 9.5 BRAM.
   - **No critical warnings** about unmatched ports (`No ports matched ...`). If you get one,
     an external port name in 3.7 is wrong.
5. **File → Export → Export Hardware** → **Include bitstream** → name `qber`, folder
   `C:\qber_fresh\` → Finish. You now have `C:\qber_fresh\qber.xsa`.

---

## 5. Vitis (2023.2 unified IDE)

1. Open **Vitis 2023.2** → **Set Workspace** → `C:\qber_fresh\ws`.
2. **Platform**: File → New Component → **Platform** → name `qber_plat` → Next
   → "Hardware Design" → browse to `C:\qber_fresh\qber.xsa` → Next
   → OS **standalone**, processor **ps7_cortexa9_0** → Next → Finish.
   Select `qber_plat` in the Flow panel → **Build**.
3. **Four applications**. For each name below:

   | Application | Files to copy |
   |---|---|
   | `fulltest` | everything in `vitis\fulltest\` |
   | `main` | everything in `vitis\main\` |
   | `demo` | everything in `vitis\demo\` |
   | `oledtest` | everything in `vitis\oledtest\` |

   For each one:
   - File → New Component → **Application** → name it → platform **qber_plat**
     (domain `standalone_ps7_cortexa9_0`) → Next → Finish. Make it an **empty** application.
   - Copy every file from the matching folder into the application's **`src`** folder.
     Do it in Windows Explorer (`C:\qber_fresh\ws\<name>\src\`) or by dragging into Vitis.
   - If the template created a `main.c` or `helloworld.c` in `src`, **delete it**.
     Only `demo` has a `main.c` of its own.
   - Open `src\UserConfig.cmake` (it opens as a settings page):
     - **Libraries**: add **`m`**
     - **Optimization**: **`-O2`**
   - Select the application → **Build**. It should finish with no errors.

---

## 6. Run on the board

Serial settings: **115200 baud, 8N1**. Find the COM port in Windows Device Manager → Ports.
Only **one** program can use the COM port at a time: PuTTY, **or** the live plot page,
**or** the Vitis serial monitor. Close the others first.

Run an application: select it in Vitis → **Run** (the first time, Vitis programs the
bitstream too). To switch applications, just Run the next one.

### 6.1 `fulltest` (run first)
Expect the five golden cases, a short rate sweep, and at the end **`# fulltest: PASS`**.
A FAIL means the bitstream or the addresses in 3.8 are wrong.

### 6.2 `oledtest`
- Expect **`# I2C scan at 100 kHz: 0x3C`** (or 0x3D), then three display set-ups, 8 s each (A, B, C).
  Note which letter shows text. `demo` uses **A**.
- If the scan says **nothing answered**, no software change can fix it. Check:
  - VCC-GND at the module reads 3.3 V;
  - SCL and SDA each read about 3.3 V when idle;
  - the wiring order on JB;
  - whether the module works on another board.

### 6.3 `demo`
The OLED shows the settings screen and the LEDs show the SPRT score.

| Key | Action |
|---|---|
| **A** | set noise %: type digits, then **A** again to confirm |
| **B** | set Eve % (fraction of photons intercepted): type digits, then **B** again |
| **D** | change mode: RUN → SLOW → STEP |
| **E** | clear the number being typed |
| **F** | run |
| hold **F** 1 s | FPGA vs ARM rate sweep |

| Button / switch | Action |
|---|---|
| **BTNC** | run (same as F) |
| **BTNR** | one step (STEP mode) |
| **BTNU** | reliability test (wrong-decision rates) |
| **BTND** | reset |
| **SW0** | RUN (down) / SLOW (up) |

In RUN mode the results screen shows the QBER, the SPRT and fixed-test bits and decisions,
the wrong-decision rates, and the bits saved. The demo also prints CSV on the UART,
so the live plot page works with it too.

### 6.4 `main` (report data, about 2 minutes)
1. Open **`host\live_plot.html`** in **Edge or Chrome** → **Connect to board** → pick the COM port.
2. Run `main` in Vitis. Graph 1, the reliability results and Graph 2 fill in live;
   it ends with `# sweep finished`.
3. Click **Save log** to keep the CSV.
4. On a PC with Python: `python plot.py saved_log.txt --out figures` makes the report figures.

---

## 7. If something goes wrong

| Problem | Fix |
|---|---|
| "Could not connect to host" in Vitis | Vitis → Target Connections → Local → 127.0.0.1:3121. Check the PROG USB cable, and power-cycle the board. |
| COM port busy | close PuTTY, the browser tab or the Vitis serial monitor |
| Build error "multiple definition of main" | an extra `main.c`/`helloworld.c` from the template is still in `src`: delete it |
| Build error about `XPAR_AXI_GPIO_KYPD_BASEADDR` | the GPIO was not renamed exactly `axi_gpio_kypd` (or `axi_gpio_btnsw`): rename in the block design and rebuild everything |
| Keypad keys wrong or dead | keypad must be in JA (not JB), top row in JA1-JA6 |
| Switches/buttons dead | J18 must be on 1V8 (matches LVCMOS18 in `ui_pmods.xdc`) |
| Changed something in Vivado | re-export the XSA, then in Vitis right-click `qber_plat` → Update Hardware Specification → build the platform → clean and build the apps |
