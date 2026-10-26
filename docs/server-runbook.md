# Runbook do servidor

As decisões estão no [ADR 0007](adr/0007-pages-cdn-phased-ingest.md) (Pages, layout `v2`, validação, App Attest) e no [ADR 0008](adr/0008-smart-sync.md) (cadência por fonte, detecção de mudança, reconstrução incremental e orçamento de deploys); os detalhes de cada processo, em [server/README.md](../server/README.md).

Resumo:

- **Leitura pública.** Vai toda para o Cloudflare Pages (`fiscal-dados`, em `https://dados.fiscal.byescaleira.com/v2/…`), no plano gratuito.
- **A VPS atual é o bastidor.** Nela ficam:
  - a sincronização por cadência (um tique a cada 5 min que roda só o que está devido e sai);
  - o poller da apuração com o APNs;
  - o registro de token com App Attest.
- **Nada aqui roda sozinho.** Deploy, escrita na VPS e deploy real no Pages só com o ok do usuário, pedido a cada vez.

```text
fiscal-sync.timer (5 min) ─▶ fiscal-ingest -sync: catálogo ─▶ sonda ─▶ só a fonte que mudou
            │ SQLite/snapshot ─▶ public/v1 (preparo, manifesto de hashes) ─▶ site/sites/<stamp> (delta + links físicos) ── valida ──▶ site/ready
            ▼
          fiscal-pages (orçamento mensal, wrangler só o que mudou) ─▶ Pages fiscal-dados ─▶ app (milhões)
          quente (today, agenda, votes/recent) ─▶ public/v1 ─▶ Caddy api/v1 (max-age 30) ─▶ app lê primeiro
fiscal-api (TSE + APNs + registro com App Attest) ─▶ public/v1/races*.json ─┘
```

## 1. O que o usuário faz na Cloudflare (uma vez)

O projeto `fiscal-dados` e o domínio `dados.fiscal.byescaleira.com` já existem. O DNS de `byescaleira.com` continua na Vercel, com o CNAME `dados.fiscal` apontando para `fiscal-dados.pages.dev`.

1. **Conferir o domínio.** Em Workers & Pages › `fiscal-dados` › Custom domains, `dados.fiscal.byescaleira.com` precisa aparecer como **Active**. Se aparecer como pendente, confira na Vercel o CNAME `dados.fiscal` → `fiscal-dados.pages.dev`, sem proxy nem redirecionamento.
2. **Guardar o Account ID.** Fica em Workers & Pages › painel da direita, "Account ID": são 32 caracteres hexadecimais.
3. **Criar o token da API.** Em My Profile › API Tokens › Create Token › Custom token:
   - **Nome:** `fiscal-pages-deploy`.
   - **Permissão:** Account · **Cloudflare Pages** · **Edit**. A Cloudflare não restringe essa permissão a um projeto: ela vale para os projetos Pages da conta.
   - **Account Resources:** Include · só a sua conta.
   - **Client IP Address Filtering:** Allow · `179.198.114.91` e `2a02:4780:6e:6fea::/64` (só a VPS usa o token). A VPS sai para a internet pelo IPv6; só com o IPv4 a API do Pages responde `Authentication error` (10000), embora `/user/tokens/verify` diga que o token está ativo.
   - **TTL:** sem data, ou um ano com lembrete.
   - **O token aparece uma vez só.** Não cole no chat nem no repositório.
4. **Painel do projeto Pages:**
   - **Settings › Builds:** sem integração Git (o projeto é só de Direct Upload).
   - **Settings › Functions:** sem nada. O Fiscal não usa Functions, então nada é cobrado por requisição.
5. **Proteção no plano grátis.** Os arquivos estáticos do Pages não têm limite de requisições e já passam pela proteção contra DDoS da Cloudflare. Regras de WAF e de rate limit exigem a zona do domínio na Cloudflare, o que não é o caso. A VPS só recebe o `POST` do registro, que tem limite por IP no Go e App Attest.

## 2. O que o usuário faz na VPS (uma vez, com o ok dele)

Guardar o token sem passar pelo chat. O jeito que funcionou: deixar o comando abaixo digitado no terminal do Mac, clicar no botão de copiar do token na Cloudflare e só então apertar Enter (copiar o próprio comando troca o conteúdo da área de transferência):

```sh
pbpaste | tr -d ' \r\n' | ssh root@179.198.114.91 'cat > /opt/fiscal-api/secrets/cloudflare-pages-token && chmod 600 /opt/fiscal-api/secrets/cloudflare-pages-token && wc -c < /opt/fiscal-api/secrets/cloudflare-pages-token'
```

Alternativa dentro da VPS (o `read -rs` pode não receber colagem em alguns terminais):

```sh
ssh root@179.198.114.91
cd /opt/fiscal-api
install -m 600 -o 1000 -g 1000 /dev/null secrets/cloudflare-pages-token
read -rs TOKEN && printf '%s' "$TOKEN" > secrets/cloudflare-pages-token && unset TOKEN
echo "CLOUDFLARE_ACCOUNT_ID=<o Account ID>" >> .env && chmod 600 .env
mkdir -p pages-data && chown 1000:1000 pages-data && chmod 700 pages-data
```

O `APPATTEST_APP_ID` não precisa entrar no `.env`: ele sai de `APNS_TEAM_ID` + `APNS_TOPIC` sem o sufixo, ou seja, `TEAMID.com.byescaleira.fiscal`. Opcionais:

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `APPATTEST_MODE` | `optional` | `required` depois que todas as versões no ar tiverem App Attest; `off` desliga |
| `APPATTEST_ALLOW_DEVELOPMENT` | `0` | `1` aceita o ambiente de desenvolvimento (builds do Xcode) |
| `INGEST_MEM_LIMIT` / `INGEST_GOMEMLIMIT` | `1200m` / `900MiB` | Teto da fase; suba os dois juntos se o job for morto por memória. Na VPS atual (4 vCPU e 16 GB) ficou `8192m` / `7GiB`, com `INGEST_CPUS=3`, `INGEST_WORKERS=8` e `INGEST_REQUEST_GAP=150ms` (26/10, o usuário liberou os limites depois do upgrade). Com 1,2 GB e com 2 GB a montagem completa do site foi morta (137) |
| `INGEST_MAX_LOAD` / `INGEST_MIN_AVAILABLE_MB` | `2` / `1536` | Guarda de carga: acima do load ou abaixo da memória livre, a fase espera e pula. Na VPS atual (4 vCPU e 16 GB desde 26/10) ficou `INGEST_MAX_LOAD=6` |
| `PAGES_DATA_INTERVAL` | `1h` | Intervalo mínimo entre deploys de releases quentes (`hot`, `destaques`) |
| `PAGES_MAX_DEPLOYS_PER_DAY` | `400` | Teto diário de deploys |
| `PAGES_MAX_DEPLOYS_PER_MONTH` | `450` | Teto mensal de deploys; as releases de rotina se espalham pelo que resta do mês (seção 6) |
| `HOT_FROM_ORIGIN` | `1` | `release.json` manda o app ler o quente primeiro na VPS; `0` devolve tudo ao Pages |

## 3. Deploy das imagens (com o ok do usuário a cada vez)

```sh
scripts/server-deploy.sh                      # só imprime o plano
scripts/server-deploy.sh --apply              # api, ingest, pages e units
scripts/server-deploy.sh --apply --only api   # só a API, com volta automática
```

O que o script faz:

1. **Compila no Mac** (`GOOS=linux GOARCH=amd64`) os três binários.
2. **Envia** binários, Dockerfiles, `compose.yaml` e units para `/opt/fiscal-api/builds/<sha>`. Não toca em `.env`, `secrets/`, `data/`, `ingest-data/` nem `public/`.
3. **Monta as imagens na VPS** com `nice -n 19 ionice -c3`. Só há `COPY`, sem compilação. A imagem `fiscal-pages` instala o `wrangler@4.149.0` na primeira vez.
4. **Promove `:current`**, guardando a anterior em `:previous`. A API troca com `docker compose up -d --no-deps fiscal-api`. Se não ficar `healthy` em 90 s, o script volta sozinho para `:previous`.
5. **Units.**
   - Instala as units, remove o container antigo de longa duração `fiscal-ingest`, desliga e apaga os timers antigos (`fiscal-phase-*.timer`, `fiscal-live.*`) e liga o `fiscal-sync.timer`.
   - O `fiscal-pages.timer` fica **desligado**.

Para voltar uma imagem à mão, rode `docker tag fiscal-<api|ingest|pages>:previous fiscal-<…>:current`. No caso da API, rode também `docker compose up -d --no-deps fiscal-api`.

Leitura e escrita pública não passam pela VPS, então a troca da API afeta por segundos só o registro de token, e o app tenta de novo.

## 4. Primeiro deploy de dados (o coordenador faz)

```sh
cd /opt/fiscal-api
docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -job memoria
docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site status
docker compose --profile jobs run --rm --no-deps -T fiscal-pages -dry-run
docker compose --profile jobs run --rm --no-deps -T fiscal-pages
curl -sI https://dados.fiscal.byescaleira.com/v2/release.json
```

Cada comando:

1. **`-job memoria`** reconstrói o site a partir do banco atual, sem ler fonte nenhuma, valida e compara com o caminho incremental.
2. **`-site status`** mostra a release pronta, o número de arquivos (meta ≤ 15.000; falha acima de 18.000) e as pessoas.
3. **`fiscal-pages -dry-run`** monta a pasta do deploy e diz quantos arquivos iriam, sem enviar.
4. **`fiscal-pages`** faz o deploy real.
5. **O `curl`** confere o resultado: o app só passa a usar o Pages quando `v2/release.json` responde com `"layout":"v2"`.

## 5. Cadência por fonte

A sincronização segue o catálogo versionado em `server/internal/ingest/cadence.go` ([ADR 0008](adr/0008-smart-sync.md)). O `fiscal-sync.timer` dispara `fiscal-ingest -sync` a cada 5 min, e o catálogo decide o que roda. Cada trabalho só reconstrói a sua parte, e o resto vem da release anterior por link físico.

Horários em Brasília.

| Trabalho | O que lê | Quando | Sonda antes de baixar | Por quê |
| --- | --- | --- | --- | --- |
| `hot` | pauta e votações de hoje (Câmara e Senado) | a cada 5 min, seg–sex das 9h à 0h; senão de hora em hora | a própria leitura: impressão digital da pauta e das votações | O Plenário pauta e vota em dias úteis; fora disso a pauta quase não muda |
| `destaques` | perfis, votos por pessoa, fatos, destaques e peso (do snapshot) | no máximo a cada 20 min, só com votação nova | — | Acompanha a sessão sem refazer perfis a cada 5 min |
| `checagens` | Projeto Comprova | a cada 45 min, das 7h à 0h | a última publicação alterada (1 consulta) | Poucas checagens por dia, em horário comercial |
| `senado` | senadores, votos, propostas, discursos e CEAPS | todo dia 01:10 | nenhuma (API sem validador) | Presença, cota e discursos mudam no máximo uma vez por dia |
| `assembleias` | SAPL de AC, AM, PB, PI e RO | todo dia 02:00 | nenhuma | Matérias entram em dias úteis |
| `anp` | preços médios de combustíveis | segunda 03:20 | `HEAD` das 4 planilhas | Série mensal, sem data fixa |
| `sidra` | IPCA e rendimento | todo dia 03:30 | o último período da tabela 1737 | O IPCA sai uma vez por mês, perto do dia 10, no calendário do IBGE |
| `receita` | arrecadação por estado | segunda 03:40 | `HEAD`; sem validador, o hash do CSV | Publicada uma vez por mês, sem dia fixo |
| `camara` | deputados, votos, presença, propostas, discursos e CEAP | todo dia 05:00 | nenhuma: a Câmara regera os arquivos anuais toda noite e o `Last-Modified` muda sem conteúdo novo | Leitura diária depois da regeração (0h–4h) |
| `tse` | candidaturas, bens, votos e contas das eleições gerais | domingo 00:20 | `HEAD` dos ZIPs (`ETag` e tamanho) | Só muda quando o TSE republica |
| `cidades` | municípios do IBGE, prefeitos, vices e vereadores | sábado 00:20 | `HEAD` dos ZIPs de 2024 e hash da lista do IBGE | Só reconstrói os ~75 mil arquivos de cidades quando a fonte muda |
| `historia` | Memória (eleições de 1989 a 2022 e indicadores) | dia 1º, 03:50 | `HEAD` dos ZIPs e versão do conteúdo curado | Resultados fechados; o conteúdo muda com o deploy |
| `repercussao` | contagens do GDELT e da Wikipédia | a cada 6 h | nenhuma | Janelas de 30 dias e cota do GDELT |
| `memoria` | nada: reconstrução completa do banco e verificação | quarta 00:20 | — | Compara o incremental com o completo; divergência vira alerta |
| `apuracao` | TSE ao vivo (poller do `fiscal-api`, 20 s) | só em dia de eleição | — | `fiscal-pages.timer` ligado à mão (seção 6) |

Regras:

- **Sonda sem mudança.** A fonte não é lida e nada é reconstruído. Cada trabalho com sonda tem uma idade máxima (35 a 180 dias) depois da qual lê mesmo assim.
- **Sonda que falha** (rede) não bloqueia: o trabalho roda.
- **Horário perdido.** Um trabalho diário ou semanal que não rodou (VPS fora, lock ocupado, carga alta) roda no próximo tique. Se falhou, tenta de novo depois de 30 min.
- **Primeira execução.** Sem `sync-state.json`, o catálogo assume os dados de hoje em dia e roda só o `hot`.
- **Lock global.** Um tique que encontra outro rodando sai na hora e tenta no próximo.
- **Guarda de carga.** Antes de cada trabalho pesado (fontes, `destaques`, `memoria`), sem espera: com load acima de `INGEST_MAX_LOAD`, o trabalho fica para o próximo tique. O `hot` não espera.
- **Sobreposição.** `checagens`, `anp`, `sidra`, `receita`, `repercussao`, `cidades` e `historia` reaproveitam o snapshot e trocam só a sua parte. `camara`, `senado`, `assembleias` e `tse` restauram o resto do banco, mas mantêm cidades e Memória como estão.
- **Deploy.** Depois de cada tique, o `fiscal-pages` publica dentro do orçamento mensal (seção 6).

## 6. Operação

- **Situação:**
  - `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -plan` lista cada trabalho, se está devido e por quê, a cadência, a última execução, o resultado e o erro;
  - `systemctl list-timers 'fiscal-*'`;
  - `journalctl -u fiscal-sync --since today` mostra uma linha `job <nome>: <resultado> (changed=N, release=…)` por trabalho;
  - `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site status`.
- **Forçar uma fonte agora** (ignora cadência e sonda):
  - `systemctl start fiscal-phase@camara`, que roda o trabalho e depois o `fiscal-pages`;
  - ou `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -job camara`;
  - para publicar sem esperar o orçamento, rode em seguida `fiscal-pages -force`.
- **Ver o que mudou:**
  - o `job …` do log traz quantos arquivos mudaram e a release;
  - `release.json` traz `base` (a release anterior) e `rebuilt` (pacotes refeitos);
  - `ingest-data/v1-manifest.json` › `pending` lista o que ainda não foi publicado;
  - `ingest-data/sync-state.json` guarda, por trabalho, a última execução, a impressão digital da sonda e o resultado.
- **Alerta de consistência** (`ALERT consistency` no log, `fiscal-sync.service` em falha com código 3):
  - **Na hora:** nada a fazer, porque a release completa já está pronta e sai no próximo tique.
  - **Depois:** abrir `ingest-data/consistency.json` (`sample` lista os primeiros arquivos que divergiram), achar a causa no caminho incremental e corrigir.
- **Pausar tudo:** `systemctl stop fiscal-sync.timer`. Para voltar, use `start`.
- **Voltar os dados publicados:**
  1. **Na hora:** painel do Pages › `fiscal-dados` › Deployments › o deploy bom › **Rollback**.
  2. **Para o próximo deploy não trazer a release ruim de volta:** `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site rollback` (ou `-to <nome>`). Releases por delta usam links físicos, e voltar não copia nada.
  3. **Pausar o timer** até corrigir a fonte.
- **Queda de volume legítima** (troca de legislatura, por exemplo): `-job camara -allow-drop` uma vez.
- **Job morto por memória** (`journalctl` mostra `OOMKilled` ou código 137):
  - o site no ar não muda;
  - suba `INGEST_MEM_LIMIT` e `INGEST_GOMEMLIMIT` no `.env` e force o trabalho de novo.
- **Dia de eleição:**
  1. Ligue o timer: `systemctl enable --now fiscal-pages.timer`. Mudança na apuração sai na hora e conta no orçamento.
  2. Suba `PAGES_MAX_DEPLOYS_PER_MONTH` só se o painel mostrar que o Direct Upload não conta no limite. Senão, a apuração segue pela origem (`api/v1/races`).
  3. Depois do resultado final, desligue com `systemctl disable --now fiscal-pages.timer`.
- **Limite de deploys do Pages:**
  - **O que a Cloudflare diz** (conferido em 26/10/2026):
    - a [página de limites](https://developers.cloudflare.com/pages/platform/limits/) dá 500 builds por mês no Free e descreve o build pelo push no Git;
    - a do [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) não fala de cota;
    - os dois limitam a 20.000 arquivos e 25 MiB por arquivo.
    - **Não está confirmado se o `wrangler pages deploy` conta.**
  - **O que o Fiscal faz.** `PAGES_MAX_DEPLOYS_PER_MONTH=450` é teto duro. As releases de rotina esperam `tempo até o fim do mês ÷ deploys restantes`, cerca de 96 min no começo do mês. As quentes esperam também `PAGES_DATA_INTERVAL`. `full`, `memoria`, rollback, `-force` e mudança na apuração saem na hora.
  - **Conferir.** Em Account Home › Workers & Pages › Plans, veja se o uso de builds do mês acompanha os deploys diretos.
  - **Se não contar:** `PAGES_MAX_DEPLOYS_PER_MONTH=9000`, `PAGES_DATA_INTERVAL=10m` e, se quiser tudo pelo Pages, `HOT_FROM_ORIGIN=0`.
  - **O quente não depende do Pages.** `today.json`, `agenda/today.json`, `votes/recent.json` e as votações de hoje ficam no `v1` da VPS assim que mudam. O `release.json` diz ao app que leia esses arquivos primeiro na origem (`origin.first`) e que busque lá uma votação que o Pages ainda não tem (`origin.onMissing`).

## 7. Caddy

O bloco `fiscal.byescaleira.com` ganha o `@hot`, antes do `@data`, com cache curto:

```
	@hot {
		method GET HEAD
		path_regexp hot ^/api/v1/(today|agenda/today|votes/recent)\.json$
	}
	handle @hot {
		root * /opt/fiscal-api/public
		rewrite * /v1/{re.hot.1}.json
		header Cache-Control "public, max-age=30, stale-while-revalidate=60"
		file_server {
			precompressed gzip
		}
	}
```

O resto fica como está:

- `@races`, para builds antigos e como reserva da apuração;
- `@data`, para o layout `v1`, as votações de hoje e a reserva geral;
- `/api/*`, encaminhado para o Go, inclusive `POST /api/v1/attest/challenge`, `POST /api/v1/attest/keys` e os registros.

Rode `caddy validate` antes de recarregar. Se a carga do Caddy pesar em pico, `HOT_FROM_ORIGIN=0` no `.env` devolve o quente ao Pages no próximo deploy, sem versão nova do app.

## 8. App Attest

- **No app.** O `LiveResultsClient` pede um desafio (`POST /api/v1/attest/challenge`). Na primeira vez, gera e atesta a chave (`POST /api/v1/attest/keys`). A cada registro, manda a asserção do corpo exato nos cabeçalhos `X-Fiscal-Attest-Key` e `X-Fiscal-Attest-Assertion`, com o desafio no corpo.
- **Sem suporte ou com o servidor antigo.** O aparelho sem suporte e o servidor antigo, que responde 404 no desafio, caem para o registro sem asserção. No modo `optional`, ele tem limite de 10 por minuto por IP.
- **No servidor.** As chaves ficam em `DATA_DIR/attest-keys.json`, sem IP. Uma chave sem uso por 400 dias sai. A resposta `attest_unknown_key` faz o app atestar de novo.
- **Pendência.** Falta o entitlement `com.apple.developer.devicecheck.appattest-environment = production` nos builds de distribuição (TestFlight e App Store já usam produção); builds do Xcode usam `development`.
