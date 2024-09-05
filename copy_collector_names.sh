#!/bin/bash

# Define the output file
output_file="directories.txt"

# Empty the output file if it already exists
> "$output_file"

# Loop through all items in the current directory
for dir in */; do
    # Check if it's a directory (not a file)
    if [ -d "$dir" ]; then
        # Strip the trailing slash from the directory name
        dir_name=$(basename "$dir")
        # Write the formatted string to the output file
        echo "/opt/kaspersky/kuma/collector/$dir_name/log/" >> "$output_file"
    fi
done

echo "Formatted directory paths have been written to $output_file"
