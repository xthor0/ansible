#!/bin/bash

run_file=/tmp/.encode_is_running
watch_dir=/scratch/watch
encode_dir=/scratch/encoded
completed_dir=/scratch/completed
unknown_completed_dir="${completed_dir}/unknown"
dvd_completed_dir="${completed_dir}/DVD"
o720p_completed_dir="${completed_dir}/720p"
o1080p_completed_dir="${completed_dir}/1080p"
o4k_completed_dir="${completed_dir}/4k"
unknown_encode_dir="${encode_dir}/unknown"
dvd_encode_dir="${encode_dir}/DVD"
o720p_encode_dir="${encode_dir}/720p"
o1080p_encode_dir="${encode_dir}/1080p"
o4k_encode_dir="${encode_dir}/4k"
input_file="${1}"

# timer
timer_start=${SECONDS}

function pushover_msg() {
    test -f ${HOME}/.pushover-api-keys
    if [ $? -eq 0 ]; then
        . ${HOME}/.pushover-api-keys
        curl -s \
            --form-string "token=${apitoken}" --form-string "user=${usertoken}" --form-string "message=Notification: $*" https://api.pushover.net/1/messages.json
    else
        echo "No pushover keys found in ~/.pushover-api-keys - can't send a message."
    fi
}

function _exit_err(){
    # TODO: we need a cleanup function which moves whatever is in ${output_dir} somewhere, so we can run again
    pushover_msg "Encode failed, see logs."
    exit 255
}

# make sure we're only encoding one file at a time
while test -f ${run_file}; do
    echo "Waiting on encode to finish, please wait..."
    sleep 5
    echo "Sleeping again in case there are multiple processess sleeping..."
    sleep $((RANDOM % 60))
done
touch ${run_file}

# ensure output directories exist
# TODO: move this shit to the Ansible playbook - it can create the dirs and ensure bash vars exist
for directory in "${watch_dir}" "${encode_dir}" "${completed_dir}" "${unknown_completed_dir}" "${dvd_completed_dir}" "${o720p_completed_dir}" "${o1080p_completed_dir}" "${o4k_completed_dir}" "${unknown_encode_dir}" "${unknown_encode_dir}" "${dvd_encode_dir}" "${o1080p_encode_dir}" "${o4k_encode_dir}"; do
    if [ ! -d "${directory}" ]; then
        echo "${directory} does not exist -- creating."
        mkdir -p "${directory}"
        if [ $? -ne 0 ]; then
            echo "Error: unable to create ${directory} -- exiting."
            exit 255
        fi
    fi
done

echo "Processing ${input_file}..."

echo "Clearing mkv metadata (which can confuse Plex)..."
mkvpropedit "${input_file}" -d title
if [ $? -ne 0 ]; then
    echo "mkvpropedit was unsuccessful - proceeding, as this error is not fatal."
fi

# use mediainfo to determine resolution, and change preset accordingly. 
# anything that is not 4k gets encoded qsv_264. qsv_265 used for 4k, simply because it saves disk space
width=$(mediainfo --Inform="Video;%Width%" "${input_file}")
case ${width} in
    3840) preset_import_file="${HOME}/.handbrake-presets/4k_qsv.json"; preset="4k_qsv"; extension="mkv" ;;
    720) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4"; suboutput="DVD" ;;
    1920) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4"; suboutput="1080p" ;;
    3840) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4"; suboutput="4k" ;;
    *) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4"; suboutput="unknown";;
esac

title=$(basename "${input_file}" .mkv)
output_file="${encode_dir}/${suboutput}/${title}.${extension}"
if [ -f "${output_file}" ]; then
    echo "Target already exists: ${output_file} -- script will now exit."
    exit 255
fi

# encode the file with HandBrakeCLI
echo "Encoding with HandBrake (using ${preset})..."
log=$(mktemp -t handbrake.log.XXXX)
flatpak run --command=HandBrakeCLI fr.handbrake.ghb --preset-import-file "${preset_import_file}" --preset "${preset}" -i "${input_file}" -o "${output_file}" 2> ${log}
if [ $? -eq 0 ]; then
    echo "HandBrake encode successful."
    rm -f ${log}
else
    exitmsg="Error: HandBrake exited unsuccessfully. Check ${log} for more details."
    echo ${exitmsg}
    pushover_msg ${exitmsg}
    _exit_err
fi

# move original source to completed dir. can be deleted later, but allows a re-encode without a re-rip, which is nice.
mv "${input_file}" "${completed_dir}/${suboutput}/"
if [ $? -ne 0 ]; then
    echo "Error: can't move ${input} to directory ${completed_dir}/${suboutput}."
fi

# clean up run file
rm -f ${run_file}

# the end
exitmsg="Movie ${title} has been successfully encoded."
echo ${exitmsg}
pushover_msg ${exitmsg}

# timer
timer_end=${SECONDS}
timer_seconds=$(expr ${timer_end} - ${timer_start})
ELAPSED="Elapsed: $((${timer_seconds} / 3600))hrs $(((${timer_seconds} / 60) % 60))min $((${timer_seconds} % 60))sec"
echo ${ELAPSED}

# exit
exit 0
