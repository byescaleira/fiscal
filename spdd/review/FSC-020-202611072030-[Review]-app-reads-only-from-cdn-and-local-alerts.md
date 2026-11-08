# Revisão da FSC-020 contra o canvas

- **Canvas:** [FSC-020](../prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)
- **Análise:** [FSC-020](../analysis/FSC-020-202611042030-[Analysis]-app-reads-only-from-cdn-and-local-alerts.md)
- **Intervalo:** `refs/review/fsc-020-base..HEAD` (`993e841`). A base é sintética: `c6f3179`, o fim da FSC-017 (PR #16), juntado com `origin/development` (`1d1501d`).
- **Data:** 07/11/2026.
- **Revisor:** `byescaleira-workspace:spec-reviewer`, por leitura do código e dos testes, sem rodar build nem testes.

## Veredito: Needs Rework (3 críticos)

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 2 |
| Entities | desvio | 1 |
| Approach | desvio | 2 |
| Structure | ok | 0 |
| Operations | desvio | 1 |
| Norms | ok | 0 |
| Safeguards | ok | 0 |
| Sincronia | desvio | 2 |

## Achados

| Severidade | Arquivo | Achado | Próximo passo |
| --- | --- | --- | --- |
| crítica | `FiscalKit/Sources/FeatureRegion/RegionActivityLoader.swift` (`b0eecd7`) | **Acréscimo.** A Região passou a mostrar uma pessoa uma vez só, com espaço entre os cartões. O commit não traz `Canvas:`, a FSC-020 não cita a mudança e o canvas da Região não foi atualizado. | `spdd-prompt-update` no canvas da Região |
| crítica | Canvas, Entities | **Sincronia.** `HighlightAlertPlanner.plan` recebe `slots` e `excluding`, não `offset`, `now` e `calendar`. Faltam no diagrama: `HighlightAlertSlots`, `settle`, `deviceOffset`, `HighlightNotificationScheduling.pending`, `HighlightActivityTracking.isAvailable`, `activeHighlightIDs` e `HighlightAlertCenter.hold`, `resume` e `notificationsAreDenied`. | `spdd-sync` |
| crítica | `docs/evidence/FSC-020/qa.md` | **Omissão.** Faltam provas de três cenários. 29: nenhum teste de `races()` com a CDN fora usando o pacote offline. 30: nenhuma captura da apuração sem o botão de acompanhar. 32: as permissões não foram conferidas no build final. | Teste do 29; captura do 30 e conferência do 32 no QA |
| importante | `FiscalKit/Sources/FiscalDomain/PublicData/HighlightAlertHabit.swift:31-34` | **Divergência.** O mínimo de 5 aberturas em 3 dias conta também as aberturas das 22:00 às 06:59, que o cenário 38 diz que não contam. Com 4 aberturas noturnas e 1 diurna, o hábito sai de uma abertura só. | Corrigir o código |
| importante | `Fiscal/Fiscal/Info.plist`, `Fiscal/Fiscal/Fiscal.entitlements` | **Pergunta ao usuário.** O canvas tira `remote-notification` e `aps-environment`, mas o ADR 0015 diz que `remote-notification` serve à sincronização do iCloud. O risco de a sincronização do CloudKit parar de chegar em segundo plano não está listado. | Decisão do usuário, registrada no canvas e no ADR 0028 |
| importante | `qa.md` | **Omissão.** A operação 3 pedia o resultado da notificação agendada em segundo plano (cenário 20), que não foi registrado. Também faltam o toque com o app aberto (19), a Ilha expandida (21) e o modo silencioso (34). | Registrar como não medido, ou medir |
| importante | `qa.md` | **Omissão.** O `verify.sh --full`, o `go vet` e o `go test`, o `site-i18n.py check` e a rodada de revisão não estão registrados. | Registrar |
| informativa | `docs/web.md:102`, `docs/adr/0016`, `docs/adr/0007:115` | Ainda citam `FiscalWebBridgeURL` e a reserva em `FiscalAPIURL`. | Ajustar o texto |
| informativa | `server/internal/httpapi/server.go:12,70` | `livePrefix` e `RedactPath` só tratam rotas que não existem mais. | Remover |
| informativa | `FiscalKit/Sources/AppShell/Integrations/HighlightAlertCenter.swift:62` | `clearLegacy()` só roda com o app liberado. Com a atualização obrigatória ativa, o token e o `AppAttestKeyID` ficam no aparelho. | Mover o `clearLegacy()` para antes do `guard` |

## Definição de pronto

| Cenários | Situação |
| --- | --- |
| 1 a 18, 20, 22, 24 e 35 a 41 | Teste (`HighlightAlertPlanTests`, `HighlightAlertHabitTests`, `HighlightAlertCenterTests`, `SettingsModelTests`) |
| 19 | No aparelho, só com o app fechado |
| 21 | Tela de bloqueio no aparelho; a Ilha expandida e a silhueta de reserva não foram vistas |
| 23 | `TestPublicRoutesAreGone` |
| 25 e 31 | QA no aparelho e log da VPS |
| 26 | Diferença das páginas |
| 27 | Diferença das chaves |
| 28 | `aFailingCDNFallsBackToThePackWithoutAnotherAddress` e o teste de erro |
| 29, 30 e 32 | Sem prova |
| 33 | Depois do deploy, por decisão do usuário |
| 34 | Som e pt-BR no aparelho; o modo silencioso não foi testado |
| 42 | Simulador |

## Decisões implícitas da IA

- A notificação em primeiro plano usa `[.banner, .list]`.
- A Atividade usa `relevanceScore: 50`, e o `staleDate` é igual ao fim.
- O identificador da notificação é `fiscal.highlight.daily`.
- A limpeza da prateleira (`pruneShelf`) usa a data de modificação do arquivo.
- Se a notificação falha ao agendar, o plano mantém a anterior.
- `HighlightActivityState.title` usa `plainSummary`, que o cenário 34 cobre.

## Saída de escopo

- O commit `b0eecd7` da Região. O resto está nas Operations.

## Sem achado

- Os trailers `Canvas:` e `Canvas-update:` estão nos commits.
- As constantes batem com os Safeguards.
- Não há API nem símbolo inventado.
