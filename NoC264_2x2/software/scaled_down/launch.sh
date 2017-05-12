#!/bin/sh
echo "Launching Buffer Node"
taskset 0x02 ./buffer/myprog &
sleep 1
echo "."
sleep 1
echo "."
sleep 1
echo "."
echo "launching Parser Node"
taskset 0x01 ./parser/myprog &