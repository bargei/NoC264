# Intructions for setting up 2x2 Implementation
## 1) Create bootable SD card with linux 
1.1) Program an SD card using image availible at https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/DE1-SoC-UP-Linux/linux_sdcard_image.zip Instructions for programming the SD card are in the pdf: https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/DE1-SoC-UP-Linux/Linux.pdf
 
## 2) Build FPGA image
2.1) Download or clone NoC264_2x2 to desktop

2.2) Open project file using Quartus 15.1 Lite

2.3) Open hps_fpga.qsys using Qsys and click generate HDL

2.4) Run Synthesis on project

2.5) Run tools>>Tcl Scripts>>hps_sdram_p0_pin_assignments.tcl

2.6) Run Fitter and Assembler

2.7) Create an .rbf file from the .sof file. Refer to section 3.1 of https://people.ece.cornell.edu/land/courses/ece5760/DE1_SOC/DE1-SoC-UP-Linux/Linux.pdf for more info.

## 3) Copy files to SD Card
3.1) copy software folder "scaled_down" to G:\work\

3.2) add new folder "hw_image" to "scaled_down"

3.3) copy the previously generated .rbf file to hw_image


## 4) Build software
4.1) insert sd card, power on the device and connect the usb-uart cable

4.2) using the serial terminal navigate to /media/fat_partition/work/scaled_down/parser/

4.3) type make

4.4) navigate to /media/fat_partition/work/scaled_down/buffer/

4.5) type make

## 5) Initial test
5.1) navigate to /media/fat_partition/work/scaled_down/

5.2) connect monitor using vga and run launch.sh
     a video should start playing
     
## 6) Setup to run on boot
6.1) Run "boot_setup.sh"

6.2) Power cycle to test

