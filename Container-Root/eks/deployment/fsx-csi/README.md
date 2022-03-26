# FSx File System

The FSx for Luster filesystem can only exists in a single AZ and all the nodes using FSx for Luster should be in the same AZ. The simplest way to do this is to set single AZ in the `eks.conf` file before creating the cluster.

- Create FSx for Luster
    Following script creates the FSx file system:

    `fsx-csi/deploy.sh`

    This script read in `../fsx-csi/fsx.conf` file. Before running the script we need to provide the subnet id (line 14) for the AZ in which the FSx is supposed to exist. Also, we need the instance profile name which is the same as the Launce template id. This can be obtained from the relevant auto-scaling group in EC2 console as shown here: 

    <center><img src="fsx_conf_instance_profile_name.png" width="80%"/></center>

    The `fsx-csi/deploy.sh` script will also create the persistent volume by applying `fsx-csi/fsx-storage-class.yaml` file.

- Create test pod

    We can create a test pos and mount the fsx file system by applying the `../efs-csi/fsx-share-test.yaml`.

- Copy data from S3

    This is the same as the copying the data to EFS as described above. Same docker and `../efs-csi/data-prep.sh` scripts are used. Just create a pod to run this script using the `../efs-csi/fsx-data-prep-pod.yaml`.

