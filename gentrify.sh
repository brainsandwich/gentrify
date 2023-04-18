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
        # ------------------------------------ Probe file information

        filename=$(basename "$file")
        infoarr=($(probe_file "$file"))
        if ! [[ ${#infoarr[@]} -eq 3 ]]
        then
            continue
        fi
        fmt=${infoarr[0]}
        spr=${infoarr[1]}
        btr=${infoarr[2]}
        convbtr=${TARGETBR}

        # ------------------------------------ Check if we need to convert

        if [ "$fmt" == "${TARGETFMT}" ]
        then
            if [ "$spr" == "${TARGETSR}" ]
            then
                printf "${COLOR_DISCARD}Skipping > '$filename' [$fmt, $spr, $btr]${COLOR_STANDARD}\n"
                continue
            fi

            if [ $btr -le ${TARGETBR} ]
            then
                convbtr=$btr
            fi
        fi

        printf "${COLOR_PERFORM}Converting '$filename' [$fmt, $spr, $btr] -> [$TARGETFMT, $TARGETSR, $convbtr] ...${COLOR_STANDARD}\n"
        directory=$(dirname "$file")
        targetfile="$directory/${filename%.*}.${TARGETFMT}"
        tempfile="$directory/${filename%.*}.temp.${TARGETFMT}"

        # ------------------------------------ First cleanup last temp file

        if [[ -f "$tempfile" ]]
        then
            printf "> Cleaning temp file '$tempfile'\n"
            if [ $DRYRUN != true ]
            then
                rm "$tempfile"
            fi
        fi

        # ------------------------------------ Detect cover art

        coverart="$directory/cover.*"
        covercmds=""
        if [ -f "$coverart" ]; then
            printf "> Found cover art '$coverart'\n"
            covercmds=-i "${coverart}" -map 0:0 -map 1:0 -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)"
        fi

        # ------------------------------------ Convert file

        printf "> Converting '$file' to '$tempfile'\n"
        if [ $DRYRUN != true ]
        then
            ffmpeg -nostdin -n -loglevel error \
                -i "$file" \
                $covercmds \
                -map_metadata 0 -id3v2_version 3 -ar ${TARGETSR} -b:a ${convbtr} "$tempfile"
        fi

        # ------------------------------------ Rename temp converted file to 
        # ------------------------------------ target name, only if conversion
        # ------------------------------------ succeeded

        if [[ -f "$tempfile" ]]
        then
            printf "> Renaming '$tempfile' to '$targetfile'\n"
            if [ $DRYRUN != true ]
            then
                mv "$tempfile" "$targetfile"
            fi
        fi

        # ------------------------------------ Remove source file if conversion
        # ------------------------------------ succeeded and we don't keep both
        # ------------------------------------ files

        if [ $KEEPBOTH != true ] && [[ "$file" != "$targetfile" ]] && [ -f "$targetfile" ]
        then
            printf "> Removing '$file', '$targetfile' exists\n"
            if [ $DRYRUN != true ]
            then
                rm "$file"
            fi
        fi
    done
}

export -f process
find -E "${BASEDIR}" -regex '.*\.(flac|mp3|aac|ogg|wav|webm|au|aiff|m4a)' \
    | parallel --pipe $PARALLELARGS "process"

wait
