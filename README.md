# LUT Batch Processor

This script applies all `.cube` LUT files in a directory to an input image using **ffmpeg**, producing one output per LUT.

## Prerequisites

* **ffmpeg** installed and accessible in your `PATH`.
* Your LUT files stored in a directory, e.g. `luts/colorslide`.
* An input image (JPEG).

## Usage

1. Set the variables at the top of the script:

   ```bash
   INPUT="/path/to/your/input.jpg"
   LUT_DIR="/path/to/luts/colorslide"
   OUTPUT_DIR="/path/to/output/directory"
   ```

2. Run the loop:

   ```bash
   for lut in "$LUT_DIR"/*.cube; do
     name="$(basename "$lut" .cube)"
     ffmpeg -hide_banner -loglevel quiet -y \
       -i "$INPUT" \
       -vf "lut3d=$lut,format=yuv444p" \
       -frames:v 1 -q:v 2 \
       "$OUTPUT_DIR/${name}.jpg"
   done
   ```

## Description

* `-hide_banner`: Suppresses ffmpeg version info.
* `-loglevel quiet`: Disables all logging.
* `-frames:v 1`: Processes exactly one frame.
* `-q:v 2`: Sets JPEG quality to high (lower number = higher quality).
* `lut3d`: Applies the 3D LUT filter.
* `format=yuv444p`: Ensures modern pixel format.

After running, the `OUTPUT_DIR` will contain one JPEG per LUT file, named after the LUT (e.g., `kodak_kodachrome_200.jpg`).

## Customization

* Adjust `-q:v` to change output quality.
* Add additional filters in the `-vf` chain as needed.
