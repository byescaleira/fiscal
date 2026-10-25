FROM golang:1.26.10-bookworm AS build
WORKDIR /src
COPY go.mod ./
COPY cmd ./cmd
COPY internal ./internal
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /liveresults-server ./cmd/server \
 && CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /fiscal-ingest ./cmd/ingest

FROM debian:bookworm-20261005-slim
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --system --uid 1000 --no-create-home --shell /usr/sbin/nologin app \
 && mkdir -p /data /secrets /public \
 && chown app:app /data /public \
 && chmod 700 /data \
 && chmod 755 /public
COPY --from=build /liveresults-server /usr/local/bin/liveresults-server
COPY --from=build /fiscal-ingest /usr/local/bin/fiscal-ingest
ENV HOST=0.0.0.0 \
    PORT=3130 \
    DATA_DIR=/data \
    PUBLIC_DIR=/public \
    APNS_KEY_FILE=/secrets/apns.p8
USER app
WORKDIR /data
EXPOSE 3130
VOLUME ["/data", "/public"]
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/usr/local/bin/liveresults-server", "-check"]
ENTRYPOINT ["/usr/local/bin/liveresults-server"]
