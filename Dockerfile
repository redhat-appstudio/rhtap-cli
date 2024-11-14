#
# Build
#
FROM registry.redhat.io/openshift4/ose-tools-rhel9:latestt@sha256:c2a2eca448a2e1b5d73f88dcd12a6c87e5f4580512303f4e38b67acf810b4778 as ose-tools
FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder

USER root

WORKDIR /workdir/rhtap-cli

COPY charts/ ./charts/
COPY cmd/ ./cmd/
COPY pkg/ ./pkg/
COPY scripts/ ./scripts/
COPY vendor/ ./vendor/

COPY config.yaml go.mod go.sum Makefile ./

RUN make GOFLAGS='-buildvcs=false'

#
# Run
#

FROM registry.access.redhat.com/ubi9-minimal:9.5-1731604394

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

COPY --from=builder /workdir/rhtap-cli/charts ./charts/
COPY --from=builder /workdir/rhtap-cli/scripts ./scripts/
COPY --from=builder /workdir/rhtap-cli/config.yaml .
COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli .
COPY --from=ose-tools /usr/bin/kubectl /usr/bin/

RUN groupadd --gid 1000 -r rhtap-cli && \
    useradd -r -d /rhtap-cli -g rhtap-cli -s /sbin/nologin --uid 1000 rhtap-cli

USER rhtap-cli

# Debug
RUN kubectl version --client

ENTRYPOINT ["/rhtap-cli/rhtap-cli"]
