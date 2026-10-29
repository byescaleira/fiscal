# Apuração ao vivo

A apuração das eleições com os números oficiais do TSE: a tela Apuração (em Fiscalizar › Eleições e no card de Hoje) e a Atividade ao Vivo de cada disputa na tela de bloqueio e na Dynamic Island, atualizada pelo servidor por push. As decisões estão em [adr/](../adr/README.md); o que falta fazer está em [backlog.md](../backlog.md).

## Princípios

- **Só o número oficial.** O app mostra o que o TSE publicou, com a hora do arquivo; sem projeção, pesquisa ou "tendência" ("sem projeções nem pesquisas").
- **Mesma cor para cada candidato, para todo mundo.** A cor é a do partido (`PartyPalette`), nunca a da Lente.
- **O servidor só publica e empurra.** O TSE é lido uma vez no servidor; o app lê arquivos estáticos e recebe push, nunca consulta o TSE ([ADR 0002](../adr/0002-static-first-server.md)).
- **Nada da pessoa vai junto.** O registro da Atividade ao Vivo leva só o token de push, a disputa e o ambiente, protegido por App Attest.

## Onde fica

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` (`LiveResults/`) | `Race`, `RaceCandidate`, `Race+Decision` (regra de decidido e de vencedor), `RaceActivity` (estado e relevância da Atividade) |
| `FiscalData` (`LiveResults/`) | `LiveResultsClient` (leitura e registro de tokens), `AppAttestor` |
| `FeatureLiveResults` | `LiveResultsModel`, `LiveResultsScreen`, `RaceDetailScreen`, `RaceActivities` (início, fim e tokens) |
| `Fiscal/FiscalWidgets` | `RaceLiveActivity`, `RaceWinnerLockScreen`, `RaceBoard` |
| `AppShell` | `Route.races` em Fiscalizar; `fiscal://races` |
| `server/` (`cmd/server`, imagem `fiscal-api`) | Leitura do TSE, arquivos `v1/races*.json`, registro de tokens, App Attest e push APNs |

## Mecânicas e regras

### Disputas e leitura do TSE

- A eleição de 2026 tem 7 disputas no 2º turno: `presidente-br` e governador de AC, AM, DF, ES, RN e TO.
- O servidor lê `https://resultados.tse.jus.br/oficial/ele2026` a cada 20 s (`POLL_INTERVAL`, de 5 s a 10 min), com 10 s de limite por pedido, e grava `PUBLIC_DIR/v1/races.json` e `races/{id}.json`, com `.gz`. Só empurra push quando o placar muda e para depois do fim.
- Na carga de dados, o job `apuracao` roda a cada 20 s só nos dias de eleição (2026-10-04 e 2026-10-25).

### O que o app lê

1. `v2/races.json` na CDN de dados, usado só se foi buscado há no máximo 300 s ou se nenhuma disputa está ao vivo.
2. Senão, `GET /api/v1/races` em `FiscalAPIURL` (`https://fiscal.byescaleira.com/api`), com 15 s de limite.
3. Sem rede, o `races.json` do pacote offline, com o aviso "Sem conexão. Mostrando os últimos números recebidos."

- A tela atualiza a cada 15 s enquanto está aberta e ao puxar para baixo. `GET /api/v1/races/{id}` responde 503 `not_ready` com `Retry-After: 20` antes do primeiro arquivo.

### Tela

- O cartão principal é o de presidente; as outras disputas ficam agrupadas por região (N, NE, CO, SE, S), com filtros por região e por situação (todas, apurando, decididas).
- O detalhe tem Candidatos, Votos e eleitores e Apuração. No 1º turno, quando não é um duelo de dois, uma linha tracejada marca 50% dos válidos.
- Quando uma disputa vira final com a tela aberta, o VoiceOver anuncia.

### Decidido e vencedor

| Situação | Resultado |
| --- | --- |
| Disputa `final`, 100% apurado ou algum candidato eleito | decidida |
| Candidato marcado eleito pelo TSE | vencedor |
| Decidida sem eleito, no 2º turno ou com até 2 candidatos | vencedor = o primeiro |
| Decidida sem eleito, no 1º turno com mais de 2 candidatos | sem vencedor (vai ao 2º turno) |

- A disputa com vencedor vira o cartaz de vitória no compartilhar ([share-cards-and-art.md](share-cards-and-art.md)).

### Atividade ao Vivo

- A pessoa segue uma disputa na tela; o app inicia a Atividade com `pushType: .token` e, se o sistema recusar, sem push.
- Fica velha (`staleDate`) 600 s depois da última atualização; relevância 100 para presidente e 50 para governador.
- Atualização por push: prioridade baixa e `stale-date` de agora + 10 min. Fim: `event: end`, prioridade alta, alerta "Resultado" / "<Nome> foi eleito(a)" (ou "Apuração encerrada") e `dismissal-date` de agora + 4 h (14.400 s).
- Parar de seguir encerra a Atividade na hora e remove o token.

### Registro do token

- O token (hex) espera numa fila e vai em `POST /api/v1/live-activities` com `{raceId, pushToken, environment, challenge}`; o ambiente é `development` em Debug e `production` no resto. Ao encerrar, `DELETE /api/v1/live-activities` com o mesmo corpo.
- O servidor aceita corpo de até 4 KiB e token de 32 a 400 caracteres hex; guarda disputa, token, ambiente e data em `registrations.json`, por até 12 h, com no máximo 50.000 registros e 20 por origem (IP com hash e sal, não gravado). Erros: 409 `token_bound_to_other_race`, 429 `too_many_registrations`, 507 `capacity_reached`.
- Token que o APNs recusa (`BadDeviceToken`, `Unregistered`, `ExpiredToken`) é apagado.
- Limites por IP: 120 leituras e 120 escritas por minuto; sem App Attest, 10 por minuto.

### App Attest

- O app pede um desafio (`POST /api/v1/attest/challenge`, válido por 2 min, até 8 abertos por cliente), atesta a chave uma vez (`POST /api/v1/attest/keys`) e guarda o id da chave; cada registro leva `X-Fiscal-Attest-Key` e `X-Fiscal-Attest-Assertion`.
- Com `401 attest_unknown_key`, o app esquece a chave e tenta de novo uma vez.
- Modos do servidor: `off`, `optional` (padrão quando há app id) e `required` (na VPS desde 2026-10-26). Ambiente de desenvolvimento só com `APPATTEST_ALLOW_DEVELOPMENT=1`. Chave sem uso por 400 dias sai de `attest-keys.json`.
- O app usa o ambiente `production` do App Attest (`com.apple.developer.devicecheck.appattest-environment`).

## Construção

1. **Domínio:** `RaceTests`, `RaceScenarioTests` e `RaceActivityPlanTests` em `FiscalDomainTests`.
2. **Dados:** `LiveResultsClientTests` e `ShowcaseLiveResultsTests` em `FiscalDataTests`; cenários de tela com `-FiscalLiveScenario` em Debug.
3. **Feature:** `LiveResultsModelTests`; `TodayRaceBoardTests` para o card de Hoje.
4. **Servidor:** `internal/tse`, `internal/live`, `internal/store`, `internal/apns`, `internal/appattest` e `internal/httpapi`, com `go test ./...`.
5. **Textos:** pt-BR no catálogo do app e no dos widgets.

## O que fica com você

- Chave APNs em `/opt/fiscal-api/secrets/apns.p8` e o deploy do `fiscal-api` na VPS ([runbook](../server-runbook.md)).
- Teste ponta a ponta no iPhone físico antes de cada eleição ([backlog](../backlog.md)).

## Histórico

| Data | Mudança ou ADR |
| --- | --- |
| 2026-10-29 | [`app-1.0`](../changes/archive/2026-10-29-app-1.0/proposal.md) |
| 2026-10-26 | [0007](../adr/0007-pages-cdn-phased-ingest.md) |
| 2026-10-25 | [`live-results`](../changes/archive/2026-10-29-live-results/proposal.md) |
| 2026-10-25 | [0002](../adr/0002-static-first-server.md) |
