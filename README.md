# Gentrify

Bulk convert audio files

I've made this script because some hardware DJ players are picky about file types, audio formats and such.
Since DJ management software are either :
* not providing facility to format files
* bloatware

I've decided to roll my own tool

## Usage

````sh
gentrify.sh <directory> [--dryrun][--keepboth][--format=FMT][--samplerate=SR][--bitrate=BR]

  <directory> :
      Path to the directory in which you want to convert files
      Required argument

  --dryrun :  
      Run the script without performing the conversion (check to see which files will be converted, and why)
      Off by default

  --keepboth :
      Keep source file after conversion
      Off by default
      
  --format=FMT :
      Set target format to FMT
      Default to mp3
      
  --samplerate=SR :
      Set target sample rate to SR
      Default to 44100 (Hz)
      
  --bitrate=BR :
      Set target bit rate to BR, not accounted for in detection
      Default to 320k (320000 b/sec)
````
      
## Details

The script uses ffmpeg to probe and convert files, so make sure it's installed beforehand (use something like `apt install ffmpeg`)
To improve performance the probing and conversion are done in parallel. You can control parallelism in the script by adjusting the `PARALLELARGS`variable (might do that in script argument next)

The script works by `find`ing all "audio" files recursively in provided directory. "audio" files mean any file matching on of these extensions : `flac|mp3|aac|ogg|wav|webm|au|aiff|m4a`.

The bitrate is not accounted for during the detection of "convertible files". I didn't do that because it would mean checking multiple cases like if the bitrate is lower or higher, which bitrates are supported by CDJs, etc.

## Copyright

Public domain bitch
