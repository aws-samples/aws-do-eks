FROM nvcr.io/nvidia/pytorch:22.07-py3

ARG http_proxy
ARG https_proxy
ARG no_proxy
ARG INSTALL_MPI
ARG INSTALL_EFA
ARG INSTALL_TESTS

ADD Container-Root /

RUN export http_proxy=$http_proxy; export https_proxy=$https_proxy; export no_proxy=$no_proxy; export INSTALL_MPI=$INSTALL_MPI; export INSTALL_EFA=$INSTALL_EFA; export INSTALL_TESTS=$INSTALL_TESTS; /setup.sh

CMD /startup.sh

