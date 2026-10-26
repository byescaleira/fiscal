FROM node:22.20.0-bookworm-slim
ARG WRANGLER_VERSION=4.149.0
RUN npm install --global --no-fund --no-audit "wrangler@${WRANGLER_VERSION}" \
 && npm cache clean --force \
 && wrangler --version
COPY --chown=1000:1000 bin/fiscal-pages /usr/local/bin/fiscal-pages
ENV DATA_DIR=/data \
    PUBLIC_DIR=/public \
    WRANGLER=/usr/local/bin/wrangler \
    WRANGLER_SEND_METRICS=false
USER 1000:1000
WORKDIR /data
ENTRYPOINT ["/usr/local/bin/fiscal-pages"]
