#!/bin/bash

watch_dir=/scratch/watch

inotifywait -e close_write -m /scratch/watch --format '%f' | while read file; do
    encode_file.sh "${file}"
done