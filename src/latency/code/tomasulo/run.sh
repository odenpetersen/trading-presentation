#!/bin/bash
d=/tmp/tomasulo_demo
ssh mainframe "mkdir -p $d"
scp -q *.v wave.tcl mainframe:$d/
ssh mainframe "cd $d && source /opt/Xilinx/2026.1/Vivado/settings64.sh && xvlog -sv rom.v tomasulo.v inorder.v tb.v && xelab -debug typical tb -s sim && xsim sim -tclbatch wave.tcl -nolog"
scp -q mainframe:$d/tomasulo.wcfg . 2>/dev/null
