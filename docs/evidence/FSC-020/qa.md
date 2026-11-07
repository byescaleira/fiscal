# QA da FSC-020: o app lê só a CDN e os alertas são locais

- **Canvas:** [FSC-020](../../../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)
- **Ambiente:** iPhone 17 Pro Max do usuário (iOS 27.3), build DEBUG da `feature/local-highlight-alerts` instalado por `scripts/device.sh`; simulador iPhone para os textos de Ajustes; log de acesso do Caddy na VPS (`/var/log/fiscal-access.log`), só leitura.
- **Data:** 05/11/2026 a 07/11/2026, no horário do aparelho (UTC-4).
- **Capturas:** nenhuma versionada. O teste no aparelho foi visto pelo usuário e relatado na conversa.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 25 | Atividade e notificação com o app fechado e a tela bloqueada | Lançar com `-FiscalAlertTestSeconds` e `-fiscal.highlightAlerts.shown "()"`, fechar o app e bloquear a tela | passou | 05/11, segunda tentativa: a Atividade apareceu e a notificação chegou depois. O usuário: "chegou a atividade com o bonequinho e a notificação" e "continua na tela". Na primeira tentativa, às 17:07, nada chegou porque os dois destaques já estavam em `shown` desde o teste da manhã, o que é o comportamento certo; daí a sobreposição de `shown` no lançamento |
| 21 | Bonequinho na tela de bloqueio | Mesmo roteiro | passou em parte | Visto na tela de bloqueio. A Ilha expandida não foi aberta; silhueta e destaque sem pessoa só em teste (`thePortraitIsPreparedBeforeScheduling`) |
| 34 | Título, subtítulo, pt-BR e som padrão | Mesmo roteiro | passou | O usuário: "tocou o som, tudo em português". O modo silencioso não foi testado |
| 19 | Toque na notificação abre o destaque | Tocar na notificação entregue | passou depois da correção | O primeiro toque fechou o app (SIGABRT): o iOS chamava o delegado fora da thread principal. Corrigido em `cabbd8f` com o delegado no ator principal; depois de reinstalar, o usuário: "deu certo agora". O toque com o app aberto não foi testado no aparelho |
| 31 | Nenhum pedido do app para `fiscal.byescaleira.com/api` | Log de acesso da VPS, agrupado por agente | passou | **07/11:** depois do merge da `development` (`dcfdb79`), o build foi instalado às 18:53, e o usuário abriu Feed, Região, Pessoa, Votações, Apuração e Ajustes. De 18:53 a 19:02, o log teve 2 pedidos, ambos do robô da Apple (`AASA-Bot`) buscando o arquivo de associação, e **0 pedidos** com agente `Fiscal/`. **05/11:** de 11:19 a 21:21, com o build anterior desta branch, também 0. Das 21:21 de 05/11 às 16:34 de 06/11 houve pedidos (`attest/challenge`, `attest/keys`, `highlight-activities`, `races`) do mesmo iPhone (Darwin 27.3.0), vindos de um build de outra branch, sem nenhuma dessas rotas no código desta (`grep` em `Fiscal/` e `FiscalKit/Sources`, também depois do merge). Os pedidos `Fiscal/24` (Darwin 27.2.0) são de um build antigo em outro aparelho. Os links do site, da privacidade e do suporte não foram abertos |
| 42 | Textos sem hora e "Notificação de destaque" | Abrir Ajustes no simulador | passou | Textos novos no catálogo; nenhum cita hora |
| 35 a 41 | Horário pelo hábito | Testes | passou em teste | `HighlightAlertHabitTests` (7), `HighlightAlertCenterTests.openingKeepsTheHabitOnlyWhileAnAlertIsOn`. O agendamento real ao longo de dias não foi observado |
| 24 | Token antigo e `AppAttestKeyID` apagados | Teste | passou em teste | `HighlightAlertPlanTests.theLegacyTokenAndAttestKeyAreErased`. As preferências do aparelho não foram lidas depois da abertura |
| Região | Dois cartões da mesma pessoa em "Na sua região agora" | Teste e iPhone | passou em teste | Relato do usuário em 05/11. Corrigido em `b0eecd7`: uma pessoa aparece uma vez e o segundo cartão ganha espaço acima. `RegionHighlightPickTests`. O espaço entre dois cartões com dados reais não foi visto, porque hoje só há uma pessoa de MS |

**Verificações**
- `scripts/lint.sh`: 0 violações. `scripts/build.sh Debug ios`: sem warnings.
- Testes afetados: `HighlightAlertHabitTests`, `HighlightAlertPlanTests`, `HighlightAlertCenterTests` (24), `FeatureSettingsTests` (34) e `FeatureRegionTests` (29), todos passaram.
- `scripts/verify.sh --full` fica para o fechamento (operação 11).

**Achado fora do escopo**
- `https://fiscal.byescaleira.com/` e o arquivo de associação da Apple (`/.well-known/apple-app-site-association` e `/apple-app-site-association`) respondem 404 na VPS, conferido de fora em 07/11. No log, todo pedido desse arquivo deu 404 desde 01/11. Sem ele, os links universais não abrem o app. Entra na decisão da operação 10 sobre tirar o site e o arquivo da VPS.

**Não medido**
- O tempo de abertura em branco no aparelho.
