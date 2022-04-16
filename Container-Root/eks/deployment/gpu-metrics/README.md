# CloudWatch GPU Metrics

Setting up CloudWatch agent to collect GPU metrics requires a docker image with `amazon-cloudwatch-agent` and `nvidi-smi` installed. All the scripts in this folder are taken from the following repository with necessary changes for gpu metrics:

https://github.com/aws-samples/amazon-cloudwatch-container-insights

The general instructions for setting up CloudWatch agent to collect cluster metric can be found [here](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Container-Insights-setup-metrics.html).

- Create the docker image

    Before building the docker image we need to specify the docker repository in the `.env` file present in the root folder. This is done by setting the `REGISTRY` environment variable.
    
    Then we can create the docker image using the Dockerfile in this folder and push it to the registry. Use the `build.sh` and `push.sh` scripts to build and push the image.

- Run the CloudWatch agent deamonset

    To create the daemonset, run the `deploy.sh` script. This script does a couple of things. It creates a new namespace `amazon-cloudwatch` and switches the context to this namespace. Secondly, it will create a ConfigMap containing the json file needed by the cloudwatch agent. Finally, it will create the daemonset which pushes the metric to CloudWatch.

    Note that the gpu metrics will show under CWAgent namespace on AWS CloudWatch console, but the rest of the cluster metrics will show under ContainerInsights namespace.

- (Optional) Test scripts

    We can run GPU and CPU stress tests to check if the metrics are being pushed to CloudWatch. We can use the provided yaml files. For example:

    `kubectl apply -f gpu_burn.yaml`

    This will run `gpu_burn` for 2 min and we should see the gpu usage in the CloudWatch (after some delay).
