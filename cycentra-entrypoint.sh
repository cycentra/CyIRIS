#!/bin/bash
set -e

echo "======================================"
echo " CyCentra CyIRIS Starting"
echo "======================================"

/iriswebapp/iris-entrypoint.sh "$@" &
IRIS_PID=$!

wait $IRIS_PID
