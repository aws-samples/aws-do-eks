FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-devel
#FROM 763104351884.dkr.ecr.us-west-2.amazonaws.com/pytorch-training:2.0.1-gpu-py310-cu118-ubuntu20.04-ec2

ENV DEBIAN_FRONTEND=noninteractive

RUN apt update && apt install -y git vim curl autoconf make g++ libtool hwloc

COPY ./efa-setup.sh /tmp

WORKDIR /tmp

RUN chmod +x *.sh; ./efa-setup.sh

RUN mkdir -p /workspace/

WORKDIR /workspace

#RUN git clone https://github.com/lessw2020/fsdp_llm.git
RUN git clone https://github.com/kanwaljitkhurmi/fsdp_llm_copy.git

WORKDIR /workspace/fsdp_llm_copy

#RUN sed -i config/nanogpt_config.py -e 's/str = "1B"/str = "10.5M"/g'
#RUN sed -i config/nanogpt_config.py -e 's/iters_to_run: int = 8 /iters_to_run: int = 800 /g'

RUN pip3 install python-etcd

RUN apt update && apt install -y htop
