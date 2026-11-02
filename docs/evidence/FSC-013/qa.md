# QA da FSC-013: Feed como primeira aba e a aba Região

- **Canvas:** [FSC-013](../../../spdd/prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado), com os dados publicados e com os dados de teste (`-FiscalDataScenario normal`, `-FiscalFollowScenario`), e iPhone 17 Pro Max físico.
- **Usuário no iPhone físico:** viu o Feed na parada da operação 3, pediu para a lista carregar conforme a demanda e aprovou ("Ficou muito bom").
- **Capturas:** as de quem segue usam a lista fixa dos dados de teste; nenhuma mostra o apoio de alguém.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Abas e abertura | Abrir o app; ⌘1 a ⌘5 | passou no iPhone; Mac não executável aqui | `testLaunchShowsTheFeedAndOpensSettings`, `AppSectionTests`, [captura](feed-top.png). O app do Mac só abre assinado, e a assinatura falhou aqui ("No Accounts" no Xcode); a ordem e os grupos do Mac estão só em teste |
| 2 | Links novos e antigos | Abrir cada link | passou | `DeepLinkTests`; `fiscal://region` aberto no simulador |
| 3 | Widget e Siri abrem Região | Tocar no widget e pedir à Siri | não executável aqui | `IntegrationLink.region` e `FollowIntentTests`; o widget e a Siri não foram usados no aparelho |
| 4 | Região sem novidades | Abrir Região | passou | [captura](region.png), `RegionFollowingTests` |
| 5 | Barra do Feed | Ver coração e Ajustes | passou | [captura](feed-top.png), `testLaunchShowsTheFeedAndOpensSettings` |
| 6 | Apuração no topo | Cenário `close` | passou | [captura](feed-live.png), `aLiveRaceTakesTheTop`, `noElectionNoCard` |
| 7 | Destaque no topo, sem repetir | Abrir o Feed | passou | [captura](feed-top.png), `theLeadHighlightIsPinnedAndNotRepeated`, `aLeadVoteOfSomeoneFollowedKeepsTheirBallotInTheList` |
| 8 | Fatos por data | Seguir duas pessoas | passou | `FeedTimelineTests`, [captura](feed-following.png) |
| 9 | Motivo em cada linha; gasto só com o mês | Rolar a lista | passou em teste e em tela para o motivo | [captura](feed-following.png), anterior à correção do mês; `aMonthOfSpendingShowsTheMonthAndNotADay` cobre o mês e o ano. A nova data do gasto não foi vista na tela |
| 10 | Voto dividido em uma linha | Dados de teste | passou | `FeedTimelineTests`, [captura](feed-following.png) |
| 11 | Filtros | Tocar em cada um | passou | `followingBringsTheirFactsWithTheReason`, `emptyFilterExplainsWhy`, simulador |
| 12 | Destino de cada linha; link dentro do cartão | Tocar nas linhas; descer até uma checagem | passou em parte | [captura](feed-fact-check.png) e `testAFactCheckCardIsAsWideAsTheOtherCards`, para a mesma largura; `Route.destination` coberto em testes; no aparelho, só o que o usuário tocou ao aprovar, sem registro por tipo |
| 13 | Evento sem repetir | Montar a lista | passou | `FeedTimelineTests`, `theRaceEventIsALineOnlyWithoutARaceOnTop`; a linha "Apuração do segundo turno" vista sem apuração no topo |
| 14 | Ano anterior ao fim, sem mudar nada de lugar | Rolar até 2025 | passou | `loadingMoreAddsOlderYearsWithoutRepeatingAndEnds`, `whatIsOnScreenNeverMovesWhenMoreLoads`, e a lista chegou a 2025 na [captura](feed-fact-check.png) |
| 15 | Fim em 2023 | Rolar até o fim | passou em teste | `theEndOnlyShowsWhenNothingIsHidden`; a mensagem de 2023 não foi vista na tela |
| 16 | Sem seguidos | Abrir sem seguir | passou | [captura](feed-invite.png), `withoutFollowingThereAreRelevantLinesAndTheEnd` |
| 17 | Falha parcial | Serviço com falhas | passou em teste | `aMissingFileIsEmptyAndOnlyFailuresAreMissing`, `aFailureEverywhereReachesTheScreen`; aviso não visto na tela |
| 18 | Lista só muda ao abrir ou puxar | Ler o código | passou em revisão de código | Sem `task` periódica nos dados da lista; só a apuração atualiza sozinha |
| 19 | Selo no Feed | Marcar como visto | passou em teste | `seeingClearsTheBadge`; número na aba não visto na tela |
| 20 | Maior tamanho de texto e VoiceOver | XXXL no simulador | passou em parte | `testFeedRowsAreButtonsAndTheEndIsReachableAtTheLargestTextSize`, [apuração](feed-largest-text.png), [lista](feed-list-largest-text.png) e [destaque](feed-hero-largest-text.png). VoiceOver ligado não foi usado |
| 21 | Reduzir movimento | Ligar o ajuste no simulador e abrir o Feed | passou em parte | Com `ReduceMotionEnabled` no simulador, o Feed abriu com a apuração e o destaque. A transição da apuração passa a `identity` no código; o quadro a quadro não foi medido |
| 22 | Duo aberto, iPad e Mac | Abrir em cada um | passou em parte | Duo deitado (678 pt): coluna e trilho [no lugar](feed-landscape.png). Duo aberto, iPad e Mac não vistos: sem simulador de iPad nesta máquina e sem build assinado do Mac; os três compilam no `verify --full`. Abrir algo "ao outro lado" não foi testado nesta fase |
| 23 | Páginas de 20 | Rolar | passou | `theListShowsOnePageAtATime`, usuário no iPhone |
| 24 | Relevante não lê anos | Rolar no filtro | passou | `theRelevantFilterReadsNoOlderYear`, [captura](feed-end-relevant.png) |
| 25 | Seguir em outra aba | Seguir e voltar | passou em teste | `followingElsewhereReloadsOnlyWhenTheSetChanged`; não repetido na tela |

## Lacunas aceitas no merge

O usuário aceitou como risco, em 02/11/2026 ("pode fazer os dois merges e seguir para a FSC-014"): Mac, iPad e Duo aberto não vistos; VoiceOver ligado não usado; toque no widget e na Siri não feito; Reduzir movimento sem medir quadro a quadro; aviso de falha parcial, mensagem de 2023, número na aba e seguir em outra aba só em teste.

## O que os testes acharam

- O cabeçalho da apuração quebrava "Presidente", "turno" e "AO VIVO" no meio no maior tamanho de texto, e o cartão não tinha o traço de botão. Corrigidos.
- O teste migrado de falha parcial mostrou que quem falhava só em parte não entrava no aviso. Agora qualquer falha entra, e o aviso toma o lugar da mensagem de fim, para o fim não dizer mais do que se sabe.
- No maior tamanho de texto, o rodapé do destaque alargava o cartão além da coluna, os filtros passavam da tela e os detalhes cortavam. Corrigidos: o rodapé quebra entre palavras, os filtros rolam de lado e o texto não corta.
- Uma checagem de 2025 aparecia logo depois de janeiro de 2026 e pulava para baixo quando o ano de 2025 carregava. Agora as linhas de um ano ainda não lido esperam esse ano.
- Item de outro ano aparecia sem o ano. Agora o ano aparece.
- `testTodayOpensTheLiveResults`, que já falhava, foi reescrito como `testTheFeedOpensTheLiveResults` e passa.

## Limite conhecido

- No Duo dobrado, ao rolar para cima, o sistema devolve a área da barra de navegação e os filtros fixos descem 58 pt, com um espaço branco acima, porque os botões dessa barra ficam no trilho lateral. Sem o fundo dos filtros, os cartões passariam por esse espaço. Fica no backlog.
