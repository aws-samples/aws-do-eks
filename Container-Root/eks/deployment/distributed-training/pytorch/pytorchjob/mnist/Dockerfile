FROM pytorch/pytorch:2.4.0-cuda12.1-cudnn9-runtime
#FROM pytorch/pytorch:1.8.1-cuda10.2-cudnn7-runtime

RUN pip install tensorboardX==1.6.0 protobuf==3.19.0 && pip cache remove *
RUN mkdir -p /opt/mnist

WORKDIR /opt/mnist/src
ADD mnist.py /opt/mnist/src/mnist.py

RUN  chgrp -R 0 /opt/mnist \
  && chmod -R g+rwX /opt/mnist

ENTRYPOINT ["python", "/opt/mnist/src/mnist.py"]
