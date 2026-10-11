# EKS Auto Mode cluster with H200 (p5en.48xlarge) or B200 (p6-b200.48xlarge) GPU nodes and EFA

Companion manifests for the cluster manifest [../eks-auto-mode-gpu-efa.yaml](../eks-auto-mode-gpu-efa.yaml).

On [EKS Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/automode.html) the `ClusterConfig` has no `nodeGroups` or `managedNodeGroups`: AWS runs the compute (a built-in Karpenter), pod networking, cluster DNS, block storage and the GPU drivers and device plugin as cluster capabilities on Bottlerocket-based nodes. The GPU nodes are described by two Kubernetes objects that are applied after the cluster exists:

- a `NodeClass` (`eks.amazonaws.com/v1`) that selects the subnet, security group and **capacity reservation** and declares the EFA interfaces statically, and
- a static `NodePool` (`karpenter.sh/v1`) that keeps a fixed number of reserved nodes of one instance type in one availability zone.

**The one thing that is not obvious:** the `cr-xxxxxxxxxxxxxxxxx` id goes into the `NodeClass` (`capacityReservationSelectorTerms`), not into the eksctl file. The `capacityReservation.capacityReservationTarget.capacityReservationID` field used by the other examples in this folder belongs to a nodegroup, and there are none here. The NodePool's `karpenter.sh/capacity-type: reserved` requirement is what binds the nodes to the reservation.

## Files

| File | Purpose |
|------|---------|
| [../eks-auto-mode-gpu-efa.yaml](../eks-auto-mode-gpu-efa.yaml) | eksctl `ClusterConfig` with `autoModeConfig.enabled: true`, us-east-2, EKS 1.35, built-in `general-purpose` + `system` node pools (left at the AWS-suggested default) |
| [nodeclass-p5en-efa.yaml](nodeclass-p5en-efa.yaml) | NodeClass for p5en.48xlarge (8 x H200): 16 network cards, 16 EFA interfaces |
| [nodepool-p5en-efa.yaml](nodepool-p5en-efa.yaml) | static NodePool, 2 x p5en.48xlarge on the reservation |
| [nodeclass-p6-b200-efa.yaml](nodeclass-p6-b200-efa.yaml) | NodeClass for p6-b200.48xlarge (8 x B200): 8 network cards, 8 EFA interfaces |
| [nodepool-p6-b200-efa.yaml](nodepool-p6-b200-efa.yaml) | static NodePool, 2 x p6-b200.48xlarge on the reservation |
| [efa-device-plugin-values.yaml](efa-device-plugin-values.yaml) | Helm values for the EFA device plugin (tolerates the GPU node taint) |

The EFA interface counts come from the EC2 API, not from a table:

```bash
aws ec2 describe-instance-types --region us-east-2 --instance-types p5en.48xlarge p5e.48xlarge p6-b200.48xlarge \
  --query 'InstanceTypes[].[InstanceType,NetworkInfo.MaximumNetworkCards,NetworkInfo.EfaInfo.MaximumEfaInterfaces,GpuInfo.Gpus[0].Name,GpuInfo.Gpus[0].Count]' --output table
```

```text
|  p5en.48xlarge    |  16 |  16 |  H200 |  8 |
|  p5e.48xlarge     |  32 |  32 |  H200 |  8 |
|  p6-b200.48xlarge |  8  |  8  |  B200 |  8 |
```

Each NodeClass has one `interface` on card 0 (the primary ENI, required) and one `efa-only` interface on every network card: card 0 device 1, then cards 1..N-1.

## Prerequisites

- eksctl 0.195.0 or newer (the schema of this `ClusterConfig` was validated with eksctl 0.207.0), kubectl, helm, AWS CLI
- An On-Demand Capacity Reservation (ODCR) or ML Capacity Block for p5en.48xlarge or p6-b200.48xlarge, and its availability zone

## Walkthrough

The steps assume the `aws-do-eks` shell with current directory `/eks`. Outside the container, replace `conf/` with `wd/conf/` and `./eks-create.sh` with `eksctl create cluster -f`.

### 1. Create the cluster

```bash
./env-config.sh
```

Set:

```bash
export IMPL=impl/eksctl/yaml
export CONF=conf/eksctl/yaml/eks-auto-mode-gpu-efa.yaml
```

Adjust `metadata.name`, `region` and `availabilityZones` in the manifest if needed (`./eks-config.sh`); the region must contain the AZ of your reservation. Then:

```bash
./eks-create.sh
```

eksctl creates the VPC, the Auto Mode cluster, the cluster IAM role and the Auto Mode node IAM role. No nodes other than the built-in CPU pools exist yet.

### 2. Look up the values the NodeClass needs

```bash
export AWS_REGION=us-east-2
export CLUSTER_NAME=do-eks-yaml-auto-mode-gpu-efa
export CAPACITY_RESERVATION_ID=cr-xxxxxxxxxxxxxxxxx   # your ODCR or Capacity Block

# availability zone and instance type of the reservation
aws ec2 describe-capacity-reservations --region $AWS_REGION --capacity-reservation-ids $CAPACITY_RESERVATION_ID \
  --query 'CapacityReservations[0].[AvailabilityZone,InstanceType,TotalInstanceCount,State]' --output text
export CR_AZ=$(aws ec2 describe-capacity-reservations --region $AWS_REGION --capacity-reservation-ids $CAPACITY_RESERVATION_ID --query 'CapacityReservations[0].AvailabilityZone' --output text)

# name of the Auto Mode node IAM role (the NodeClass takes the name, not the ARN)
export NODE_ROLE_NAME=$(aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME --query cluster.computeConfig.nodeRoleArn --output text | awk -F/ '{print $NF}')

# EKS cluster security group (allows all traffic from itself, which is what EFA needs)
export CLUSTER_SG=$(aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.clusterSecurityGroupId --output text)

# the private cluster subnet in the reservation's AZ (eksctl tags private subnets kubernetes.io/role/internal-elb=1)
export VPC_ID=$(aws eks describe-cluster --region $AWS_REGION --name $CLUSTER_NAME --query cluster.resourcesVpcConfig.vpcId --output text)
export GPU_SUBNET=$(aws ec2 describe-subnets --region $AWS_REGION \
  --filters Name=vpc-id,Values=$VPC_ID Name=availability-zone,Values=$CR_AZ Name=tag:kubernetes.io/role/internal-elb,Values=1 \
  --query 'Subnets[0].SubnetId' --output text)

echo "az=$CR_AZ role=$NODE_ROLE_NAME sg=$CLUSTER_SG subnet=$GPU_SUBNET"
```

Reusing the Auto Mode node role matters: EKS created the EC2 access entry for that role when it created the built-in node pools, so the custom NodeClass needs no extra access entry. If you point the NodeClass at a different role, [create the access entry](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html#_create_node_class_access_entry) first.

### 3. Fill in the placeholders and apply the NodeClass and NodePool

For H200 use the `p5en` pair, for B200 the `p6-b200` pair. The commands below use `p5en`.

```bash
cd conf/eksctl/yaml/eks-auto-mode-gpu-efa

sed -i -e "s/REPLACE-WITH-AUTO-MODE-NODE-ROLE-NAME/$NODE_ROLE_NAME/" \
       -e "s/subnet-xxxxxxxxxxxxxxxxx/$GPU_SUBNET/" \
       -e "s/sg-xxxxxxxxxxxxxxxxx/$CLUSTER_SG/" \
       -e "s/cr-xxxxxxxxxxxxxxxxx/$CAPACITY_RESERVATION_ID/" nodeclass-p5en-efa.yaml
sed -i -e "s/us-east-2a/$CR_AZ/" nodepool-p5en-efa.yaml

grep -n 'xxxxxxxx\|REPLACE' nodeclass-p5en-efa.yaml nodepool-p5en-efa.yaml   # must print nothing
```

Set `replicas` in the NodePool to the number of reserved instances you want running and keep `limits.nodes` above it. Then:

```bash
kubectl apply -f nodeclass-p5en-efa.yaml
kubectl apply -f nodepool-p5en-efa.yaml
```

### 4. Install the EFA device plugin

Auto Mode includes the NVIDIA drivers and GPU device plugin, but not the EFA device plugin, which advertises `vpc.amazonaws.com/efa` on the nodes. Install it the same way [/eks/deployment/efa-device-plugin/deploy.sh](../../../../../Container-Root/eks/deployment/efa-device-plugin/deploy.sh) does, with the values file that adds the toleration for the GPU node taint:

```bash
helm repo add eks https://aws.github.io/eks-charts
helm repo update
helm install efa eks/aws-efa-k8s-device-plugin -n kube-system --version v0.5.33 -f efa-device-plugin-values.yaml
```

### 5. Verify

```bash
kubectl get nodeclass p5en-efa
kubectl get nodepool p5en-efa
kubectl get nodeclaims -o wide
kubectl get nodes -L node.kubernetes.io/instance-type
```

The static pool launches `replicas` nodes right away. If none appear, `kubectl describe nodeclaim -l karpenter.sh/nodepool=p5en-efa` shows the launch error (reservation id or AZ mismatch, insufficient capacity, IAM). Once the nodes are `Ready` they should advertise 8 `nvidia.com/gpu` and one `vpc.amazonaws.com/efa` per EFA interface (16 on p5en.48xlarge, 8 on p6-b200.48xlarge):

```bash
kubectl get nodes -l karpenter.sh/nodepool=p5en-efa -o custom-columns='NAME:.metadata.name,TYPE:.metadata.labels.node\.kubernetes\.io/instance-type,GPU:.status.allocatable.nvidia\.com/gpu,EFA:.status.allocatable.vpc\.amazonaws\.com/efa'
```

A pod that requests `nvidia.com/gpu` and `vpc.amazonaws.com/efa` and tolerates the `nvidia.com/gpu` taint now schedules on these nodes. The NCCL tests in [/eks/deployment/nccl-test](../../../../../Container-Root/eks/deployment/nccl-test) are a ready-made workload: their worker pods already carry the toleration; set `INSTANCE_TYPE`, `GPU_PER_WORKER=8` and `EFA_PER_WORKER` (16 for p5en, 8 for p6-b200) in its `.env`.

### 6. Cleanup

```bash
kubectl delete -f nodepool-p5en-efa.yaml     # drains and terminates the reserved nodes
kubectl delete -f nodeclass-p5en-efa.yaml
cd /eks && ./eks-delete.sh
```

The reservation itself is not touched and keeps billing until you cancel it.

## Using p5e.48xlarge (H200, 32 EFA interfaces)

Copy `nodeclass-p5en-efa.yaml` and `nodepool-p5en-efa.yaml`, change the instance type in the NodePool to `p5e.48xlarge` and replace the `efa-only` entries for cards 1..15 in the NodeClass with cards 1..31. The list can be rendered from the EC2 API for any EFA-capable type:

```bash
INSTANCE_TYPE=p5e.48xlarge
CARDS=$(aws ec2 describe-instance-types --region $AWS_REGION --instance-types $INSTANCE_TYPE --query 'InstanceTypes[0].NetworkInfo.MaximumNetworkCards' --output text)
for ((c = 1; c < CARDS; c++)); do printf '      - networkCardIndex: %d\n        deviceIndex: 0\n        interfaceType: efa-only\n' $c; done
```

## What is different on Auto Mode

- **Bottlerocket nodes, managed by AWS.** Nodes run an AWS-managed Bottlerocket-based AMI, not AL2023; there is no SSH or SSM access, and nodes are replaced by AWS on drift (a new Auto Mode AMI roughly once per week) and after 336 hours by default. The static pool keeps `replicas` nodes through a replacement and `disruption.budgets` limits it to one node at a time. ([Learn about Auto Mode managed instances](https://docs.aws.amazon.com/eks/latest/userguide/automode-learn-instances.html), [Create a node pool](https://docs.aws.amazon.com/eks/latest/userguide/create-node-pool.html))
- **No node groups: the `cr-` id lives in the NodeClass**, bound by `karpenter.sh/capacity-type: reserved` on the NodePool. Capacity Blocks for ML always require `capacityReservationSelectorTerms`. ([Capacity Reservations with Auto Mode](https://docs.aws.amazon.com/eks/latest/userguide/auto-odcr.html))
- **Static capacity pool.** `replicas` holds the nodes regardless of pod demand. Once set, `replicas` cannot be removed again; only `limits.nodes` is honored; `weight` cannot be set; the nodes are never consolidated. ([Static capacity node pools](https://docs.aws.amazon.com/eks/latest/userguide/auto-static-capacity.html))
- **EFA is declared statically and pod IP capacity is fixed at launch.** With `advancedNetworking.networkInterfaces` set, Auto Mode attaches no additional IPs, prefixes or ENIs after launch; `secondaryIPv4PrefixCount: 1` on the primary ENI is one /28 = 16 pod IPs per node. IPv6 is not supported with static interfaces. ([Create a node class](https://docs.aws.amazon.com/eks/latest/userguide/create-node-class.html))
- **EFA and static hugepages cannot coexist on one NodeClass.** `interfaceType: efa-only` together with `advancedCompute.hugepages.pages` fails NodeClass validation, and pods that request `vpc.amazonaws.com/efa` are not provisioned from a NodeClass with static hugepages. Workloads that request `hugepages-2Mi` need that request removed or a separate non-EFA NodeClass. (same page)
- **Device plugins.** Auto Mode includes the NVIDIA GPU drivers and device plugin ([Auto Mode overview](https://docs.aws.amazon.com/eks/latest/userguide/automode.html)), so no NVIDIA device plugin or GPU operator is deployed. The EFA device plugin is not bundled (per the AWS sample [sample-eks-docs auto-mode](https://github.com/aws-samples/sample-eks-docs/tree/main/ai-ml/set-up-cluster/terraform/auto-mode); the AWS documentation pages above do not mention it) and is installed in step 4.
- **Built-in node pools kept.** `autoModeConfig.nodePools` is left unspecified (AWS: "AWS suggests not specifying any value for nodePools"), which creates `general-purpose` and `system`. They run CoreDNS and other system pods, provision the `default` NodeClass and create the access entry for the Auto Mode node role. With `nodePools: []` you would have to create that access entry yourself. ([Create an Auto Mode cluster with eksctl](https://docs.aws.amazon.com/eks/latest/userguide/automode-get-started-eksctl.html))

## Validation status

Validated offline only: the `ClusterConfig` passes the JSON schema emitted by `eksctl utils schema` (eksctl 0.207.0; a planted `nodePool` typo is rejected), and each NodeClass/NodePool pair passes a consistency check for the reservation binding, the primary-ENI and EFA interface rules, the EFA/hugepages exclusion and the static-pool rules. Nothing in this folder has been applied to a live cluster; the first cluster created from it is the proof.
