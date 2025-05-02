#!/bin/bash
if [ "$(uname -s)" == "Darwin" ]; then
	cpu_model="$(sysctl -n machdep.cpu.brand_string)"
	nproc=$(sysctl -n hw.physicalcpu)
else
  # intel models can get the CPU this way
  nproc=$(nproc)
  case "$(uname -m)" in
    "x86_64")
      cpu_model="$(grep ^model\ name /proc/cpuinfo  | head -n1 | cut -d \: -f 2 | cut -b 2-)"
      ;;
    "aarch64")
      cpu_model="$(grep ^Model /proc/cpuinfo | cut -b 10-)"
      ;;
  esac
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
