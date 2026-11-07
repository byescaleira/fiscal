# QA da FSC-009

Roteiros manuais da definição de pronto do [canvas](../../../spdd/prompt/FSC-009-202610312200-[Feat]-following-tab-and-follow-everywhere.md), executados em 31/10/2026 no simulador do iPhone Duo fechado (466×678 pt, o único iPhone disponível na máquina), depois do `scripts/verify.sh --full` verde. A build também foi instalada no iPhone do usuário. Resultado: 5 passou, 1 falhou e corrigido, 4 não executável aqui.

| Roteiro | Resultado | Evidência e observação |
| --- | --- | --- |
| Seguindo é a primeira aba e abre primeiro | passou | `following-empty-no-place.png`: título Seguindo, primeiro ícone da barra vertical selecionado |
| Sem seguidos e sem lugar: a aba pede o lugar | passou | `following-empty-no-place.png`: "Sua região" com "Encontre seu lugar" |
| Sugestões com o botão Seguir na linha | passou | `following-suggestions.png`: "Siga quem representa você", ícone de pessoa em cada linha |
| Seguir pela linha, sem abrir o perfil | passou | `following-after-follow.png`: Arthur Henrique em "Quem você segue" com o ícone de seguindo e fora das sugestões |
| Novidades de um seguido sem atividade publicada (prefeito) | falhou, corrigido | `following-after-follow-before-fix.png` mostrava "Sem dados agora" porque a falta de arquivo virava falha. Correção: `PublicDataError.notFound` conta como vazio; agora "Nada novo nos últimos 30 dias" (`following-after-follow.png`) |
| Sugestões numa cidade com muitos vereadores | passou depois do ajuste | No máximo 8, presidente, governador e senadores antes dos vereadores (`following-suggestions-capped.png`). O "Arthur Henrique" do PL que aparece é outra pessoa, governador eleito |
| Selo "Novo" e número na aba com novidades reais | não executável aqui | O cenário pede um seguido com voto nos últimos 30 dias e uma visita anterior. Coberto por `FollowingFeedTests.countsOnlyWhatIsNewSinceTheLastVisit` e `MineFollowingTests.buildsUpdatesAndClearsTheBadgeWhenSeen` |
| Seguir pela busca, pela votação e pelo menu de contexto | não executável aqui | Os toques no Duo fechado do simulador chegam fora de lugar (um toque abriu outro perfil). Coberto por `FollowControllerTests.togglesFromAnyRow`; a build está no iPhone do usuário |
| Siri, Atalhos e widget "Quem eu sigo" | não executável aqui | Sem sessão da Siri nem galeria de widgets no simulador desta máquina. Coberto por `FollowIntentTests` e `FollowingSnapshotTests` |
| Mac com Seguindo na lista de origem e o número | não executável aqui | Build do macOS verde; sem captura assinada nesta rodada |
