# Variables
ARG BUILDER=codexstorage/nim-lang:2.0.14
ARG IMAGE=ubuntu:24.04
ARG BUILD_HOME=/src
ARG MAKE_PARALLEL=${MAKE_PARALLEL:-4}
ARG NIMFLAGS="${NIMFLAGS:-"-d:disableMarchNative"}"
ARG USE_LIBBACKTRACE=${USE_LIBBACKTRACE:-1}
ARG APP_HOME=/crawler

# Build
FROM ${BUILDER} AS builder
ARG BUILD_HOME
ARG MAKE_PARALLEL
ARG NIMFLAGS
ARG USE_LIBBACKTRACE
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y cmake build-essential

WORKDIR ${BUILD_HOME}
COPY . .
RUN nimble build

# Create
FROM ${IMAGE}
ARG BUILD_HOME
ARG APP_HOME

WORKDIR ${APP_HOME}
COPY --from=builder ${BUILD_HOME}/build/* /usr/local/bin
COPY --from=builder --chmod=0755 ${BUILD_HOME}/docker/docker-entrypoint.sh /
RUN apt-get update && apt-get install -y libgomp1 curl jq && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["codexcrawler"]
