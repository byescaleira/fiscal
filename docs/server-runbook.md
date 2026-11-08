# Runbook do servidor

As decisões estão no [ADR 0007](adr/0007-pages-cdn-phased-ingest.md) (Pages, layout `v2`, validação), no [ADR 0008](adr/0008-smart-sync.md) (cadência por fonte, detecção de mudança, reconstrução incremental e orçamento de deploys) e no [ADR 0028](adr/0028-app-reads-only-from-cdn-and-local-alerts.md) (o app só lê a CDN, e a VPS só a alimenta); os detalhes de cada processo, em [server/README.md](../server/README.md).

Resumo:

- **Leitura pública.** Vai toda para o Cloudflare Pages (`fiscal-dados`, em `https://dados.fiscal.byescaleira.com/v2/…`), no plano gratuito.
- **A VPS atual só alimenta a CDN.** Nela ficam:
  - a sincronização por cadência (um tique a cada 5 min que roda só o que está devido e sai);
  - o poller da apuração, que lê o TSE e grava `races.json`;
  - a publicação no Pages.
- **O app não chama a VPS.** Não há push, App Attest, registro de token nem rota pública `/api/v1`. No código, isso vale desde `ba5e576` (FSC-020); na VPS, vale depois do deploy desse servidor, que ainda não aconteceu e vai junto com a correção dos gastos, com o ok do usuário. Até lá, a VPS ainda roda a versão anterior, com APNs, App Attest e as rotas.
- **Nada aqui roda sozinho.** Deploy, escrita na VPS e deploy real no Pages só com o ok do usuário, pedido a cada vez.

```text
fiscal-sync.timer (5 min) ─▶ fiscal-ingest -sync: catálogo ─▶ sonda ─▶ só a fonte que mudou
            │ SQLite/snapshot ─▶ public/v1 (preparo, manifesto de hashes) ─▶ site/sites/<stamp> (delta + links físicos) ── valida ──▶ site/ready
            ▼
          fiscal-pages (orçamento mensal, wrangler só o que mudou) ─▶ Pages fiscal-dados ─▶ app (milhões)
fiscal-api (só o TSE; saúde em 127.0.0.1) ─▶ public/v1/races*.json ─┘
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
5. **Proteção no plano grátis.** Os arquivos estáticos do Pages não têm limite de requisições e já passam pela proteção contra DDoS da Cloudflare. Regras de WAF e de rate limit exigem a zona do domínio na Cloudflare, o que não é o caso. Depois do deploy do servidor novo, a VPS não recebe nada do app.

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

Chave do pseudônimo do CPF (`secrets/pseudonym-key`). O `fiscal-ingest` guarda o CPF só como HMAC-SHA256 com essa chave e **não sobe sem ela** (o `-config-check` falha com `PSEUDONYM_KEY_FILE: ... (create it once with openssl rand -hex 32 ...)` e o `compose run` recusa a montagem). Crie antes do primeiro deploy da imagem nova, uma vez só:

```sh
ssh root@179.198.114.91
cd /opt/fiscal-api
install -m 600 -o 1000 -g 1000 /dev/null secrets/pseudonym-key
openssl rand -hex 32 > secrets/pseudonym-key
wc -c < secrets/pseudonym-key   # 65 (64 caracteres hexadecimais e a quebra de linha)
```

- **Guarde uma cópia** no gerenciador de senhas (`ssh root@179.198.114.91 cat /opt/fiscal-api/secrets/pseudonym-key | pbcopy`). Não cole no chat nem no repositório.
- **Não troque nem perca a chave.** Ela é só interna: os slugs públicos ficam em `ingest-data/slugs.json`, que liga cada slug às chaves internas da pessoa. Com outra chave, o CPF das fontes deixa de bater com o que está no banco e no arquivo de slugs, e quem só tem CPF (governadores, deputados estaduais) ganharia slug novo.
- **Migração automática.** Na primeira carga com a chave, cada CPF lido em claro (Câmara, Senado, TSE) também calcula o pseudônimo antigo, sem segredo, e o `slugs.json` troca o antigo pelo novo com o mesmo slug. Quem ainda não foi lido em claro fica com o antigo até a próxima fase `tse` (domingo). O banco e os backups antigos ainda guardam o pseudônimo antigo nas linhas históricas.
- **Atualização ao vivo.** O snapshot da carga passou para a versão 2: depois do deploy, o `fiscal-live` pula ("no full load yet") até a primeira fase terminar.

Opcionais:

| Variável | Padrão | Para quê |
| --- | --- | --- |
| `INGEST_MEM_LIMIT` / `INGEST_GOMEMLIMIT` | `1200m` / `900MiB` | Teto da fase; suba os dois juntos se o job for morto por memória. Na VPS atual (4 vCPU e 16 GB) ficou `8192m` / `7GiB`, com `INGEST_CPUS=3`, `INGEST_WORKERS=8` e `INGEST_REQUEST_GAP=150ms` (26/10, o usuário liberou os limites depois do upgrade). Com 1,2 GB e com 2 GB a montagem completa do site foi morta (137) |
| `INGEST_MAX_LOAD` / `INGEST_MIN_AVAILABLE_MB` | `2` / `1536` | Guarda de carga: acima do load ou abaixo da memória livre, a fase espera e pula. Na VPS atual (4 vCPU e 16 GB desde 26/10) ficou `INGEST_MAX_LOAD=6` |
| `PAGES_DATA_INTERVAL` | `1h` | Intervalo mínimo entre deploys de releases quentes (`hot`, `destaques`) |
| `PAGES_MAX_DEPLOYS_PER_DAY` | `400` | Teto diário de deploys |
| `PAGES_MAX_DEPLOYS_PER_MONTH` | `450` | Teto mensal de deploys; as releases de rotina se espalham pelo que resta do mês (seção 6) |

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
4. **Promove `:current`**, guardando a anterior em `:previous` só quando o sha muda. Cada imagem leva o rótulo `fiscal.sha`; rodar de novo o mesmo sha (o `server/deploy/promote-image.sh` confere) não apaga o alvo do rollback. A API troca com `docker compose up -d --no-deps fiscal-api`. Se não ficar `healthy` em 90 s, o script volta sozinho para `:previous`.
5. **Units.**
   - Instala as units, remove o container antigo de longa duração `fiscal-ingest`, desliga e apaga os timers antigos (`fiscal-phase-*.timer`, `fiscal-live.*`) e liga o `fiscal-sync.timer`.
   - O `fiscal-pages.timer` fica **desligado**.

Para voltar uma imagem à mão, rode `docker tag fiscal-<api|ingest|pages>:previous fiscal-<…>:current`. No caso da API, rode também `docker compose up -d --no-deps fiscal-api`.

O app não lê nem escreve na VPS, então a troca da API não afeta quem usa. Uma leitura do TSE perdida durante a troca volta no próximo `POLL_INTERVAL`.

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
5. **O `curl`** confere o resultado: `v2/release.json` responde com `"layout":"v2"`. O app lê a pasta `v2` direto, sem consultar o `release.json`; o pacote offline usa o `release` dele para saber se algo mudou.

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
| `repercussao` | contagens do GDELT e da Wikipédia | a cada 3 h | nenhuma | Janelas de 30 dias valendo 72 h; o GDELT recusa rajadas (429), então cada leitura mede no máximo 15 min, espera 20, 45 e 90 s entre recusas e para depois de duas consultas recusadas seguidas |
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
- **Alerta de destaque.** Não passa pelo servidor: o app lê `v2/highlights.json` na CDN e agenda a Atividade e a notificação no aparelho. Um destaque só chega ao aparelho depois de estar no Pages.

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
- **Alerta de consistência** (`ALERT consistency` ou `ALERT store` no log; o `fiscal-ingest -sync` sai com código 3, ou 4 quando outro trabalho também falhou; o aviso chega na hora, e o `fiscal-sync.service` segue para o `fiscal-pages` mesmo assim):
  - **Na hora:** a reconstrução da `memoria` roda numa cópia do preparo (`public/check`, com links físicos) e monta a release sem mover o `ready`. Com divergência, o preparo e o site ficam como estavam, e os caminhos ficam em `ingest-data/consistency.json` › `held`. `-site status` avisa. Um trabalho de fonte que depois produza o mesmo conteúdo publica pelo caminho normal.
  - **Achar a causa:** compare a cópia (`public/check/v1/<caminho>`) com o preparo (`public/v1/<caminho>`). Depois de um deploy com regra nova na ligação, a divergência é esperada até rodar um trabalho de ligação. `ALERT store` quer dizer que uma fonte repetiu uma chave com outro conteúdo e o banco perdeu linhas: a release com o que a fonte leu já saiu, e a chave precisa ser corrigida no código.
  - **Para publicar a cópia**, depois de conferir que ela está certa: `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site publish-held`. Leva ao preparo os caminhos que não mudaram de novo desde a conferência (os outros ficam com o conteúdo novo, e o log diz quantos), monta a release inteira, zera o `held` e apaga a cópia. O próximo `fiscal-pages` publica.
  - **Corrigir fonte e cópia numa vez só**, com o ok do usuário: `systemctl stop fiscal-sync.timer`; `fiscal-ingest -job camara`, que não publica sozinho; `fiscal-ingest -site publish-held`; `fiscal-pages`; `systemctl start fiscal-sync.timer`.
  - **Só `-sync` e `-job` avisam.** `-once` e `-phase` só registram `ALERT store` no log.
- **Alerta da carga** (`fiscal-load-alert.sh`, em `ExecStopPost` do `fiscal-sync.service`):
  - avisa uma vez, por um tópico privado do ntfy, depois de 6 execuções seguidas com falha ou com os dados de `public/v1/meta.json` com mais de 48 horas sem mudar;
  - avisa de novo quando a execução termina bem com os dados em dia. O estado fica em `/var/lib/fiscal-load-alert`;
  - uma divergência avisa na hora, uma vez por execução, e tenta de novo na execução seguinte se o ntfy não responder. O código 3 não conta como falha; o 4 conta;
  - o aviso de dados sem mudar pode vir de um período sem novidade nas fontes, então confira o `-plan` antes de tratar como falha;
  - o aviso não leva dado de ninguém, e nenhuma falha do script muda o resultado do serviço. Tópico ausente ou ntfy fora do ar só ficam no log, e ele tenta de novo na execução seguinte;
  - **Criar ou trocar o tópico:** no app Terminal do Mac, fora do Claude Code, para o nome não passar pelo chat: `ssh root@179.198.114.91 'umask 077; openssl rand -hex 16 > /opt/fiscal-api/secrets/ntfy-topic; cat /opt/fiscal-api/secrets/ntfy-topic'`. Assine o nome no app ntfy;
  - **Testar:** `/opt/fiscal-api/fiscal-load-alert.sh --test`. O script usa `curl` e `python3` do host, sem os quais o aviso não sai e a carga segue normal;
  - **Conferir:** `journalctl -u fiscal-sync --since today | grep fiscal-load-alert`.
- **Imagens sumindo:** em 03/11/2026, a limpeza diária do Docker tinha apagado as imagens `fiscal-ingest` e `fiscal-pages`, que não têm contêiner rodando, e os dados ficaram parados desde 28/10. `/etc/cron.d/docker-image-prune` agora usa `--filter "label!=fiscal.sha"`. Se o `fiscal-sync` falhar com imagem ausente, confira esse filtro e refaça o deploy.
- **Conferir os dados publicados:** `python3 scripts/party-check.py --published` compara o partido entre o índice e as listas por estado, e `python3 scripts/portrait-check.py --published` procura quem está sem traços.
- **Pausar tudo:** `systemctl stop fiscal-sync.timer`. Para voltar, use `start`.
- **Voltar os dados publicados:**
  1. **Na hora:** painel do Pages › `fiscal-dados` › Deployments › o deploy bom › **Rollback**.
  2. **Para o próximo deploy não trazer a release ruim de volta:** `docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -site rollback` (ou `-to <nome>`). Releases por delta usam links físicos, e voltar não copia nada. O rollback pega o `ingest.lock`: com um trabalho rodando, espera até `INGEST_LOCK_WAIT` (20 min) e, se ele não acabar, sai com código 75 sem mudar nada. O `-site status` não espera.
  3. **Pausar o timer** até corrigir a fonte.
- **Queda de volume legítima** (troca de legislatura, por exemplo): `-job camara -allow-drop` uma vez.
- **Job morto por memória** (`journalctl` mostra `OOMKilled` ou código 137):
  - o site no ar não muda;
  - suba `INGEST_MEM_LIMIT` e `INGEST_GOMEMLIMIT` no `.env` e force o trabalho de novo.
- **Dia de eleição:**
  1. Ligue o timer: `systemctl enable --now fiscal-pages.timer`. Mudança na apuração sai na hora e conta no orçamento.
  2. Suba `PAGES_MAX_DEPLOYS_PER_MONTH` só se o painel mostrar que o Direct Upload não conta no limite. Não há reserva na VPS: se o teto chegar, a apuração no app fica parada no último deploy.
  3. Depois do resultado final, desligue com `systemctl disable --now fiscal-pages.timer`.
- **Limite de deploys do Pages:**
  - **O que a Cloudflare diz** (conferido em 26/10/2026):
    - a [página de limites](https://developers.cloudflare.com/pages/platform/limits/) dá 500 builds por mês no Free e descreve o build pelo push no Git;
    - a do [Direct Upload](https://developers.cloudflare.com/pages/get-started/direct-upload/) não fala de cota;
    - os dois limitam a 20.000 arquivos e 25 MiB por arquivo.
    - **Não está confirmado se o `wrangler pages deploy` conta.**
  - **O que o Fiscal faz.** `PAGES_MAX_DEPLOYS_PER_MONTH=450` é teto duro. As releases de rotina esperam `tempo até o fim do mês ÷ deploys restantes`, cerca de 96 min no começo do mês. As quentes esperam também `PAGES_DATA_INTERVAL`. `full`, `memoria`, rollback, `-force` e mudança na apuração saem na hora.
  - **Conferir.** Em Account Home › Workers & Pages › Plans, veja se o uso de builds do mês acompanha os deploys diretos.
  - **Se não contar:** `PAGES_MAX_DEPLOYS_PER_MONTH=9000` e `PAGES_DATA_INTERVAL=10m`.
  - **Em produção (26/10/2026).** Depois de uns 12 deploys diretos, o painel não mostrou contador de builds do Pages e os "Workers build mins" seguiram em 0. O `.env` da VPS usa `PAGES_MAX_DEPLOYS_PER_MONTH=4500` (cerca de um deploy a cada 10 min) e `PAGES_DATA_INTERVAL=10m`. Se um deploy for recusado por cota, a release no ar continua servindo e o quente fica parado até o próximo deploy; volte o teto para 450.
  - **O quente vem do Pages (desde 03/11/2026).** `today.json`, `agenda/today.json`, `votes/recent.json` e as votações de hoje chegam ao app no próximo deploy, em até `PAGES_DATA_INTERVAL`. O app não tem reserva na VPS: com o Pages fora, ele usa o cache, depois o pacote offline e depois mostra o erro.

## 7. Caddy

O app não lê nada da VPS ([ADR 0028](adr/0028-app-reads-only-from-cdn-and-local-alerts.md)). O bloco `fiscal.byescaleira.com` que está na VPS ainda é o de antes desta mudança, com estes trechos para o Fiscal:

- `@data` (e o `@hot`, se foi acrescentado), que serve o `v1` de `/opt/fiscal-api/public` com cache curto;
- `@races`, que serve `races.json` e `races/<id>.json` do mesmo lugar;
- `/api/*`, encaminhado para o Go em `127.0.0.1:3130`, com `/api/v1/admin/*` respondendo 404.

Nenhum deles é usado pelo app desta versão. Depois do deploy do servidor novo, o Go só responde `GET /api/health` e 404; enquanto o Caddy encaminhar `/api/*`, a saúde também responde de fora.

Tirar esses trechos do bloco é uma edição à parte, só com o ok do usuário, depois do deploy. Confira o bloco real antes, porque este texto não é cópia do que está na VPS, e siga os quatro passos: backup `.bak.<epoch>`, edição só deste bloco, `caddy validate` e `systemctl reload caddy`. O `log` do bloco fica, porque é por ele que se confere que o app não chama a VPS. O arquivo de associação da Apple (`/.well-known/apple-app-site-association`) e o site são da seção 9.

## 8. Depois do deploy da FSC-020 (com o ok do usuário)

O deploy do servidor de `ba5e576` vai junto com a correção dos gastos, pelo `scripts/server-deploy.sh` (seção 3), com o ok do usuário. Depois dele, cada passo abaixo também pede o ok, a cada vez:

1. **Conferir a carga e a publicação (cenário 33 da [FSC-020](../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)).** Com a VPN do Mac desligada:
   - `journalctl -u fiscal-sync --since today` mostra os trabalhos e o `fiscal-pages` publicando;
   - `curl -sI https://dados.fiscal.byescaleira.com/v2/races.json` responde 200;
   - `curl -s http://127.0.0.1:3130/api/health`, na VPS, responde `{"ok":true,…}`;
   - o log de acesso (`/var/log/fiscal-access.log`) não tem pedido com agente `Fiscal/` depois da instalação do app novo.
2. **Apagar o que a versão anterior guardou na VPS.** Em `/opt/fiscal-api/data`: `highlight-registrations.json`, `highlight-alerts.json`, `registrations.json` e `attest-keys.json`. Em `/opt/fiscal-api/public`, a pasta `published/`. Confira os nomes reais antes de apagar.
3. **Revogar a chave do APNs (recomendado).** O servidor novo não lê a chave, e ela ainda manda push para todos os aparelhos do app. O recomendado é revogá-la no Apple Developer e apagar `secrets/apns.p8` da VPS, com o ok do usuário. Se outro app usa a mesma chave, registre aqui o motivo de mantê-la. A sincronização do iCloud não depende dela.
4. **Limpar o `.env` da VPS.** O `compose.yaml` novo não passa a nenhum serviço as variáveis `APNS_*`, `APNS_DISABLED`, `APPATTEST_*`, `ADMIN_TOKEN`, `HIGHLIGHT_ALERTS` e `HOT_FROM_ORIGIN`, e o `fiscal-api` não monta mais `secrets/`. Elas podem sair do `.env`.
5. **Caddy.** A edição da seção 7.
6. **Só então, privacidade e rótulo.** A política nova ("Dados que coletamos: Nenhum") e o rótulo "Dados não coletados" só valem depois dos passos 2 e 4. Publicar o site com a política nova e trocar o rótulo no App Store Connect vêm depois deles, cada um com o ok do usuário.

## 9. Site no mesmo bloco (proposta, com o ok do usuário)

Hoje o bloco `fiscal.byescaleira.com` termina em `handle { respond 404 }`: o site não está no ar, e `/` e o arquivo de associação da Apple respondem 404 (conferido de fora em 07/11/2026, [QA da FSC-020](evidence/FSC-020/qa.md)). Sem esse arquivo, os links universais não abrem o app. Para publicar o site (`site/` do repositório, arquivos estáticos em `/opt/fiscal-site/public`), o bloco fica como abaixo. É o que o repositório pede (skill `byescaleira-sdd`, `launch-site-and-support.md` e `vps-operations.md`), não o que está na VPS: confira o bloco real antes de editar e siga os quatro passos (backup `.bak.<epoch>`, edição só deste bloco, `caddy validate`, `systemctl reload caddy`).

```
fiscal.byescaleira.com {
	encode zstd gzip

	header {
		Strict-Transport-Security "max-age=31536000; includeSubDomains"
		X-Content-Type-Options "nosniff"
		Referrer-Policy "strict-origin-when-cross-origin"
		?Cache-Control "public, max-age=300"
		-Server
	}

	handle /admin* {
		reverse_proxy 127.0.0.1:3120
	}

	handle /bridge/* {
		reverse_proxy 127.0.0.1:3110
	}

	@aasa path /.well-known/apple-app-site-association
	header @aasa Content-Type "application/json"

	handle {
		root * /opt/fiscal-site/public
		try_files {path} {path}.html
		file_server
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

- **Sem `@hot`, `@races`, `@data` nem `/api/*`**: o app não lê a VPS (seção 7).
- **`?Cache-Control`** só entra quando a resposta não trouxe o seu: o `no-store` da ponte e do admin fica como está; o site ganha `public, max-age=300`.
- **`try_files {path} {path}.html`** serve `/privacy`, `/terms`, `/support` e `/link` sem `.html`, como o `scripts/site-server.mjs` faz em `127.0.0.1:4173`.
- **`handle /admin*`** é o painel de flags e versões (`admin/README.md`). **`handle /bridge/*`** só faz sentido com a ponte no ar, junto com o Fiscal na Web, depois da 1.0; até lá, pode ficar de fora.
- **`/.well-known/apple-app-site-association`** precisa responder `200` com JSON, sem redirecionamento, enquanto houver versão na loja com `applinks:`.
- **Saúde depois do reload:** `curl -s http://127.0.0.1:3130/api/health` na VPS (`{"ok":true,"version":"…"}`), `curl -s https://fiscal.byescaleira.com/admin/health` e, com a ponte no ar, `/bridge/health`, todos com a versão; depois as rotas do site com a receita de [docs/web.md](web.md#publicar).
