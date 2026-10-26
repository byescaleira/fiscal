# Servidor do Fiscal

Go 1.26.10 com a biblioteca padrão; a única dependência externa é `modernc.org/sqlite` (Go puro), usada só pela carga ([ADR 0006](../docs/adr/0006-ingest-sqlite-store.md)). Dois processos na mesma imagem:

- **`liveresults-server`** (`cmd/server`): a apuração ao vivo. Lê os arquivos do TSE do 2º turno (presidente e governador de AC, AM, DF, ES, RN e TO), serve o placar em `/api/v1/races` e atualiza as Live Activities por APNs quando os números mudam. Contrato em `docs/changes/live-results/proposal.md`.
- **`fiscal-ingest`** (`cmd/ingest`): a carga de dados da 1.0. Lê Câmara, Senado, TSE, IBGE, Receita, as assembleias com SAPL e as checagens do Projeto Comprova e publica os arquivos estáticos do contrato (`docs/changes/app-1.0/contract.md`, seção 2) em `PUBLIC_DIR/v1`. Detalhes em [Carga de dados](#carga-de-dados-fiscal-ingest).

## Apuração ao vivo (`liveresults-server`)

### Variáveis

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
| `HIGHLIGHT_ALERTS` | `1` | `0` desliga a Live Activity do destaque: sem as rotas `/api/v1/highlight-activities` (404) e sem ler `PUBLIC_DIR/v1/highlights.json` |

Sem `APNS_KEY_FILE`, `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC` o servidor não sobe, a menos que `APNS_DISABLED=1`. A chave é carregada e um JWT é assinado no boot.

### Rotas

| Rota | Resposta |
| --- | --- |
| `GET /api/health` | `{"ok":true}` |
| `GET /api/v1/races` | `{"races":[Race],"fetchedAt":"…"}`; `503 not_ready` antes do primeiro dado |
| `GET /api/v1/races/{id}` | `Race`; `404 race_not_found`; `503 not_ready` |
| `POST /api/v1/live-activities` | `{"raceId","pushToken","environment"}` → `204`; `422 invalid_request`, `413 body_too_large`, `409 token_bound_to_other_race`, `429 too_many_registrations`, `429 rate_limited`, `507 capacity_reached` |
| `DELETE /api/v1/live-activities` | corpo `{"pushToken":"<hex>"}` (até 4 KiB) → `204` sempre que o corpo for válido, exista ou não o registro; `422 invalid_request`, `413 body_too_large`, `429 rate_limited` |
| `POST /api/v1/highlight-activities` | `{"pushToken","environment"}` (token de push-to-start da `HighlightActivityAttributes`) → `204`; `422 invalid_request`, `413 body_too_large`, `409 token_bound_to_other_environment`, `429 too_many_registrations`, `429 rate_limited`, `507 capacity_reached` |
| `DELETE /api/v1/highlight-activities` | corpo `{"pushToken":"<hex>"}` → `204` sempre que o corpo for válido; `422 invalid_request`, `413 body_too_large`, `429 rate_limited` |
| `POST /api/v1/admin/push-test` | `Authorization: Bearer $ADMIN_TOKEN`, `{"raceId"}` → `{"registrations","sent","failed","removed","event"}` |

O token vai no corpo do `DELETE`, nunca na URL: o log do Caddy grava a URI inteira. A rota antiga `DELETE /api/v1/live-activities/{pushToken}` não existe mais (responde `404 not_found`, e o log do Go continua cortando o token em 6 caracteres).

Ids: `presidente-br`, `governador-ac`, `governador-am`, `governador-df`, `governador-es`, `governador-rn`, `governador-to`.

Registros:
- Cada registro guarda `createdAt` e vale 12 h. Registrar de novo o mesmo token renova o prazo. Registros vencidos são ignorados no envio e removidos na varredura que roda junto do flush, a cada 2 s.
- Um token já registrado não troca de `raceId` nem de `environment`: o pedido diferente recebe `409 token_bound_to_other_race` e o original fica.
- No máximo 20 registros vivos por IP de origem (IPv6 agrupado por /64), `429 too_many_registrations` acima disso. O IP só é guardado como SHA-256 truncado com um sal aleatório gerado no boot, em memória; `registrations.json` não leva IP nem hash, e ao reiniciar o teto recomeça.

Destaque na tela de bloqueio (regra em `docs/changes/app-1.0/weight.md`):
- Os tokens de push-to-start ficam em `DATA_DIR/highlight-registrations.json` (sem IP), valem 30 dias e são renovados a cada abertura do app; até 200 000 registros e 100 por IP.
- A cada minuto o servidor confere `PUBLIC_DIR/v1/highlights.json` (gravado pela carga) e só relê quando data ou tamanho mudam. O primeiro item com peso ≥ 85, de fato até 24 h depois do fim do dia dele (Brasília), e ainda não enviado vira um push-to-start (`event: start`, prioridade 10) para todos os tokens; o id vai para `DATA_DIR/highlight-alerts.json` (14 dias). Sem nenhum token registrado, nada é marcado como enviado.

Rate limit por IP: 120 GET e 120 POST/DELETE por minuto (CGNAT), `429 rate_limited` acima. IPv6 conta por /64. `X-Forwarded-For` (último valor) só é aceito quando a conexão vem de loopback ou de rede privada (gateway do Docker, `10/8`, `172.16/12`, `192.168/16`, `fc00::/7`); de qualquer outro endereço vale o `RemoteAddr`. Quando o mapa de buckets lota (100 000), o mais antigo é descartado.

Arquivos estáticos (`PUBLIC_DIR/v1`): no boot do modo TSE só `races.json` e a pasta `races/` são apagados e republicados a partir do `state.json`; o resto de `v1/` é da carga de dados e não é tocado. A cada leitura, os arquivos das disputas são gravados antes dos pushes e só quando o conteúdo muda; `races.json` só é regravado quando alguma disputa muda, então o `fetchedAt` dele é o da última mudança, e o `ETag`/`304` do Caddy se mantém entre leituras sem novidade.

### Rodar local

```sh
cd server
go build ./... && go vet ./... && go test -race ./...
SIMULATE=1 APNS_DISABLED=1 POLL_INTERVAL=5s go run ./cmd/server
curl -s http://127.0.0.1:3130/api/v1/races
```

Com APNs de verdade, aponte `APNS_KEY_FILE` para a `.p8` e preencha `APNS_KEY_ID`, `APNS_TEAM_ID` e `APNS_TOPIC`.

## Deploy da apuração

Em `/opt/fiscal-api` na VPS, com o `.env` (`chmod 600`, nomes em `.env.example`), `secrets/apns.p8` e `data/` (dono 1000, pastas `700`, chave `600`). O código sobe com `rsync -a`, **sem `--delete`**, e sem tocar no que só existe na VPS:

```sh
rsync -a --exclude .env --exclude secrets/ --exclude data/ --exclude ingest-data/ --exclude ingest-backups/ --exclude public/ server/ vps:/opt/fiscal-api/
```

`.env`, `secrets/`, `data/`, `ingest-data/`, `ingest-backups/` e `public/` nunca saem da máquina local nem são sobrescritos ou apagados na VPS. O `ADMIN_TOKEN` é gerado na própria VPS e vai só para o `.env`:

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

## Carga de dados (`fiscal-ingest`)

Roda no container `fiscal-ingest` (mesma imagem, `entrypoint` próprio no `compose.yaml`), sem porta e sem rota HTTP. Dois ciclos:

1. **Carga completa** no boot e todo dia às `INGEST_FULL_AT` (hora de Brasília). Se falhar, nada novo é publicado (os arquivos anteriores ficam) e ela tenta de novo em 5, 15 e 30 min.
2. **Atualização ao vivo** a cada `INGEST_LIVE_INTERVAL`: pauta do dia do Plenário das duas casas, votações de hoje (API da Câmara e `/votacao` do Senado), próxima sessão e o card da apuração (lido de `PUBLIC_DIR/v1/races.json` quando o arquivo é de hoje). Regrava `agenda/today.json`, `today.json`, `votes/*` e os votos por pessoa que mudaram.

Tudo o que é lido fica guardado no banco SQLite (`STORE_PATH`), com histórico, e os arquivos são gerados a partir dele; detalhes em [Banco da carga](#banco-da-carga-fiscaldb).

Cada arquivo sai com o `.gz` ao lado, por escrita atômica (`internal/publish`, o mesmo código da apuração), e só é regravado quando o conteúdo muda. O `updatedAt` de cada fonte só anda quando os dados daquela fonte mudam (`DATA_DIR/sources.json`), para o `ETag` do Caddy se manter entre cargas sem novidade. Arquivos de pessoas e votações que saíram do escopo são apagados (`people/`, `votes/`, `places/`, `index/`, `agenda/`, `money/`, `method/`, `indicators/`); `races*` nunca.

### Variáveis da carga

| Variável | Padrão | Uso |
| --- | --- | --- |
| `PUBLIC_DIR` | `./public` (`/public` no container) | Raiz pública; os arquivos vão para `PUBLIC_DIR/v1` |
| `DATA_DIR` | `./data` (`/data` no container, volume `./ingest-data`) | `fiscal.db` (o banco, com `-wal` e `-shm`), `backups/` (volume `./ingest-backups`), `slugs.json`, `sources.json`, `ingest-status.json`, `comprova.json` (checagens lidas), `checks-review.json` (lista interna de revisão), `cities-review.json` (casamento TSE ↔ IBGE dos municípios, interno), `repercussion.json` (só contagens do GDELT e da Wikipédia, sem texto de terceiros), `indicators.json` (última leitura boa da ANP e do SIDRA) e `cache/` (downloads condicionais e agregados do TSE); pasta `0700`, arquivos `0600` |
| `INGEST_YEARS` | de `2023` até o ano corrente (a legislatura) | Anos de atividade da Câmara, do Senado e das assembleias: `2026`, `2023-2026` ou `2025,2026` |
| `TSE_YEARS` | `2022,2026` | Eleições lidas por inteiro (candidaturas, bens, votos por município e contas). A penúltima é a do mandato atual, a última é a dos eleitos aguardando posse |
| `TSE_CANDIDATE_YEARS` | `2018` | Eleições lidas só para candidaturas e bens (ligação dos senadores eleitos em 2018 e linha do tempo) |
| `INGEST_UFS` | vazio (todas) | Limita a carga a UFs (`ac,sp`). O presidente e o vice entram sempre. Os arquivos anuais da Câmara são nacionais e são baixados inteiros mesmo assim |
| `INGEST_SOURCES` | vazio (todas) | Subconjunto de `camara,senado,tse,ibge,receita,assembleias,comprova,cidades,repercussao,anp,sidra` |
| `TSE_CITY_YEAR` | `2024` | Eleição municipal lida para prefeitos, vices e vereadores (`2016`, `2020`, `2024`…; nunca no futuro) |
| `INGEST_FULL_AT` | `06:30` | Hora (Brasília) da carga completa diária; a Câmara regera os arquivos anuais entre 00h e 04h |
| `INGEST_LIVE_INTERVAL` | `10m` | Intervalo da atualização ao vivo (de 2 min a 1 h) |
| `INGEST_WORKERS` | `4` | Requisições paralelas às APIs (1 a 16) |
| `COMPROVA_SINCE` | `2022-01-01` | Início da janela de checagens do Comprova (`AAAA-MM-DD`, de 2018 até hoje) |
| `NEWS_BUDGET` | `120` | Consultas ao GDELT por carga completa (1 a 600), uma a cada 6 segundos; o resto usa as contagens guardadas em `DATA_DIR/repercussion.json` por até 3 dias |
| `INGEST_REQUEST_GAP` | `150ms` | Intervalo mínimo entre requisições ao mesmo host (o Senado devolve 429 acima de 10 por segundo) |
| `STORE_PATH` | `DATA_DIR/fiscal.db` (`/data/fiscal.db` no container) | Banco SQLite da carga; precisa terminar em `.db` |
| `BACKUP_KEEP` | `14` | Quantos backups diários manter em `DATA_DIR/backups` (1 a 365) |

Configuração inválida derruba o processo no boot (falha fechada). Nenhuma variável é segredo.

### Fontes e o que vira cada arquivo

| Fonte | O que é lido | Vai para |
| --- | --- | --- |
| Câmara, API v2 | `/deputados`, `/deputados/{id}`, `/historico`, `/discursos` (por ano; se a API der 500, mês a mês), `/eventos` e `/eventos/{id}/pauta` do Plenário, `/votacoes` de hoje com `/votos` e `/orientacoes` | perfil, contato, mandato, presença (só nos períodos de exercício), discursos, pauta, votações de hoje |
| Câmara, arquivos anuais | `proposicoesAutores`, `proposicoes`, `votacoes`, `votacoesVotos`, `votacoesOrientacoes`, `votacoesProposicoes`, `eventos`, `eventosOrgaos`, `eventosPresencaDeputados`, `orgaosDeputados-L57` e a CEAP (`Ano-{ano}.csv.zip`) | propostas, votos, orientação do partido, presença, comissões, gastos, `money/overview.json`, leis do dia |
| Senado | `/senador/lista/atual`, `/senador/{c}`, `/mandatos`, `/comissoes?ativo=S`, `/discursos`, `/processo?codigoParlamentarAutor`, `/votacao`, `/plenario/agenda/dia` e `/mes`; CEAPS pela API administrativa (com `codSenador`). Nenhum serviço descontinuado | perfil, mandato, comissões, propostas, discursos, votos, gastos, pauta |
| TSE | `consulta_cand`, `bem_candidato`, `votacao_candidato_munzona` e `prestacao_de_contas_eleitorais_candidatos` (receitas e despesas contratadas). Lê só os CSVs das UFs pedidas (mais `BR`, nunca `BRASIL`) de dentro dos ZIPs por HTTP Range, filtra os cargos 1 a 8, em Latin-1 com `;`. O agregado fica em cache até o `ETag` do ZIP mudar | governadores, vices, deputados estaduais e distritais, presidente e vice, eleitos de 2026, bens, campanhas, linha do tempo |
| IBGE | municípios (`view=nivelado`) | `index/places.json` |
| TSE, eleição municipal (`cidades`) | `consulta_cand_2024.zip` (cargos 11, 12 e 13, só os eleitos: `ELEITO`, `ELEITO POR QP`, `ELEITO POR MÉDIA`, com o 2º turno de prefeito), `bem_candidato_2024.zip` e `votacao_candidato_munzona_2024.zip`, em `https://cdn.tse.jus.br/estatistica/sead/odsele/…`, pelo mesmo leitor de ZIP por HTTP Range, só das UFs pedidas | `places/city/{ibge}.json` e o perfil leve `people/{slug}.json` de cada prefeito, vice e vereador |
| Receita | `arrecadacao-estado.csv` (último ano com 12 meses; as colunas de detalhe substituem os totais) | `money/overview.json` › `revenue`, ou `null` |
| Assembleias (SAPL) | AC, AM, PB, PI e RO: parlamentares, legislatura atual e mandatos, autores, tipos e matérias de cada ano | quem está em exercício (com os suplentes no cargo), propostas, contato e foto. Nas outras UFs a cobertura é `notPublished` |
| ANP, Série Histórica do Levantamento de Preços (`anp`) | as planilhas mensais `shlp/2001-2012/mensal-brasil-2001-a-2012.xlsx`, `mensal-estados-2001-a-2012.xlsx`, `shlp/mensal/mensal-brasil-desde-jan2013.xlsx` e `mensal-estados-desde-jan2013.xlsx` em `https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia/precos/precos-revenda-e-de-distribuicao-combustiveis/`, lidas por um leitor de XLSX próprio (`internal/sources/xlsx`); o preço médio de revenda do mês de gasolina comum, etanol hidratado, diesel S10 e GLP (13 kg), no Brasil e nas 27 UFs | `indicators/{gasolina,etanol,diesel-s10,glp}.json` |
| IBGE, SIDRA (`sidra`) | `https://apisidra.ibge.gov.br/values`: tabela 1737 (número-índice do IPCA, Brasil, desde 1995) e a variação mensal (variável 63) das tabelas 2938 (jul/2006 a dez/2011), 1419 (2012 a 2019) e 7060 (desde 2020), no Brasil, nas 11 regiões metropolitanas e nas 5 capitais do IPCA, para o índice geral (7169), alimentação no domicílio (7171), aluguel residencial (7448), energia elétrica residencial (7485) e gasolina (7657). Fora do índice geral do Brasil, o índice é encadeado das variações mensais (base 100 no mês antes do primeiro dado seguido) | `indicators/ipca*.json` |
| Projeto Comprova (CC BY-ND 4.0) | API pública do WordPress, `/wp-json/wp/v2/publicacoes` (100 por página, até `X-WP-TotalPages`, só os campos usados). A primeira carga lê a janela inteira; as seguintes pedem só o que mudou (`modified_after`, com 1 h de folga) e a cada 7 dias a janela é relida inteira, para tirar o que saiu do ar | `people/{slug}/checks.json` (título, selo, data e link; o corpo da checagem não é guardado nem publicado) |
| Repercussão (`repercussao`) | GDELT DOC 2.0 (`mode=timelinevolraw`, 30 dias, `sourcelang:portuguese`, uma consulta a cada 6 s, até `NEWS_BUDGET` por carga) pela proposição e pelo nome; Wikipédia em português (`action=query` com redirecionamento, em lotes de 50) e Wikimedia Pageviews (`per-article`, `user`, 30 dias) do artigo do político e do tema. O Bluesky fica de fora: `searchPosts` responde 403 sem autenticação | `people/{slug}/actions.json`, `highlights.json` e `method/weight.json` (só contagens; regra em `docs/changes/app-1.0/weight.md`) |

### Regras

- **Ligações:** deputado federal ↔ TSE por CPF; senador ↔ TSE por nome completo ou de urna + UF + cargo 5 + ano anterior ao início do mandato (só com resultado único); depois disso, todas as candidaturas da pessoa pelo CPF. O CPF nunca é publicado nem guardado em claro: a chave interna é um hash.
- **Quem está no cargo:** a lista da própria casa para Câmara e Senado; deputados que aparecem nos votos do ano e estão de licença entram como `onLeave`. Presidente, vice, governador e vice vêm dos eleitos de 2022; quem disputou outro cargo em 2026 renunciou (Constituição, art. 14, § 6º), e o vice assume, sem vice no lugar. Deputados estaduais vêm dos eleitos de 2022; nas assembleias com SAPL, os mandatos da legislatura atual dizem quem está em exercício (os suplentes no cargo entram; os eleitos fora da lista viram `onLeave` quando a lista cobre ao menos 80% das cadeiras). Os eleitos de 2026 entram como `electedAwaiting`.
- **Mandatos:** datas da Constituição (presidente até 05/01/2027 e governador até 06/01/2027, pela EC 111/2021; Câmara e Senado em 1º de fevereiro). Deputado estadual fica `null`.
- **Salário:** R$ 46.366,19 para presidente, vice, senador e deputado federal (Decreto Legislativo nº 172/2022); os outros cargos ficam `null`.
- **Temas e linguagem simples:** radicais escritos para o Fiscal (`internal/publicdata/themes.go`) e regras próprias (`internal/publicdata/plain.go`); a ementa oficial vai sempre ao lado.
- **Slugs:** nome de urna em kebab-case, com `-uf` só quando o nome se repete em mais de uma UF; o registro em `DATA_DIR/slugs.json` mantém o slug de cada pessoa entre cargas e nunca o passa para outra.
- **Neutralidade e ausência:** listas em ordem alfabética, sem ranking; dado que a fonte não publica ou que não foi carregado é `null`, com o motivo em `coverage`. Gasto de fornecedor pessoa física sai sem documento (só CNPJ é publicado).
- **Municípios:**
  - **Quem entra:** os eleitos de `TSE_CITY_YEAR` por município e cargo. Quando o mesmo arquivo traz uma eleição suplementar com eleito (Oiapoque, 2026), vale a mais recente. Sem eleito no dado aberto (eleição anulada, sub judice, retotalização), o grupo some e o arquivo diz o motivo em `note`; nada é inventado.
  - **TSE ↔ IBGE:** o código do TSE (`SG_UE`) é casado com o IBGE pelo nome dentro da UF, em etapas e só com candidato único dos dois lados: nome sem acento e sem pontuação; sem as partículas (`d'`, `de`, `do`, `dos`…: "Espigão do Oeste" ↔ "Espigão D'Oeste"); grafia (`th`→`t`, `z`→`s`, `y`→`i`, letra dobrada, nasal final: "São Thomé" ↔ "São Tomé", "Camacã" ↔ "Camacan"); prefixo ("São Luiz" ↔ "São Luiz do Anauá"); e uma tabela curta de renomeações (Boa Saúde ↔ Januário Cicco, RN). O que sobra vai para `DATA_DIR/cities-review.json` (`unmatchedUnit`), junto dos municípios sem eleição (`noElection`: Brasília e Fernando de Noronha) e de cada casamento que não foi exato.
  - **Todo município do IBGE ganha `places/city/{ibge}.json`**, inclusive os sem eleição, com o motivo em `note`.
  - **Perfil leve:** nome de urna, nome civil, partido, cargo, mandato (01/01/2025 a 31/12/2028; `null` no início quando a eleição foi suplementar), nascimento, escolaridade, bens e votos de 2024. Campanha e salário ficam `notLoaded`; foto `null`. O título de eleitor só serve de chave interna, como hash (`titulo:…`), igual ao CPF.
  - **Fora do índice:** prefeitos, vices e vereadores não entram em `index/people.json`, `meta.json › counts` nem `places/{uf}.json`.
  - **Atualização ao vivo:** reaproveita os arquivos de municípios da última carga completa (não os regrava a cada 10 min), e a limpeza não os apaga.
  - **Falha:** a fonte é opcional. Se o TSE falhar, a carga usa a última leitura boa em `DATA_DIR/cache/tse`; sem leitura anterior, sai sem arquivos de municípios e com aviso no log.
- **Preços e índices (`indicators/`):**
  - **Arquivos:** `indicators/index.json` (`{ items: [{ id, name, unit, kind, scope, scopes, start, latest, latestDate, change12m }], sources }`, com o último valor e a variação em 12 meses do Brasil) e `indicators/{id}.json` (`{ id, name, unit, kind (price | index), scope (br | uf), areas: [{ scope, name, series: [{ date, value }] }], sources }`), em base mensal (`date` é o dia 1º do mês).
  - **Antes e durante o mandato:** `people/{slug}/context.json` para todo político federal e estadual em exercício com data de posse (deputado estadual sem data usa 1º de fevereiro do ano seguinte à eleição): `{ mandateStart, scope, indicators: [{ id, name, unit, kind, scope, area, atStart, atStartDate, latest, latestDate, months, changeDuring, beforeDate, changeBefore, series }], sources }`. O valor da posse é o do mês anterior ao mês da posse; `changeDuring` é a variação dele até o último mês publicado (`months` meses) e `changeBefore` a variação nos mesmos `months` meses antes; `series` traz o recorte de `2 × months` meses. A jurisdição é o Brasil para presidente e vice e a UF para os demais; sem série na UF (o IPCA só cobre 16 UFs), vale a do Brasil, e o item diz qual (`scope`, `area`). Prefeitos, vices e vereadores ficam sem o arquivo (seriam 69 mil cópias do mesmo recorte por UF); o app faz o mesmo cálculo a partir de `indicators/{id}.json`. Eleitos aguardando posse também não ganham o arquivo. Nenhum texto de causa: só valores e variações.
  - **Falha:** as duas fontes são opcionais. Se a ANP ou o SIDRA falharem (ou vierem com menos de 100 meses no Brasil, ou a ANP sem as 27 UFs), a carga segue com a última leitura boa de `DATA_DIR/indicators.json`; sem leitura anterior, sai sem esses arquivos.
- **Falha:** se a Câmara listar menos de 400 deputados, o Senado menos de 70 senadores, o IBGE menos de 5.000 municípios, ou uma fonte obrigatória (Câmara, Senado, TSE das eleições inteiras, IBGE) falhar, a carga usa a última leitura guardada no banco daquela fonte (estado `fallback`, `updatedAt` mantido); sem leitura guardada, para sem publicar. Receita e assembleias que falham viram `null` ou `notLoaded`, com aviso no log. Se o Comprova falhar, a carga segue com as checagens da última leitura boa (`DATA_DIR/comprova.json`), e os arquivos publicados ficam iguais.

### Checagens (Projeto Comprova)

Piloto do item "Checagens no perfil" do brief (`docs/brief.md`), com a pesquisa em `docs/research/2026-10-25-fact-checks.md`. Licença CC BY-ND 4.0, conferida na [metodologia](https://projetocomprova.com.br/about/metodologia/) em 2026-10-25: o título vai como o Comprova escreveu, com crédito e link da licença em cada item.

- **Selo:** o rótulo da agência como veio, nunca um nosso. Sinais lidos de cada publicação: a tag (`tags[].tag`), a frase de definição do texto ("Enganoso, para o Comprova, é…"), o cabeçalho da seção (`<b>Contextualizando</b>:`, `<b>Comprova Explica</b>:`) e o nome do arquivo da imagem do selo (`02-Site-FALSO-…` em `image-masked` e `og:image`). Rótulos achados: Falso, Enganoso, Comprovado, Verdadeiro, Sátira, Contextualizando, Comprova Explica e Golpe. Sem sinal, ou com sinais que discordam, o selo é `null` (e a discordância vai para a revisão).
- **Fora:** publicações institucionais (comunicados, lançamentos, relatórios, imagem `01-Site-…`) e links fora de `https://projetocomprova.com.br`.
- **Associação** (`internal/publicdata/checks.go`): o nome de urna ou o nome civil completo, sem acento e sem caixa, por palavras inteiras, no título ou na explicação da tag, escrito com inicial maiúscula e identificando uma única pessoa do escopo. Nome de uma palavra só liga apenas quando é o nome de urna exato e único (Lula). Não ligam e vão para `DATA_DIR/checks-review.json`, que não é publicado:
  - `ambiguousName`: homônimos no escopo;
  - `partOfLongerName`: o nome colado em outro nome com maiúscula ("ACM Neto", "Comando Vermelho", "Forte do Pinheirinho", "Governo Lula"), salvo nomes de três palavras ou mais;
  - `surnameOnly`: só o sobrenome ("Bolsonaro" não liga a Flávio Bolsonaro);
  - `officeMismatch`: um cargo antes do nome que a pessoa não tem ("o ministro da Economia, Paulo Guedes" para o deputado Paulo Guedes); "ex-", "então" e "pré-" anulam o cargo, e "presidente da/do …" não conta;
  - `possibleHomonym`: as outras checagens de quem teve cargo contraditório e nenhuma confirmação (cargo certo antes do nome ou partido entre parênteses depois dele);
  - `verdictConflict`: selos que discordam.
- **Publicação:** `people/{slug}/checks.json` só quando há ao menos uma checagem, em ordem de data decrescente; quem é citado por nome em várias checagens recebe todas, sem contagem nem ranking.

### Banco da carga (`fiscal.db`)

SQLite em WAL, aberto só pelo `fiscal-ingest` (pacote `internal/datastore`, uma conexão). O schema é versionado (`schema_migrations`) e migra no boot. Nenhuma requisição pública lê o banco: ele alimenta os arquivos estáticos.

**Histórico.** Toda tabela de dado tem `source`, `key`, `hash`, `payload` (JSON da fonte já convertida), `valid_from`, `valid_to`, `first_run` e `seen_run`. Leitura igual só atualiza `seen_run`; conteúdo novo fecha a versão atual (`valid_to`) e abre outra; o que some de uma leitura completa é fechado, nunca apagado. A versão atual é `valid_to IS NULL`.

| Tabela | Fonte (`source`) | Chave | O que guarda |
| --- | --- | --- | --- |
| `people` | `camara`, `senado` (leitura da casa) e `fiscal` (pessoa já ligada e publicada, com `slug`) | `camara:<id>`, `senado:<código>` ou `cpf:<hash>` | nome, cargo, UF, partido, situação; o payload leva candidaturas, comissões, discursos e presença |
| `mandates` | `fiscal` | pessoa + cargo + UF + início | cada cargo com partido, situação e datas |
| `votes`, `ballots` | `camara`, `senado` | id da votação; votação + pessoa | votações (sem os votos) e cada voto nominal |
| `propositions` | `camara`, `senado`, `assembleia-<uf>` | pessoa + ano + id | propostas de autoria |
| `expenses` | `camara`, `senado` | pessoa + ano + id | gastos da cota |
| `places` | `ibge` | `municipality:<código>` | municípios |
| `city_officials` | `tse-cidades` | município + pessoa | prefeitos, vices e vereadores |
| `snapshots` | por fonte | livre (`quota`, `laws`, `candidacies:<ano>`, `campaigns`, `revenue`, `check:<id>`, `city:<código>`, `agenda:<data>`) | o resto do que a fonte entrega, com `fetched_at` da última leitura |
| `series` | por fonte | série + escopo + data | `quota.total` (casa, ano), `revenue.total` (UF ou `br`, ano), `checks.published` (`br`, mês); preços, indicadores e sinais de repercussão entram aqui |
| `sources_runs` | | | uma linha por execução (`source = 'all'`, `kind` `full`, `live` ou `backup`) e uma por fonte: início, fim, estado (`ok`, `failed`, `fallback`, `skipped`), contagens (`inserted`, `changed`, `unchanged`, `closed`) e erro |

O CPF não entra em claro: vira `cpf:<hash>` antes de gravar e antes da ligação entre bases.

**Fonte fora do ar.** Câmara, Senado, TSE, IBGE e Receita voltam do banco quando a leitura falha; municípios e checagens, quando a leitura e o cache próprio falham. A pauta do dia guardada cobre a primeira carga depois de um reinício. As assembleias seguem o fluxo de antes.

**Status público.** `PUBLIC_DIR/v1/status.json`, regravado a cada execução: `full`, `live` e `backup` (início, fim, estado e contagens da última), `lastFullOk` e, por fonte, a última execução e a última leitura `ok`. Sem mensagens de erro, caminhos ou segredos.

**Backup.** Depois da primeira carga completa bem-sucedida de cada dia (hora de Brasília), `VACUUM INTO` grava `DATA_DIR/backups/fiscal-AAAA-MM-DD.db` (`0600`), uma cópia consistente feita com o banco aberto, e os mais antigos que os `BACKUP_KEEP` mais novos são apagados. No container a pasta é o volume `./ingest-backups`; copie-a para fora da VPS de vez em quando.

**Restauração.** Com o serviço parado:

```sh
cd /opt/fiscal-api
docker compose stop fiscal-ingest
docker compose run --rm fiscal-ingest -restore /data/backups/fiscal-2026-10-25.db
docker compose start fiscal-ingest
```

O `-restore` confere `PRAGMA integrity_check` do backup, troca `fiscal.db` por escrita atômica e apaga `fiscal.db-wal` e `fiscal.db-shm`. Na próxima carga as fontes são relidas e o histórico continua a partir do backup. Para olhar o banco sem parar nada, abra um backup (`sqlite3 ingest-backups/fiscal-AAAA-MM-DD.db`), nunca o `fiscal.db` em uso.

### Rodar a carga local

```sh
cd server
gofmt -l . && go vet ./... && go test -race -count=1 ./...
PUBLIC_DIR=/tmp/fiscal/public DATA_DIR=/tmp/fiscal/data INGEST_UFS=ac INGEST_YEARS=2026 go run ./cmd/ingest -once
```

`-once` faz uma carga completa, o backup do dia e sai (código 1 se falhar); `-restore <arquivo>` troca o banco por um backup e sai; sem as flags, o processo fica no agendamento. `-check` é o healthcheck do container (heartbeat a cada minuto em `DATA_DIR/ingest-status.json`).

Carga real limitada de 2026-10-25 (AC, ano de 2026, TSE 2018, 2022 e 2026): 2 min 44 s, 51 pessoas, 974 votações, 1.127 arquivos, 7,8 MiB de JSON e 1,6 MiB em `.gz`; repetida sem mudança nas fontes, regravou só `meta.json`. A carga nacional baixa por volta de 100 MiB de arquivos da Câmara por ano e algumas centenas de MiB dos ZIPs do TSE (só os CSVs necessários), que ficam em `DATA_DIR/cache` e só são baixados de novo quando mudam.

Checagens reais de 2026-10-25, com os 513 deputados federais, os 81 senadores e o presidente e o vice no escopo: as 4 primeiras páginas (400 publicações de 2022 a março de 2023) deram 396 checagens, 174 ligadas a 20 pessoas (187 ligações) e 122 casos na revisão, em 3 s de leitura; a janela inteira (12 páginas, 1.152 checagens) ligou 404 checagens a 37 pessoas (424 ligações), com 269 casos na revisão e 112 checagens sem selo.

### Deploy da carga

Na VPS, ao lado da apuração e só com o ok do usuário: criar `/opt/fiscal-api/ingest-data` e `/opt/fiscal-api/ingest-backups` com dono 1000 e modo `700` e subir o serviço `fiscal-ingest` do `compose.yaml`. O container não abre porta, roda `read_only`, sem capacidades, com `mem_limit: 1536m`, e escreve só em `/data` e `/public`.

O Caddy precisa servir os novos arquivos estáticos antes do `handle /api/*` (proposta, ainda não aplicada):

```
	@data {
		method GET HEAD
		path_regexp data ^/api/v1/((meta|today|status)|(index|places|people|votes|agenda|money)/[a-z0-9/-]+)\.json$
	}
	handle @data {
		root * /opt/fiscal-api/public
		rewrite * /v1/{re.data.1}.json
		header Cache-Control "public, max-age=300, stale-while-revalidate=3600"
		file_server {
			precompressed gzip
		}
	}
```
