# QA da FSC-012: fim da Lente e a página "Meu apoio"

- **Canvas:** [FSC-012](../../../spdd/prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado) com os dados publicados de 28/10/2026, e iPhone 17 Pro Max físico.
- **Usuário no iPhone físico:** a página aprovada na parada da operação 5 ("ficou bom"); pediu para a faixa de filtros não cortar e apontou a folha "Como medimos" em branco, e confirmou as duas correções ("deu certo aqui"). A retirada da Lente das outras telas ainda não foi vista no aparelho.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Abre sem setup | Abrir o app | passou em parte | `testANewInstallOpensStraightOnTheFirstTab`, sem apagar o app antes; instalação limpa de verdade não feita |
| 2 | Telas iguais com e sem apoio | Hoje, Votações, Dinheiro, Compare e Busca | passou | Os modelos não recebem o apoio, e a regra `support_stays_private` barrou um vazamento proposital; [Votações](votes.png), [Dinheiro](money.png) |
| 3 | Nada de "lente" | Catálogo e código | passou | Nenhum valor do catálogo cita lente; sobram `LensEntity`, os esquemas antigos e o host `lens` do `DeepLink` |
| 4 | Cor de destaque vale em todo o app | Ver as telas | passou | [Dinheiro](money.png), [Ajustes](settings.png) |
| 5 | Galeria sem sugestão | Estúdio no Pôster | passou nos testes; não visto na tela | `ArtistsModelTests`, `ShareModelTests` |
| 6 | `fiscal://lens` abre a página | Link | passou | `DeepLinkTests` |
| 7 | Entradas | Coração em Votações, linha em Ajustes, deep link | passou em parte | [Votações](votes.png), [Ajustes](settings.png); abri pelo link, o toque na linha não foi feito |
| 8 | Página sem escolha | Abrir vazia | passou | [captura](empty.png) |
| 9 | Editor e limites | Marcar pessoa e causas, sexta opção | passou | [editor](editor.png), `SupportEditorModelTests`, `SupportChoiceTests` |
| 10 | Desmarcar mantém seguido | Editor | passou | `savingFollowsWhoWasAddedAndRemovingKeepsFollowing` |
| 11 | Linha do tempo | Pessoa e causas reais | passou | [captura](timeline.png), `SupportTimelineTests` |
| 12 | Voto dividido em uma linha | Duas pessoas | passou nos testes; não visto na tela | `aVoteWhereTwoPeopleDifferIsOneLineWithBothBallots` |
| 13 | Filtros | Pessoa e causa | passou nos testes | `filtersKeepOnlyThePersonOrTheCause`, `anEmptyFilterExplainsWhy`; o usuário usou a faixa no aparelho |
| 14 | Cargo sem votos | Governador | passou nos testes | `anOfficeWithoutVotesSaysSo` |
| 15 | Destino da linha | Tocar | passou | `aLineOfVoteOpensTheVoteAndTheRestTheContent`, e o toque abriu o conteúdo no simulador |
| 16 | Limite de 100 | Muitos votos | passou nos testes | `theListStopsAtTheLimit` |
| 17 | Falha de rede | Cenário indisponível | passou nos testes | `withoutTheSourcesTheFailureIsKept` |
| 18 | Apagar | Confirmar | passou nos testes; não visto na tela | `erasingClearsTheChoice`, `erasingKeepsWhoThePersonFollows` |
| 19 | Acessibilidade | Fontes grandes, VoiceOver, Reduzir movimento | não executado | Falta rodar na página |
| 20 | Só no aparelho | Banco em disco | passou | `SupportPrivacyTests`, `DeviceStoreTests` |
| 21 | Apoio fora de cartaz, Spotlight, widget e notificação | Código | passou | A regra `support_stays_private` cobre features e `AppShell`, com `IntegrationCenterTests`; os widgets não leem o banco |
| 22 | Exportação | Exportar | passou | `exportsTheSupportAndTheFollowedPeopleAsJSON`, sem chave `lens` |
| 23 | Quem já tinha Lente | Banco da V2 em disco | passou | `aSecondVersionStoreOpensWithTheCurrentSchema` |

**Correções fora do canvas, pedidas pelo usuário:**
- A faixa de filtros corre até a borda da tela.
- As folhas "Como medimos" e do método de comparação não herdam mais texto branco dos cartões escuros; a primeira página rola em telas pequenas. [Captura](method-sheet.png).

**Não verificado:**
- VoiceOver, fontes de acessibilidade e Reduzir movimento na página.
- Layout largo: iPad, Duo aberto e Mac na tela. O visionOS só em build.
- Hoje, Perfil, Fiscalizar e Compartilhar sem a Lente: testes passam, mas não foram olhados na tela depois da retirada.
- Publicação do site: não feita, espera o ok.

**Auditoria:** `bin/audit --hook` sem violações.
