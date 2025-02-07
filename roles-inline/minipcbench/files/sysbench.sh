#!/bin/bash
if [ "$(uname -s)" == "Darwin" ]; then
	cpu_model="$(sysctl -n machdep.cpu.brand_string)"
	nproc=$(sysctl -n hw.physicalcpu)
else
	cpu_model="$(grep ^model\ name /proc/cpuinfo  | head -n1 | cut -d \: -f 2 | cut -b 2-)"
	nproc=$(nproc)
fi

echo "CPU Model: ${cpu_model} :: ${nproc} CPU Cores"
echo
echo "CPU Test (Single-thread)"
sysbench cpu run | grep "events per second"
echo
echo "CPU Test (Multi-thread)"
sysbench --threads=${nproc} cpu run | grep "events per second"
echo
echo "Memory Test (Single-thread)"
sysbench memory run | grep -Ei '(total operations|transferred)'
echo
echo "Memory Test (Multi-thread)"
sysbench --threads=${nproc} memory run | grep -Ei '(total operations|transferred)'
