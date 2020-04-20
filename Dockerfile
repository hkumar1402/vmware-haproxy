# Copyright (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

################################################################################
##                               BUILD ARGS                                   ##
################################################################################
# The golang image is used to build the DataPlane API.
ARG GOLANG_IMAGE=golang:1.14.1


################################################################################
##                        BUILD DATAPLANE API STAGE                           ##
################################################################################
FROM ${GOLANG_IMAGE} as builder

# The Git ref used to build the DataPlane API binary.
ARG DATAPLANEAPI_REF
ENV DATAPLANEAPI_REF ${DATAPLANEAPI_REF:-494f9b817842d9e28f7b75c4c32a59395794636c}

WORKDIR /

RUN git clone https://github.com/haproxytech/dataplaneapi.git && \
    cd dataplaneapi && \
    git checkout -b build-me ${DATAPLANEAPI_REF} && \
    make build


################################################################################
##                               MAIN STAGE                                   ##
################################################################################
FROM photon:3.0 as main
LABEL "maintainer" "Andrew Kutz <akutz@vmware.com>"

WORKDIR /

COPY --from=builder /dataplaneapi/build/dataplaneapi /usr/local/bin/dataplaneapi
RUN chmod 0755 /usr/local/bin/dataplaneapi

RUN tdnf install -y curl vim lsof pcre rpm shadow systemd iputils iproute2

# The path to the HAProxy RPM.
ARG HAPROXY_RPM_URI
ENV HAPROXY_RPM_URI ${HAPROXY_RPM_URI:-http://pa-dbc1118.eng.vmware.com/ppadmavilasom/results/haproxy-2.1.0/haproxy-2.1.0-1.ph3.x86_64.rpm}

RUN rpm -ivh ${HAPROXY_RPM_URI} && \
    useradd --system --home-dir=/var/lib/haproxy --user-group haproxy && \
    mkdir -p /var/lib/haproxy && \
    chown -R haproxy:haproxy /var/lib/haproxy

COPY ansible/roles/haproxy/files/etc/haproxy/haproxy.cfg \
     example/ca.crt example/server.crt example/server.key \
     /etc/haproxy/
RUN chmod 0640 /etc/haproxy/haproxy.cfg /etc/haproxy/*.crt && \
    chmod 0440 /etc/haproxy/*.key

CMD [ "-f", "/etc/haproxy/haproxy.cfg" ]
ENTRYPOINT [ "/usr/sbin/haproxy" ]