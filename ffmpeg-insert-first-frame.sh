#!/usr/bin/env bash
set -euo pipefail

#
# This works by preparing both the image and video in MPEG-TS container,
# which can be concatenated trivially with ffmpeg.
# 
# This is nice because it's trivial to transform HEVC/H264 MP4 to MPEG-TS,
# without any loss of quality or reencoding. Handbrake can then finalize
# the resulting combined video stream.
#
# Credits:
# https://stackoverflow.com/a/56786943
#
#

# Check if inputs are given
if [ "$#" -ne 2 ]; then
  echo "ffmpeg-insert-first-frame.sh"
  echo "Inserts <image> as the first frame of <video> for thumbnailing purposes"
  echo
  echo "Usage:"
  echo "$0 <image> <video>"
  echo "Note that <video> MUST be either HEVC or H264"
  echo
  echo "Example":
  echo "$0 thumb.jpg video.mp4"
  echo
  exit 1
fi
IMAGE_FILE=$(realpath "$1")
VIDEO_FILE=$(realpath "$2")

# Obtain metadata from video
WIDTH=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of csv=p=0 "$VIDEO_FILE")
HEIGHT=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$VIDEO_FILE")
FRAMERATE=$(ffprobe -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$VIDEO_FILE" | bc -l)
CODEC=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$VIDEO_FILE")
echo "    Codec: ${CODEC}"
echo "Dimension: ${WIDTH}x${HEIGHT}"
echo "Framerate: ${FRAMERATE}"
echo

# Abort if not hevc or h264; we need it for MPEG-TS
# https://ffmpeg.org/ffmpeg-bitstream-filters.html
if [[ "$CODEC" != "hevc" && "$CODEC" != "h264" ]]; then
  echo "Video codec is neither HEVC nor H264"
  echo "Aborting"
  exit 1
fi
BITSTREAM_FILTER="${CODEC}_mp4toannexb"


# We're good to go from here onwards
#######################################

# Configure log file
LOGFILE="$(date "+%F at %T.log")"
LOGFILE="$(realpath "$LOGFILE")"

# Configure log levels
ffmpeg() {
  local FFMPEG="$(which ffmpeg)"
  "$FFMPEG" -hide_banner -y "$@"
}

# Use temp workdir
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
pushd "$TEMP_DIR" > /dev/null


# Convert image to video
printf "==> Generating single frame thumbnail video... "
ffmpeg \
  -loop 1 \
  -framerate "$FRAMERATE" \
  -i "$IMAGE_FILE" \
  -vf "scale=${WIDTH}:${HEIGHT}" \
  -c:v "$CODEC" \
  -frames:v 1 \
  "thumb.mp4" 2>"$LOGFILE"
echo "✅"
echo

# Convert into MPEG-TS container
echo "==> Converting videos to MPEG-TS container..."

printf "Thumb... "
ffmpeg \
  -i "thumb.mp4" \
  -c copy \
  -bsf:v "$BITSTREAM_FILTER" \
  -f mpegts \
  "thumb.ts" 2>"$LOGFILE"
echo "✅"

printf "Video... "
ffmpeg \
  -i "$VIDEO_FILE" \
  -c copy \
  -bsf:v "$BITSTREAM_FILTER" \
  -f mpegts \
  "video.ts" 2>"$LOGFILE"
echo "✅"
echo

# Concat the two video
printf "==> Concatenating... "
ffmpeg \
  -i "concat:thumb.ts|video.ts" \
  -c copy \
  -bsf:a aac_adtstoasc \
  "output.mp4" 2>"$LOGFILE"
echo "✅"
echo

popd > /dev/null

# Output
OUTPUT_FILE="$(basename "$VIDEO_FILE" .mp4)-combined.mp4"
echo "Done!"
echo "Output: $OUTPUT_FILE"
mv "$TEMP_DIR/output.mp4" "$OUTPUT_FILE"
