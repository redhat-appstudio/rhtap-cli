#
# Build
#

FROM registry.access.redhat.com/ubi9/go-toolset:latest AS builder

USER root

WORKDIR /workdir/rhtap-cli

COPY charts/ ./charts/
COPY cmd/ ./cmd/
COPY pkg/ ./pkg/
COPY scripts/ ./scripts/
COPY vendor/ ./vendor/

COPY config.yaml go.mod go.sum Makefile .

RUN make GOFLAGS='-buildvcs=false'

#
# Run
#

FROM registry.access.redhat.com/ubi9-minimal:9.4

WORKDIR /rhtap-cli

COPY --from=builder /workdir/rhtap-cli/charts .
COPY --from=builder /workdir/rhtap-cli/scripts .
COPY --from=builder /workdir/rhtap-cli/config.yaml .

COPY --from=builder /workdir/rhtap-cli/bin/rhtap-cli .

USER rhtap-cli

ENTRYPOINT ["/rhtap-cli/rhtap-cli"]
