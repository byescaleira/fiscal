# Seguir no centro do Fiscal: aba Seguindo e seguir em todo lugar

## Requirements

Hoje só se segue alguém pelo herói do perfil, e quem a pessoa segue aparece no fim da aba Região e em até 4 linhas de Hoje, sem dizer o que fizeram. Esta mudança põe seguir no centro do app, como pediu o usuário em 31/10/2026 ("precisamos deixar mais claro a função de seguir um políticos no app (como se fosse o core do app, mais evidência)"). Análise: [FSC-009](../analysis/FSC-009-202610312136-[Analysis]-following-core.md).

Decisões do usuário:
- Seguindo é a primeira aba e absorve a Região.
- As novidades de quem a pessoa segue ficam no topo.
- Os representantes do lugar aparecem como sugestão.
- Sem notificação: só selo na aba ("Só selo na aba, sem notificação").

Definição de pronto:

- **Given** o app aberto **When** a barra de abas aparece **Then** as abas são, nesta ordem, Seguindo · Hoje · Votações · Dinheiro · Fiscalizar, e Seguindo abre primeiro (`AppSectionTests.followingIsTheFirstSection`). No Mac, Seguindo é o primeiro item de "Acompanhar" e ⌘1.
- **Given** um link `fiscal://mine` (atalho, widget antigo, link publicado) **When** ele é aberto **Then** a aba Seguindo abre (`DeepLinkTests.mineOpensFollowing`). `fiscal://following` também abre.
- **Given** a pessoa segue Fulana e Beltrano, Fulana votou "Sim" no PL 1/2026 em 30/10 e Beltrano teve R$ 12.345,67 de gastos publicados em outubro **When** abre a aba Seguindo **Then** o topo "Novidades" lista as duas, da mais nova para a mais antiga, cada uma com nome, o que aconteceu, data e fonte (a Casa pelo cargo: deputado federal → Câmara, senador → Senado, outros cargos sem Casa; na checagem, o veículo), e o toque abre a votação ou os gastos (`FollowingFeedTests.ordersNewestFirstAcrossPeople`, `MineFollowingTests.aMissingFileIsEmptyAndOnlyFailuresAreMissing`). Os gastos entram datados no dia 1 do último mês com valor.
- **Given** a primeira visita **When** as novidades são montadas **Then** entram só itens dos últimos 30 dias, no máximo 50 (`FollowingFeedTests.keepsThirtyDaysAndFiftyItems`). Quando a janela começa no ano anterior (começo de janeiro), os votos e gastos dos dois anos são lidos (`FollowingFeedTests.theWindowReachesThePreviousYearOnlyInEarlyJanuary`, `MineFollowingTests.inJanuaryTheWindowAlsoReadsThePreviousYear`).
- **Given** a última visita em 28/10 **When** a pessoa volta em 31/10 **Then** os itens depois de 28/10 têm o selo "Novo", e a aba mostra o número deles (`.badge`). Ao sair da aba (outra aba selecionada) ou quando o app vai para o fundo, a marca de cada seguido passa para agora e o número zera; abrir uma votação ou um perfil dentro da aba não conta como saída. Sem marca de visita, vale a data em que a pessoa passou a ser seguida (`followedAt`) (`FollowingSeenStoreTests`, `FollowingFeedTests.countsOnlyWhatIsNewSinceTheLastVisit`, `MineFollowingTests.buildsUpdatesAndClearsTheBadgeWhenSeen`).
- **Given** ninguém seguido e o estado SP escolhido **When** a aba abre **Then** aparece o convite "Siga quem representa você" com até 8 sugestões, quem a pessoa apoia primeiro e depois os representantes de SP na ordem presidente, governador, senadores, prefeito, deputados e vereadores, cada um com o botão Seguir na linha. Sem lugar e sem Lente, o convite pede o lugar (`MineFollowingTests.suggestsRepresentativesAndSupportedNotFollowed`).
- **Given** a aba Seguindo **When** a pessoa rola abaixo das novidades **Then** vê, nesta ordem:
  - "Quem você segue", em ordem alfabética;
  - "Sugestões";
  - "Sua região" (título da seção do herói), com o herói do lugar, o governo, as bancadas, o Senado, o agora da região e a fonte, como a Região mostra hoje.
- **Given** qualquer uma destas linhas de pessoa **When** a pessoa toca no botão Seguir da linha ou usa "Seguir"/"Deixar de seguir" no menu de contexto **Then** o estado muda sem abrir o perfil (`FollowControllerTests.togglesFromAnyRow`). As linhas são:
  - resultado da busca;
  - representante e senador da região;
  - quem votou numa votação;
  - gastadores de Dinheiro;
  - quem aguarda julgamento;
  - autor do destaque em Hoje.

  No Mac, as tabelas (representantes da região e quem votou) ganham as mesmas ações no menu de contexto (`MineRosterTests` para `MineRoster.card(for:)`). Um segundo toque enquanto a primeira gravação da mesma pessoa não terminou é ignorado (`FollowControllerTests.ignoresASecondTapWhileTheFirstIsSaving`). Seguir pela linha já atualiza todas as telas pelo `FiscalChangeHub` do banco, sem recarga extra.
- **Given** um toque em Seguir **When** o estado muda **Then** há háptico (`sensoryFeedback`) e o símbolo troca com `quietBounce`, sem animação com Reduzir movimento. O VoiceOver anuncia "Seguindo Fulana" ou "Deixou de seguir Fulana".
- **Given** a Siri ou Atalhos **When** a pessoa diz "Seguir Fulana no Fiscal" ou roda o atalho **Then** Fulana passa a ser seguida sem abrir o app. "Deixar de seguir" desfaz, e "Quem eu sigo no Fiscal" abre a aba Seguindo. Seguir e deixar de seguir pedem o aparelho desbloqueado (`authenticationPolicy = .requiresAuthentication`). Com atualização obrigatória pendente, os três falham com `UpdateRequiredError` (`FollowIntentTests`).
- **Given** o widget de representantes **When** a pessoa escolhe "Quem eu sigo" na configuração **Then** ele mostra até 4 seguidos com a novidade mais recente de cada um (o pequeno diz ao VoiceOver o primeiro "e mais N"); "Meu estado" continua como hoje. Depois de seguir ou deixar de seguir, pelo app, pela Siri ou pelos Atalhos, a pessoa sai do `following.json` na hora e o widget recarrega (`FollowingSnapshotTests.forgetsWhoWasUnfollowed`, `FollowControllerTests.refreshesTheWidgetAndForgetsWhoWasUnfollowed`).
- **Given** a aba Seguindo e os Ajustes **When** os textos aparecem **Then**:
  - não existe mais "fica só neste aparelho";
  - o rodapé diz "Quem você segue fica no seu iCloud, se a sincronização estiver ligada.";
  - Hoje não manda escolher o estado para seguir.
- **Given** Hoje **When** a pessoa segue alguém **Then** o cartão de seguidos dá lugar a uma linha "N novidades de quem você segue", ou "Siga quem representa você" com zero seguidos, que abre a aba Seguindo.
- **Given** um seguido sem votos, gastos nem checagens publicados (um prefeito, por exemplo) **When** a aba monta as novidades **Then** ele não conta como falha: o arquivo que não existe (`PublicDataError.notFound`) é lido como vazio.
- **Erro:** se a leitura de uma pessoa falha (sem rede e fora do pacote offline), as outras novidades aparecem e uma linha só, "Sem dados agora", junta quem falhou ("Não deu para carregar A e B. Toque para tentar de novo."); o toque relê as novidades. Nenhuma falha esconde a aba (`MineFollowingTests.aMissingFileIsEmptyAndOnlyFailuresAreMissing`).

## Entities

```mermaid
classDiagram
  class AppSection {
    <<enum>>
    following
    today
    votes
    money
    search
  }
  class FollowingUpdate {
    String id
    PersonCard person
    Kind kind
    CalendarDay day
  }
  class Kind {
    <<enum>>
    vote(PersonVote)
    expenses(year, month, cents)
    check(FactCheck)
  }
  class FollowingFeed {
    <<pure>>
    build(activities, today) FollowingUpdate[]
    newCount(updates, seen) Int
    windowStart(today) CalendarDay
    years(today) Int[]
  }
  class Activity {
    PersonCard person
    PersonVote[] votes
    ExpenseList expenses
    Int expensesYear
    FactCheck[] checks
  }
  class FollowingSeenStore {
    seen(slug) Date
    markSeen(slugs, at)
  }
  class FollowController {
    Set~String~ followed
    isFollowing(slug) Bool
    toggle(PersonCard)
    toggle(slug)
  }
  class FollowingWidget {
    refresh(unfollowed)
  }
  class FollowingBadge {
    Int count
  }
  class FollowingSnapshot {
    Entry[] entries
    removing(slug)
    forget(slug)
  }
  class MineModel {
    FollowingUpdate[] updates
    PersonCard[] missing
    PersonCard[] suggestions
    markSeen()
    title(for) String
    detail(for) String
    route(for) Route
  }
  FollowingUpdate --> Kind
  FollowingFeed --> Activity
  FollowingFeed --> FollowingUpdate
  FollowController ..> FollowingWidget
  FollowingWidget ..> FollowingSnapshot
  MineModel --> FollowingFeed
  MineModel --> FollowingSeenStore
  MineModel --> FollowingBadge
  FollowController ..> FollowRepository
  FollowingSnapshot ..> AppGroup
```

- **`AppSection.following`** substitui `mine`:
  - `rawValue` "following", título "Following" (Seguindo) e símbolo `person.2`;
  - `DeepLink` mapeia o host `mine` para `.following`;
  - `SourceGroup.followAlong` passa a ser `[.following, .today]`.
- **`FollowingUpdate`** (novo, `FiscalDomain`): `person`, `kind` e `day`.
  - `Kind` é `.vote(PersonVote)`, `.expenses(year:month:cents:)` ou `.check(FactCheck)`;
  - `id` é o slug mais o tipo e o id de origem (o voto, o ano-mês dos gastos ou a checagem);
  - os gastos são datados no dia 1 do último mês com valor do ano lido;
  - título, detalhe e destino ficam no model da aba (`MineModel+FollowingText`: `title(for:)`, `detail(for:)` e `route(for:)`, `.vote(id:)` ou `.expenses(slug:year:)`), e a checagem abre o link da fonte, porque a `Route` mora no `FeatureCore`;
  - a fonte do voto e dos gastos é a Casa pelo cargo (`MineModel.houseName`: deputado federal → "Câmara", senador → "Senado", outros cargos sem Casa); a da checagem é o veículo (`publisher`);
  - presença fica de fora, porque só existe somada por ano, sem data.
- **`FollowingFeed`** (novo, `FiscalDomain`, funções puras): `build(_ activities: [Activity], today:)` junta as `Activity` de cada seguido (votos, gastos de um ano e checagens), corta em 30 dias (`windowStart`) e 50 itens, ordena por data (desempate por nome) e `newCount` conta os itens mais novos que a marca de cada pessoa. `years(for:)` diz quais anos ler: o atual e, se a janela começa no ano anterior, também ele (uma `Activity` por ano, com as checagens só na do ano atual).
- **`FollowingSeenStore`** (novo, `FeatureCore`): `UserDefaults` local, chave `fiscal.following.seen` (`[slug: Date]`). Fica fora do iCloud e do SwiftData, e entra no "Apagar preferências" do Developer pelo prefixo `fiscal.`, sem mudança no `DeveloperModel`. Sem marca de uma pessoa, vale o `followedAt` dela.
- **`FollowController`** (novo, `FeatureCore`, `@MainActor @Observable`, um por janela, injetado como o `SessionModel`):
  - guarda os slugs seguidos, recarregados a cada `session.generation`;
  - `toggle(_ card:)` segue ou deixa de seguir pelo `FollowRepository`;
  - `toggle(slug:)` acha o `PersonCard` no índice de pessoas (`service.people()`) para as linhas que só têm slug, como a de quem votou;
  - ignora um segundo toque na mesma pessoa enquanto a gravação anterior não terminou;
  - depois de gravar, chama `FollowingWidget.refresh(unfollowed:)` (injetável nos testes).
- **`FollowingWidget`** (novo, `FeatureCore`): o `kind` do widget e `refresh(unfollowed:)`, que tira a pessoa do `following.json` (`FollowingSnapshot.forget`) quando deixou de ser seguida e recarrega a linha do tempo. O `FollowIntentWriter` da Siri usa o mesmo caminho.
- **`FollowingBadge`** (novo, `FeatureCore`, `@Observable`, por janela): o número de novidades que a `TabView` e a lista de origem do Mac mostram. O `MineModel` atualiza.
- **`FollowingSnapshot`** (novo, `FiscalDomain/Integrations`): até 6 entradas (`PersonCard` mais a novidade mais recente), gravadas pelo app em `fiscal/following.json` no App Group `group.com.byescaleira` (compartilhado pelos apps byescaleira, lido só pelo widget do Fiscal); `removing(_:)` e `forget(_:)` tiram quem deixou de ser seguido.
- **Sugestões (prompt-update de 31/10/2026, achado na QA):** no máximo 8, em ordem de cargo (`MineModel.suggestionOrder`), porque uma cidade grande lista dezenas de vereadores.
- **`MineModel`** ganha:
  - `updates`, `updatesPhase`, `missing`, `suggestions`, `newCount` e `markSeen()`;
  - um `PublicDataService` para `votes(slug:year:)`, `expenses(slug:year:)` e `checks(slug:)` de cada seguido, com no máximo 6 pessoas lidas ao mesmo tempo e o `settle` da FSC-002, inclusive no caminho sem seguidos (que invalida uma leitura em andamento);
  - o arquivo que não existe (`PublicDataError.notFound`) é lido como vazio; a pessoa só entra em `missing` quando as checagens e todas as leituras de voto e gasto falham.

## Approach

1. **Estratégia:**
   - A aba Seguindo é a `FeatureMine` reordenada, sem módulo novo.
   - As novidades nascem no aparelho, das mesmas chamadas públicas do perfil, que já leem do pacote offline quando não há rede. A lista de quem a pessoa segue nunca sai do aparelho.
   - Seguir vira uma peça única (`FollowController` e `FollowButton`/`.followActions(...)`) usada por todas as linhas de pessoa.
2. **Decisões** (portas da análise; nenhuma nova de porta `pergunta`):
   - **Sem notificação** (pergunta respondida pelo usuário): só o selo na aba e as novidades no widget. As notificações seguem iguais para todos (25/10/2026).
   - **Marca de última visita local:** a marca é atualizada quando `FiscalNavigation.selectedSection` deixa `.following` (o `onChange`; no Mac, que recria a pilha a cada seção, o `onDisappear` com outra seção já selecionada) ou quando o app vai para o fundo, para o selo "Novo" ficar visível durante a visita. Abrir uma rota dentro da aba não marca.
   - **Região dentro de Seguindo:** "Sua região" é o título da seção do `MineHeroSection` e reaproveita `MineRegionContent` e `MineInviteSection` sem mudar o desenho. O título da aba passa a ser "Seguindo", e os textos que falavam da aba Região (tour, Lente, votação) falam de Seguindo.
   - **Hoje:**
     - sai o `TodayRepresentativesSection`, junto com o carregamento de votos dos seguidos do `TodayModel` e o código que só ele usava (`TodayBallot`, `BallotChip` de Hoje, `TodayModel.house(for:)` e `detail(for:)`);
     - entra a `TodayFollowingLink`, que lê o `FollowingBadge` e muda `selectedSection` para `.following`.
   - **Botão Seguir na linha:**
     - `FollowButton` compacto com `person.badge.plus` e `person.fill.checkmark` (o `person.badge.checkmark` só existe a partir do 27), alvo de 44 pt, rótulo de acessibilidade com o nome, `quietBounce` e `sensoryFeedback(.success)`;
     - fica no fim da linha, fora do `RouteLink`, para não abrir o perfil;
     - nas linhas sem espaço (autor do destaque, tabelas do Mac), só o menu de contexto.
   - **Fora da lista de seguir:** os candidatos da apuração (`RaceStandingRow`) usam o slug do retrato, e não o da pessoa, e a Memória mostra nomes do passado. Os dois ficam sem botão.
   - **Perfil:** o herói passa a usar o `FollowController`, para o estado bater com as listas. O háptico e o anúncio ao VoiceOver são os mesmos do botão da linha.
   - **Intents:**
     - `FollowPersonIntent` e `UnfollowPersonIntent` (`AppIntent`, `supportedModes = .background`, `authenticationPolicy = .requiresAuthentication`, `PersonEntity`) gravam pelo `FollowIntentWriter`, com o `FollowRepository` do banco aberto por `FiscalServices.shared.database(cloudSync:)`, como o `OfflineDataCenter`, e depois atualizam o `following.json` e o widget;
     - `OpenFollowingIntent` ("Quem eu sigo") é um `AppIntent` de primeiro plano (`supportedModes = .foreground`, não `OpenIntent`) que usa `pendingURL = IntegrationLink.following`;
     - os três checam `IntentWorkspace.ensureOpen()`; as frases ficam no `Fiscal/Fiscal/AppShortcuts.xcstrings`.
   - **Widget:**
     - o `RepresentativesWidget` passa para `AppIntentConfiguration`, com o parâmetro "Mostrar": "Meu estado", o padrão de hoje, ou "Quem eu sigo";
     - "Quem eu sigo" lê o `FollowingSnapshot` do App Group, que o app grava ao montar as novidades e de onde tira a pessoa na hora em que deixa de ser seguida;
     - o widget não faz rede nova; as views ficam em `FollowingWidgetViews.swift`.
   - **Textos:** o rodapé e o vazio de "Quem você segue" falam do iCloud ("fica no seu iCloud, se a sincronização estiver ligada"), e somem as frases "neste aparelho".
   - **ADR:** nenhum novo. Seguir já é capacidade do app; o [ADR 0018](../../docs/adr/0018-widgets-read-public-data.md) (Proposto) registra o retrato `following.json` no App Group compartilhado e o que o CDN vê das leituras por pessoa.
3. **Referências:**
   - **Apps de seguir com novidades no topo:** Apple Sports ("Minhas equipes"), Apple News ("Seguindo") e GitHub ("Following").
   - **Pesquisa e HIG:** a pesquisa de plataformas de 28/10/2026 e a HIG de *Tab bars* (primeira aba é a mais usada).

## Structure

```text
FiscalKit/
  Sources/FiscalDomain/PublicData/FollowingUpdate.swift          (novo) FollowingUpdate e FollowingFeed
  Sources/FiscalDomain/Integrations/FollowingSnapshot.swift      (novo) snapshot do widget no App Group
  Sources/FiscalDomain/Integrations/VoteBoard.swift              IntegrationLink.following
  Sources/FeatureCore/Navigation/AppSection.swift                following no lugar de mine, grupo e atalho
  Sources/FeatureCore/Following/FollowController.swift           (novo) estado e toggle de seguir por janela e FollowingBadge
  Sources/FeatureCore/Following/FollowingWidget.swift            (novo) kind do widget, forget e recarga
  Sources/FeatureCore/Following/FollowingSeenStore.swift         (novo) marca local de última visita
  Sources/FeatureCore/Following/FollowButton.swift               (novo) botão da linha e .followActions(...)
  Sources/FeatureMine/MineModel.swift, MineModel+Following.swift updates, suggestions, newCount, markSeen
  Sources/FeatureMine/MineModel+FollowingText.swift              (novo) título, detalhe, destino e Casa de cada novidade
  Sources/FeatureMine/MineScreen.swift                           ordem: novidades, quem você segue, sugestões, sua região
  Sources/FeatureMine/MineFollowing.swift                        (novo) seções de novidades, seguidos e sugestões
  Sources/FeatureMine/MineSections.swift                         sai MineFollowingSection; textos do iCloud
  Sources/FeatureToday/TodayRepresentativesSection.swift         vira TodayFollowingLink
  Sources/FeatureToday/TodayModel.swift, TodayModel+Text.swift, TodayScreen.swift  sem votos dos seguidos; textos do link
  Sources/FeatureToday/TodayBallot.swift, TodayComponents.swift  sai o código morto (TodayBallot, BallotChip)
  Sources/FeatureSearch/SearchResultsList.swift                  FollowButton na linha
  Sources/FeatureVotes/VoteBallotsSection.swift, VoteBallotsTable.swift  seguir por slug
  Sources/FeatureMine/MineSections.swift, MineBenches.swift, MineGovernment.swift, MineRosterTable.swift
  Sources/FeatureMoney/SpendingSections.swift                    seguir nos gastadores
  Sources/FeatureMemory/ElectionScheduleSection.swift            seguir em quem aguarda
  Sources/FeatureToday/TodayHighlightHero.swift                  menu de contexto do autor
  Sources/FeatureProfile/ProfileHero.swift, ProfileModel.swift   herói pelo FollowController
  Sources/AppShell/MainScreen.swift, MacShell.swift, FiscalWindow.swift  badge e injeção do FollowController
  Sources/AppShell/DeepLink.swift                                mine e following abrem a aba
  Sources/AppShell/Integrations/FiscalIntents.swift              FollowPersonIntent, UnfollowPersonIntent, OpenFollowingIntent
  Sources/AppShell/Integrations/FollowIntentWriter.swift         (novo) gravação dos intents e atualização do widget
  Sources/FeatureGuides/Tutorial/Tutorial+Start.swift, FeatureLens/LensEditSections.swift  textos que citavam a Região
  Tests/FiscalDomainTests/FollowingFeedTests.swift               (novo)
  Tests/FiscalDomainTests/FollowingSnapshotTests.swift           (novo)
  Tests/FeatureCoreTests/FollowControllerTests.swift             (novo)
  Tests/FeatureCoreTests/FollowingSeenStoreTests.swift           (novo)
  Tests/FeatureCoreTests/AppSectionTests.swift                   following primeiro
  Tests/FeatureCoreTests/FoldNavigationTests.swift               dobra com Seguindo
  Tests/AppShellTests/DeepLinkTests.swift                        mine abre following
  Tests/AppShellTests/FollowIntentTests.swift                    (novo)
  Tests/FeatureMineTests/MineFollowingTests.swift                (novo) sugestões, novidades, markSeen, arquivo vazio, janeiro, Casa
  Tests/FeatureMineTests/MineRosterTests.swift                   MineRoster.card(for:)
  Tests/FeatureProfileTests/ProfileModelTests.swift              herói pelo FollowController
  Tests/FeatureTodayTests/*                                      sem seguidos em Hoje
Fiscal/Fiscal/FiscalShortcuts.swift                              frases de seguir, deixar de seguir e quem eu sigo
Fiscal/Fiscal/AppShortcuts.xcstrings                             (novo) frases dos atalhos em pt-BR
Fiscal/FiscalWidgets/RepresentativesWidget.swift                 AppIntentConfiguration com "Mostrar"
Fiscal/FiscalWidgets/FollowingWidgetViews.swift                  (novo) widget "Quem eu sigo" pequeno e médio
Fiscal/FiscalUITests/LaunchTests.swift                           abas com Seguindo primeiro e Hoje antes da Apuração
Fiscal/Fiscal/Localizable.xcstrings, Fiscal/FiscalWidgets/Localizable.xcstrings  textos em pt-BR
docs/evidence/FSC-009/                                           capturas e qa.md
CHANGELOG.md, docs/roadmap.md, spdd/README.md                    registro da mudança
docs/adr/0018-widgets-read-public-data.md                        following.json no App Group e o que o CDN vê
```

## Operations

1. **Domínio das novidades.**
   - `FollowingUpdate`, `FollowingFeed.build` (30 dias, 50 itens, mais novo primeiro, desempate por nome) e `newCount`.
   - `FollowingSnapshot`, com até 6 entradas e codificação estável.
   - Verificação: `FollowingFeedTests`, `FollowingSnapshotTests`.
2. **Peças de seguir.** Depende de: 1.
   - `FollowingSeenStore`, `FollowingBadge`, `FollowController` (com o índice de pessoas para `toggle(slug:)`), `FollowButton` e `.followActions(...)`.
   - Injeção por janela no `FiscalWindow`.
   - Verificação: `FollowingSeenStoreTests`, `FollowControllerTests`.
3. **Aba Seguindo.** Depende de: 2.
   - `AppSection.following`, `DeepLink` (`mine` e `following`), `IntegrationLink.following`, `.badge` na `TabView` e na lista de origem do Mac.
   - `MineModel` com novidades, sugestões e `markSeen`.
   - `MineScreen` na ordem nova, com as seções de `MineFollowing.swift` e "Sua região".
   - Textos do iCloud.
   - Verificação: `AppSectionTests`, `DeepLinkTests`, `MineModelTests`, `scripts/verify.sh --quick ios`.
4. **Seguir em todo lugar.** Depende de: 2. `[P]` com 3.
   - `FollowButton` e `.followActions` nas linhas de busca, região (roster, senadores, governo), votação (por slug), gastadores, quem aguarda, autor do destaque e tabelas do Mac.
   - O herói do perfil passa a usar o `FollowController`.
   - Verificação: `FollowControllerTests`, build iOS e macOS.
5. **Hoje.** Depende de: 3.
   - `TodayFollowingLink` no lugar do `TodayRepresentativesSection`.
   - `TodayModel` sem seguidos.
   - Verificação: `FeatureTodayTests`.
6. **Siri, Atalhos e widget.** Depende de: 2 e 3.
   - Os três intents e as frases no `FiscalShortcuts`.
   - O app grava o `FollowingSnapshot` ao montar as novidades.
   - O widget com `AppIntentConfiguration` e "Mostrar".
   - Verificação: `FollowIntentTests`, build do alvo de widgets.
7. **Textos.** Depende de: 3 a 6.
   - Chaves novas em pt-BR no app e nos widgets: aba, seções, botão, anúncios, intents, widget, Hoje.
   - Verificação: `scripts/strings.sh`.
8. **Rodar e QA.** Depende de: 1 a 7.
   - `scripts/verify.sh --full`.
   - Build no iPhone do usuário (memória "Install on his iPhone first").
   - Roteiros em `docs/evidence/FSC-009/qa.md`:
     - aba com e sem seguidos;
     - selo "Novo" e número na aba;
     - seguir pela busca, pela votação e pelo menu de contexto;
     - Hoje;
     - Siri ou Atalhos;
     - widget "Quem eu sigo";
     - Mac com a lista de origem.
9. **Revisão e PR.** Depende de: 8.
   - `/byescaleira-workspace:review` (`ui`, `code`, `security`, porque há App Group e intents) e `/byescaleira-workspace:spdd-code-review` na mesma mensagem.
   - Correções num commit só.
   - `CHANGELOG.md`, roadmap e `spdd/README.md`.
   - PR para a `development`, com o merge pedido ao usuário.

## Norms

- **Regra 3 (arquitetura):**
  - regras e cálculo das novidades no `FiscalDomain`, como funções puras;
  - estado nos models `@Observable` injetados pelo ambiente;
  - nenhuma view chama repositório.
- **Regra 4 (código):**
  - zero comentários e zero avisos;
  - Swift Testing para o feed, a marca, o controller, os intents e o snapshot;
  - `.timeLimit` em toda suíte que espera;
  - tokens do design system.
- **Regra 5 (design):**
  - fundo branco ou preto;
  - Bricolage só nos títulos de destaque;
  - selo "Novo" em chip;
  - animação discreta com Reduzir movimento e o modo econômico;
  - a dobra e o Mac seguem a FSC-008.
- **Regra 6 (textos):** só pt-BR, frases curtas, sem adjetivo sobre a pessoa.
- **Fatos só (memória "Fiscal: facts only"):** cada novidade tem fonte e data. Nenhuma ordem por "mais ativo", nota ou ranking.
- **ADR 0017 e 0018:** a lista de seguidos fica no iCloud privado da pessoa e, até 6 pessoas, no `following.json` do App Group `group.com.byescaleira`, compartilhado pelos apps byescaleira e lido só pelo widget do Fiscal. Nunca vai a servidor do Fiscal nem ao `EventLog`.

## Safeguards

- **Funcional:**
  - `fiscal://mine`, os atalhos antigos e o widget antigo continuam abrindo a aba.
  - Seguir de qualquer linha nunca abre o perfil por engano: o botão fica fora do `RouteLink`.
  - O estado de seguir é o mesmo em todas as telas, porque há um `FollowController` por janela, recarregado pelo `session.generation`.
  - A falha de uma pessoa não esconde as outras novidades.
- **Desempenho:**
  - no máximo 6 leituras de pessoa ao mesmo tempo e 50 itens na lista;
  - o selo é calculado sem nova leitura;
  - o snapshot do widget tem no máximo 6 entradas.
- **Privacidade:**
  - a marca de última visita fica só no `UserDefaults` local;
  - o snapshot no App Group compartilhado só tem dado público (cartão e novidade), mas a lista de até 6 pessoas seguidas fica legível para qualquer app byescaleira do mesmo grupo;
  - nenhum evento novo no `EventLog` leva slug;
  - a aba Seguindo lê no CDN os arquivos públicos de cada seguido; o CDN vê o IP e o conjunto de pessoas pedidas, como num perfil aberto, e o Fiscal não guarda nada disso;
  - seguir e deixar de seguir pela Siri pedem o aparelho desbloqueado.
- **Integração e compatibilidade:**
  - nenhum schema do SwiftData nem do CloudKit muda;
  - `FollowEntity` intacto.
- **QUEBRA:**
  - a primeira aba muda de Hoje para Seguindo;
  - a Região deixa de ser aba;
  - os textos "Region"/"Região" e os de seguir mudam;
  - a configuração do widget de representantes muda de estática para configurável, e o widget já posto mantém "Meu estado".
- **Fora do escopo:**
  - notificação de qualquer tipo;
  - fluxo de compartilhar (fase 3);
  - web (fases 4 e 5);
  - presença como novidade;
  - seguir candidatos da apuração e nomes da Memória;
  - seguir partido ou tema;
  - mudar o pacote offline.
