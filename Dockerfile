#
# Build
#

FROM registry.redhat.io/openshift4/ose-tools-rhel9@sha256:145f82dfb62fc38bcf5da96ab848b5a7769f849e5f1f6cf18d9df7adb7bb272c AS ose-tools
FROM registry.access.redhat.com/ubi9/go-toolset:1.23.6-1747333074 AS builder

USER root
WORKDIR /workdir/tssc

COPY installer/ ./installer/

COPY cmd/ ./cmd/
COPY pkg/ ./pkg/
COPY vendor/ ./vendor/

COPY go.mod go.sum Makefile ./

RUN make GOFLAGS='-buildvcs=false'

#
# Run
#

FROM registry.access.redhat.com/ubi9-minimal:9.6-1749489516

LABEL \
  name="tssc" \
  com.redhat.component="tssc" \
  description="Red Hat Trusted Software Supply Chain allows organizations to curate their own trusted, \
    repeatable pipelines that stay compliant with industry requirements. Built on proven, trusted open \
    source technologies, Red Hat Trusted Software Supply Chain is a set of solutions to protect users, \
    customers, and partners from risks and vulnerabilities in their software factory." \
  io.k8s.description="Red Hat Trusted Software Supply Chain allows organizations to curate their own trusted, \
    repeatable pipelines that stay compliant with industry requirements. Built on proven, trusted open \
    source technologies, Red Hat Trusted Software Supply Chain is a set of solutions to protect users, \
    customers, and partners from risks and vulnerabilities in their software factory." \
  summary="Provides the tssc binary." \
  io.k8s.display-name="Red Hat Trusted Software Supply Chain CLI" \
  io.openshift.tags="tssc tas tpa rhdh ec tap openshift"

WORKDIR /licenses

COPY LICENSE.txt .

WORKDIR /tssc

COPY --from=ose-tools /usr/bin/jq /usr/bin/kubectl /usr/bin/oc /usr/bin/vi /usr/bin/
# jq libraries
COPY --from=ose-tools /usr/lib64/libjq.so.1 /usr/lib64/libonig.so.5 /usr/lib64/
# vi libraries
COPY --from=ose-tools /usr/libexec/vi /usr/libexec/

COPY --from=builder /workdir/tssc/installer/charts ./charts
COPY --from=builder /workdir/tssc/installer/config.yaml ./
COPY --from=builder /workdir/tssc/bin/tssc /usr/local/bin/tssc

RUN groupadd --gid 999 -r tssc && \
    useradd -r -d /tssc -g tssc -s /sbin/nologin --uid 999 tssc && \
    chown -R tssc:tssc .

USER tssc

RUN echo "# jq" && jq --version && \
    echo "# kubectl" && kubectl version --client && \
    echo "# oc" && oc version

ENV KUBECONFIG=/tssc/.kube/config

ENTRYPOINT ["tssc"]
