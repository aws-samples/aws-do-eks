FROM pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime

RUN apt update && apt install -y git vim

RUN mkdir -p /workspace/

WORKDIR /workspace

RUN git clone https://github.com/lessw2020/fsdp_llm.git

WORKDIR /workspace/fsdp_llm

#RUN sed -i config/nanogpt_config.py -e 's/str = "1B"/str = "10.5M"/g'
RUN sed -i config/nanogpt_config.py -e 's/iters_to_run: int = 8 /iters_to_run: int = 800 /g'

