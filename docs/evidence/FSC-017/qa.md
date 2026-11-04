# QA da FSC-017: partido atual, retratos novos e alerta de carga

- **Canvas:** [FSC-017](../../../spdd/prompt/FSC-017-202611031133-[Feat]-current-party-and-load-alert.md)
- **Ambiente:** servidor na VPS, versões `8cb104bf3236` (`api` e `pages`) e `dc0598a0b0c1` (`ingest` e units); simulador "Fiscal iPhone Duo" (iOS 27.1) com os dados publicados; iPhone do usuário para o alerta.
- **Data:** 03/11/2026.
- **Capturas:** mostram só dados públicos, sem o apoio de ninguém.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 a 6 | Partido atual, histórico, Câmara e Senado, sem candidatura nova, assembleia | `go test ./internal/publicdata/` | passou em teste | `TestLinkUsesTheLatestCandidacyPartyForTSEOffices`, `TestLinkKeepsThePartyOfTheHouses`, `TestLinkAssemblyUsesTheLatestParty` |
| 7 | Nenhuma pessoa com dois partidos no publicado | `python3 scripts/party-check.py --published` | **pendente** | Ainda 259 em 03/11, antes da reconstrução. O código já está na VPS, e a reconstrução semanal (`memoria`) está prevista para 04/11, 00:20 de Brasília. Confirmar depois dela |
| 8 | Destaque, colegas e checagens com o mesmo partido | Teste e conferência no publicado | passou em parte | `TestBuildShowsTheCurrentPartyInEveryCardOfThePerson` cobre o índice, a página e a lista do estado; o destaque e os colegas usam o mesmo `card`, e as checagens usam `Primary().Party`, conferidos só na leitura do código. Falta o publicado, depois da mesma reconstrução |
| 9 | Quatro vices desenhados | Abrir a página de cada um com os dados publicados | passou | [Captura](portraits.png). Traços a partir das fotos oficiais do TSE, sem guardar as fotos |
| 10 | Retratos no publicado | `scripts/portrait-check.py --published` | passou | 2.362 pessoas, 0 sem traços, 0 problemas |
| 11 a 16 | Alerta: 6 falhas, aviso único, volta, dados velhos, sem tópico, ntfy fora | `go test ./deploy/`, também com `-race` | passou em teste | `server/deploy/load_alert_test.go`, com servidor falso. O título do aviso de dados velhos mudou depois do deploy e chega à VPS no próximo deploy de `units` |
| 11 | Aviso real no celular | `fiscal-load-alert.sh --test` | passou | O usuário viu a notificação às 12:54 no horário do celular, depois de assinar o tópico de novo no app ntfy. Uma falha real da carga não foi provocada |
| 17 | Medida dos destaques | Leitura na VPS | passou | 30 dias: 0 com peso 85, 0 com 80, 1 com 75 e no máximo 12 com 70, em 9 dias. Aproximado: o servidor não guarda o histórico, então a medida usa as ações mais pesadas de cada pessoa (741 arquivos) |
| 18 | Causa dos 401 e testes da regra | Log do Caddy e testes | passou em parte | 148 dos 149 têm a assinatura de rede do simulador, sem App Attest. O 401 não foi reproduzido ao vivo: 5 lançamentos no simulador não geraram registro. Testes: `HighlightAlertRuleTests` e `HighlightAlertCenterTests` |
| 19 | Runbook e backlog | Leitura | passou | Caso das imagens, filtro do cron, alerta e como conferir; App ID da Meta fora do backlog |
| 20 | Peso 70 entra, 69 não | Testes em Go e Swift | passou em teste | `TestEligibleAsksForTheMinimumWeight`, `theWeightMustReachTheMinimum`; `method/weight.json` publicado com 70 |
| 20 | Atividade ao Vivo real por push | Esperar um destaque de peso 70 ou mais no dia | **não verificado** | O início por push nunca aconteceu em produção, e nenhum destaque atual está na janela |
| 21 | Ajustes e método dizem 70 | Método publicado e código | passou em parte | `method/weight.json` confirmado. O texto de Ajustes está no código e no catálogo; a tela não foi aberta |
| 22 | `release.json` sem `origin` | Ler o publicado | passou | Release `20261103T170024Z-hot` sem o campo; valor efetivo `HOT_FROM_ORIGIN: "0"` na VPS; teste `TestHotDataStaysOnTheCDNByDefault` |
| 23 | VPS como reserva | Teste do app | passou em teste | `fallsBackWhenTheCDNIsDown`, em `PublicDataLayoutTests`, no `verify --full`. O caminho do app não mudou, e uma queda real do Pages não foi simulada |

**Verificações**
- `scripts/verify.sh --full`: ok, com 0 violações no lint, sobre `dc0598a` (commit às 12:43; o log do build marca 12:48, no fuso do Mac). Depois dele entraram canvases, este QA, o título do aviso, os modos do `party-check` e testes em Go, conferidos com `go test` em `./internal/publicdata/`, `./deploy/`, `./internal/highlightalert/` e `./cmd/ingest/`. O app não mudou desde então.
- Auditoria do plugin: sem violações.

**Lista antes do deploy**
- O usuário recebeu a lista das 427 pessoas que mudam de partido em CSV e respondeu "sim" em 03/11/2026, antes de qualquer deploy.

**Desvio do canvas**
- **Tópico no chat:** o nome do tópico do ntfy apareceu na conversa em que foi criado, porque o comando foi rodado pelo Claude Code. O canvas proíbe isso. A exceção está no Safeguard. Quem tiver o nome pode ler o estado da carga e mandar avisos falsos ao celular do usuário. O arquivo na VPS não mudou desde a criação. Ao ser perguntado, o usuário respondeu "ta certo", e a decisão final fica para o relatório da fase. O runbook explica como trocar.

**Não medido**
- Nenhum teste de carga foi feito. Os números de 50 milhões de usuários em `docs/backlog.md` e no ADR 0008 são estimativas.
