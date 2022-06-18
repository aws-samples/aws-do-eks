# Model Training

To run a pytorch model training job, we need to have a docker image with pytorch and torchvision. This docker also needs to contain our training code. The `Dockerfile` here creates such docker image. We can create the required docker image using `build.sh` script and push it the ECR repository using `push.sh` script.

Note that, in this `Dockerfile` we're starting from a [public docker](https://gallery.ecr.aws/w6p6i9i7/aws-efa-nccl-rdma) which is specifically designed to run pytorch on instances with [EFA](https://aws.amazon.com/hpc/efa/). If we don't need EFA, then we can use other [pytorch images](https://hub.docker.com/r/pytorch/pytorch) with gpu support.

The other thing we need inside the docker image is the training code. For our examples, we're using the training code from pytorch [elastic](https://github.com/pytorch/elastic) repo which is cloned inside the docker image.

The provided `yaml` files will run the selected torchvision model on imagenet dataset stored in EFS or FSx filesystems. We just need to apply the relevant yaml file:

`kubectl apply -f imagenet-efa.yaml`
