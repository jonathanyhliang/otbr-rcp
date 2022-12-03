ARG BASE_IMAGE=ubuntu:bionic
FROM ${BASE_IMAGE}

CMD ["bash"]

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=en_US.UTF-8

RUN /bin/sh -c set -x \
    && apt-get update -y \
    && apt-get install -y locales \
    && localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 \
    && apt-get --no-install-recommends install -fy bzip2 git ninja-build python3 \
       python3-pip python3-setuptools software-properties-common sudo netbase \
       inetutils-ping ca-certificates socat \
    && update-ca-certificates \
    && python3 -m pip install -U pip \
    && python3 -m pip install -U cmake \
    && python3 -m pip install wheel # buildkit

WORKDIR /

RUN git clone https://github.com/openthread/openthread --depth=1

RUN /bin/sh -c set -x \
    && cd openthread \
    && ./script/bootstrap \
    && mkdir build \
    && cd build \
    && cmake -GNinja -DOT_COMMISSIONER=ON -DOT_JOINER=ON -DOT_PLATFORM=simulation .. \
    && ninja # buildkit

WORKDIR /

RUN /bin/sh -c set -x \
    && cd openthread \
    && ./bootstrap \
    && ./script/cmake-build simulation

ARG INFRA_IF_NAME
ARG BORDER_ROUTING
ARG BACKBONE_ROUTER
ARG OT_BACKBONE_CI
ARG OTBR_OPTIONS
ARG DNS64
ARG NAT64
ARG NAT64_SERVICE
ARG NAT64_DYNAMIC_POOL
ARG REFERENCE_DEVICE
ARG RELEASE
ARG REST_API
ARG WEB_GUI
ARG MDNS

ENV INFRA_IF_NAME=${INFRA_IF_NAME:-eth0}
ENV BORDER_ROUTING=${BORDER_ROUTING:-1}
ENV BACKBONE_ROUTER=${BACKBONE_ROUTER:-1}
ENV OT_BACKBONE_CI=${OT_BACKBONE_CI:-0}
ENV OTBR_MDNS=${MDNS:-mDNSResponder}
ENV OTBR_OPTIONS=${OTBR_OPTIONS}
ENV DEBIAN_FRONTEND noninteractive
ENV PLATFORM ubuntu
ENV REFERENCE_DEVICE=${REFERENCE_DEVICE:-0}
ENV RELEASE=${RELEASE:-1}
ENV NAT64=${NAT64:-1}
ENV NAT64_SERVICE=${NAT64_SERVICE:-openthread}
ENV NAT64_DYNAMIC_POOL=${NAT64_DYNAMIC_POOL:-192.168.255.0/24}
ENV DNS64=${DNS64:-0}
ENV WEB_GUI=${WEB_GUI:-1}
ENV REST_API=${REST_API:-1}
ENV DOCKER 1

RUN env

# Required during build or run
ENV OTBR_DOCKER_REQS sudo python3

# Required during build, could be removed
ENV OTBR_DOCKER_DEPS git ca-certificates

# Required and installed during build (script/bootstrap), could be removed
ENV OTBR_BUILD_DEPS apt-utils build-essential psmisc ninja-build cmake wget ca-certificates \
  libreadline-dev libncurses-dev libcpputest-dev libdbus-1-dev libavahi-common-dev \
  libavahi-client-dev libboost-dev libboost-filesystem-dev libboost-system-dev \
  libnetfilter-queue-dev

# Required for OpenThread Backbone CI
ENV OTBR_OT_BACKBONE_CI_DEPS curl lcov wget build-essential python3-dbus

# Required and installed during build (script/bootstrap) when RELEASE=1, could be removed
ENV OTBR_NORELEASE_DEPS \
  cpputest-dev

WORKDIR /

RUN git clone https://github.com/openthread/ot-br-posix --depth=1

WORKDIR /ot-br-posix

RUN apt-get update \
    && apt-get install --no-install-recommends -y $OTBR_DOCKER_REQS $OTBR_DOCKER_DEPS \
    && ([ "${OT_BACKBONE_CI}" != "1" ] || apt-get install --no-install-recommends -y $OTBR_OT_BACKBONE_CI_DEPS) \
    && ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
    && ./script/bootstrap \
    && ./script/setup \
    && ([ "${DNS64}" = "0" ] || chmod 644 /etc/bind/named.conf.options) \
    && ([ "${OT_BACKBONE_CI}" = "1" ] || ( \
        mv ./script /tmp \
        && mv ./etc /tmp \
        && find . -delete \
        && rm -rf /usr/include \
        && mv /tmp/script . \
        && mv /tmp/etc . \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $OTBR_DOCKER_DEPS \
        && apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false $OTBR_BUILD_DEPS  \
        && ([ "${RELEASE}" = 1 ] ||  apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false "$OTBR_NORELEASE_DEPS";) \
        && rm -rf /var/lib/apt/lists/* \
    ))

EXPOSE 80
