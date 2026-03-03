#!/bin/bash

set -e

APP_NAME="Caffeine"

echo "Building $APP_NAME..."
./build.sh

echo "Stopping running instance..."
pkill -x "$APP_NAME" || true

echo "Copying to /Applications..."
rm -rf "/Applications/$APP_NAME.app"
cp -r "build/$APP_NAME.app" "/Applications/"

echo "Launching $APP_NAME..."
open "/Applications/$APP_NAME.app"

echo "Done!"
