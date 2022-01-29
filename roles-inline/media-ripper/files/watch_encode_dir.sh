#!/bin/bash

watch_dir=/scratch/watch

inotifywait -e close_write -m /scratch/watch --format '%f' | while read watch_dir file; do
    # encode_file.sh "${file}"
    echo "encode_file.sh \"${watch_dir}/${file}\""
done