#
# Build
#

FROM registry.redhat.io/openshift4/ose-tools-rhel9@sha256:12bc1a965451a5c11558cb6f6dc78109c674ab340463ac1a24c46cd8166ca3bd AS ose-tools
FROM registry.access.redhat.com/ubi9/go-toolset:1.22.9-1739801907 AS builder

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

FROM registry.access.redhat.com/ubi9-minimal:9.5-1739420147

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

COPY --from=ose-tools /usr/bin/jq /usr/bin/kubectl /usr/bin/oc /usr/bin/vi /usr/bin/
# jq libraries
COPY --from=ose-tools /usr/lib64/libjq.so.1 /usr/lib64/libonig.so.5 /usr/lib64/
# vi libraries
COPY --from=ose-tools /usr/libexec/vi /usr/libexec/

COPY --from=builder /workdir/rhtap-cli/installer/charts ./charts
COPY --from=builder /workdir/rhtap-cli/installer/config.yaml ./
COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli /usr/local/bin/rhtap-cli

RUN groupadd --gid 999 -r rhtap-cli && \
    useradd -r -d /rhtap-cli -g rhtap-cli -s /sbin/nologin --uid 999 rhtap-cli && \
    chown -R rhtap-cli:rhtap-cli .

USER rhtap-cli

RUN echo "# jq" && jq --version && \
    echo "# kubectl" && kubectl version --client && \
    echo "# oc" && oc version

ENV KUBECONFIG=/rhtap-cli/.kube/config

ENTRYPOINT ["rhtap-cli"]
