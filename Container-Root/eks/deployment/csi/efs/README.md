# EFS File System

Following are the steps to create and mount an EFS file system:

- Create EFS file system:
    
    If you don't already have an EFS volume, you need to create one and also set up mount targets. This script does all that:

    `./efs-create.sh`

    This script creates a security group, then creates EFS file system, and finally creates mount targets for the EFS file system for each subnet.

- Create persistent volume

    Before creating persistent volume, we need to deploy EFS CSI driver. Then we can create the persistent volume. Following script does this process:

    `./deploy.sh`

    This script will setup the CSI driver. Next we create the persistent volume by:

    `kubectl apply - f efs-pvs.yaml`
    
    Note that the `deploy.sh` script fetches the EFS file system id using aws cli. If you have multiple volumes then you need to provide the specific EFS volume id in the `deploy.sh` script (line 18) or directly in the `efs-pvc.yaml` file (line 24). Otherwise you'll get errors while creating the persistent volume.

- Create a test pod and mount persistent volume

    Optionally, we can also create a test pod and mount the EFS volume to that pod. This is done by applying

    `kubectl apply -f efs-share-test.yaml`

- Copy training data to EFS volume

    Assuming that a docker image with `data_prep.sh` script exists, create a pod that will run the `data_prep.sh` script, by applying
    
    `kubectl apply -f efs-data-prep-pod.yaml`.

    We need to specify the s3 bucket and mount path in this yaml file before creating a pod.

- (Optional) Copy trained model and last checkpoint to S3

    (Note that this is based on the output of TorchElastic model training job.) Assuming that a docker image with `model-save.sh` script exists we can copy the best model and last saved checkpoint to S3 bucket. 
    To run the `model-save.sh` script we just need to create a pod by

    `kubectl apply -f efs-model-save-pod.yaml`.
    
    We need to provide the s3 bucket in this yaml file where the model needs to saved.

- Clean up

    The `delete.sh` script will delete the test pod and the persistent volume. This will also clean up the CSI driver. But this will not delete the EFS volume.