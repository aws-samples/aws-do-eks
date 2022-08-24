FROM public.ecr.aws/w6p6i9i7/aws-efa-nccl-rdma:21.11-pt-py3

RUN apt-get update && apt-get install -y git htop
RUN pip3 install python-etcd

RUN mkdir -p /workspace/
RUN cd /workspace && \
    git clone https://github.com/pytorch/elastic.git
