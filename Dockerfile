#
# Build
#

FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder

USER root

WORKDIR /workdir/rhtap-cli

COPY installer/ ./installer/

COPY cmd/ ./cmd/
COPY pkg/ ./pkg/
COPY vendor/ ./vendor/

COPY go.mod go.sum Makefile ./

RUN make GOFLAGS='-buildvcs=false'

#
# Run
#

FROM registry.access.redhat.com/ubi9-minimal:9.4-1227.1726694542

LABEL \
  name="rhtap-cli" \
  com.redhat.component="rhtap-cli" \
  description="Red Hat Trusted Application Pipeline allows organizations to curate their own trusted, repeatable pipelines \
        that stay compliant with industry requirements. Built on proven, trusted open source technologies, Red Hat \
        Trusted Application Pipeline is part of Red Hat Trusted Software Supply Chain, a set of solutions to protect \ 
        users, customers, and partners from risks and vulnerabilities in their software factory." \
  io.k8s.description="Red Hat Trusted Application Pipeline allows organizations to curate their own trusted, repeatable pipelines \
  that stay compliant with industry requirements. Built on proven, trusted open source technologies, Red Hat \
  Trusted Application Pipeline is part of Red Hat Trusted Software Supply Chain, a set of solutions to protect \ 
  users, customers, and partners from risks and vulnerabilities in their software factory." \
  summary="Provides the binaries for downloading the RHTAP CLI." \
  io.k8s.display-name="Red Hat Trusted Application Pipeline CLI" \
  io.openshift.tags="rhtap-cli tas tpa rhdh ec tap openshift"

WORKDIR /rhtap-cli

COPY --from=builder /workdir/rhtap-cli/installer ./

COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli /usr/local/bin/rhtap-cli

RUN microdnf install -y gzip shadow-utils tar && \
    groupadd --gid 1000 -r rhtap-cli && \
    useradd -r -d /rhtap-cli -g rhtap-cli -s /sbin/nologin --uid 1000 rhtap-cli && \
    ARCH=$(uname -m) && \
    KUBECTL_VERSION=$(curl -sL https://dl.k8s.io/release/stable.txt) && \
    if [ "$ARCH" = "x86_64" ]; then \
        curl --proto "=https" --tlsv1.2 -sSf -L -O "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        curl --proto "=https" --tlsv1.2 -sSf -L -O "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/arm64/kubectl"; \
    fi && \
    chmod +x kubectl && \
    mv kubectl /usr/bin/kubectl && \
    microdnf remove -y shadow-utils && \
    microdnf clean all

USER rhtap-cli

ENTRYPOINT ["rhtap-cli"]
