#!/bin/bash

watch_dir=/scratch/watch

inotifywait -e moved_to -m /scratch/watch --format '%f' | while read file; do
    encode_file.sh "${watch_dir}/${file}"
done