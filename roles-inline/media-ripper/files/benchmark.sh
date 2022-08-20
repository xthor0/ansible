#!/bin/bash

# TODO: Check if Darwin, because on Linux, especially for flatpak, command will be different
os=$(uname -s)
if [ "${os}" == "Darwin" ]; then
  hbcli="HandBrakeCLI"
  cpu="$(sysctl -n machdep.cpu.brand_string)"
  today="$(gdate --iso)"
  encoder="h265 (VideoToolbox)"
fi

test -d log || mkdir log
test -d output || mkdir output

report_base_name="handbrake_bench_${today}"
if [[ -f "${report_base_name}.txt" ]] ; then
  i=0
  while [[ -f "${report_base_name}-${i}.txt" ]] ; do
    let i++
  done
  report_name="${report_base_name}-${i}.txt"
else
  report_name="${report_base_name}.txt"
fi

# write a header to the report
echo "CPU || Encoder || Source || Avg FPS" > "${report_name}"

# begin the fun and games!
for file in source/*; do
  shortname="$(basename "${file}" .mkv)"
  echo "Benchmarking: ${shortname}"
  for chapter in 3 5 11 16 22; do
    echo "Processing: chapter ${chapter}..."
    base_filename="${shortname}_c${chapter}"
    output="output/${base_filename}.mp4"
    log="log/${base_filename}.log"
    ${hbcli} --preset-import-file 4k_hvec_vt.json --preset 4k_hvec_vt -i "${file}" -o "${output}" -c ${chapter} 2> "${log}"
    if [ $? -eq 0 ]; then
      fps="$(grep 'average encoding speed' "${log}" | tail -n1 | awk '{ print $9 }')"
    else
      fps="N/A"
    fi
    result="${cpu} || ${encoder} || ${shortname} || ${fps}"
    echo "${result}"
    echo "${result}" >> "${report_name}"
  done
done
