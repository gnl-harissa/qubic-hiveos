#!/bin/bash

cp -r cpu "/tmp/."
cp -r gpu "/tmp/."

echo $(date +%s) > "/tmp/miner_start_time"

echo $MINER_LOG_BASENAME.log

echo "Starting Mining instance..."
sh run2.sh
