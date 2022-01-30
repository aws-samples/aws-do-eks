# EFS File System

Following are the steps to mount an EFS file system to a container and copy data to the EFS volume:

- Create EFS file system:
    
    If you don't already have an EFS volume, you need to create one and also set up mount targets. This script does all that:

    `efs-create.sh`

    This script creates a security group, then creates EFS file system, and finally creates mount targets for the EFS file system for each subnet.

- Create Persistent Volume

    Before creating persistent volume, we need to deploy EFS CSI driver. Then we can create the persistent volume. Following script does this process:

    `deploy.sh`

    This script will setup the CSI driver, then create the persistent volume by applying `efs-pvs.yaml`. Finally, this will also create a test pod and mount the EFS volume to that pod. This is done by applying `efs-share-test.yaml`.

    Note that the `deploy.sh` script fetches the EFS file system id using aws cli. If you have multiple volumes then you need to provide the specific EFS volume id in the `deploy.sh` script (line 18) or directly in the `efs-pvc.yaml` file (line 24). Otherwise you'll get errors while creating the persistent volume.

- Copy training data to EFS volume

    This requires multiple steps:

    - Create a shell scrip to copy data from S3 to the shared directory where EFS is mounted:

        `data-prep.sh`
    
    - Create a docker and add this script to the docker container. The `Dockerfile` simply adds the `data-prep.sh` and `model-save.sh` scripts (to be used later) to the docker container. 

        The `build.sh` and `push.sh` will create this docker and push to ECR. But we need to provide the URI of the repository which is hard wired in these scripts.

    - Finally, create a pod that will run the `data-prep.sh` script, by applying `efs-data-prep-pod.yaml`.

- Copy trained model and last checkpoint to S3

    `model-save.sh` script will copy the best model and last saved checkpoint to S3 bucket. Note that this is based on the output of TorchElastic model training job.

    To run this script we just need to create a pod by applying `model-save-pod.yaml`. We need to provide the s3 bucket in this yaml file where the model needs to saved.

- Clean up

    The `delete.sh` script will delete the test pod and the persistent volume. This will also clean up the CSI driver. But this will not delete the EFS volume.


# FSx File System

Working with FSx is similar to EFS except that the FSx is single AZ. Therefore all the nodes using FSx for Luster should be in the same AZ.

- Create FSx for Luster
    Following script creates the FSx file system:

    `../fsx-csi/deploy.sh`

    This script read in `../fsx-csi/fsx.conf` file. Before running the scrip we need to provide the subnet id (line 14) and instance profile name in the conf file.

    The `../fsx-csi/deploy.sh` script will also create the persistent volume by applying `../fsx-csi/fsx-storage-class.yaml` file.

- Create test pod

    We can create a test pos and mount the fsx file system by applying the `fsx-share-test.yaml`.

- Copy data from S3

    This is the same as the copying the data to EFS as described above. Same docker and `data-prep.sh` scripts are used. Just create a pod to run this script using the `fsx-data-prep-pod.yaml`.

