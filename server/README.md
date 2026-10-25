# Servidor da apuração ao vivo

Serviço em Go 1.26.10, só com a biblioteca padrão. Lê os arquivos do TSE do 2º turno (presidente e governador de AC, AM, DF, ES, RN e TO), serve o placar em `/api/v1/races` e atualiza as Live Activities por APNs quando os números mudam. O contrato está em `docs/changes/live-results/proposal.md`.

## Variáveis

| Variável | Padrão | Uso |
| --- | --- | --- |
| `HOST` | `127.0.0.1` (`0.0.0.0` no container) | Endereço de escuta |
| `PORT` | `3130` | Porta |
| `DATA_DIR` | `./data` (`/data` no container) | `registrations.json` e `state.json`, pasta `0700`, arquivos `0600` |
| `PUBLIC_DIR` | `./public` (`/public` no container) | Onde o poller grava os arquivos estáticos que o Caddy serve; com `SIMULATE=1` nada é gravado |
| `TSE_BASE_URL` | `https://resultados.tse.jus.br/oficial/ele2026` | Base dos arquivos do TSE; só `https://` (`http://` só com `SIMULATE=1`) |
| `POLL_INTERVAL` | `20s` | Intervalo de leitura do TSE (`20s` ou `20`; de 5 s a 10 min) |
| `SIMULATE` | vazio | `1` troca o TSE por dados sintéticos que andam por ~10 min e terminam com um eleito em cada disputa; os dados simulados ficam só na memória e em `GET /api/v1/races` do Go, nunca em `PUBLIC_DIR` |
| `APNS_KEY_FILE` | vazio (`/secrets/apns.p8` no container) | Chave `.p8` (PKCS#8 PEM) |
| `APNS_KEY_ID` | vazio | Key ID da chave |
| `APNS_TEAM_ID` | vazio | Team ID |
| `APNS_TOPIC` | vazio | Tópico completo, com o sufixo: `com.byescaleira.fiscal.push-type.liveactivity` |
| `APNS_DISABLED` | vazio | `1` sobe sem APNs e só loga o resumo dos pushes (sem token) |
| `ADMIN_TOKEN` | vazio | Liga `POST /api/v1/admin/push-test` (32+ caracteres); vazio, a rota responde 404. Gere na VPS com `openssl rand -hex 32` e guarde só no `.env` |

Sem `APNS_KEY_FILE`, `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC` o servidor não sobe, a menos que `APNS_DISABLED=1`. A chave é carregada e um JWT é assinado no boot.

## Rotas

| Rota | Resposta |
| --- | --- |
| `GET /api/health` | `{"ok":true}` |
| `GET /api/v1/races` | `{"races":[Race],"fetchedAt":"…"}`; `503 not_ready` antes do primeiro dado |
| `GET /api/v1/races/{id}` | `Race`; `404 race_not_found`; `503 not_ready` |
| `POST /api/v1/live-activities` | `{"raceId","pushToken","environment"}` → `204`; `422 invalid_request`, `413 body_too_large`, `409 token_bound_to_other_race`, `429 too_many_registrations`, `429 rate_limited`, `507 capacity_reached` |
| `DELETE /api/v1/live-activities` | corpo `{"pushToken":"<hex>"}` (até 4 KiB) → `204` sempre que o corpo for válido, exista ou não o registro; `422 invalid_request`, `413 body_too_large`, `429 rate_limited` |
| `POST /api/v1/admin/push-test` | `Authorization: Bearer $ADMIN_TOKEN`, `{"raceId"}` → `{"registrations","sent","failed","removed","event"}` |

O token vai no corpo do `DELETE`, nunca na URL: o log do Caddy grava a URI inteira. A rota antiga `DELETE /api/v1/live-activities/{pushToken}` não existe mais (responde `404 not_found`, e o log do Go continua cortando o token em 6 caracteres).

Ids: `presidente-br`, `governador-ac`, `governador-am`, `governador-df`, `governador-es`, `governador-rn`, `governador-to`.

Registros:
- Cada registro guarda `createdAt` e vale 12 h. Registrar de novo o mesmo token renova o prazo. Registros vencidos são ignorados no envio e removidos na varredura que roda junto do flush, a cada 2 s.
- Um token já registrado não troca de `raceId` nem de `environment`: o pedido diferente recebe `409 token_bound_to_other_race` e o original fica.
- No máximo 20 registros vivos por IP de origem (IPv6 agrupado por /64), `429 too_many_registrations` acima disso. O IP só é guardado como SHA-256 truncado com um sal aleatório gerado no boot, em memória; `registrations.json` não leva IP nem hash, e ao reiniciar o teto recomeça.

Rate limit por IP: 120 GET e 120 POST/DELETE por minuto (CGNAT), `429 rate_limited` acima. IPv6 conta por /64. `X-Forwarded-For` (último valor) só é aceito quando a conexão vem de loopback ou de rede privada (gateway do Docker, `10/8`, `172.16/12`, `192.168/16`, `fc00::/7`); de qualquer outro endereço vale o `RemoteAddr`. Quando o mapa de buckets lota (100 000), o mais antigo é descartado.

Arquivos estáticos (`PUBLIC_DIR/v1`): no boot do modo TSE a pasta `v1` é apagada e republicada a partir do `state.json`. A cada leitura, os arquivos das disputas são gravados antes dos pushes e só quando o conteúdo muda; `races.json` só é regravado quando alguma disputa muda, então o `fetchedAt` dele é o da última mudança, e o `ETag`/`304` do Caddy se mantém entre leituras sem novidade.

## Rodar local

```sh
cd server
go build ./... && go vet ./... && go test -race ./...
SIMULATE=1 APNS_DISABLED=1 POLL_INTERVAL=5s go run ./cmd/server
curl -s http://127.0.0.1:3130/api/v1/races
```

Com APNs de verdade, aponte `APNS_KEY_FILE` para a `.p8` e preencha `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC`.

## Deploy

Em `/opt/fiscal-api` na VPS, com o `.env` (`chmod 600`, nomes em `.env.example`), `secrets/apns.p8` e `data/` (dono 1000, pastas `700`, chave `600`). O código sobe com `rsync -a`, **sem `--delete`**, e sem tocar no que só existe na VPS:

```sh
rsync -a --exclude .env --exclude secrets/ --exclude data/ --exclude public/ server/ vps:/opt/fiscal-api/
```

`.env`, `secrets/`, `data/` e `public/` nunca saem da máquina local nem são sobrescritos ou apagados na VPS. O `ADMIN_TOKEN` é gerado na própria VPS e vai só para o `.env`:

```sh
cd /opt/fiscal-api
echo "ADMIN_TOKEN=$(openssl rand -hex 32)" >> .env
chmod 600 .env
docker compose up -d --build
docker compose ps
curl -s http://127.0.0.1:3130/api/health
```

A rota de teste do admin não passa pelo Caddy (ele responde 404 em `/api/v1/admin/*`); use só por SSH, direto no loopback:

```sh
ssh vps 'set -a; . /opt/fiscal-api/.env; curl -s -X POST http://127.0.0.1:3130/api/v1/admin/push-test -H "Authorization: Bearer $ADMIN_TOKEN" -d "{\"raceId\":\"presidente-br\"}"'
```

O Caddy encaminha `/api/*` de `fiscal.byescaleira.com` para `127.0.0.1:3130`. O container tem `pids_limit: 128` e log `json-file` com 3 arquivos de 10 MB.

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

	handle /api/v1/admin/* {
		respond 404
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

O contrato não põe token na URL (o DELETE leva o token no corpo), por isso o log JSON do Caddy não precisa de filtro. Rode `caddy validate --config /etc/caddy/Caddyfile` antes de recarregar.

O `rewrite` roda antes de `uri` no Caddy, por isso os matchers usam o caminho original com `/api`.
