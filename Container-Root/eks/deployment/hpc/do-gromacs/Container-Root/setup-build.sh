#!/bin/sh

if [ -d /etc/apt ]; then
        [ -n "$http_proxy" ] && echo "Acquire::http::proxy \"${http_proxy}\";" > /etc/apt/apt.conf; \
        [ -n "$https_proxy" ] && echo "Acquire::https::proxy \"${https_proxy}\";" >> /etc/apt/apt.conf; \
        [ -f /etc/apt/apt.conf ] && cat /etc/apt/apt.conf
fi

# Write environment
mkdir /opt/spack-environment
SPACK_YAML=/opt/spack-environment/spack.yaml
echo "spack:" > $SPACK_YAML
echo "  specs:" >> $SPACK_YAML
echo "  - gromacs" >> $SPACK_YAML
echo "  - osu-micro-benchmarks" >> $SPACK_YAML
echo "  packages:" >> $SPACK_YAML
echo "    all:" >> $SPACK_YAML
echo "      target: [ $SPACK_TARGET ]" >> $SPACK_YAML
echo "  concretizer:" >> $SPACK_YAML
echo "    unify: true" >> $SPACK_YAML
echo "  config:" >> $SPACK_YAML
echo "    install_tree: /opt/software" >> $SPACK_YAML
echo "  view: /opt/view" >> $SPACK_YAML
echo "" >> $SPACK_YAML

echo ""
echo "Environment:"
env

echo ""
echo "$SPACK_YAML"
cat $SPACK_YAML

# Set up spack env, binary cache
echo ""
spack env activate -d /opt/spack-environment
spack mirror add binary_mirror https://binaries.spack.io/$SPACK_CACHE_VERSION 
spack buildcache keys --install --trust 
spack install --reuse --use-cache --fail-fast 
spack gc -y 
spack find -v

# Strip binaries
find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s

spack env activate --sh -v -d /opt/spack-environment > /etc/profile.d/z10_spack_environment.sh
