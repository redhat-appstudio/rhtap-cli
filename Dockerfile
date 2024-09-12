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

FROM quay.io/openshift/origin-cli:latest

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

COPY --from=builder /workdir/rhtap-cli/installer/charts ./charts
COPY --from=builder /workdir/rhtap-cli/installer/scripts ./scripts
COPY --from=builder /workdir/rhtap-cli/installer/config.yaml .

COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli /usr/local/bin/rhtap-cli

RUN groupadd -g 1000 -r rhtap-cli && \
    useradd -u 1000 -g rhtap-cli -r -d /rhtap-cli -s /sbin/nologin rhtap-cli && \
    chown -v -R rhtap-cli:rhtap-cli /rhtap-cli

USER rhtap-cli

ENTRYPOINT ["rhtap-cli"]
