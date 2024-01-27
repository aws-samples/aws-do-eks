# Prometheus - Grafana Deployment

## Prerequisites

Prometheus and Grafana use Kubernetes persistent volumes to store data. A default storage class is required. The default storage class in EKS is typically gp2. This requires the EBS CSI driver to be deployed to the cluster. You can deploy the driver either via the scripts in /eks/deployment/csi/ebs, or by depoying the EBS CSI managed add-on from the EKS console.

## Deploy

This deployment uses Helm charts to deploy Prometheus and Grafana to your cluster.

To deploy Prometheus and Grafana, simply run

```bash
./deploy.sh
```

## Status

To check the status of the deployment execute:

```bash
./status.sh
```

You should see all pods running in the prometheus and grafana namespaces.

## Login

To expose the Grafana UI outside of the Kubernetes cluster, run:

```bash
./expose.sh
```

This command will port-forward the Grafana service and provide a URL for access.

Login as user `admin`.

The password is configurable in the deploy script, and can be obtained by running

```bash
./auth.sh
```

## Dashboards
By default there are no dashboards that are pre-configured in Grafana. There are countless choices of dashboards ready for import on [grafana.com](https://grafana.com/grafana/dashboards/?search=Kubernetes). To import any of these dashboards, please click on the dashboards icon on the left side of the Grafana screen, then select "+ Import". In the text field, enter the ID number of the dashboard you would like to import from the grafana.com catalog, then select Prometheus as the data source and click "Load".

Recommended dashboards IDs:

10000 - Cluster monitoring

747 - Pod monitoring

## Delete
Removing Prometheus and Grafana from your cluster can be done by executing:

```bash
./delete.sh
```

