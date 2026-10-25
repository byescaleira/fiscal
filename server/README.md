# Servidor da apuração ao vivo

Serviço em Go 1.26.5, só com a biblioteca padrão. Lê os arquivos do TSE do 2º turno (presidente e governador de AC, AM, DF, ES, RN e TO), serve o placar em `/api/v1/races` e atualiza as Live Activities por APNs quando os números mudam. O contrato está em `docs/changes/live-results/proposal.md`.

## Variáveis

| Variável | Padrão | Uso |
| --- | --- | --- |
| `HOST` | `127.0.0.1` (`0.0.0.0` no container) | Endereço de escuta |
| `PORT` | `3130` | Porta |
| `DATA_DIR` | `./data` (`/data` no container) | `registrations.json` e `state.json`, pasta `0700`, arquivos `0600` |
| `TSE_BASE_URL` | `https://resultados.tse.jus.br/oficial/ele2026` | Base dos arquivos do TSE |
| `POLL_INTERVAL` | `20s` | Intervalo de leitura do TSE (`20s` ou `20`; de 5 s a 10 min) |
| `SIMULATE` | vazio | `1` troca o TSE por dados sintéticos que andam por ~10 min e terminam com um eleito em cada disputa |
| `APNS_KEY_FILE` | vazio (`/secrets/apns.p8` no container) | Chave `.p8` (PKCS#8 PEM) |
| `APNS_KEY_ID` | vazio | Key ID da chave |
| `APNS_TEAM_ID` | vazio | Team ID |
| `APNS_TOPIC` | vazio | Tópico completo, com o sufixo: `com.byescaleira.fiscal.push-type.liveactivity` |
| `APNS_DISABLED` | vazio | `1` sobe sem APNs e só loga o resumo dos pushes (sem token) |
| `ADMIN_TOKEN` | vazio | Liga `POST /api/v1/admin/push-test` (32+ caracteres); vazio, a rota responde 404 |

Sem `APNS_KEY_FILE`, `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC` o servidor não sobe, a menos que `APNS_DISABLED=1`. A chave é carregada e um JWT é assinado no boot.

## Rotas

| Rota | Resposta |
| --- | --- |
| `GET /api/health` | `{"ok":true}` |
| `GET /api/v1/races` | `{"races":[Race],"fetchedAt":"…"}`; `503 not_ready` antes do primeiro dado |
| `GET /api/v1/races/{id}` | `Race`; `404 race_not_found`; `503 not_ready` |
| `POST /api/v1/live-activities` | `{"raceId","pushToken","environment"}` → `204`; `422 invalid_request`, `413 body_too_large`, `507 capacity_reached` |
| `DELETE /api/v1/live-activities/{pushToken}` | `204` |
| `POST /api/v1/admin/push-test` | `Authorization: Bearer $ADMIN_TOKEN`, `{"raceId"}` → `{"registrations","sent","failed","removed","event"}` |

Ids: `presidente-br`, `governador-ac`, `governador-am`, `governador-df`, `governador-es`, `governador-rn`, `governador-to`. Rate limit por IP (último `X-Forwarded-For`): 120 GET e 30 POST/DELETE por minuto, `429` acima.

## Rodar local

```sh
cd server
go build ./... && go vet ./... && go test -race ./...
SIMULATE=1 APNS_DISABLED=1 POLL_INTERVAL=5s go run ./cmd/server
curl -s http://127.0.0.1:3130/api/v1/races
```

Com APNs de verdade, aponte `APNS_KEY_FILE` para a `.p8` e preencha `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC`.

## Deploy

Em `/opt/fiscal-api` na VPS, com o conteúdo desta pasta, o `.env` (`chmod 600`, nomes em `.env.example`), `secrets/apns.p8` e `data/` (dono 1000, pastas `700`, chave `600`):

```sh
cd /opt/fiscal-api
docker compose up -d --build
docker compose ps
curl -s http://127.0.0.1:3130/api/health
```

O Caddy encaminha `/api/*` de `fiscal.byescaleira.com` para `127.0.0.1:3130`.

## Caddy (no ar desde 2026-10-25)

Leitura sai do disco, sem passar pelo Go ([ADR 0002](../docs/adr/0002-static-first-server.md)): o poller grava `public/v1/races.json` e `public/v1/races/<id>.json` (com `.gz`), e o Caddy entrega com `ETag`, `304` e gzip pré-comprimido. Só o registro de tokens chega ao Go.

```
fiscal.byescaleira.com {
	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		-Server
	}

	@races path /api/v1/races /api/v1/races/*
	handle @races {
		root * /opt/fiscal-api/public
		@list path /api/v1/races
		rewrite @list /v1/races.json
		@one path_regexp one ^/api/v1/races/([a-z]+-[a-z]{2})$
		rewrite @one /v1/races/{re.one.1}.json
		header Cache-Control "public, max-age=10, stale-while-revalidate=30"
		file_server {
			precompressed gzip
		}
	}

	handle /api/* {
		encode zstd gzip
		reverse_proxy 127.0.0.1:3130
	}

	handle {
		respond 404
	}

	log {
		output file /var/log/fiscal-access.log {
			roll_size 100mb
			roll_keep 10
		}
		format json
	}
}
```

O `rewrite` roda antes de `uri` no Caddy, por isso os matchers usam o caminho original com `/api`.
