#!/bin/bash

# Define the temporary directory
TEMP_DIR="$HOME/Desktop/RandomPhotos"
mkdir -p "$TEMP_DIR"

# AppleScript to export photos to the temporary directory
osascript <<EOD
tell application "Photos"
    set imageList to get every media item
    set imageCount to count of imageList
    set randomImages to {}
    repeat 3 times
        set randomIndex to random number from 1 to imageCount
        set end of randomImages to item randomIndex of imageList
    end repeat
    repeat with i from 1 to 3
        set imagePath to (POSIX path of "$TEMP_DIR/") & "random_photo_" & i & ".jpg"
        set imageItem to item i of randomImages
        set imageFile to (imagePath as POSIX file)
        export imageItem version "original" to imageFile
    end repeat
end tell
EOD

# List the selected images
echo "Selected images:"
ls "$TEMP_DIR"