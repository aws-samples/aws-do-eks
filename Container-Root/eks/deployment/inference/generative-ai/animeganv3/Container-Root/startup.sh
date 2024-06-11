#!/bin/sh

# Container startup script
echo "Container-Root/startup.sh executed"

echo ""
if [ -f ./AnimeGANv3_src.so ]; then
	echo "AnimeGANv3_src.so found ..."
else
	echo "Downloading AnimeGANv3_src.so ..."
	curl -L -o AnimeGANv3_src.so https://huggingface.co/spaces/TachibanaYoshino/AnimeGANv3/resolve/main/AnimeGANv3_src.so?download=true
fi


echo ""
if [ -f ./AnimeGANv3_bin.so ]; then
	echo "AnimeGANv3_bin.so found ..."
else
	echo "Downloading AnimeGANv3_bin.so ..."
	curl -L -o AnimeGANv3_bin.so https://huggingface.co/spaces/TachibanaYoshino/AnimeGANv3/resolve/main/AnimeGANv3_bin.so?download=true
fi

export GRADIO_SERVER_NAME=0.0.0.0
export GRADIO_SERVER_PORT=8080

python app.py

