# Dados públicos

Os arquivos estáticos que o app lê para tudo que não é a apuração: perfis, votações, pauta, dinheiro, lugares, Hoje, destaques, indicadores e a Memória. Saem da carga das fontes oficiais na VPS e ficam na CDN `dados.fiscal.byescaleira.com` (Cloudflare Pages), com os arquivos do dia também na VPS. As decisões estão em [ADR 0002](../adr/0002-static-first-server.md), [0006](../adr/0006-ingest-sqlite-store.md), [0007](../adr/0007-pages-cdn-phased-ingest.md) e [0008](../adr/0008-smart-sync.md); o que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **Nada calculado por acesso.** O servidor prepara tudo antes e publica arquivos; o app só faz `GET`.
- **Sempre no ar.** Cada release é validada e comparada com a anterior antes de publicar; release ruim não substitui a boa.
- **Sem rede, o que já veio.** O app serve a cópia guardada e avisa, nunca uma tela vazia sem motivo.
- **Pedido sem identidade.** Nenhum pedido de dado público leva conta, token ou identificador do aparelho.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` (`PublicData/`) | Tipos do contrato (`PersonCard`, `Profile`, `VoteSummary`, `VoteDetail`, `MoneyOverview`, `TodayDigest`…), `PublicDataService` (caminhos), `PublicDataError`, `PublicFormat`, `OfflinePack` |
| `FiscalData` (`PublicData/`) | `PublicDataClient`, `PublicDataLayout` (`v2` e agrupamentos), pacote offline (`OfflinePackPlan`, `OfflinePackStore`), `ShowcasePublicData` (Debug) |
| `AppShell` (`Offline/`) | `OfflineDataCenter` e a tarefa em segundo plano ([ADR 0015](../adr/0015-background-fetch-offline-pack.md)) |
| `server/` | `cmd/ingest` (`fiscal-ingest`), `cmd/pages` (`fiscal-pages`), `internal/ingest`, `internal/publicdata`, `internal/site`, `internal/pages` e `internal/sources/*` |

## Mecânicas e regras

### Endereços e versão

| Chave do `Info.plist` | Valor | Uso |
| --- | --- | --- |
| `FiscalDataURL` | `https://dados.fiscal.byescaleira.com` | CDN, layout `v2` |
| `FiscalAPIURL` | `https://fiscal.byescaleira.com/api` | Arquivos do dia (origem) e o layout antigo `v1` |

- O app lê `v2/release.json` (8 s de limite) e usa o `v2` só com resposta 200 e `layout == "v2"`; o resultado vale 600 s quando a release está ao vivo e 120 s quando não, guardado em `PublicDataLayoutLive`. Sem `v2`, cai para `FiscalAPIURL/v1/<caminho>`.
- O bloco `origin` da release lista os arquivos quentes (`today.json`, `agenda/today.json`, `votes/recent.json`) e `onMissing` (`votes/`), lidos primeiro na VPS com 6 s de limite e `maxAge` de 30 s (`HOT_FROM_ORIGIN=1`).
- No `v2`, perfis vêm agrupados em `people/{slug}.json` (`{profile, files}`), cidades em `places/city/{ibge}.json` (`{place, people}`), o índice de pessoas por cidade em 256 baldes e as votações por id em 512 baldes (2 primeiros bytes do SHA-256, módulo o número de baldes).

### Arquivos

| Família | Caminhos |
| --- | --- |
| Índices | `meta.json`, `index/people.json`, `index/places.json`, `index/facts.json` |
| Lugares | `places/{uf}.json`, `places/city/{ibge}.json` |
| Pessoas | `people/{slug}.json` e, por ano, `votes-`, `proposals-`, `speeches-`, `expenses-{ano}.json`; `checks.json`, `actions.json`, `context.json` |
| Votações e pauta | `votes/recent.json`, `votes/{id}.json`, `agenda/today.json` |
| Dinheiro | `money/overview.json`, `money/mandate-cost.json`, `money/places.json` |
| Hoje e método | `today.json`, `highlights.json`, `method/weight.json` |
| Indicadores | `indicators/index.json`, `indicators/{id}.json` |
| Memória | `history/elections/index.json`, `history/elections/{id}.json`, `history/periods.json`, `history/study.json` |
| Apuração | `races.json` ([live-results.md](live-results.md)) |

### Cache

- `URLCache` de 8 MB em memória e 128 MB em disco (`Caches/PublicData`), 20 s de limite por pedido e `If-None-Match` com o `ETag`; 12 respostas recentes ficam 30 s em memória.
- Cabeçalhos da CDN (`_headers`): `races` 10 s; `meta`, `today`, `highlights`, `status` e `release` 60 s; índices e pauta 300 s; pessoas, votações, lugares, dinheiro, método e indicadores 3.600 s; Memória 86.400 s.

### Erros

| `PublicDataError` | Quando | O que a pessoa lê |
| --- | --- | --- |
| `notFound` | HTTP 404 ou 410 | "Este dado ainda não foi publicado." |
| `rejected` | Outro 4xx, menos 429 | "Não foi possível falar com o servidor de dados públicos. Tente de novo daqui a pouco." |
| `unavailable` | 429, 5xx ou falha de rede com cópia ausente | igual ao anterior |
| `offline` | Sem rede e fora do pacote offline | "Isso não está salvo para uso offline. Conecte-se à internet para ver." |
| `invalidData` | Formato que o app não lê | "Os dados públicos chegaram num formato que o Fiscal não consegue ler." |

- Com falha e cópia guardada, o app mostra a cópia e marca o aviso offline (`OfflineNotice`); a tela usa `PublicDataContent` para carregando, erro com "Tentar novamente" e vazio.

### Pacote offline

- Ao abrir, atualiza se a última vez tem mais de 600 s; em segundo plano, `BGAppRefreshTask` `com.byescaleira.fiscal.offline-refresh` com início depois de pelo menos 4 h.
- Leva meta, índices de pessoas e lugares, Hoje, pauta, destaques, votações recentes e `races.json`; a UF e a cidade de casa; até 40 pessoas (seguidas, apoiadas na Lente e até 12 representantes); orçamento de 12 MiB.
- Fica em `Application Support/OfflinePack`, fora do backup; release igual reaproveita os arquivos.

### Carga e publicação

- Cadências (`internal/ingest/cadence.go`, horário de Brasília):

| Job | Quando |
| --- | --- |
| `hot` (pauta e votações do dia) | A cada 5 min de segunda a sexta, das 9 h às 24 h; de hora em hora fora disso |
| `destaques` | A cada 20 min, só quando chega votação nova |
| `checagens` (Comprova) | A cada 45 min, das 7 h às 24 h |
| `repercussao` | A cada 3 h |
| `senado`, `assembleias`, `camara`, `sidra` | Todo dia, 01:10, 02:00, 05:00 e 03:30 |
| `anp`, `receita` | Segunda, 03:20 e 03:40 |
| `cidades`, `tse` | Sábado 00:20 e domingo 00:20 |
| `memoria` (reconstrução completa) | Quarta, 00:20 |
| `historia` | Dia 1 de cada mês, 03:50 |
| `apuracao` | A cada 20 s, só nos dias de eleição |

- Cada fonte só é baixada quando muda; o SQLite guarda o histórico e os arquivos saem dele ([ADR 0008](../adr/0008-smart-sync.md)).
- `fiscal-pages` publica no Pages no máximo uma vez por hora (`PAGES_DATA_INTERVAL`), até 400 deploys por dia e 450 por mês, com 3 tentativas e 30 s entre elas.
- O plano Free do Pages aceita 20.000 arquivos; o site fica em até `SITE_MAX_FILES` (18.000 por padrão, de 100 a 20.000), com 9 arquivos vivos por release. Queda de 20% ou mais no número de arquivos bloqueia a publicação, e `meta.json`, `index/people.json` e `today.json` são obrigatórios.

## Construção

1. **Domínio:** `PublicDataDecodingTests`, `PublicFormatTests`, `VoteSummaryRelatedTests` em `FiscalDomainTests`.
2. **Dados:** `PublicDataClientTests`, `PublicDataLayoutTests`, `PublicDataOriginTests`, `OfflinePackTests`, `PublishedContractTests`, `PublishedCompletenessTests` e `ShowcasePublicDataTests` em `FiscalDataTests`.
3. **Debug:** `-FiscalDataScenario normal|empty|offline|longNames|unavailable` troca o cliente pelo `ShowcasePublicData`.
4. **Servidor:** `internal/ingest`, `internal/publicdata`, `internal/site`, `internal/pages` e `internal/sources/*`, com `go test ./...` (no `scripts/verify.sh`).

## O que fica com você

- Deploy da carga e do `fiscal-pages` na VPS e o token do Cloudflare ([runbook](../server-runbook.md)).
- O DNS de `dados.fiscal.byescaleira.com` (CNAME na Vercel para o Pages).

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md), com o [contrato](../changes/archive/2026-10-29-app-1.0/contract.md) original em `v1` |
| 2026-10-26 | [0008](../adr/0008-smart-sync.md), [0007](../adr/0007-pages-cdn-phased-ingest.md) |
| 2026-10-25 | [0006](../adr/0006-ingest-sqlite-store.md), [0005](../adr/0005-data-ingest-process.md), [0002](../adr/0002-static-first-server.md) |
