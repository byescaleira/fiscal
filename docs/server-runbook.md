# Runbook do servidor

A decisão está no [ADR 0007](adr/0007-pages-cdn-phased-ingest.md); os detalhes de cada processo, em [server/README.md](../server/README.md).

Resumo:

- **Leitura pública.** Vai toda para o Cloudflare Pages (`fiscal-dados`, em `https://dados.fiscal.byescaleira.com/v2/…`), no plano gratuito.
- **A VPS atual é o bastidor.** Nela ficam:
  - a carga em fases (jobs que rodam e saem);
  - o poller da apuração com o APNs;
  - o registro de token com App Attest.
- **Nada aqui roda sozinho.** Deploy, escrita na VPS e deploy real no Pages só com o ok do usuário, pedido a cada vez.

```text
fontes ─▶ fiscal-ingest -phase X (1 núcleo, nice 19, 1,2 GB, mata primeiro)
            │ SQLite ─▶ public/v1 (preparo) ─▶ site/sites/<stamp>  ── valida ──▶ site/ready
            ▼
          fiscal-pages (wrangler, só o que mudou) ─▶ Pages fiscal-dados ─▶ app (milhões)
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
| `INGEST_MEM_LIMIT` / `INGEST_GOMEMLIMIT` | `1200m` / `900MiB` | Teto da fase; suba os dois juntos se o job for morto por memória |
| `INGEST_MAX_LOAD` / `INGEST_MIN_AVAILABLE_MB` | `2` / `1536` | Guarda de carga: acima do load ou abaixo da memória livre, a fase espera e pula |
| `PAGES_DATA_INTERVAL` | `1h` | Intervalo mínimo entre deploys da atualização ao vivo (as fases publicam logo) |
| `PAGES_MAX_DEPLOYS_PER_DAY` | `400` | Teto diário de deploys |

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
   - Instala as units, remove o container antigo de longa duração `fiscal-ingest` e liga os timers das fases e o da atualização ao vivo.
   - O `fiscal-pages.timer` fica **desligado**.

Para voltar uma imagem à mão, rode `docker tag fiscal-<api|ingest|pages>:previous fiscal-<…>:current`. No caso da API, rode também `docker compose up -d --no-deps fiscal-api`.

Leitura e escrita pública não passam pela VPS, então a troca da API afeta por segundos só o registro de token, e o app tenta de novo.

## 4. Primeiro deploy de dados (o coordenador faz)

```sh
cd /opt/fiscal-api
docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -phase memoria
docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site status
docker compose --profile jobs run --rm --no-deps -T fiscal-pages -dry-run
docker compose --profile jobs run --rm --no-deps -T fiscal-pages
curl -sI https://dados.fiscal.byescaleira.com/v2/release.json
```

Cada comando:

1. **`-phase memoria`** reconstrói o site a partir do banco atual, sem ler fonte nenhuma, e valida.
2. **`-site status`** mostra a release pronta, o número de arquivos (meta ≤ 15.000; falha acima de 18.000) e as pessoas.
3. **`fiscal-pages -dry-run`** monta a pasta do deploy e diz quantos arquivos iriam, sem enviar.
4. **`fiscal-pages`** faz o deploy real.
5. **O `curl`** confere o resultado: o app só passa a usar o Pages quando `v2/release.json` responde com `"layout":"v2"`.

## 5. Calendário das fases (hora de Brasília)

| Quando | Job | O que lê |
| --- | --- | --- |
| Todo dia 01:10 | `fiscal-phase@senado` | Senado: senadores, votos, propostas, discursos, CEAPS |
| Todo dia 02:00 | `fiscal-phase@assembleias` | SAPL de AC, AM, PB, PI e RO |
| Todo dia 02:40 | `fiscal-phase@checagens` | Projeto Comprova |
| Todo dia 03:20 | `fiscal-phase@indicadores` | ANP e SIDRA (IPCA) |
| Todo dia 04:00 | `fiscal-phase@repercussao` | GDELT e Wikipédia (só contagens) |
| Todo dia 05:00 | `fiscal-phase@camara` | Câmara, depois que ela regera os arquivos anuais (00h–04h) |
| Sábado 00:20 | `fiscal-phase@cidades` | IBGE e prefeitos, vices e vereadores |
| Domingo 00:20 | `fiscal-phase@tse` | Candidaturas, bens, votos e contas das eleições gerais |
| Segunda 00:20 | `fiscal-phase@receita` | Arrecadação federal |
| Quarta 00:20 | `fiscal-phase@memoria` | Nada: reconstrói o site a partir do banco |
| A cada 10 min, 07:00–23:50 | `fiscal-live` | Pauta e votações de hoje (snapshot da última fase) |
| Só em dia de eleição | `fiscal-pages.timer` (a cada 60 s) | Publica os arquivos da apuração quando mudam |

Regras dos jobs:

- **Atraso aleatório.** Cada timer tem até 5 min de atraso aleatório.
- **Lock global.** Uma fase que encontra outra rodando espera até 20 min e desiste com código 75 (tenta na próxima janela). A atualização ao vivo pula na hora.
- **Guarda de carga.** Com load acima de 2 ou menos de 1,5 GB livres, a fase espera até 20 min e pula.
- **Deploy em série.** Ao terminar, cada fase chama o `fiscal-pages`, que faz o deploy só do que mudou, um deploy por vez e com 3 tentativas.

## 6. Operação

- **Situação:**
  - `systemctl list-timers 'fiscal-*'`;
  - `journalctl -u 'fiscal-phase@*' --since today`;
  - `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site status`.
- **Pausar tudo:** `systemctl stop 'fiscal-phase-*.timer' fiscal-live.timer`. Para voltar, use `start`.
- **Voltar os dados publicados:**
  1. **Na hora:** painel do Pages › `fiscal-dados` › Deployments › o deploy bom › **Rollback**.
  2. **Para o próximo deploy não trazer a release ruim de volta:** `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site rollback`, que aponta `ready` para a release anterior (ou `-to <nome>`).
  3. **Pausar os timers** até corrigir a fonte.
- **Queda de volume legítima** (troca de legislatura, por exemplo): rode a fase uma vez com `-allow-drop`.
- **Job morto por memória** (`journalctl` mostra `OOMKilled` ou código 137):
  - o site no ar não muda;
  - suba `INGEST_MEM_LIMIT` e `INGEST_GOMEMLIMIT` no `.env` (por exemplo, `1600m` e `1200MiB`) e rode a fase de novo.
- **Dia de eleição:**
  1. Ligue o timer: `systemctl enable --now fiscal-pages.timer`.
  2. Confira se `v2/races.json` muda a cada minuto.
  3. Depois do resultado final, desligue com `systemctl disable --now fiscal-pages.timer`.
- **Limite de deploys do Pages:**
  - **Conferir.** No primeiro dia, confira em Workers & Pages › `fiscal-dados` › Deployments se os deploys diretos aparecem contados no uso de builds do mês (Account Home › Workers & Pages › Plans).
  - **Se contarem** (500 por mês no Free):
    - `PAGES_DATA_INTERVAL=4h`;
    - `PAGES_MAX_DEPLOYS_PER_DAY=15`;
    - na apuração, `PAGES_MAX_DEPLOYS_PER_DAY` alto só no dia.
  - **Saída para a apuração:** o app cai para `https://fiscal.byescaleira.com/api/v1/races`, servido pelo Caddy direto do disco.

## 7. Caddy

O bloco `fiscal.byescaleira.com` continua igual:

- `@races`, para builds antigos e como reserva da apuração;
- `@data`, para o layout `v1`;
- `/api/*`, encaminhado para o Go, inclusive `POST /api/v1/attest/challenge`, `POST /api/v1/attest/keys` e os registros.

Quando todas as versões no ar lerem o Pages, `@data` pode sair, e a VPS deixa de servir dado público de vez. Rode `caddy validate` antes de recarregar.

## 8. App Attest

- **No app.** O `LiveResultsClient` pede um desafio (`POST /api/v1/attest/challenge`). Na primeira vez, gera e atesta a chave (`POST /api/v1/attest/keys`). A cada registro, manda a asserção do corpo exato nos cabeçalhos `X-Fiscal-Attest-Key` e `X-Fiscal-Attest-Assertion`, com o desafio no corpo.
- **Sem suporte ou com o servidor antigo.** O aparelho sem suporte e o servidor antigo, que responde 404 no desafio, caem para o registro sem asserção. No modo `optional`, ele tem limite de 10 por minuto por IP.
- **No servidor.** As chaves ficam em `DATA_DIR/attest-keys.json`, sem IP. Uma chave sem uso por 400 dias sai. A resposta `attest_unknown_key` faz o app atestar de novo.
- **Pendência.** Falta o entitlement `com.apple.developer.devicecheck.appattest-environment = production` nos builds de distribuição (TestFlight e App Store já usam produção); builds do Xcode usam `development`.
