#!/bin/bash
cd "$(dirname "$0")/backend"
pkill -f "node server.js" 2>/dev/null
nohup node server.js > server.log 2>&1 &
echo "Server backend started with PID $!"
