# EBS CSI Driver

The [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver/blob/master/docs/install.md) can be deployed using the `./deploy.sh` script provided here. The driver requires your instance role to have certain permissions which may not be granted by default. 
If EBS volume provisioning is not working, please check that your instance role has the AmazonEBSCSIDriverPolicy added. 
If you require snapshotting, install the [CSI Snapshotter Controller and CRD](https://github.com/kubernetes-csi/external-snapshotter).

