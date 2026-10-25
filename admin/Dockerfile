FROM node:22.11.0-alpine
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund && npm cache clean --force
COPY src ./src
COPY public ./public
RUN mkdir -p /secrets /data && chown node:node /secrets /data
USER node
ENV NODE_ENV=production HOST=0.0.0.0 PORT=3120 SECRETS_DIR=/secrets DATA_DIR=/data
EXPOSE 3120
CMD ["node", "src/main.mjs"]
