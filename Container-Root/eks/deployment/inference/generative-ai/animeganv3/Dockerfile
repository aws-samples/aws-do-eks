#FROM nvcr.io/nvidia/cuda:11.8.0-runtime-ubuntu22.04
FROM nvcr.io/nvidia/pytorch:24.04-py3

ARG http_proxy
ARG https_proxy
ARG no_proxy

ENV DEBIAN_FRONTEND=noninteractive

ADD Container-Root /

RUN export http_proxy=$http_proxy; export https_proxy=$https_proxy; export no_proxy=$no_proxy; /setup.sh; rm -f /setup.sh

CMD /startup.sh

WORKDIR /
