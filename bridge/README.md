# Fiscal Web bridge

Serviço mínimo que guarda, por até 24 horas, o resumo **cifrado** que o app envia para o Fiscal na Web (`docs/web.md`). Ele não consegue ler o conteúdo: só guarda o pacote, confere o dono (hash do `ownerToken`) e entrega ao navegador.

- Código: `server.mjs` (Node 22, sem dependências). Testes: `node --test server.test.mjs`.
- Produção: VPS em `/opt/fiscal-bridge`, `docker compose up -d --build`, ouvindo só em `127.0.0.1:3110`, publicado pelo Caddy em `https://fiscal.byescaleira.com/bridge/` (bloco do site, `handle /bridge/*`). O `Cache-Control` do site é condicional (`?Cache-Control`) para não sobrescrever o `no-store` da ponte.
- Atualizar: copiar `server.mjs`, `Dockerfile` e `compose.yaml` para `/opt/fiscal-bridge` e rodar `docker compose up -d --build`. As sessões ficam em memória: reiniciar apaga as sessões, e o app reenvia no próximo ciclo.

## Ajustes sem reiniciar

| Campo | Padrão | Faz |
| --- | --- | --- |
| `enabled` | `true` | `false` pausa: `PUT`, `GET` e `DELETE` respondem `503 {"error":"paused"}` com `Retry-After: 60`; `/bridge/health` continua `200` com `"paused": true`. |
| `maxSnapshots` | `5000` | Acima disso, sessões novas recebem `503 {"error":"full"}`. |
| `readPerMinute` | `120` | `GET` por IP por minuto. |
| `writePerMinute` | `60` | `PUT` e `DELETE` por IP por minuto. |
| `maxBody` | `1048576` | Bytes por pacote (`413` acima). |
| `ttlHours` | `24` | Validade (até 24), aplicada também às sessões já guardadas. |

A configuração fica em `/data/config.json` (volume `data`) e volta depois de reiniciar.

## Porta de controle

- `0.0.0.0:3111` **dentro** do container, só na rede Docker `fiscal-control` (alias `fiscal-bridge`); não é publicada no host nem no Caddy.
- Sobe só com `BRIDGE_ADMIN_TOKEN` (32+ caracteres) no `/opt/fiscal-bridge/.env` (chmod 600). Toda chamada usa `Authorization: Bearer <token>`.
- `GET /internal/stats`: sessões guardadas, bytes aproximados, contadores por minuto da última hora (`reads`, `writes`, `deletes`, `notFound`, `rateLimited`, `unavailable`), totais, memória, tempo no ar e configuração.
- `GET /internal/config` e `PUT /internal/config` (JSON parcial; `400 {"error":"invalid_value","field":…}` se algo estiver fora do limite).

Ver de dentro da VPS:

```bash
cd /opt/fiscal-bridge && set -a && . ./.env && set +a
docker compose exec bridge wget -qO- --header "Authorization: Bearer $BRIDGE_ADMIN_TOKEN" http://127.0.0.1:3111/internal/stats
```
