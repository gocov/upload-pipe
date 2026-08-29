# The pinned gocov CLI release is fetched at *build* time and verified
# against the release's sha256 checksums — the pipe never downloads
# anything at runtime. The image tag is the pipe version; the CLI version
# is pinned per image via GOCOV_VERSION.
#
# TARGETARCH is set automatically by buildx for multi-arch builds
# (linux/amd64 + linux/arm64); the default keeps plain `docker build`
# working on classic builders (e.g. Bitbucket Cloud CI, which has no
# buildx — the multi-arch release build runs on the GitHub mirror).
FROM alpine:3.22 AS fetch
ARG TARGETARCH=amd64
ARG GOCOV_VERSION=v0.13.2
RUN apk add --no-cache curl
WORKDIR /dl
RUN base="https://github.com/gocov/gocov/releases/download/${GOCOV_VERSION}" && \
    curl -fsSL --retry 3 --retry-delay 2 -O "${base}/gocov-linux-${TARGETARCH}" && \
    curl -fsSL --retry 3 --retry-delay 2 -O "${base}/checksums.txt" && \
    want="$(awk -v f="gocov-linux-${TARGETARCH}" '$2 == f' checksums.txt)" && \
    [ -n "$want" ] && \
    echo "$want" | sha256sum -c - && \
    mv "gocov-linux-${TARGETARCH}" gocov && \
    chmod +x gocov

FROM alpine:3.22
COPY pipe/pipe.sh /pipe.sh
# bash: pipe.sh shares glob semantics with gocov-action's upload.sh;
# ca-certificates: the CLI uploads over TLS.
RUN apk add --no-cache bash ca-certificates && chmod +x /pipe.sh
COPY --from=fetch /dl/gocov /usr/local/bin/gocov
ENTRYPOINT ["/pipe.sh"]
