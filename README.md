<img alt="aws-do-cli" src="./aws-do-eks-1024.png" width="25%" align="right" />

# AWS do EKS (aws-do-eks) <br/> Create and Manage your Amazon EKS clusters using the [do-framework](https://bit.ly/do-framework)

<center><img src="aws-do-eks.png" width="80%"/> </br>

Fig. 1 - EKS cluster sample
</center>


## Overview
As described in the [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/create-cluster.html), creating an EKS cluster can be done using [eksctl](https://eksctl.io/usage/creating-and-managing-clusters/), the [AWS console](https://console.aws.amazon.com/eks/home#/clusters), or the [aws cli](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html). [Terraform](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest) can also be used to create and manage your EKS infrastructure. Regardless of your choice, each of these tools has its specifics and requires learning.  
The [do-framework](https://bit.ly/do-framework) strives to simplify DevOps and MLOps tasks by automating complex operations into intuitive action scripts. For example, instead of running an `eksctl` command with several command line arguments to create an EKS cluster, [aws-do-eks](https://bit.ly/do-eks) provides an `eks-create.sh` script which wraps any of the supported tools including eksctl or terraform and provides a simplified and intuitive user experience. The only prerequisite needed to build and run this project is [Docker](https://docs.docker.com/get-docker/). The main use case of this project is to specify a desired cluster configuration, then create or manage the EKS cluster by executing the corresponding script. This process is described in further detail below.

## Configure
Configuration items are located in three configuration files at the project, container, and cluster level. 

The [`.env`](.env) file in the project's root contains all project-level settings and is used when building and running the `aws-do-eks` project. To edit this configuration, execute the [`./config.sh`](config.sh) script, or simply open the [`.env`](.env) file in your favorite editor. 

The [`conf/env.conf`](wd/conf/env.conf) file has container environment settings and is used by the scripts that create, update, or delete your EKS cluster. The most important settings in this file are the implementation of cluster tooling (`IMPL`) (eksctl, terraform, etc) and the path to your cluster configuration (`CONF`). To edit this file, execute [`./env-config.sh`](env-config.sh) or open [`conf/env.conf`](wd/conf/env.conf) in your favorite editor. By default the environment is configured to use `impl/eksctl/yaml` as implementation and `conf/eksctl/yaml/eks.yaml` as cluster configuration. If you prefer to use [Terraform](https://www.terraform.io/use-cases/infrastructure-as-code) instead of [eksctl](https://eksctl.io), set `IMPL` to `impl/terraform` and `CONF` to the `variables.tf` file of your terraform template (e.g. [conf/terraform/eks/variables.tf](wd/conf/terraform/eks/variables.tf)). If you prefer to use [eksctl](https://eksctl.io) with a properties-style environment configuration file, set `IMPL` to `impl/eksctl/env` and CONF to the path of your configuration file (e.g. [conf/eksctl/env/eks.conf](wd/conf/eksctl/env/eks.conf)). Heterogeneous clusters are supported. For example, in [`eks.conf`](wd/conf/eksctl/env/eks.conf)  you can specify the list of nodegroups to be added to the cluster and their scale. 
Following the same pattern this project can be extended to support other toolsets for creation and management of EKS infrastructure (e.g. [CDK](https://aws.amazon.com/cdk/)).

The cluster-level configuration is stored in the location, specified by you in the `CONF` variable. Typically this is in a subdirectory of the [conf/](wd/conf) directory. The project comes with a collection of pre-configured clusters that can be used immediately, or you can use the provided examples as a template and create your own cluster configuration.

AWS Credentials can be configured at the instance level through an instance role or injected into the `aws-do-eks` container using volume or secrets mounting. To configure credentials, run aws configure. Credentials you configure on the host will be mounted into the `aws-do-eks` container according to the `VOL_MAP` setting in [`.env`](.env).

## Build
This project follows the [Depend on Docker](https://github.com/iankoulski/depend-on-docker) template to build a container including all needed tools and utilities for creation and management of your EKS clusters. Please execute the [`./build.sh`](./build.sh) script to create the `aws-do-eks` container image. If desired, the image name or registry address can be modified in the project configuration file [`.env`](.env).

## Run
The [`./run.sh`](./run.sh) script starts the project container. After the container is started, use the [`./exec.sh`](./exec.sh) script to open a bash shell in the container. All necessary tools to allow creation, management, and operation of EKS are available in this shell. 

## ENV Configure
Once you have opened the `aws-do-eks` shell you will be dropped in the `/eks` directory where you will find the EKS control scripts.
Execute [`./env-config.sh`](Container-Root/eks/env-config.sh) to edit the current environment settings. Here you can select the tooling implementation (`IMPL`) and your target cluster configuration (`CONF`).

## EKS Configure
The [`./eks-config.sh`](Container-Root/eks/eks-config.sh) script opens the current cluster configuration in the default editor. You can adjust nodegroups and many other settings of the cluster through this configuration.

## EKS Create
Execute the [`./eks-create.sh`](Container-Root/eks/eks-create.sh) script to create the configured cluster. This operation will take a while as it involves creation of a VPC, Subnets, Autoscaling groups, the EKS cluster, its nodes and any other necessary resources. Upon successful completion of this process, your shell will be configured for `kubectl` access to the created EKS cluster. 

## EKS Status
To view the current status of the cluster execute the [`eks-status.sh`](Container-Root/eks/eks-status.sh) script. It will display the cluster information as well as details about any of its nodegroups.

## EKS Update
To make changes to your existing cluster or set the sizes of your cluster node groups, afer editing the cluster configuration via [`eks-config.sh`](Container-Root/eks/eks-update.sh), then run [`./eks-update.sh`](Container-Root/eks/eks-update.sh).

## EKS Delete
To decomission your cluster and remove all AWS resources associated with it, execute the [`./eks-delete.sh`](Container-Root/eks/eks-delete.sh) script. This is a destructive operation. If there is anything in your cluster that you need saved, please persist it outside of the cluster VPC before executing this script.

## Shell customiazations
When you open a shell into a running `aws-do-eks` container via `./exec.sh`, you will be able to execute `kubectl`, `aws`,`eksctl, and terraform` commands. There are other tools and shell customizations that are installed in the container for convenience.

### Tools and customizations
* [kubectx](https://github.com/ahmetb/kubectx) - show or set current Kubernetes context
* [kubens](https://github.com/ahmetb/kubectx) - show or set current namespace
* [kubetail](https://github.com/johanhaleby/kubetail/master/kubetail) - tail the logs of pods that have a name matching a specified pattern
* [kubectl-node-shell](https://github.com/kvaps/kubectl-node-shell) - open an interactive shell into a kubernetes node using a privileged mode (Do not use in production)
* [kubeps1](https://github.com/jonmosco/kube-ps1) - customize shell prompt with cluster info 

### Aliases
```
alias dp='pod-describe.sh'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias grep='grep --color=auto'
alias k='kubectl'
alias kc='kubectx'
alias kctl='kubectl'
alias kctx='kubectx'
alias kdp='pod-describe.sh'
alias ke='pod-exec.sh'
alias kgn='nodes-list.sh'
alias kgnt='nodes-types-list.sh'
alias kgp='pods-list.sh'
alias kl='pod-logs.sh'
alias kn='kubens'
alias kns='kubens'
alias koff='rm -f ~/.kubeon; source ~/.bashrc'
alias kon='touch ~/.kubeon; source ~/.bashrc'
alias ks='kubectl node-shell'
alias kt='kubetail'
alias l='ls -CF'
alias la='ls -A'
alias ll='ls -alh --color=auto'
alias lns='nodes-list.sh'
alias lnt='nodes-types-list.sh'
alias lp='pods-list.sh'
alias ls='ls --color=auto'
alias nl='nodes-list.sh'
alias ntl='nodes-types-list.sh'
alias nv='eks-node-viewer'
alias pe='pod-exec.sh'
alias pl='pod-logs.sh'
alias t='terraform'
alias tf='terraform'
alias tx='torchx'
alias wkgn='watch-nodes.sh'
alias wkgnt='watch-node-types.sh'
alias wkgp='watch-pods.sh'
alias wn='watch-nodes.sh'
alias wnt='watch-node-types.sh'
alias wp='watch-pods.sh'
```

## Other scripts

### Infrastructure
The [`eks`](Container-Root/eks) folder contains [`vpc`](Container-Root/eks/vpc), [`ops`](Container-Root/eks/ops), [`conf`](Container-Root/wd/conf) and [`impl`](Container-Root/eks/impl) subfolders. These subfolders contain cluster-level scripts that are used by the scripts in the main folder or can be invoked independently. 

### Deployment
The [`deployment`](Container-Root/eks/deployment) folder contains scripts for deploying system-level capabilities like cluster-autoscaler, aws-load-balancer-controller, nvidia-gpu-operator, etc. to the EKS cluster. If you would like cluster-autoscaler deployed automatically when the cluster is created, set CLUSTER_AUTOSCALER_DEPLOY="true" in eks.conf. To deploy the cluster-autoscaler to an EKS cluster that has already been created, change your current directory to deployment/cluster-autoscaler, then execute [`./deploy-cluster-autoscaler.sh`](Container-Root/eks/deployment/cluster-autoscaler/deploy-cluster-autoscaler.sh). Follow a similar pattern for other deployments.

### Operations
The [`ops`](Container-Root/eks/ops) folder contains scripts for management and operation of workloads on the EKS cluster. The goal of these scripts is to provide shorthand for commonly used `kubectl`command lines. Aliases of these scripts have been configured as described above to further simplify operations.

### Container
The project home folder offers a number of additional scripts for management of the aws-do-eks container.
* [`./login.sh`](./login.sh) - use the currently configured aws settings to authenticate with the configured registry
* [`./push.sh`](./push.sh) - push aws-do-eks container image to configured registry
* [`./pull.sh`](./pull.sh) - pull aws-do-eks container image from a configured existing registry
* [`./status.sh`](./status.sh) - show current status of aws-do-eks container
* [`./start.sh`](./status.sh) - start the aws-do-eks container if is currently in "Exited" status
* [`./stop.sh`](./stop.sh) - stop and remove the aws-do-eks container
* [`./test.sh`](./test.sh) - run container unit tests

## Examples

These examples assume that you have opened the `aws-do-eks` shell and the current working directory is `/eks`. 

### 1. Create EKS Cluster with P4de nodegroup and EFA networking using eksctl and on-demand capacity reservation

#### 1.1. Configure environment

```bash
./env-config.sh
```

Set:

```bash
export IMPL=impl/eksctl/yaml
export CONF=conf/eksctl/yaml/eks-gpu-p4de-odcr.yaml
```

#### 1.2. Configure cluster

```bash
./eks-config.sh
```

Set:

```yaml
    capacityReservation:
      capacityReservationTarget:
        capacityReservationID: "cr-xxxxxxxxxxxxxxxxx"
```

Use the actual `capacityReservaationID` of your ODCR. Also ensure the `availabilityZones` reflect the one from the capacity reservation.

#### 1.3. Create cluster

```bash
./eks-create.sh
```

### 2. Create EKS Cluster with P5 nodegroup and EFA networking using Terraform and on-demand capacity reservation

#### 2.1. Configure environment

```bash
./env-config.sh
```

Set:

```bash
export IMPL=impl/terraform
export CONF=conf/terraform/eks-p5/variables.tf
```

#### 2.2. Configure cluster

```bash
./eks-config.sh
```

Set `odcr_id`. Set other variables as needed.

#### 2.3. Create cluster

```bash
./eks-create.sh
```

## Troubleshooting
* eksctl authentication errors - execute "aws configure --profile <profile_name>" and provide access key id and secret access key to configure access.

```
Create a new profile, different than default:
aws configure --profile <profile-name>

Update kubeconfig with profile::
aws eks update-kubeconfig --region <region> --name <cluster-name> --profile <profile-name>

Check that <profile-name> is in ~/.kube/config

user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      args:
      - --region
      - <region>
      - eks
      - get-token
      - --cluster-name
      - <cluster-name>
      command: aws
      env:
      - name: AWS_PROFILE
        value: <profile-name>
```

Alternatively check `~/.aws/credentials` and remove any `session_id` entries.

Another solution is to `export AWS_ACCESS_KEY_ID=<your_access_key_id>`, `export AWS_SECRET_ACCESS_KEY=<your_secret_access_key>`, and `export AWS_DEFAULT_REGION=<your_cluster_aws_region>` in your environment.


* timeouts from eksctl api - the cloudformation apis used by eksctl are throttled, normally eksctl will retry when a timeout occurs
* context deadline exceeded - when executing eksctl commands you may see this error message. In this case please retry running the same command after the failure occurs. The cloud formation stack may have completed successfully already, but that information may not be known to eksctl. Running the command again updates the status and checks if all necessary objects have been created. 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This project is licensed under the MIT-0 License. See the [LICENSE](LICENSE) file.

## References

* [Docker](https://docker.com)
* [Kubernetes](https://kubernetes.io)
* [Amazon Web Services (AWS)](https://aws.amazon.com/)
* [Amazon EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
* [Amazon Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks)
* [AWS Fargate](https://aws.amazon.com/fargate)
* [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)
* [eksctl yaml schema](https://eksctl.io/usage/schema/)
* [Depend on Docker Project](https://github.com/iankoulski/depend-on-docker)
* [Terraform](https://terraform.io)

