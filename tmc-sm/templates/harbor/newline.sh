#!/bin/bash
output=""
while read line; do
    # Replace newline with a single space
    line=${line//$'\n'/ }

    # Append the modified line to the output string
    output="$output $line"
done < "$1"
echo "$output"