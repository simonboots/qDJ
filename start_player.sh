#!/bin/bash

while (true); do
    FILE=`./qDJ.rb -d`
    echo "Now playing: $FILE"
    afplay "$FILE"
done
