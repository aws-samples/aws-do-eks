#!/bin/bash

echo ""
echo "v====================================================================================v"

os_release=$(cat /etc/os-release)
echo $os_release | grep "Amazon Linux" > /dev/null
if [ "$?" == "0" ]; then
	# Amazon Linux
	echo "Installing accelerator metrics cloudwatch exporter service on Amazon Linux ..."
	/usr/bin/pip3 install boto3
	mkdir -p /opt/aws
	yum install amazon-cloudwatch-agent git -y
        if [ -d /tmp/aws-efa-nccl-baseami ]; then
        	rm -rf /tmp/aws-efa-nccl-baseami
	fi
	git clone https://github.com/aws-samples/aws-efa-nccl-baseami-pipeline.git /tmp/aws-efa-nccl-baseami
        mkdir -p /opt/aws/cloudwatch
	cp -rf /tmp/aws-efa-nccl-baseami/nvidia-efa-ami_base/cloudwatch /opt/aws/
	mv /opt/aws/cloudwatch/aws-hw-monitor.service /lib/systemd/system
	echo -e '#!/bin/sh\n' | sudo tee /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
	echo -e '/usr/bin/python3 /opt/aws/cloudwatch/nvidia/aws-hwaccel-error-parser.py &' | sudo tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
	echo -e '/usr/bin/python3 /opt/aws/cloudwatch/nvidia/accel-to-cw.py /opt/aws/cloudwatch/nvidia/nvidia-exporter >> /dev/null 2>&1 &\n' | sudo tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
	echo -e '/usr/bin/python3 /opt/aws/cloudwatch/efa/efa-to-cw.py /opt/aws/cloudwatch/efa/efa-exporter >> /dev/null 2>&1 &\n' | sudo tee -a /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
	chmod +x /opt/aws/cloudwatch/aws-cloudwatch-wrapper.sh
	cp /opt/aws/cloudwatch/nvidia/cwa-config.json /opt/aws/amazon-cloudwatch-agent/bin/config.json
	/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json -s
	systemctl enable aws-hw-monitor.service
	systemctl restart amazon-cloudwatch-agent.service
	systemctl restart aws-hw-monitor.service
	systemctl status aws-hw-monitor.service
else
	echo "Accelerator metrics not supported on this operating system:"
	echo $os_release
fi

echo ""

