ARG BASE_IMAGE_PATH="rust:slim-trixie"

FROM $BASE_IMAGE_PATH

ARG BUILD="20250812"
ARG MAINTAINER="Alex Iankoulski <iankouls@amazon.com>"
ARG DESCRIPTION="Depend on Docker efatop image based on rust and ratatui"
ARG http_proxy
ARG https_proxy
ARG no_proxy

LABEL MAINTAINER="$MAINTAINER"

LABEL DESCRIPTION="$DESCRIPTION"

LABEL BUILD="$BUILD"

ADD Container-Root /

RUN export http_proxy=$http_proxy; export https_proxy=$https_proxy; export no_proxy=$no_proxy; /setup.sh; rm -f /setup.sh

CMD /startup.sh

