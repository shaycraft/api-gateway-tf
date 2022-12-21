#!/bin/sh

PARENT_DIR=$(dirname "$0")
cd "$PARENT_DIR"/src/ping-test || exit

if [ "$1" = "dev" ]; then
  npm ci
else
  npm ci --prod
fi
