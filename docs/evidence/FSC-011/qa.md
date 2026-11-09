# QA da FSC-011: conteúdo, links dentro do app, Quem governa e gráficos

- **Canvas:** [FSC-011](../../../spdd/prompt/FSC-011-202611011855-[Feat]-navigation-links-charts-refinements.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado) com os dados publicados de 28/10/2026, e iPhone 17 Pro Max físico.
- **Aprovação do usuário no iPhone físico:** os seis pontos do roteiro entregue em 01/11/2026. Pediu um ajuste no gráfico do mandato ("encostando na barra de cima"), corrigido, e aprovou com "agora foi".

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Link abre dentro do app | Dinheiro > Quanto custa um mandato > Auxílio-moradia; fechar volta à mesma tela | passou | [captura](in-app-browser.png); processo `SafariViewService` em execução, sem MobileSafari |
| 2 | Link sobre uma folha aberta | Nenhuma folha do app tem link hoje; uma versão temporária, fora do commit, abriu uma folha com `ExternalLink`, tocou nele e fechou o navegador | passou | [folha](probe-sheet.png), [navegador sobre ela](probe-browser-over-sheet.png), `SafariViewService` em execução, sem erro de apresentação; ao fechar, a folha continua aberta |
| 3 | App Store sai do app | Política: `apps.apple.com` e `itunes.apple.com` | passou nos testes; não visto na tela | `InAppBrowserPolicyTests` no kit |
| 4 | Outro esquema fica com o sistema | Política: `mailto`, `tel`, `fiscal`, `file`, sem host | passou nos testes; não visto na tela | `InAppBrowserPolicyTests` no kit |
| 5 | Mac usa o navegador do sistema | Modificador sem efeito no macOS | só build; não visto na tela | `scripts/verify.sh --full` |
| 6 | Link mostra a seta | Atos do mandato, fonte, Fontes oficiais | passou | [captura](mandate-chart.png), [captura](content-from-profile.png) |
| 7 | Lint recusa `Link` solto | Regra `external_link_component` | passou | `scripts/lint.sh` com 0 violações depois da troca de todos os pontos |
| 8 | VoiceOver no link | Rótulo, traço de link e dica | passou em parte | `LinkAccessibilityTests` prova o traço de link e o rótulo. A dica "Abre no navegador" está só no código e no catálogo: o XCUITest não a lê, e o VoiceOver de verdade não rodou |
| 9 | Destaque abre o conteúdo | Hoje > Destaque do momento | passou | Aprovado no iPhone; manchete em texto simples |
| 10 | Região abre o conteúdo | Seguindo > Na sua região agora | passou | [cartão](region-card.png), [tela](content-from-region.png) |
| 11 | Proposta do perfil | Perfil > Propostas | passou | Aprovado no iPhone; `ProfileProposalRow` usa a mesma rota |
| 12 | Ação do perfil | Perfil > O que está fazendo > PEC 17/2026 | passou | [lista](profile-proposals.png), [tela](content-from-profile.png), sem botão do autor |
| 13 | Voto abre a votação | Destino único | passou | `ContentDetailModelTests`, `TodayModelTests` |
| 14 | Dinheiro e indicador abrem o conteúdo | Destino único | passou nos testes; os dados de hoje não têm esse tipo | `ContentDetailTests` |
| 15 | Campo ausente some | Modelo e tela sem etapa, data ou URL | passou | `ContentDetailTests`, `ContentDetailModelTests`; os blocos se ajustam em pares |
| 16 | Compartilhar só em Hoje | Hoje e link do widget têm o botão; região e perfil, não | passou | [estúdio](content-share.png), [região](content-from-region.png) |
| 17 | Link do widget | `fiscal://highlight/action-senado-9117720` | passou | [captura](content-from-widget-link.png); o toque no widget em si não foi feito |
| 18 | Destaque que saiu da lista | `fiscal://highlight/action-gone` | passou; sem rede, só nos testes | [captura](highlight-gone.png), `aFailureIsKeptForTheRetry` |
| 19 | Cartão sem vice centrado | Seguindo > Quem governa, Prefeitura de Boa Vista | passou | [captura](seat-centered.png), aprovado no iPhone |
| 20 | Cartão com vice igual | Governo do estado, ao lado | passou | [captura](seat-centered.png) |
| 21 | Gráfico do mandato | Folga acima do nome do cargo e legenda sem corte | passou | [captura](mandate-chart.png), aprovado no iPhone |
| 22 | Gráfico da cota | Sem siglas; a barra mostra o estado; cada estado fica exposto à acessibilidade | passou | [captura](quota-chart.png), aprovado no iPhone; `LinkAccessibilityTests` acha a barra "São Paulo" com o valor. O VoiceOver de verdade não rodou |

**Lacuna aceita no merge:** o usuário pediu o merge em 01/11/2026 sem o teste com o VoiceOver ligado. A dica "Abre no navegador" segue sem prova no aparelho.

**Não verificado:**
- VoiceOver ligado de verdade (a árvore de acessibilidade foi conferida por XCUITest) e fontes de acessibilidade na tela nova.
- Layout largo: iPad, Duo aberto e Mac na tela. O simulador do iPad não foi usado.
- visionOS só em build.
- Toque real no widget da tela inicial.

**Verificação automática:** o resultado final está no fim da [revisão](../../../spdd/review/FSC-011-202611012010-[Review]-navigation-links-charts-refinements.md). `scripts/ui-test.sh`: `LinkAccessibilityTests` e `testLaunchShowsFollowingAndOpensSettings` passam, este depois de pular o setup da Lente; `testTodayOpensTheLiveResults` segue falhando por não achar o botão de Apuração e está no backlog.

**Auditoria:** `bin/audit --hook` sem violações.
