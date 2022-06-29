FROM ubuntu:20.04

RUN apt-get update && apt-get install -y curl unzip python3 python3-pip
RUN pip3 install bs4 lxml

#Install AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip && ./aws/install

#Remove aws cli artifacts after installation
RUN rm -rf aws && rm awscliv2.zip

ADD data-prep.sh /
RUN chmod +x /data-prep.sh

ADD model-save.sh /
RUN chmod +x /model-save.sh

ADD imagenet_data_prep.py /
