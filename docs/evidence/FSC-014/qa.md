# QA da FSC-014: nova página do político e compartilhar um item

- **Canvas:** [FSC-014](../../../spdd/prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md)
- **Ambiente:** simulador "Fiscal iPhone Duo" (iOS 27.1, dobrado) com os dados de teste (`-FiscalDataScenario normal`, `-FiscalFollowScenario normal`), e iPhone 17 Pro Max físico, com os dados reais.
- **Usuário no iPhone físico:** viu a página na parada da operação 3, os cartões na da operação 7 e os ajustes depois. Pediu para tirar "Durante o mandato" e para a setinha com um destino principal, relatou o bug da rolagem dos atalhos e, ao final, confirmou a correção desse bug e aprovou os cartões.
- **Capturas:** usam a lista fixa dos dados de teste; nenhuma mostra o apoio de alguém. A folha [cards-all-styles.jpg](cards-all-styles.jpg) sai do teste de cartões, em que parte dos rótulos fica em inglês; em pt-BR eles foram vistos na tela de compartilhar.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Deputada com todos os capítulos | Abrir o perfil | passou | `aFederalDeputyReadsEveryChapterInTheFixedOrder`, [topo](profile-top.png) |
| 2 | Governador | Abrir o perfil | passou | `testAGovernorOnlySeesTheChaptersWithData`, [topo](governor-top.png), [capítulos](governor-chapters.png) |
| 3 | Ordem por cargo | Comparar duas pessoas | passou em teste | `theOrderDependsOnTheOfficeNotOnTheValues` |
| 4 | Capítulo sem dado | Deputado estadual | passou em teste | `aChapterWithoutDataDoesNotExist` |
| 5 | Resumo | Tocar num fato | passou | `theSummaryShowsAtMostFourPublishedFactsWithTheirChapter`, simulador |
| 6 | O que a fonte não publica | Deputado estadual e governador | passou em teste | `aStateDeputyWithoutAssemblyDataShowsNoDashAndSaysWhy`; a frase não foi conferida na tela |
| 7 | Falha numa fonte | Serviço com falha | passou em teste | `aFailedSourceKeepsTheRestAndOffersAnotherTry`; o aviso não foi visto na tela |
| 8 | Cabeçalho fixo | Rolar | passou | `testShortcutsAppearOnScrollAndJumpToTheirChapter`, [captura](profile-sticky-header.png), iPhone |
| 9 | Gesto e atalho marcado | Rolar | passou em parte | Atalho marcado no simulador. O gesto o usuário viu no iPhone; aqui só em capturas paradas |
| 10 | Gesto só pelo capítulo | Tabela | passou em teste | `everyChapterHasOneFixedGesture`; a função recebe só o capítulo |
| 11 | Reduzir movimento | Ligar no simulador e rolar | passou em parte | Com o ajuste ligado, duas capturas do retrato com 4 s de diferença ficaram idênticas; `aSmallPortraitPlaysAskedGestureOnlyWhenItMayAnimate`. Pouca energia só por código |
| 12 | Sem expressões de juízo | Ler o código | passou em revisão de código | Só `wave` ao seguir |
| 13 | Ilustração do Fiscal | Abrir o perfil | passou | `ProfileChaptersTests`, [captura](profile-top.png). VoiceOver ligado não foi usado; o rótulo vem de `PersonPortrait` |
| 14 | Quanto gasta | Abrir o capítulo | passou | [captura](profile-money.png), `everyExpenseOpensTheFullListOfTheSelectedYear` |
| 15 | Gasto só em 2025 | Serviço de teste | passou em teste | `theSpendingStartsAtTheLatestYearWithExpensesAndCanChange`; a troca de ano não foi usada na tela |
| 16 | Cota no resumo leva ao capítulo | Tocar no fato | passou | Simulador |
| 17 | Cartão de nota | Compartilhar uma nota | passou | `aCompanyReceiptSaysHowMuchItIsPartOf`, [cartões](cards-all-styles.jpg), simulador |
| 18 | Nota sem CNPJ | Ver a lista | passou | `aReceiptWithoutCompanyNumberNeverBecomesACard`, `aPersonReceiptSubjectFailsInsteadOfShowingTheName`, `onlyACompanyReceiptAndAMonthCanBeShared`, simulador |
| 19 | Cartão do mês | Compartilhar um mês | passou | `aMonthShowsItsTotalAndItsCategories`, [cartões](cards-all-styles.jpg) |
| 20 | Cartão de voto | Compartilhar um voto | passou | `aPersonVoteCarriesTheProposalAndNoJudgement`, `testShareButtonsSayWhatTheyShareAndOpenTheCard`, [captura](share-ballot.png) |
| 21 | Cartão de proposta | Compartilhar uma proposta | passou | `aProposalLinksToThePersonAndShowsOnlyTheYear`, [cartões](cards-all-styles.jpg) |
| 22 | Campo ausente | Montar sem o fato ou a fonte | passou em teste | `aCardWithoutItsMainFactOrSourceDoesNotExist` |
| 23 | Sem bonequinho e sem apoio | Ver os cartões | passou | [cartões](cards-all-styles.jpg); a regra `support_stays_private` no lint |
| 24 | Links | Conferir a chave | passou em teste | `ShareItemCardsTests` |
| 25 | O que circulou | Abrir com checagens | passou | `checksComeByDateWithoutCountOrVerdictOrderAndOnlyWhenThereAreAny`, simulador |
| 26 | Sem checagens | Deputado estadual | passou em teste | O mesmo teste |
| 27 | Sem contexto na página | Governador | passou | `testAGovernorOnlySeesTheChaptersWithData` |
| 28 | Maior tamanho de texto e VoiceOver | XXXL no simulador | passou em parte | `testTheEndIsReachableAtTheLargestTextSize`, [topo](profile-largest-top.png), [votos](profile-largest-votes.png), [fim](profile-largest-end.png). Um e-mail longo quebra por não caber na linha. VoiceOver ligado não foi usado |
| 29 | Duo aberto, iPad e Mac | Abrir | não executável aqui | Só o Duo dobrado foi visto. Não há simulador de iPad, e o app do Mac só abre assinado. O build do Mac e do visionOS roda no `verify --full` |
| 30 | Setinha e toque no Feed | Tocar no cartão | passou | `testTheRestOfAFeedCardOpensItsContent`, [Feed](feed.png), [destino](card-content-vote.png) |
| 31 | Pessoa no cartão | Tocar na pessoa | passou | `testAPersonInAFeedCardOpensTheirProfile`, [destino](card-person-profile.png). Testada a linha de várias pessoas; o retrato de uma pessoa só é o mesmo tipo de botão, sem teste próprio |
| 32 | Fonte externa | Cartão de checagem | passou em teste | `testAFactCheckCardIsAsWideAsTheOtherCards`; o toque no navegador não foi feito |
| 33 | Linha de voto e proposta | Ver no perfil | passou em parte | Voto no simulador; proposta com o mesmo código, sem conferência visual |
| 34 | Destaque, região e apuração | Ver | passou em parte | Destaque e apuração ao vivo no simulador. Cartão compacto, cartão de eleito, cartões de "Região agora" e "Quem gasta mais" sem conferência visual |
| 35 | VoiceOver nos cartões | Ler os rótulos | passou em teste | `CardDestinationTests` acha os botões pelo rótulo. VoiceOver ligado não foi usado |

**Prefeito e vereador:** a página não foi vista na tela, porque os dados de teste não têm perfil municipal. A ordem é a mesma do governador e está em `theOrderDependsOnTheOfficeNotOnTheValues`.

**Teste instável:** `testLaunchShowsTheFeedAndOpensSettings` falhou uma vez na suíte completa e passou ao rodar sozinho. Não mexe no que mudou nesta fase, e a causa não foi investigada.

**Crash achado no QA:** abrir o perfil a partir do Feed fechava o app, por um item vazio na barra que relia o `SessionModel`. Corrigido com `.toolbar(removing: .title)` e coberto por `testAPersonInAFeedCardOpensTheirProfile`.
