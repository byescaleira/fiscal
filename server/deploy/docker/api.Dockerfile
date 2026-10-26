FROM gcr.io/distroless/static-debian12:nonroot
COPY --chown=1000:1000 bin/liveresults-server /usr/local/bin/liveresults-server
ENV HOST=0.0.0.0 \
    PORT=3130 \
    DATA_DIR=/data \
    PUBLIC_DIR=/public \
    APNS_KEY_FILE=/secrets/apns.p8
USER 1000:1000
WORKDIR /data
EXPOSE 3130
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD ["/usr/local/bin/liveresults-server", "-check"]
ENTRYPOINT ["/usr/local/bin/liveresults-server"]
