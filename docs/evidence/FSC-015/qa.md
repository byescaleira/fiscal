# QA da FSC-015: barra do topo, votações, região e ícones das abas

- **Canvas:** [FSC-015](../../../spdd/prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado) com os dados de teste (`-FiscalDataScenario normal`, `-FiscalFollowScenario normal`), e iPhone 17 Pro Max físico, com os dados reais.
- **Usuário no iPhone físico:** viu o detalhe da votação na parada da operação 5 e pediu o ajuste do "Outros". Na parada da operação 9, disse "ficou bom" sobre Votações, Região, a tela nova, as abas e as barras, e pediu o pin com o círculo na aba Região.
- **Capturas:** usam a lista fixa dos dados de teste; nenhuma mostra o apoio de alguém.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Barra da votação e atalhos | Rolar e tocar num atalho | passou | `testTheBarKeepsTheScoreAndJumpsToItsPart`, [barra](vote-sticky-header.png), [salto](vote-sticky-parties.png), iPhone |
| 2 | Barra some no topo, sem pular | Voltar ao topo | passou em parte | `theBarAppearsOnlyAfterTheHeroLeavesAndKnowsWhereAChapterIs`; o usuário viu no iPhone. A ausência de pulo não tem medida automática |
| 3 | Barra da corrida | Rolar | passou em parte | Simulador, com "Presidente · Brasil" e "87,0% apurado", sem atalhos. Sem teste de interface nem captura versionada. O usuário disse "ficou bom" sobre as barras no iPhone |
| 4 | Barra das notas | Rolar | passou em parte | Simulador, com nome, ano com o filtro e total, sem atalhos. Sem teste de interface nem captura versionada |
| 5 | Sem barra em Votações e no Feed | Rolar | passou em parte | [Votações](votes-top.png) sem a barra no código e no simulador. As outras abas foram lidas no código |
| 6 | Página do político igual | Testes da `FSC-014` | passou em parte | `ProfileChaptersTests`, sem mudar os testes; iPhone. Nos tamanhos de acessibilidade, a barra agora limita o texto, então o layout muda neles (exceção registrada em Norms) |
| 7 | Reduzir movimento | Ligar no simulador e tocar num atalho | passou em parte | No código, a barra e os saltos usam animação nula. Com o ajuste ligado, a barra apareceu; o instante do salto não foi capturado |
| 8 | Ordem do detalhe | Abrir e rolar | passou | [Topo](vote-top.png), `aNominalVoteHasChaptersAndTheListOfVotes`, simulador. "Quem você apoia" não foi visto com uma escolha, para não expor apoio em captura |
| 9 | "Ver os 513 votos" | Tocar | passou | `testSeeingEveryVoteOpensTheListWithItsFilters`, [captura](vote-ballots.png), `theRollCallIsAlphabeticalAndSearchable` |
| 10 | Partido abre filtrado | Tocar em PL | passou | Simulador, com "Mostrando só PL"; `thePartyStartsSelectedWhenTheListOpensFromARow` |
| 11 | Votação simbólica | Abrir | passou | `aVoiceVoteHasNoScoreNoDashAndNoListOfVotes`, `testAVoiceVoteSaysWhatTheHouseRecorded`, [captura](vote-symbolic.png), iPhone |
| 12 | Nominal sem nomes | Modelo | passou em teste | `aNominalVoteWithoutNamesSaysSoAndOffersNoList`; a frase não foi vista na tela |
| 13 | Mac com a tabela | Abrir no Mac | não executável aqui | O build de macOS passa no `verify --full`; o Mac não abre nesta máquina |
| 14 | Sim e Não em círculo | Ver o placar | passou em parte | [Topo](vote-top.png), iPhone. VoiceOver ligado não foi usado; o rótulo vem do `StatusCircle` |
| 15 | Resultado na linha | Ver Votações | passou | [Votações](votes-top.png) |
| 16 | "1 outro voto" e "9 outros votos" | Texto | passou em parte | "9 outros votos" e "3 outros votos" na tela. O singular só está provado pela entrada no catálogo |
| 17 | "Albuquerque" | Ver em Seus representantes | passou em parte | Simulador, inteiro numa linha, em Dynamic Type padrão. Coluna estreita não foi medida |
| 18 | Bloco de partidos inteiro | Orientação | passou em parte | Vem do código e do teste de orientação; o nome longo real não foi visto na tela |
| 19 | Linhas de Votações | Abrir a aba | passou em parte | [Votações](votes-top.png): número, resumo em duas linhas, resultado, placar, hora e tema; mais de duas linhas no Duo dobrado e o iPhone, maior, foi visto pelo usuário. A contagem de três linhas por tela não foi medida |
| 20 | Próxima sessão | Abrir e tocar | passou em parte | Com itens da sessão: `aFutureSessionWithItsAgendaShowsTheDateAndTheCount` e simulador, só com dados de teste, porque a fonte real ainda não traz esse caso. Sem itens: `aPastAgendaNeverLendsItsItemsToTheNextSession`; a linha sem seta não foi vista na tela |
| 21 | Em sessão | Modelo | passou em teste | `aSessionUnderWaySaysSoWithItsItems`; a linha não foi vista na tela nesse estado |
| 22 | Pauta vencida | Modelo | passou em teste | `aPastAgendaWithoutSessionsAheadShowsNothing`, `aPastAgendaNeverLendsItsItemsToTheNextSession`, `todaysItemsDoNotCountForASessionOnAnotherDay` |
| 23 | Tela da pauta | Abrir | passou em parte | Simulador, com temas inteiros e o status em texto. Os dados de teste não trazem link oficial, então ele não foi visto nesta tela |
| 24 | Região sem seguidos | Abrir | passou | `testRegionStartsOnThePlace`, [captura](region-top.png), iPhone |
| 25 | Filtro Seguindo | Tocar e abrir | passou | `testTheFollowingFilterOpensWhoYouFollow`, [filtro](feed-following.png), [tela](following.png) |
| 26 | Seguir e deixar de seguir | Tocar | passou em parte | `testFollowingAndUnfollowingWorkOnTheScreen`, `unfollowingLeavesTheListAndComesBackAsASuggestion`. O reflexo no Feed depende do `session.generation` e não foi conferido na tela |
| 27 | Sem lugar | Abrir | passou | `testTheLinkOpensTheScreenAndWithoutAPlaceInvitesToChooseIt`, [captura](following-empty.png) |
| 28 | Ninguém seguido | Convite do Feed | passou | `testTheFeedInviteLeadsToTheScreen` |
| 29 | Links, widget e Siri | Abrir | passou em parte | `DeepLinkTests`, `FollowIntentTests` e a captura pelo link. O widget e a Siri não foram abertos |
| 30 | Abas | Ver | passou | `feedRegionAndSearchUseTheirTabSymbols`, simulador; o usuário aprovou no iPhone e pediu o pin em Região |
| 31 | Maior tamanho e VoiceOver | Rolar até o fim | passou em parte | `testTheEndIsReachableAtTheLargestTextSize` no detalhe e em quem você segue, [fim](vote-largest-end.png). VoiceOver ligado não foi usado |
| 32 | Duo aberto, iPad e Mac | Abrir | não executável aqui | Vistas só com o Duo dobrado e o iPhone físico. Os builds passam |

**Defeito achado no QA:** no maior tamanho de texto, a barra crescia até ocupar a tela, cortava o título e impedia a rolagem. A barra agora limita o texto a `xxxLarge`, e `testTheEndIsReachableAtTheLargestTextSize` cobre isso. A linha de Votações, o título do dia ("Onte-m") e a linha da pauta também foram corrigidos nesse tamanho.

**Fora do canvas, no backlog:** no maior tamanho, a corrida corta o nome e o gráfico mensal sobrepõe os meses. Os dados publicados estão parados em 28/10.

**Pauta real:** a fonte publica os itens só da sessão do dia. Em dia sem sessão, a linha mostra só a data, sem quantidade nem seta, para não apresentar pauta antiga como atual.

**Lista no modo de teste:** com `-FiscalFollowScenario`, `FollowingModel` lê a mesma lista fixa do Feed, e o botão de seguir grava no banco real do simulador. Fora do modo de teste, os dois usam o mesmo banco. Por isso o teste de seguir roda sem esse argumento.
