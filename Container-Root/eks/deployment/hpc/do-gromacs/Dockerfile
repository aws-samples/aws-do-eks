ARG BUILD_IMAGE
ARG RUN_IMAGE

FROM $BUILD_IMAGE as build

ARG SPACK_VERSION
ARG SPACK_CACHE_VERSION
ARG SPACK_TARGET
ARG http_proxy
ARG https_proxy
ARG no_proxy

ADD Container-Root /

RUN echo SPACK_TARGET=$SPACK_TARGET

RUN http_proxy=$http_proxy https_proxy=$https_proxy no_proxy=$no_proxy SPACK_TARGET=$SPACK_TARGET SPACK_CACHE_VERSION=$SPACK_CACHE_VERSION /setup-build.sh; rm -f /setup-build.sh

FROM $RUN_IMAGE as final

COPY --from=build /opt/software /opt/software
COPY --from=build /opt/view /opt/view
COPY --from=build /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh
COPY --from=build /setup-run.sh /setup-run.sh
COPY --from=build /test*.sh /
COPY --from=build /app /app

RUN http_proxy=$http_proxy https_proxy=$https_proxy no_proxy=$no_proxy /setup-run.sh; rm -f /setup-run.sh

WORKDIR /app

CMD /app/startup.sh

