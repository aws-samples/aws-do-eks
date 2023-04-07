# Horizontal Pod Autoscaling

The [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) is included in the base set of Kubernetes resources that comes included with any new cluster.

The `hpa-example` folder contains a simple php-apache microservice which can be built and deployed to illustrate how HPA works. The example requires `metrics-server` to be deployed on the cluster. A script for that is provided in the `/eks/deployment` directory.

[KEDA](keda.sh) is a Kubernetes Event Driven Autoscaler which works alongside standard horizontal pod autoscaler and enables scaling based on various events. Refer to the `keda` directory for deployment.

