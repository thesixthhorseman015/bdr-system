FROM postgres:16-alpine

RUN apk add --no-cache bash curl gzip coreutils util-linux

# Download standalone MinIO Client binary from the updated release endpoint
RUN curl -sSL https://dl.min.io/aistor/mc/release/linux-amd64/mc -o /usr/local/bin/mc && \
    chmod +x /usr/local/bin/mc

WORKDIR /scripts

COPY scripts/ /scripts/
RUN chmod +x /scripts/*.sh

ENTRYPOINT ["/scripts/entrypoint.sh"]