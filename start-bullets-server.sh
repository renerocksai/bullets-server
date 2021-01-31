#!/bin/sh

echo "starting bullets server..."

cd /app
cp -v /keys/privkey.pem /app/privkey.key
cp -v /keys/fullchain.pem /app/fullchain.crt
./server --keyfile=/app/privkey.key --certfile=/app/fullchain.crt --port 9000

