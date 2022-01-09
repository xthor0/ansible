#!/bin/bash

startDate=$(date)
fullStart=$(date +%s)

# output dir for encoded files
encode_dir=/storage/videos/encoded

# if testmode is enabled, only encode a couple of chapters (2-4)
if [ -n "${1}" ]; then
	testmode="-c 2-4"
	testfilename="-test"
fi

log=$(mktemp -t makemkvcon.log.XXXX)
find . -maxdepth 1 -type f -iname "*.mkv" | while read inputfile; do
	start=$(date +%s)
	newfile=$(basename "$inputfile" .mkv)

	# remove the title
	mkvpropedit "${inputfile}" -d title
	
	# use mediainfo to determine resolution, and change preset accordingly. 
	# anything that is not 4k gets encoded qsv_264. qsv_265 used for 4k, simply because it saves disk space
	widthdigit=$(mediainfo "${inputfile}" | grep ^Width | awk '{ print $3 }')
	case ${widthdigit} in
		3) preset_import_file="${HOME}/.handbrake-presets/4k_qsv.json"; preset="4k_qsv"; extension="mkv" ;;
		*) preset_import_file="${HOME}/.handbrake-presets/1080p_qsv.json"; preset="1080p_qsv"; extension="mp4" ;;
	esac

    output_file="${encode_dir}/${newfile}${testfilename}.${extension}"
	if [ -f "${output_file}" ]; then
		echo "Target already exists: ${output_file} -- skipping."
		continue
	fi

	# encode the file with HandBrakeCLI
	echo "Source: ${inputfile}"
	echo "Target: ${output_file}"
	echo "Preset: ${preset}"
	log=$(mktemp -t handbrake.log.XXXX)
	echo | flatpak run --command=HandBrakeCLI fr.handbrake.ghb --preset-import-file "${preset_import_file}" --preset "${preset}" "${testmode}" -i "${inputfile}" -o "${output_file}" 2> ${log}
    if [ $? -eq 0 ]; then
        rm -f ${log}
    else
        echo "Error - check ${log} for details."
    fi
	end=$(date +%s)

	# TODO: fix this math. This isn't working right.
	diff=$((${end} - ${start}))
	echo "$((${diff} / 60)) minutes and $((${diff} % 60)) seconds elapsed."
done

endDate=$(date)
fullEnd=$(date +%s)
fulldiff=$((${end} - ${start}))

# pushover message
test -f ${HOME}/.pushover-api-keys
if [ $? -eq 0 ]; then
	# if I'm doing testing - I'm probably at the console. Don't pushover me.
	if [ -z "${testmode}" ]; then
		. ${HOME}/.pushover-api-keys
		curl -s --form-string "token=${apitoken}" --form-string "user=${usertoken}" --form-string "message=Notification: Batch HandBrake job completed. :: Start: ${startDate} -- End: ${endDate} :: $((${fulldiff} / 60)) minutes and $((${fulldiff} % 60)) seconds elapsed." https://api.pushover.net/1/messages.json		
	fi
fi

echo "All done!"

exit 0
