#!/bin/sh

if [ -d /etc/apt ]; then
        [ -n "$http_proxy" ] && echo "Acquire::http::proxy \"${http_proxy}\";" > /etc/apt/apt.conf; \
        [ -n "$https_proxy" ] && echo "Acquire::https::proxy \"${https_proxy}\";" >> /etc/apt/apt.conf; \
        [ -f /etc/apt/apt.conf ] && cat /etc/apt/apt.conf
fi

apt-get update

apt-get install -y g++-8-i686-linux-gnu gcc-8-i686-linux-gnu gcc-i686-linux-gnu g++-i686-linux-gnu ffmpeg libsm6 libxext6

python -m pip install -r /requirements.txt

