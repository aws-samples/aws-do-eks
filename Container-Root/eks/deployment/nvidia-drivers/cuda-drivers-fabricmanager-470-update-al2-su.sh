#!/bin/bash

echo ""
echo "v==================================================v""
echo "Checking for failed nvidia fabricmanager service ..."
systemctl status nvidia-fabricmanager | grep "nvidia-fabricmanager.service failed"
if [ "$?" == "1" ]; then
	echo "Found failed nvidia-fabricmanager.service. Updating ..."
	yum remove -y nvidia-fabricmanager-470 nvidia-driver-470
	yum install -y cuda-drivers-fabricmanager-470
	systemctl daemon-reload
	systemctl restart nvidia-fabricmanager
	systemctl status nvidia-fabricmanager 
else
	echo "nvidia-fabricmanager.service is helthy. Skipping update."
fi
echo ""

