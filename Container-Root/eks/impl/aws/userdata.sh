#!/bin/bash

. ./nodegroup.conf

CA=$(aws eks describe-cluster --query "cluster.certificateAuthority.data" --output text --name $CLUSTER --region $REGION)
API=$(aws eks describe-cluster --query "cluster.endpoint" --output text --name $CLUSTER --region $REGION)
CIDR=$(aws eks describe-cluster --query "cluster.kubernetesNetworkConfig.serviceIpv4Cidr" --output text --name $CLUSTER --region $REGION)
DNS=$(echo $CIDR | sed -e 's#[0-9]*/[0-9]*#10#g')

cat << EOF
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="//"

--//
Content-Type: text/x-shellscript; charset="us-ascii"
#!/bin/bash
set -x

#curl -O https://efa-installer.amazonaws.com/aws-efa-installer-${EFA_VERSION}.tar.gz --output-dir /tmp
#tar -xf /tmp/aws-efa-installer-${EFA_VERSION}.tar.gz -C /tmp
#cd /tmp/aws-efa-installer
#./efa_installer.sh -y -g
#/opt/amazon/efa/bin/fi_info -p efa

/etc/eks/bootstrap.sh $CLUSTER --local-disks raid0 --b64-cluster-ca $CA --apiserver-endpoint $API --dns-cluster-ip $DNS

--//--
EOF
