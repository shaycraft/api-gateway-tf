#!/bin/sh

PARENT_DIR=$(dirname "$0")
cd "$PARENT_DIR"/lambda_payload || exit

if [ "$1" = "dev" ]; then
  npm ci
else
  npm ci --prod
fi
