FROM vault.habana.ai/gaudi-docker/1.5.0/ubuntu20.04/habanalabs/tensorflow-installer-tf-cpu-2.9.1

RUN git clone -b 1.5.0 https://github.com/HabanaAI/Model-References.git

# Installs hccl_ofi_wrapper to interact with libfabric to utilize HW and networking mode (EFA)
ARG OFI_WRAPPER_WS="/root/hccl_ofi_wrapper"
RUN git clone "https://github.com/HabanaAI/hccl_ofi_wrapper.git" "${OFI_WRAPPER_WS}" && \
  cd "${OFI_WRAPPER_WS}" && \
  ln -s /opt/amazon/efa/lib64 /opt/amazon/efa/lib && \
  LIBFABRIC_ROOT=/opt/amazon/efa make

ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:"${OFI_WRAPPER_WS}"
