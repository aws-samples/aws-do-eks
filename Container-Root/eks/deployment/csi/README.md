# Creating File Systems and Copying Data

The detailed steps for creating file systems and persistent volumes are provided in the relevant sub directories.

For copying the data to any persistent volume, we can run a bash script with the suitable `aws cli` command. In this directory we have `data-prep.sh` script which copies data from s3 to a specific mount point.

The Dockerfile provided here just creates a docker image with a copy of the scripts in this directory. Use the `build.sh` and `push.sh` scripts to build and push the docker image.
