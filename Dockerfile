#FROM public.ecr.aws/ubuntu/ubuntu:20.04
FROM ubuntu:20.04

ARG http_proxy
ARG https_proxy
ARG no_proxy

ENV DEBIAN_FRONTEND=noninteractive
ENV AWS_PAGER=""
ENV VERBOSE="true"

ADD Container-Root /
ADD wd/conf/ /eks/conf/

RUN export http_proxy=$http_proxy; export https_proxy=$https_proxy; export no_proxy=$no_proxy; /setup.sh; rm -f /setup.sh

WORKDIR /eks

CMD /startup.sh

