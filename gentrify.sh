#!/bin/bash

# ------------------------------ MACROS

export COLOR_STANDARD='\033[0m'
export COLOR_DISCARD='\033[1;37m'
export COLOR_PERFORM='\033[0;35m'

# ------------------------------ INPUT ARGUMENTS

export BASEDIR=.
export TARGETFMT=mp3
export TARGETSR=44100
export TARGETBR=320k
export KEEPBOTH=false
export DRYRUN=false
export PARALLELARGS="-N1 -j16"

while [ $# -gt 0 ]; do
    case "$1" in
        --format=*)
            TARGETFMT="${1#*=}"
            ;;
        --samplerate=*)
            TARGETSR="${1#*=}"
            ;;
        --bitrate=*)
            TARGETBR="${1#*=}"
            ;;
        --keepboth)
            KEEPBOTH=true
            ;;
        --dryrun)
            DRYRUN=true
            ;;
        *)
            if [ -d "$1" ]; then
                BASEDIR="$1"
            fi
    esac
    shift
done

if ! [ -d "$BASEDIR" ]; then
    echo "Missing base directory argument"
    exit 1
fi

TARGETBR="${TARGETBR/k/000}"
TARGETBR="${TARGETBR/K/000}"
TARGETBR="${TARGETBR/M/000000}"

echo "Working recursively from '$BASEDIR'"
echo "- target format : $TARGETFMT"
echo "- target sample rate : $TARGETSR"
echo "- target bitrate : $TARGETBR"
echo "- parallel args : $PARALLELARGS"
if [[ $KEEPBOTH = true ]]
then
    echo "- keeping old file"
fi
if [[ $DRYRUN = true ]]
then
    echo "- dry run"
fi

# ------------------------------ PROCESSING

function probe_file() {
    ffprobe -v 0 -select_streams a -show_entries stream=codec_name,sample_rate,bit_rate -of default=nokey=1:noprint_wrappers=1 "$1"
}
export -f probe_file

function process() {
    while read -r file
    do
        filename=$(basename "$file")
        infoarr=($(probe_file "$file"))
        if ! [[ ${#infoarr[@]} -eq 3 ]]
        then
            continue
        fi
        fmt=${infoarr[0]}
        spr=${infoarr[1]}
        btr=${infoarr[2]}

        if [ "$fmt" == "${TARGETFMT}" ] && [ "$spr" == "${TARGETSR}" ]
        then
            printf "${COLOR_DISCARD}Skipping > '$filename' [$fmt, $spr, $btr]${COLOR_STANDARD}\n"
            continue
        fi

        printf "${COLOR_PERFORM}Converting > '$filename' [$fmt, $spr, $btr] ...${COLOR_STANDARD}\n"

        if [[ $DRYRUN = true ]]
        then
            continue
        fi

        directory=$(dirname "$file")
        targetfile="$directory/${filename%.*}.${TARGETFMT}"
        tempfile="$directory/${filename%.*}.temp.${TARGETFMT}"
        if [[ -f "$tempfile" ]]
        then
            rm "$tempfile"
        fi

        coverart="$directory/cover.*"
        covercmds=""
        if [ -f "$coverart" ]; then
            covercmds=-i "${coverart}" -map 0:0 -map 1:0 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)"
        fi

        if [[ $KEEPBOTH = true ]]
        then
            ffmpeg -nostdin -n -loglevel error \
                -i "$file" \
                $covercmds \
                -map_metadata 0 -id3v2_version 3 -ar ${TARGETSR} -b:a ${TARGETBR} "$tempfile" \
                    && mv "$tempfile" "$targetfile"
        else
            ffmpeg -nostdin -n -loglevel error \
                -i "$file" \
                $covercmds \
                -map_metadata 0 -id3v2_version 3 -ar ${TARGETSR} -b:a ${TARGETBR} "$tempfile" \
                    && mv "$tempfile" "$targetfile" \
                    && rm "$file"
        fi
    done
}

export -f process
find -E "${BASEDIR}" -regex '.*\.(flac|mp3|aac|ogg|wav|webm|au|aiff|m4a)' \
    | parallel --pipe $PARALLELARGS "process"

wait