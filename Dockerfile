# The pinned gocov CLI release is fetched at *build* time and verified
# against the release's sha256 checksums — the pipe never downloads
# anything at runtime. The image tag is the pipe version; the CLI version
# is pinned per image via GOCOV_VERSION.
#
# TARGETARCH is set automatically by BuildKit (buildx, and plain
# `docker build` on current Docker) to the platform being built. It is
# declared with no default on purpose: a default in the ARG line wins
# over the automatic value, which is how the published arm64 images
# (0.18.0 and 0.19.0 at least) shipped the amd64 CLI. Classic builders
# (e.g. Bitbucket Cloud CI, which has no buildx — the multi-arch release
# build runs on the GitHub mirror) leave it empty, and the RUN below
# falls back to amd64.
FROM alpine:3.22 AS fetch
ARG TARGETARCH
ARG GOCOV_VERSION=v0.26.2
RUN apk add --no-cache curl
WORKDIR /dl
RUN arch="${TARGETARCH:-amd64}" && \
    base="https://github.com/gocov/gocov/releases/download/${GOCOV_VERSION}" && \
    curl -fsSL --retry 3 --retry-delay 2 -O "${base}/gocov-linux-${arch}" && \
    curl -fsSL --retry 3 --retry-delay 2 -O "${base}/checksums.txt" && \
    want="$(awk -v f="gocov-linux-${arch}" '$2 == f' checksums.txt)" && \
    [ -n "$want" ] && \
    echo "$want" | sha256sum -c - && \
    mv "gocov-linux-${arch}" gocov && \
    chmod +x gocov

FROM alpine:3.22
COPY pipe/pipe.sh /pipe.sh
# bash: pipe.sh shares glob semantics with gocov-action's upload.sh;
# ca-certificates: the CLI uploads over TLS.
RUN apk add --no-cache bash ca-certificates && chmod +x /pipe.sh
COPY --from=fetch /dl/gocov /usr/local/bin/gocov
ENTRYPOINT ["/pipe.sh"]
