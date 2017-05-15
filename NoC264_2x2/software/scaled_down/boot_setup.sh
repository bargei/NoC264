#!/bin/sh

cp boot_script.sh /etc/init.d/noc_264_boot_script.sh
update-rc.d /etc/init.d/noc_264_boot_script.sh
mv programfpga programfpga_backup

