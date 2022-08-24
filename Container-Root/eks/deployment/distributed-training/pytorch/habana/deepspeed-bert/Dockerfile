FROM vault.habana.ai/gaudi-docker/1.5.0/ubuntu20.04/habanalabs/pytorch-installer-1.11.0:1.5.0-610

RUN apt-get install -y openssh-server

ENV HOME /root
RUN echo $HOME

##############################################################################
# SSH Setup
##############################################################################
ENV SSHDIR $HOME/.ssh
RUN mkdir -p ${SSHDIR} \
&& touch ${SSHDIR}/sshd_config \
&& ssh-keygen -t rsa -f ${SSHDIR}/ssh_host_rsa_key -N '' \
&& cp ${SSHDIR}/ssh_host_rsa_key.pub ${SSHDIR}/authorized_keys \
&& cp ${SSHDIR}/ssh_host_rsa_key ${SSHDIR}/id_rsa \
&& echo "       IdentityFile ${SSHDIR}/id_rsa" >> ${SSHDIR}/config \
&& echo "       StrictHostKeyChecking no" >> ${SSHDIR}/config \
&& echo "       UserKnownHostsFile /dev/null" >> ${SSHDIR}/config \
&& echo "       Port 2022" >> ${SSHDIR}/config \
&& echo 'Port 2022' >> ${SSHDIR}/sshd_config \
&& echo "HostKey ${SSHDIR}/ssh_host_rsa_key" >> ${SSHDIR}/sshd_config \
&& echo "PidFile ${SSHDIR}/sshd.pid" >> ${SSHDIR}/sshd_config \
&& chmod -R 600 ${SSHDIR}/*
RUN eval `ssh-agent -s` && ssh-add ${SSHDIR}/id_rsa


# RUN echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config && \
#     sed -i 's/#\(StrictModes \).*/\1no/g' /etc/ssh/sshd_config

RUN git clone -b 1.5.0 https://github.com/HabanaAI/Model-References.git
RUN git clone -b v1.5.0 https://github.com/HabanaAI/deepspeed.git

# ADD run_pretraining.py /Model-References/PyTorch/nlp/pretraining/deepspeed-bert/run_pretraining.py

RUN pip install -r /Model-References/PyTorch/nlp/pretraining/deepspeed-bert/requirements.txt && \
    pip install /deepspeed/. && \
    apt-get install -y tmux pdsh && \
    pip install torch-summary mpi4py

# Installs hccl_ofi_wrapper to interact with libfabric to utilize HW and networking mode (EFA)
ARG OFI_WRAPPER_WS="/root/hccl_ofi_wrapper"
RUN git clone "https://github.com/HabanaAI/hccl_ofi_wrapper.git" "${OFI_WRAPPER_WS}" && \
  cd "${OFI_WRAPPER_WS}" && \
  ln -s /opt/amazon/efa/lib64 /opt/amazon/efa/lib && \
  LIBFABRIC_ROOT=/opt/amazon/efa make

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/amazon/openmpi/lib:/opt/amazon/efa/lib/:${OFI_WRAPPER_WS}

ADD .deepspeed_env /root/.deepspeed_env

ENV PYTHONPATH=/Model-References:/usr/lib/habanalabs
ENV PATH=$PATH:/opt/amazon/efa/bin
ENV HCL_CONFIG_PATH=/etc/hcl/worker_config.json
ENV HCCL_OVER_TCP=0
ENV HCCL_OVER_OFI=1
ENV FI_PROVIDER=efa
ENV DOCKER_SSHD_PORT=2022
ENV OMPI_MCA_btl_vader_single_copy_mechanism="none"

ADD scripts /Model-References/PyTorch/nlp/pretraining/deepspeed-bert/scripts
