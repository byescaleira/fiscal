# QA da FSC-024: curtir no Feed com a onda

- **Canvas:** [FSC-024](../../../spdd/prompt/FSC-024-202611061418-[Feat]-feed-like-with-ripple.md)
- **Ambiente:** simulador "Fiscal Metal iPhone Duo" (iOS 27.1), com os dados publicados, em 06/11/2026. Build com o `byescaleira-kit` 0.11.0.
- **iPhone físico:** não usado. O toque háptico, a onda em 120 Hz e o custo da faixa ficam para a validação no aparelho, junto da carta da FSC-023, no [backlog](../../backlog.md).
- **Como a onda foi capturada:** gravação da tela (`simctl io recordVideo`) e quadros tirados com o `ffmpeg`, porque a faixa dura 1,6 s.

| # | Cenário | Roteiro | Resultado | Evidência |
| --- | --- | --- | --- | --- |
| 1 | Curtir | Tocar no coração de uma linha e do destaque do topo | passou | [Destaque](highlight-wash.png): faixa branca entre o fundo e o conteúdo, com a onda chegando à borda. [Linha](row-wash-sequence.png): faixa na cor de destaque que some; o texto e o retrato não se mexem. [Coração cheio](row-liked.png) |
| 2 | Descurtir | Tocar de novo | passou | O coração volta a vazio, sem faixa. `LikeControllerTests.likesAndUnlikes` |
| 3 | Guardado | Fechar e abrir o app | passou | O destaque curtido continua cheio depois de reabrir. `LikeStoreTests.aLikeSurvivesReopeningAndStaysOutOfBackups` |
| 4 | Sem movimento | Reduzir movimento ligado, curtir | passou | [Sequência](reduce-motion-sequence.png): o coração enche, sem faixa e sem onda. O modo leve usa a mesma regra (`MotionBudget.isConstrained`), não testado à parte |
| 5 | VoiceOver | Coração como alternância | passou em código; leitura não executável aqui | O botão é um `Toggle` com `accessibilityRepresentation`, rótulo "Curtir". A leitura em voz fica para o iPhone, com a validação da carta (canvas, Operation 9) |
| 6 | Lista "Curtidas" | Menu do coração › Curtidas | passou | [Menu](feed-menu.png) e [lista](liked-list.png), mais recente primeiro. A proposta ainda no Feed abre o mesmo detalhe da linha. Destinos em `NavigationTests.eachLikedItemOpensItsOwnScreen` e `LikeControllerTests.anItemStillInTheFeedOpensWhatTheFeedShows` |
| 7 | Lista vazia | Depois de apagar | passou | [Vazia](liked-empty.png): "Nada curtido" e "Toque no coração de um item do Feed para guardar aqui." |
| 8 | Apagar curtidas | Lixeira › confirmar | passou | [Confirmação](erase-confirm.png). "Descurtir" ao arrastar e no menu de contexto, em `LikeControllerTests.removingAndErasing`; os gestos não foram feitos no simulador |
| 9 | Destaque do topo | Coração branco no rodapé do destaque | passou | [Destaque](highlight-wash.png). A apuração ficou fora (Approach 13) |
| 10 | Privacidade | Modelos e backup | passou em teste | `SupportPrivacyTests`, `DeviceStoreTests`, `LikeStoreTests` e `DataExportModelTests.exportsTheLikedItems`. Nenhuma referência a curtidas em widget, Spotlight, Siri, `FiscalEvents` ou cartaz (`git grep` de `LikeController`, `LikedItem` e `likes` só acha o Feed, a janela, a navegação, a exportação e a camada de dados) |
| 11 | Migração | Banco V4 aberto na V5 | passou em teste | `SchemaMigrationTests.aFourthVersionStoreKeepsSupportAndFollowsWithNoLikes`; o app abriu no simulador sobre um banco existente |
| 12 | Curtir não muda o Feed | Ordem e filtro | passou | O `FeedModel` não conhece curtidas; a ordem do Feed foi a mesma antes e depois de curtir nas capturas |
| 13 | Erro ao gravar | Falha do repositório e dois toques | passou em teste | `LikeControllerTests.aFailedSaveGoesBackAndReportsTheError` e `ignoresASecondTapWhileTheFirstIsSaving` |
| 14 | Exportação antiga | JSON sem `liked` | passou em teste | `DataExportModelTests.anArchiveFromBeforeLikesStillReads` |
| — | Modo escuro | Curtir uma votação | passou | [Sequência](row-wash-dark-sequence.png) |

**Achados durante o QA, corrigidos na fase:**
- Os textos novos apareciam em inglês no primeiro build, porque o catálogo foi sincronizado depois dele. Um novo build mostra tudo em pt-BR.
- A proposta curtida, ainda no Feed, aparecia como "Este item saiu do Feed". O canvas foi atualizado (Approach 9), e a lista passou a usar a rota que o Feed mostra agora.

**Ponto para a revisão de interface:** a linha do coração soma cerca de 44 pt a cada item do Feed.

**Depois da revisão:** a faixa, a onda e o toque háptico passaram a disparar só depois de a curtida ser gravada; o coração vazio do destaque usa o branco com `.opacityStrong`; a lista ganhou o menu de contexto e o `.privacySensitive()`. Só o build e os testes conferiram essas mudanças, sem nova captura.

**Teste no iPhone (06/11/2026), com o usuário:**
- o coração no rodapé abria uma faixa vazia em cada card ("adicionou uma faixa branca enorme em cada card"): foi para o cabeçalho, ao lado da data ([captura](row-heart-header.png));
- curtir fazia a rolagem pular e voltar de um item deixava o Feed em outra posição: a curtida grava sem avisar a sessão (`LikeStoreTests.likingDoesNotTellTheSessionToReload`), e o Feed só troca a lista quando ela muda;
- a onda não agradou ("eu acho que a animação com o coração estava mais legal"): saíram a faixa e a onda, fica a animação do coração. As evidências da onda acima ficam como histórico.

