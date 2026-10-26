FROM gcr.io/distroless/static-debian12:nonroot
COPY --chown=1000:1000 bin/fiscal-ingest /usr/local/bin/fiscal-ingest
ENV DATA_DIR=/data \
    PUBLIC_DIR=/public
USER 1000:1000
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/fiscal-ingest"]
