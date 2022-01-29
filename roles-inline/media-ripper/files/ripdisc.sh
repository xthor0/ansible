#!/bin/bash

### NOTE:
# in order for makemkv (or, makemkvcon, even) to be able to properly detect the title track on scrambled BDROMs,
# an old version of Java MUST be installed. https://www.oracle.com/java/technologies/javase-downloads.html - get Java SE 8

# tools I installed for this script to work:
# apt install makemkv-oss makemkv-bin mediainfo mkvtoolnix jq bc curl flatpak

# handbrake must be installed via flatpak or QSV doesn't work right
# https://handbrake.fr/docs/en/1.3.0/get-handbrake/download-and-install.html

# TODO: https://github.com/automatic-ripping-machine/automatic-ripping-machine/blob/v2_master/setup/51-automedia.rules
# create the udev files in /etc/udev/rules.d/
# end goal: This script kicks off automatically when I drop a disc in the drive. I feel like I'm SUPER close!

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

# ensure output directories exist
discinfo_output_dir="${HOME}/discinfo"
output_dir=/storage/videos/rips
encode_dir=/storage/videos/encoded
completed_dir=/storage/videos/completed
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
for directory in "${discinfo_output_dir}" "${output_dir}" "${encode_dir}" "${completed_dir}" "${unknown_completed_dir}" "${dvd_completed_dir}" "${o720p_completed_dir}" "${o1080p_completed_dir}" "${o4k_completed_dir}" "${unknown_encode_dir}" "${unknown_encode_dir}" "${dvd_encode_dir}" "${o1080p_encode_dir}" "${o4k_encode_dir}"; do
    if [ ! -d "${directory}" ]; then
        echo "${directory} does not exist -- creating."
        mkdir -p "${directory}"
        if [ $? -ne 0 ]; then
            echo "Error: unable to create ${directory} -- exiting."
            exit 255
        fi
    fi
done

# ensure output_dir is empty -- otherwise, a previous run needs a cleanup
if [ "$(ls -A ${output_dir})" ]; then
    echo "Error: ${output_dir} is not empty. A previous run did not complete successfully."
    _exit_err
fi

# TODO: DVD identification
# supposedly I can make a request against metaservices.windowsmedia.com, pass in the CRC, and get the title back.
# thing is, I'm not sure I care - almost everything I own is BDROM.

# dump the disc info using makemkv to a temp file
echo "Scanning disc with makemkv, please wait..."
discinfo=$(mktemp -p "${discinfo_output_dir}" discinfo.tempfile.XXXXX)
makemkvcon --progress=-stdout -r info dev:/dev/sr0 > $discinfo
hash="$(date +%s%N | md5sum | cut -b -6)"

# if this is a BDROM, we can scrape an xml file and get a human-readable title. Neat!
echo "Checking for BDROM XML..."
mount /dev/sr0
mountpoint -q /media/cdrom0
if [ $? -eq 0 ]; then
    # BDROM mounted successfully
    test -f /media/cdrom0/BDMV/META/DL/bdmt_eng.xml
    if [ $? -eq 0 ]; then
        # save the XML - it's failing on some discs and will help me debug
        xmltemp=$(mktemp -p "${discinfo_output_dir}" bdmtxml.temp.XXXX)
        cp /media/cdrom0/BDMV/META/DL/bdmt_eng.xml ${xmltemp}
        title=$(cat /media/cdrom0/BDMV/META/DL/bdmt_eng.xml | grep di:name | cut -d \> -f 2 | cut -d \< -f 1 | cut -d \- -f 1 | tr -d [:cntrl:])
        echo "Title retrieved from BDROM XML: ${title}"
        bdmtxml="${discinfo_output_dir}/${title}-${hash}.xml"
        mv ${xmltemp} "${bdmtxml}"
    else
        echo "bdmt_eng.xml does not exist."
    fi
    umount /dev/sr0
else
    echo "Unable to mount disc, skipping title identification from XML."
fi

# if title is empty, let's get it from makemkv
if [ -z "$title" ]; then
    # use what we can get from makemkv
    echo "Disc title is not set, retrieving from makemkv output..."
    title=$(cat ${discinfo} | grep '^DRV:0' | cut -d \, -f 6 | tr -d \")
    echo "Title from makemkv: ${title}"
fi

# if title is STILL not set, exit
if [ -z "$title" ]; then
	echo "Title could not be determined from disc - exiting."
	_exit_err
fi

# save the disc info we got from makemkv, but named so we can reference it (for debugging, later, if necessary)
discinfo_backup="${discinfo_output_dir}/${title}-${hash}.txt"
mv ${discinfo} "${discinfo_backup}"
discinfo="${discinfo_backup}"

# let's see if Java was able to determine what the title track of this disc is.
grep -q FPL_MainFeature "${discinfo}"
if [ $? -eq 0 ]; then
    # if this check passes, it means that Java was able to properly determine the correct feature track
    titletrack=$(grep '^TINFO:.*27.*FPL_MainFeature' "${discinfo}" | cut -d : -f 2 | cut -d , -f 1)
    echo "Java located the title track: ${titletrack}"
else
    # some discs (I'm looking at you, John Wick) have a gazillion tracks in the output. (337, on the Amazon version of John Wick)
    # On discs like this, the only way forward is either the Windows PowerDVD hack here - https://www.makemkv.com/forum/viewtopic.php?t=16251
    # or, checking the forums for the correct playlist.
    # so, this is a quick n' dirty hack to make sure we're not ripping a disc that might fill up my hard drive.
    echo "Java was unable to locate the title track of this disc. Determining which title to rip by length only."
    trackcount=$(grep -c ^TINFO:.*,27,0, "${discinfo}")
    echo "Found ${trackcount} tracks on this disc"
    if [ ${trackcount} -gt 100 ]; then
        echo "Sorry, this disc has more than 100 tracks, playlist obfuscation may be going on."
        echo "You should rip this disc manually and make sure it is what it purports to be."
        _exit_err
    else
        # this should find the longest track
        # TODO: should I do this by CHAPTERS, instead? What if the longest track has no chapters??
        titletrack=$(grep '^TINFO:.*,9,0,' "${discinfo}" | cut -b 7- | tr , ' ' | tr -d \" | awk '{ print $4 " " $1 }' | sort -rn | head -n1 | awk '{ print $2 }')
        echo "Found longest track: ${titletrack}"
    fi
fi

# make sure before we proceed that titletrack is a DIGIT
re='^[0-9]+$'
if ! [[ ${titletrack} =~ ${re} ]] ; then
   echo "Whoops - something went wrong. ${titletrack} is either empty or not a number."
   _exit_err
fi

# get the output filename
outputfile=$(grep ^TINFO:${titletrack},27,0, "${discinfo}" | cut -d \" -f 2)

# start extraction with makemkv
echo "Ripping title track ${titletrack} to ${outputfile} with makemkvcon..."
log=$(mktemp -t makemkvcon.log.XXXX)
( makemkvcon --progress=-stdout -r --decrypt --directio=true mkv dev:/dev/sr0 ${titletrack} "${output_dir}" >& ${log} ) &
bgpid=$!

# this is a much nicer progress bar than anything makemkvcon gives us, unfortunately...
while [ -d /proc/${bgpid} ]; do
    job="$(grep ^PRGC ${log} | tail -n1 | cut -d , -f 3 | tr -d '"')"
    jobprog="$(grep ^PRGV ${log} | tail -n1 | cut -d \: -f 2 | cut -d \, -f 1)"
    totalprog="$(grep ^PRGV ${log} | tail -n1 | cut -d \: -f 2 | cut -d \, -f 3)"

    # we need to make sure jobprog/totalprog are digits - otherwise, bc bitches
    if [[ ${jobprog} =~ ${re} ]] ; then
        progperc=$(echo "scale=4;(${jobprog} / ${totalprog}) * 100" | bc | head -c-3)
        tput sc
        #tput el
        #echo "Debugging: jobprog = ${jobprog} :: totalprog = ${totalprog} :: progperc = ${progperc}"
        tput el
        echo -n "${job} :: ${progperc} %"
        sleep 5
        tput rc
    else
        # let's hope 10 seconds does the trick...
        sleep 10
    fi
done

# write a newline, or we'll clobber the last status message
echo

# pretty sure that this is redundant, but what the hell
wait ${bgpid}

# fun - either makemkvcon doesn't exit with a non-zero status, or $? does NOT in fact have the last exit code. Can't tell.
# either way, a failing BDROM drive would routinely cause makemkvcon to fail. So I guess we can't rely on exit statuses...
if [ -f "${output_dir}/${outputfile}" ]; then
    echo "makemkvcon completed successfully."
    rm -f ${log}
else
    exitmsg="Failure: makemkvcon exited with a non-zero status. Take a look at ${log} for more information. Exiting now..."
    echo ${exitmsg}
    pushover_msg $exitmsg
    _exit_err
fi

# rename the file using Filebot (makes life easier for Plex)
echo "Renaming file with FileBot (test mode)..."
filebot_log=$(mktemp /tmp/filebot.XXXXX.log)
filebot -rename "${output_dir}/${outputfile}" --db themoviedb --q "${title}" --action test --log all --log-file ${filebot_log}
if [ $? -eq 1 ]; then
    # what will FileBot name this file?
    ripfile="$(grep TEST ${filebot_log} | cut -d \[ -f 4- | tr -d \])"
    filebot -rename "${output_dir}/${outputfile}" --db themoviedb --q "${title}"
    test -f "${ripfile}"
    if [ $? -eq 0 ]; then
        echo "Filebot renamed ${output_dir}/${outputfile} to ${ripfile}"
    fi
fi
rm -f ${filebot_log}

# make sure ripfile got set, otherwise...
if [ -z "${ripfile}" ]; then
    ripfile="${output_dir}/${outputfile}"
    echo "Filebot was unsuccessful. You can consult the log for debugging purposes. Proceeding to encode the file as-is."
fi

echo "Clearing mkv metadata (which can confuse Plex)..."
mkvpropedit "${ripfile}" -d title
if [ $? -ne 0 ]; then
    echo "mkvpropedit was unsuccessful - proceeding, as this error is not fatal."
fi

# use mediainfo to determine resolution, and change preset accordingly. 
# anything that is not 4k gets encoded qsv_264. qsv_265 used for 4k, simply because it saves disk space
width=$(mediainfo --Inform="Video;%Width%" "${ripfile}")
case ${width} in
    3840) preset_import_file="${HOME}/.handbrake-presets/4k_qsv.json"; preset="4k_qsv"; extension="mkv" ;;
    *) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4" ;;
esac

encodefile_basename=$(basename "${ripfile}" .mkv)
encodefile="${encode_dir}/${encodefile_basename}${testfilename}.${extension}"
if [ -f "${encodefile}" ]; then
    echo "Target already exists: ${encodefile} -- script will now exit."
    exit 255
fi

# encode the file with HandBrakeCLI
echo "Encoding with HandBrake (using ${preset})..."
log=$(mktemp -t handbrake.log.XXXX)
flatpak run --command=HandBrakeCLI fr.handbrake.ghb --preset-import-file "${preset_import_file}" --preset "${preset}" -i "${ripfile}" -o "${encodefile}" 2> ${log}
if [ $? -eq 0 ]; then
    echo "HandBrake encode successful."
    rm -f ${log}
else
    exitmsg="Error: HandBrake exited unsuccessfully. Check ${log} for more details."
    echo ${exitmsg}
    pushover_msg ${exitmsg}
    _exit_err
fi

# let's figure out what directory we want to put the output file in. Really, we should be dealing with 480, 1080, and 3840
# anything else we'll just stuff in other
case ${width} in
    720) suboutput="DVD";;
    1920) suboutput="1080p";;
    3840) suboutput="4k";;
    *) suboutput="unknown";;
esac

# move original source to completed dir. can be deleted later, but allows a re-encode without a re-rip, which is nice.
mv "${ripfile}" "${completed_dir}/${suboutput}/"
if [ $? -ne 0 ]; then
    echo "Error: can't move ${ripfile} to directory ${completed_dir}/${suboutput}."
fi

# move encoded file to completed directory
mv "${encodefile}" "${encode_dir}/${suboutput}/"
if [ $? -ne 0 ]; then
    echo "Error: can't move ${encodefile} to directory ${encode_dir}/${suboutput}."
fi

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
