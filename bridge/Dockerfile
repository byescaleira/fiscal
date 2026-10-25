FROM node:22.11.0-alpine
WORKDIR /app
RUN mkdir /data && chown node:node /data
COPY server.mjs ./
USER node
ENV HOST=0.0.0.0 PORT=3110 INTERNAL_HOST=0.0.0.0 INTERNAL_PORT=3111 CONFIG_FILE=/data/config.json
EXPOSE 3110
VOLUME /data
CMD ["node", "--max-old-space-size=640", "server.mjs"]
