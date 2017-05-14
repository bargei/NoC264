#!/bin/sh
echo "Flashing the FPGA image"
echo "Flashing FPGA 1/7" >> /media/fat_partition/log
echo 0 > /sys/class/fpga-bridge/fpga2hps/enable
echo "              2/7" >> /media/fat_partition/log
echo 0 > /sys/class/fpga-bridge/hps2fpga/enable
echo "              3/7" >> /media/fat_partition/log
echo 0 > /sys/class/fpga-bridge/lwhps2fpga/enable
echo "              4/7" >> /media/fat_partition/log
dd if=/media/fat_partition/work/scaled_down/hw_image/output_file.rbf of=/dev/fpga0 bs=1M
echo "              5/7" >> /media/fat_partition/log
echo 1 > /sys/class/fpga-bridge/fpga2hps/enable
echo "              6/7" >> /media/fat_partition/log


echo 1 > /sys/class/fpga-bridge/hps2fpga/enable
echo "              7/7" >> /media/fat_partition/log
echo 1 > /sys/class/fpga-bridge/lwhps2fpga/enable
echo "Flashing FPGA DONE!" >> /media/fat_partition/log

sleep 1

echo "Launching Buffer Node"
taskset 0x02 /media/fat_partition/work/scaled_down/buffer/buffer_prog &
sleep 1
proc_id=`pgrep buffer_prog`
chrt -r  -p 1  $proc_id
echo "buffer node pid: "
echo $proc_id

sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."
echo "launching Parser Node"
taskset 0x01 /media/fat_partition/work/scaled_down/parser/parser_prog &
proc_id=`pgrep parser_prog`
chrt -r -p 1  $proc_id
echo "parser node pid "
echo $proc_id

