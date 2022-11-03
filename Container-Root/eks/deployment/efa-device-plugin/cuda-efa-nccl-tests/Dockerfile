FROM nvcr.io/nvidia/cuda:11.4.1-cudnn8-devel-ubuntu18.04

ARG http_proxy
ARG https_proxy
ARG no_proxy

ARG EFA_INSTALLER_VERSION=latest
ARG AWS_OFI_NCCL_VERSION=aws
ARG NCCL_TESTS_VERSION=master

ENV LD_LIBRARY_PATH /usr/local/cuda/extras/CUPTI/lib64:/opt/amazon/openmpi/lib:/opt/nccl/build/lib:/opt/amazon/efa/lib:/opt/aws-ofi-nccl/install/lib:$LD_LIBRARY_PATH
ENV PATH /opt/amazon/openmpi/bin/:/opt/amazon/efa/bin:/usr/bin:/usr/local/bin:$PATH
ENV NCCL_PROTO simple

ADD Container-Root /

RUN export EFA_INSTALLER_VERSION=$EFA_INSTALLER_VERSION; export AWS_OFI_NCCL_VERSION=$AWS_OFI_NCCL_VERSION; export NCCL_TESTS_VERSION=$NCCL_TESTS_VERSION; export http_proxy=$http_proxy; export https_proxy=$https_proxy; export no_proxy=$no_proxy; /setup.sh; rm -f /setup.sh

CMD /startup.sh

