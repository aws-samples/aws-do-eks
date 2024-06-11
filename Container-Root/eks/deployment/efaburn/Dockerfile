FROM ubuntu:20.04
ARG EFA_INSTALLER_VERSION=1.30.0
RUN apt update && apt install curl -y
# Install EFA
RUN cd $HOME \
    && curl -O https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
    && tar -xf $HOME/aws-efa-installer-${EFA_INSTALLER_VERSION}.tar.gz \
    && cd aws-efa-installer \
    && ./efa_installer.sh -y -g -d --skip-kmod --skip-limit-conf --no-verify
# Setup test
RUN cp $HOME/aws-efa-installer/efa_test.sh /efa_test.sh && sed -i -e 's/-e rdm -p efa/-e rdm -p efa -I 10000 -S 8388608/g' /efa_test.sh
CMD /bin/sh -c ". /etc/profile.d/zippy_efa.sh && while true; do /efa_test.sh; done"

