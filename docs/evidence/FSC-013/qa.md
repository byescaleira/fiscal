# QA da FSC-013: Feed como primeira aba e a aba Região

- **Canvas:** [FSC-013](../../../spdd/prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado), com os dados publicados e com os dados de teste (`-FiscalDataScenario normal`, `-FiscalFollowScenario`), e iPhone 17 Pro Max físico.
- **Usuário no iPhone físico:** viu o Feed na parada da operação 3, pediu para a lista carregar conforme a demanda e aprovou ("Ficou muito bom").
- **Capturas:** as de quem segue usam a lista fixa dos dados de teste; nenhuma mostra o apoio de alguém.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Abas e abertura | Abrir o app; ⌘1 a ⌘5 | passou no iPhone; Mac não visto | `testLaunchShowsTheFeedAndOpensSettings`, `AppSectionTests`, [captura](feed-top.png) |
| 2 | Links novos e antigos | Abrir cada link | passou | `DeepLinkTests`; `fiscal://region` aberto no simulador |
| 3 | Widget e Siri abrem Região | Tocar no widget e pedir à Siri | não executável aqui | `IntegrationLink.region` e `FollowIntentTests`; o widget e a Siri não foram usados no aparelho |
| 4 | Região sem novidades | Abrir Região | passou | [captura](region.png), `RegionFollowingTests` |
| 5 | Barra do Feed | Ver coração e Ajustes | passou | [captura](feed-top.png), `testLaunchShowsTheFeedAndOpensSettings` |
| 6 | Apuração no topo | Cenário `close` | passou | [captura](feed-live.png), `aLiveRaceTakesTheTop`, `noElectionNoCard` |
| 7 | Destaque no topo, sem repetir | Abrir o Feed | passou | [captura](feed-top.png), `theLeadHighlightIsPinnedAndNotRepeated` |
| 8 | Fatos por data | Seguir duas pessoas | passou | `FeedTimelineTests`, [captura](feed-following.png) |
| 9 | Motivo em cada linha | Rolar a lista | passou | [captura](feed-following.png) |
| 10 | Voto dividido em uma linha | Dados de teste | passou | `FeedTimelineTests`, [captura](feed-following.png) |
| 11 | Filtros | Tocar em cada um | passou | `followingBringsTheirFactsWithTheReason`, `emptyFilterExplainsWhy`, simulador |
| 12 | Destino de cada linha | Tocar nas linhas | passou em parte | `Route.destination` coberto em testes; no aparelho, só o que o usuário tocou ao aprovar, sem registro por tipo |
| 13 | Evento sem repetir | Montar a lista | passou | `FeedTimelineTests` |
| 14 | Ano anterior ao fim | Rolar até o fim | passou em teste | `loadingMoreAddsOlderYearsWithoutRepeatingAndEnds`; a leitura na tela não foi vista |
| 15 | Fim em 2023 | Rolar até o fim | passou em teste | `theEndOnlyShowsWhenNothingIsHidden`; a mensagem de 2023 não foi vista na tela |
| 16 | Sem seguidos | Abrir sem seguir | passou | [captura](feed-invite.png), `withoutFollowingThereAreRelevantLinesAndTheEnd` |
| 17 | Falha parcial | Serviço com falhas | passou em teste | `aMissingFileIsEmptyAndOnlyFailuresAreMissing`, `aFailureEverywhereReachesTheScreen`; aviso não visto na tela |
| 18 | Lista só muda ao abrir ou puxar | Ler o código | passou em revisão de código | Sem `task` periódica nos dados da lista; só a apuração atualiza sozinha |
| 19 | Selo no Feed | Marcar como visto | passou em teste | `seeingClearsTheBadge`; número na aba não visto na tela |
| 20 | Maior tamanho de texto e VoiceOver | XXXL no simulador | passou em parte | `testFeedRowsAreButtonsAndTheEndIsReachableAtTheLargestTextSize`, [captura](feed-largest-text.png). VoiceOver ligado não foi usado |
| 21 | Reduzir movimento | Ligar o ajuste | não executado | A lista não anima; o selo e os heróis usam `ReducesMotion` no código |
| 22 | Duo aberto, iPad e Mac | Abrir em cada um | não executado | Compilado para macOS e visionOS no `verify --full`; sem simulador de iPad nesta máquina; layout largo não visto |
| 23 | Páginas de 20 | Rolar | passou | `theListShowsOnePageAtATime`, usuário no iPhone |
| 24 | Relevante não lê anos | Rolar no filtro | passou | `theRelevantFilterReadsNoOlderYear`, [captura](feed-end-relevant.png) |
| 25 | Seguir em outra aba | Seguir e voltar | passou em teste | `followingElsewhereReloadsOnlyWhenTheSetChanged`; não repetido na tela |

## O que os testes acharam

- O cabeçalho da apuração quebrava "Presidente", "turno" e "AO VIVO" no meio no maior tamanho de texto, e o cartão não tinha o traço de botão. Corrigidos.
- O teste migrado de falha parcial mostrou que quem falhava só em parte não entrava no aviso. Agora qualquer falha entra, e o aviso toma o lugar da mensagem de fim, para o fim não dizer mais do que se sabe.
- `testTodayOpensTheLiveResults`, que já falhava, foi reescrito como `testTheFeedOpensTheLiveResults` e passa.

## Limite conhecido

- No Duo dobrado, ao rolar para cima, o sistema devolve a área da barra de navegação e os filtros fixos descem 58 pt, com um espaço branco acima, porque os botões dessa barra ficam no trilho lateral. Sem o fundo dos filtros, os cartões passariam por esse espaço. Fica no backlog.
