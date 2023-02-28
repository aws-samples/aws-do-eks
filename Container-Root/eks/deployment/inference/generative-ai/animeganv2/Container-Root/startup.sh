#!/bin/sh

# Container startup script
echo "Container-Root/startup.sh executed"

export GRADIO_SERVER_NAME=0.0.0.0
export GRADIO_SERVER_PORT=8080

python app.py

