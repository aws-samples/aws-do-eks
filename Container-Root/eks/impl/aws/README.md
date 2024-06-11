# AWS CLI scripts for EKS management

This directory contains scripts which use the AWS CLI to help manage EKS infrastructure

## Description of files

* nodegroup.conf - centralized configuration for any of the scripts located in this directory

* [`ami-list.sh`](ami-list.sh) - list eks optimized gpu AMIs for the REGION specified in nodegroup.conf
* [`profile-list.sh`](profile-list.sh) - list available instance profiles and associated role name and ARN
* [`lt-list.sh`](lt-list.sh) - list available launch templates
* [`eks-nodegroup-list.sh`](eks-nodegroup-list.sh) - list nodegroups of the cluster specified in nodegroup.conf
* [`lt-generate.sh`](lt-generate.sh) - generate a launch template definition based on the values configured in nodegroup.conf. The script is configured to generate a P5.48xlarge launch template by default. Modify this script if a different template is desired.
* [`lt-create.sh`](lt-create.sh) - create a launch template based on the values configured in nodegroup.conf (uses lt-generate.sh)
* [`lt-delete.sh`](lt-delete.sh) - delete a launch template by id specified as argument
* [`eks-nodegroup-create.sh`](eks-nodegroup-create.sh) - create a nodegroup in the cluster as configured in nodegroup.conf
* [`eks-nodegroup-delete.sh`](eks-nodegroup-delete.sh) - delete a nodegroup from a cluster as specified by required command line arguments
* [`userdata.sh`](userdata.sh) - userdata script used to bootstrap nodegroup instances. This script is automatically embedded in the launch template.

## Add a GPU nodegroup to an existing EKS cluster

1. Edit `nodegroup.conf` and fill in the following values:
    * CLUSTER - your existing cluster name
    * REGION - the region where your cluster exists
    * LAUNCH_TEMPLATE_NAME - desired name for your new launch template
    * LAUNCH_TEMPLATE_VERSION=1 - version of your launch template
    * NODEGROUP_NAME - desired name for your nodegroup
    * NODEGROUP_ROLE_ARN - role ARN to be assigned to the new nodes. You can view a list of available roles by running the `profile-list.sh` script
    * SUBNETS - Subnet ID where you wish to launch nodes from this node group
    * MIN_SIZE=0 - minimum number of nodes in the node group
    * DESIRED_SIZE - number of nodes to be launched when the node group is created
    * MAX_SIZE - maximum number of nodes in the node group
    * EFA_VERSION=1.26.0 - this should typically be the latest version of the EFA installer
    * AMI - AMI ID for the nodegroup nodes, use `ami-list.sh` to retrieve the available ID
    * SSH_KEY_NAME - key pair name to use for ssh access to your new nodes, you can use the [aws-do-cli](https://bit.ly/aws-do-cli) project to manage key pairs, or directly use the [ec2-keypair-list.sh](https://github.com/aws-samples/aws-do-cli/blob/main/Container-Root/cli/ec2/ec2-keypair-list.sh) script.

2. Create template

Run 

```bash
./lt-create.sh
```

Copy the launch template ID as you will need it for the next step

3. Edit `nodegroup.conf` and fill in `LAUNCH_TEMPLATE_ID`

4. Create nodegroup

Run 

```bash
./eks-nodegroup-create.sh
```

This adds the configured nodegroup to the cluster

5. Verify

Run 

```bash
./eks-nodegroup-list.sh
```

You should see that the new nodegroup has been added to your cluster

6. Monitor cluster nodes

You can run commands 

```bash
kubectl get nodes -L node.kubernetes.io/instance-type
```

or

```
kgn
```

 or 

```bash
nv
```

This will display the nodes in your cluster. Once the nodes are initialized they will join the cluster and enter `Ready` status. In the meantime you can observe the nodes through the EC2 console.

NOTE: If EFA is enabled in the node group, edit the security group that the nodes are attached to and add a rule to allow all outgoing traffic originating from the same security group. This is required for EFA to work.

