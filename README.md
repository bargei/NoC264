# NoC264
NoC based h.264 decoder for FPGA

For licensing info related to the CONNECT verilog and HEX files see LICENSE_CONNECT.
Otherwise see LICENSE for licensing info for other source files.

## First Time Setup How-to (3x3 implementation)
    1) Setup VGA connections
    2) Build hardware and program FPGA
    3) Build Buffer Node SW and run on NIOS II core 1
    4) Build Parser Node SW and debug on NIOS II core 0

### Step 1: Setup VGA connections
    1.1) make the following connections on GPIO header 1 / VGA board (see https://github.com/fenlogic/vga666)

    SIGNAL       | FPGA PIN NAME | PIN LOCATION ON GPIO HEADER | PIN LOCATION ON VGA BOARD
    -------------+---------------+-----------------------------+---------------------------
    vga_v_sync   | gpio(2 )      | 3                           | 3
    vga_h_sync   | gpio(4 )      | 5                           | 5
    vga_blue(0)  | gpio(6 )      | 7                           | 7
    vga_green(4) | gpio(7 )      | 8                           | 14
    vga_green(5) | gpio(9 )      | 10                          | 15
    vga_red(1)   | gpio(10)      | 13                          | 11
    vga_red(2)   | gpio(11)      | 14                          | 18
    vga_green(0) | gpio(16)      | 19                          | 19
    vga_blue(5)  | gpio(18)      | 21                          | 21
    vga_green(1) | gpio(20)      | 23                          | 23
    vga_blue(4)  | gpio(21)      | 24                          | 24
    vga_blue(3)  | gpio(23)      | 26                          | 26
    vga_blue(1)  | gpio(24)      | 27                          | 29
    vga_blue(2)  | gpio(26)      | 31                          | 31
    vga_green(2) | gpio(27)      | 32                          | 32
    vga_green(3) | gpio(28)      | 33                          | 33
    vga_red(3)   | gpio(30)      | 35                          | 35
    vga_red(0)   | gpio(31)      | 36                          | 36
    vga_red(4)   | gpio(33)      | 38                          | 38
    vga_red(5)   | gpio(35)      | 40                          | 40

### Step 2: Build hardware and program FPGA
    2.1) Download or clone NoC264_3x3 to desktop
    2.2) Open project file using Quartus 16.1 Standard
    2.3) Open nios_system.qsys using Qsys and click generate HDL
    2.4) Run Synthesis on project
    2.5) Run tools>>Tcl Scripts>>nios_system_DDR2_Controller_p0_pin_assignments.tcl
    2.6) Run Fitter and Assembler
    2.7) Use programming tool to download HW to FPGA

### Step 3: Build Buffer Node SW and run on NIOS II core 1
    3.1)  From Quartus open "Nios II Software Build Tools for Eclipse" under Tools
    3.2)  Select ...\NoC264\NoC264_3x3\ as the workspace
    3.3)  Right click in project explorer and select new>>Nios II Application and Bsp from Template
    3.4)  Make the following selections
    
    SOPC Information File Name: nios_system.sopcinfo
    CPU name:                   nios2_gen2_1
    Project name:               Buffer_Node
    Template:                   Blank Project
    
    leave other settings as default, and click finish
    
    3.5)  Right click under Buffer_Node_bsp in the eclipse project explorer pane. Select Nios II>>BSP Editor...
    3.6)  Under drivers tab select enable_small_driver
          Under the main tab change bsp_cflags_optimization to -O3
          Save, click generate and exit
    3.7)  Select all source files under Buffer_Node, right click and select "Add to Nios II Build"
    3.8)  In the Buffer_Node project change APP_CFLAGS_OPTIMIZATION := -O0 to APP_CFLAGS_OPTIMIZATION := -O3
    3.9)  Build Buffer_Node
    3.10) To run: right click in project and select Run As>>Nios II Hardware
    
### Step 4: Build Parser Node SW and debug on NIOS II core 0
    4.1) Same as step 3 with following modifications
         Start from 3.3
         CPU name     = nios2_gen2_0
         Project name = Parser_Node
         To run: use "Debug As" instead of "Run As"
         While editing BSP: under drivers uncheck timer_0
         