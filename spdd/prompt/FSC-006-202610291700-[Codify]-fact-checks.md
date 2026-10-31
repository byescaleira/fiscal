# Checagens do Projeto Comprova

## Requirements

Quem fiscaliza um político quer saber se alguma agência de checagem publicou algo que o cita. Para isso, o servidor lê as publicações do Projeto Comprova (licença CC BY-ND 4.0) e liga cada checagem a uma pessoa só quando o nome não deixa dúvida. Depois publica `people/{slug}/checks.json` com título, selo, data e link como a agência publicou. No app, a resposta aparece na investigação "Houve checagens sobre {nome}?" de Fiscalizar. Ficam de fora: outras agências (Lupa, Aos Fatos) e a API do Google, que dependem de autorização por escrito; qualquer contagem de "mentiras" ou nota da pessoa; e a seção de checagens do perfil, que existe no código mas está desligada.

Definição de pronto (os nomes de pessoas são fictícios, pela Constituição 14; os testes citados usam os das próprias fixtures):

- **Given** duas páginas da API com 9 publicações e nenhum armazenamento anterior **When** `Client.Update` roda às 18:00 UTC de 2026-10-25 **Then** a leitura é completa (`Stats.Full`) e pede `per_page=100`, `orderby=id` e `after=2022-01-01T00:00:00`. Ela guarda 7 checagens e descarta 2: a institucional 106 e a 107, de fora do site. O `completeAt` fica "2026-10-25T18:00:00Z" e, com `MaxPages` 1, fica vazio (`TestFullLoadReadsEveryPageAndExtractsTheSeal` e `TestMaxPagesLeavesTheStoreIncomplete` em `server/internal/sources/comprova/comprova_test.go`).
- **Given** um armazenamento completo de 2026-10-25 18:00 cuja publicação alterada mais recente é de 2026-10-24T20:00:00 **When** a carga roda em 2026-10-26 09:00 **Then** a leitura é incremental, com `modified_after=2026-10-24T19:00:00` e `dates_are_gmt=true`. A carga mantém a checagem 50, troca a 101 pela versão nova, tira a 106 (que virou institucional) e conserva o `completeAt`. Um armazenamento sem `completeAt`, com outro `since` ou com `completeAt` de 7 dias ou mais volta a ler a janela inteira (`TestIncrementalLoadAsksOnlyForModifiedPosts`, `TestStaleOrPartialStoreTriggersAFullLoad`).
- **Given** o texto "Texto sobre falso e enganoso sem marcador." ou "O post é falso, para o Comprova" **When** `Verdicts` procura o selo **Then** a lista sai vazia e o `verdict` fica nulo. A tag "Golpes virtuais" com a imagem `02-Site-GOLPE-Pix.png` dá "Golpe". As frases "Falso, para o Comprova, é…" e "Enganoso, para o Comprova, é…" juntas dão "Enganoso" e "Falso", que viram `Conflict` com `verdict` nulo (`TestVerdictsNeverGuess`, publicação 104 de `TestFullLoadReadsEveryPageAndExtractsTheSeal`).
- **Given** um link `http://projetocomprova.com.br/…`, `https://projetocomprova.com.br.evil.example/x/`, `https://user@projetocomprova.com.br/x/`, só a raiz `https://projetocomprova.com.br/` ou `javascript:alert(1)` **When** `CanonicalURL` confere o link **Then** a publicação é descartada. De um link válido saem a query e o fragmento (`TestCanonicalURL`).
- **Given** o escopo com Rosa, Rosa da Fonte, Ivo Prado e Eduardo Prado **When** `MatchChecks` lê "Rosa da Fonte não votou contra a proposta…", "Receita de rosa cristalizada não cura gripe" e "Ivo Prado acusou Rosa de mentir sobre a obra" **Then** a primeira liga só `rosa-da-fonte`, a segunda não liga ninguém e a terceira liga `ivo-prado` e `rosa` (`TestChecksLinkOnlyTheExactFullName` em `server/internal/publicdata/checks_test.go`).
- **Given** os títulos "Vídeo antigo do governo Prado circula como se fosse atual", "Post de Otávio distorce fala sobre igrejas", "Carlos Silva não disse que vai fechar escolas" e "Lauro Neto não declarou apoio a candidato" **When** `MatchChecks` roda **Then** nenhum liga. Ficam na revisão `surnameOnly` "prado" (candidatos `eduardo-prado` e `ivo-prado`), `ambiguousName` "carlos silva" (`carlos-silva-ba` e `carlos-silva-sp`) e `partOfLongerName` "neto". "Otávio" sozinho não gera revisão, e a revisão vem da mais nova para a mais antiga (`TestChecksLinkOnlyTheExactFullName`, `TestChecksSendHomonymsAndPartialNamesToReview`).
- **Given** o deputado Paulo Lemos no escopo e os textos "o ministro da Economia, Paulo Lemos", "Deputado Ivo Prado não disse isso", "Vídeo do ex-presidente Rosa foi editado" e "o então juiz Davi Cunha" **When** `MatchChecks` roda **Then** os dois primeiros vão para `officeMismatch`. A outra checagem que cita Paulo Lemos, sem confirmação, vai para `possibleHomonym`. "ex-presidente" e "então juiz" anulam o cargo, e as duas últimas ligam `rosa` e `davi-cunha` (`TestChecksUseTheOfficeTitleAgainstHomonymsOutsideTheScope`).
- **Given** `comprova-99` e `comprova-100` de 2026-10-01 e `comprova-150` de 2026-10-20, esta com os selos "Enganoso" e "Falso", todas sobre Otávio Reis **When** `MatchChecks` ordena **Then** a ordem é `comprova-150`, `comprova-100`, `comprova-99`. A 150 é publicada com `verdict` nulo e gera a revisão `verdictConflict` com os rótulos "Enganoso" e "Falso" e o candidato `otavio-reis` (`TestChecksOrderAndVerdictConflict`).
- **Given** as publicações 7 ("Vídeo de Alan Rick foi editado para parecer outra fala", tag "Enganoso") e 8 ("Post sobre Rick engana") **When** `Ingest.Full` roda **Then** sai só `people/alan-rick/checks.json`, com 1 item `comprova-7`: "Enganoso", 2026-10-20, editor "Projeto Comprova" e a fonte `comprova`. O relatório traz `Checks` 2, `CheckPeople` 1, `CheckLinks` 1 e `Reviews` 1. `checks-review.json` fica em `DATA_DIR` com `surnameOnly` "rick" e nunca aparece em `v1/`, e `comprova.json` tem permissão 0600 (`TestFullPublishesChecksAndKeepsThemWhenTheSourceFails` em `server/internal/ingest/ingest_test.go`, `TestBuildPublishesChecksOnlyForLinkedPeople`).
- **Given** a API do Comprova respondendo 503 na carga seguinte **When** `Ingest.Full` roda **Then** a carga não para, um aviso cita "comprova" e `people/alan-rick/checks.json` continua byte a byte igual (`TestFullPublishesChecksAndKeepsThemWhenTheSourceFails`).
- **Given** `people/lula/checks.json` com `comprova-20389` ("Falso", 2026-09-30) e `comprova-20025` (`verdict` nulo) **When** `PublicDataClient.checks(slug:)` lê o arquivo **Then** devolve os dois itens nessa ordem, com editor "Projeto Comprova", licença "CC BY-ND 4.0", o link da licença e a fonte `comprova`. Um 404 para `kim-kataguiri` devolve `nil`, que quer dizer "sem checagens" (`FactCheckTests.decodesTheChecksOfAPerson`, `FactCheckTests.aMissingFileMeansNoChecks`).
- **Given** o servidor respondendo 503, ou um corpo `{"items": 1}` **When** `checks(slug:)` lê **Then** lança `PublicDataError.unavailable` e `PublicDataError.invalidData`, respectivamente (`FactCheckTests.otherFailuresStillThrow`). No modo de vitrine `.offline`, lança `PublicDataError.offline` (`FactCheckTests.showcaseCoversEverySealAndPeopleWithout`).
- **Given** a vitrine de depuração com 4 checagens da Pessoa A e nenhuma da Pessoa B **When** a pessoa toca a sugestão "Houve checagens sobre {nome}?" em Fiscalizar **Then** aparece "O Projeto Comprova publicou 4 checagens que citam {nome}.", seguido das 3 primeiras com selo ("Sem selo" quando nulo), data, título e link. Embaixo vêm "Fonte: Projeto Comprova · CC BY-ND 4.0" e "Uma checagem que cita alguém nem sempre é sobre algo que essa pessoa disse.". Para a Pessoa B a frase é "O Projeto Comprova não tem checagem publicada que cite {nome}." (roteiro manual: abrir Fiscalizar na vitrine, investigar as checagens de uma pessoa com checagens e de outra sem).
- **Given** qualquer perfil, com `ProfileModel.showsFactChecks` igual a `false` **When** o perfil abre **Then** a seção "Checagens" não aparece (`ProfileModelTests.loadsTheProfileWithItsNumbersAndActivity` confere o valor `false`; roteiro manual: abrir um perfil qualquer e confirmar que não há seção "Checagens").

## Entities

```mermaid
classDiagram
  class ComprovaClient {
    Getter Get
    String Since
    int MaxPages
    Duration Refresh
    Update(prev) Store
  }
  class ComprovaStore {
    String since
    String completeAt
    List~ComprovaCheck~ checks
  }
  class ComprovaCheck {
    int64 id
    String date
    String modified
    String url
    String title
    String? verdict
    List~String~ conflict
    List~String~ explanations
  }
  class RawCheck {
    String ID
    String Source
    String Title
    List~String~ Texts
    String? Verdict
    List~String~ Conflict
    String Publisher
    String License
    String LicenseURL
  }
  class CheckMatch {
    Map ByPerson
    List~CheckReview~ Reviews
  }
  class CheckReview {
    String checkId
    String reason
    String name
    List~String~ candidates
    List~String~ labels
  }
  class CheckList {
    List~FactCheck~ items
    List~Source~ sources
  }
  class FactCheckGo {
    String id
    String title
    String? verdict
    String date
    String url
    String publisher
    String license
    String licenseUrl
  }
  class FactCheckList {
    List~FactCheck~ items
    List~Source~ sources
  }
  class FactCheck {
    String id
    String title
    String? verdict
    CalendarDay date
    URL url
    String publisher
    String license
    URL licenseUrl
  }
  class InvestigationEvidence {
    Map checks
    Set~String~ checked
  }
  class CheckLine {
    String id
    String title
    String? verdict
    String date
    URL url
  }
  class InvestigationPiece {
    checks(PersonCard)
  }
  class ProfileModel {
    Bool showsFactChecks
  }
  ComprovaClient --> ComprovaStore : produz
  ComprovaStore "1" --> "*" ComprovaCheck
  ComprovaCheck ..> RawCheck : loadChecks converte
  RawCheck ..> CheckMatch : MatchChecks
  CheckMatch "1" --> "*" FactCheckGo
  CheckMatch "1" --> "*" CheckReview
  CheckList "1" --> "*" FactCheckGo
  CheckList ..> FactCheckList : checks.json
  FactCheckList "1" --> "*" FactCheck
  InvestigationPiece ..> InvestigationEvidence : pede checks(slug:)
  InvestigationEvidence "1" --> "*" FactCheckList
  FactCheck ..> CheckLine : 3 primeiras
```

- `ComprovaClient` (`comprova.Client` em `server/internal/sources/comprova/comprova.go`) lê a API do WordPress do Comprova, completa ou incremental, e devolve um `ComprovaStore`.
- `ComprovaStore` (`comprova.Store`) é o estado da leitura, gravado em `DATA_DIR/comprova.json`. `completeAt` só existe depois de uma leitura completa que terminou.
- `ComprovaCheck` (`comprova.Check`) é uma publicação aceita, já com o título em texto puro, o selo único ou a lista `Conflict` e as explicações das tags.
- `RawCheck` (`server/internal/publicdata/checks.go`) é a checagem pronta para casar com nomes, com id `comprova-<n>`, fonte `comprova`, editor, licença e link da licença. Também é o payload guardado no SQLite com a chave `check:` (ADR 0006).
- `CheckMatch` e `CheckReview` (`checks.go`) são o resultado do casamento: as checagens por pessoa e a lista interna de revisão. A lista sai em `DATA_DIR/checks-review.json` (`checkReviewFile` em `server/internal/ingest/checks.go`) e nunca é publicada.
- `CheckList` e `FactCheckGo` (`publicdata.CheckList` e `publicdata.FactCheck`) formam o JSON público de `people/{slug}/checks.json`. `PersonFacts.Checks` (`server/internal/publicdata/facts.go`) põe a contagem por pessoa em `index/facts.json`.
- `FactCheck` e `FactCheckList` (`FiscalKit/Sources/FiscalDomain/PublicData/FactCheck.swift`) são o mesmo contrato no app, `Codable` e `Sendable`, com `date` em `CalendarDay` e `verdict` opcional. `PersonFacts.checks` (`FiscalDomain/PublicData/PersonFacts.swift`) decodifica a contagem do índice.
- `InvestigationEvidence` (`FiscalKit/Sources/FeatureSearch/InvestigationEngine.swift`) guarda a lista de cada slug e o conjunto `checked` dos slugs que responderam.
- `CheckLine` (`InvestigationLink.CheckLine` em `FeatureSearch/InvestigationBoard.swift`) é a linha pronta para a tela.
- `InvestigationPiece.checks(PersonCard)` (`FeatureSearch/InvestigationPiece.swift`) é a peça da investigação. Ela é codificada em `InvestigationEntity.pieces` de `FiscalSchemaV3`, que sincroniza pelo CloudKit. As checagens em si não são salvas: são relidas a cada abertura.
- `ProfileModel.showsFactChecks` (`FeatureProfile/ProfileModel.swift`) é a constante que desliga a seção do perfil.
- Nenhum `@Model` novo nem mudança de schema SwiftData pertence a esta capacidade. Ela só depende de o nome do caso `checks` continuar estável dentro do `pieces` salvo.

## Approach

1. **Estratégia da solução:** a cada 45 minutos, das 7 h às 24 h, o job `checagens` sonda a última publicação alterada do Comprova. Se algo mudou, lê de novo só o que mudou, com 1 h de folga, e uma vez a cada 7 dias relê a janela inteira desde `COMPROVA_SINCE`. Cada publicação vira uma checagem com o selo da agência ou com `null`. O `Build` casa os nomes de todas as pessoas do escopo com o título e as explicações das tags. Liga só nome inteiro, com inicial maiúscula, de uma única pessoa e que não seja parte de um nome maior. O resto vai para a revisão interna. Sai `people/{slug}/checks.json` só para quem tem pelo menos uma checagem, e o stager `v2` embute o arquivo em `people/{slug}.json`. No app, `PublicDataClient.checks(slug:)` lê o arquivo, com o 404 tratado como lista vazia. A investigação mostra a frase, as 3 primeiras checagens, a fonte com a licença e o aviso de incerteza. A seção do perfil continua desligada.
2. **Decisões:**
   - Só o Comprova, porque é a única licença aberta achada (CC BY-ND 4.0). Lupa e Aos Fatos proíbem raspagem e reprodução sem autorização por escrito. A API do Google é alfa, não tem cota documentada e limita cache. Descartado: raspar as agências ou chamar o Google a cada visita. Fonte: `docs/research/2026-10-25-fact-checks.md`. ADR: não há; a decisão está na pesquisa, em `server/README.md` e em `docs/changes/archive/2026-10-29-app-1.0/proposal.md`.
   - O título, o selo, a data e o link vão como a agência publicou, com crédito e link da licença em cada item, porque a CC BY-ND não permite derivação. Descartado: um selo normalizado nosso. ADR: não precisa (Constituição 14).
   - O selo sai de quatro sinais: tag, frase de definição, cabeçalho e nome da imagem. Sem sinal, ele fica `null`; com sinais que discordam, também `null`, e a publicação entra na revisão. Descartado: adivinhar o selo pelo texto livre. ADR: não precisa.
   - O nome só liga quando não deixa dúvida (nome de urna ou civil inteiro, único no escopo, solto). O cargo antes do nome confirma ou contradiz; o partido entre parênteses depois dele confirma. Na dúvida, a checagem fica de fora e vai para a revisão. Descartado: tabela manual de apelidos e revisão humana antes de publicar, como a pesquisa sugeria. ADR: não precisa.
   - Os arquivos são estáticos e pré-gerados, sem cálculo por requisição. ADR: `docs/adr/0002-static-first-server.md`.
   - As leituras ficam como snapshots `check:` e série `checks.published` por mês no SQLite, sem nada apagado. ADR: `docs/adr/0006-ingest-sqlite-store.md`.
   - No CDN, o layout `v2` junta os arquivos da pessoa em `people/{slug}.json`. ADR: `docs/adr/0007-pages-cdn-phased-ingest.md`.
   - O job é de sobreposição, com sonda de API e idade máxima de 24 h. Descartado: a fase diária de madrugada do ADR 0007. ADR: `docs/adr/0008-smart-sync.md`.
   - A seção do perfil fica desligada por constante no model, porque hoje mostraria só um item genérico. A ligação está no backlog como P2. Descartado: mostrar a seção sem a lista. ADR: não precisa.
   - O app é só em pt-BR. ADR: `docs/adr/0003-portuguese-only.md`.
3. **Tratamento de erros:**
   - **Servidor, leitura:** falha de rede ou cabeçalho `X-WP-TotalPages` ausente fazem `Update` devolver erro. `loadChecks` então mantém o último armazenamento, com o aviso "comprova: … (kept the checks from the last load)". Sem armazenamento, o aviso é "(no fact checks published)" e a carga segue.
   - **Servidor, `comprova.json`:** um `comprova.json` ilegível vira aviso, e a leitura começa do zero. Sem leitura nova, `storeChecks` publica a última leitura guardada no banco (estado `fallback`) ou marca a fonte como `failed`.
   - **Servidor, publicações descartadas:** publicação com id inválido, link fora do site, data ilegível, sem título ou institucional é descartada e, numa leitura incremental, removida do armazenamento.
   - **Servidor, configuração:** `COMPROVA_SINCE` fora de AAAA-MM-DD, antes de 2018 ou no futuro faz a configuração falhar fechada.
   - **App, arquivo:** um 404 de `checks.json` vira `nil`, e a investigação mostra "O Projeto Comprova não tem checagem publicada que cite {nome}.".
   - **App, falhas:** `unavailable`, `offline` e `invalidData` sobem como erro. Primeiro passam pelo pacote offline e pelo cache do cliente (FSC-002).
   - **App, investigação:** o motor conta a falha. A pergunta de checagens some, porque o slug não entra em `checked`. A investigação só lança erro quando todas as leituras falham.
4. **Riscos:**
   - Homônimo fora do escopo ligado por engano → cargo contraditório, `possibleHomonym` para as outras checagens de quem nunca teve confirmação, e o aviso de incerteza na tela.
   - Nome que é palavra comum (nome em minúsculas, como "rosa") → só liga com inicial maiúscula e palavra inteira.
   - Sobrenome de família política, compartilhado por mais de uma pessoa do escopo → nunca liga sozinho.
   - Mudança no layout do WordPress do Comprova → selo `null` em vez de errado, e a revisão interna para ler de vez em quando.
   - Publicação que vira institucional ou sai do ar → removida na leitura incremental e na releitura de 7 dias.
   - Conteúdo malicioso no link → `CanonicalURL` aceita só `https` no host exato, sem usuário, e tira query e fragmento.
   - Leitura cortada em `maxPages` → `completeAt` vazio, e a próxima carga relê tudo.

**Known divergences:**

- `Spec × código:` a spec diz que "Selos em conflito vão para a revisão". O código publica a checagem mesmo assim, com `verdict` nulo, e o app mostra "Sem selo". A revisão `verdictConflict` é só um aviso a mais (`server/internal/sources/comprova/comprova.go:247-254`, `server/internal/publicdata/checks.go:458-465`).
- `Spec × código:` a spec lista como descartadas as publicações institucionais, de fora do site e sem título. O código também descarta id menor ou igual a 0 e data ilegível (`server/internal/sources/comprova/comprova.go:220-230`).
- `Spec × código:` a spec resume `possibleHomonym` como "Cargo contraditório sem confirmação". No código, a contradição e a confirmação valem pelo conjunto inteiro de checagens: basta um cargo contraditório em qualquer uma, sem nenhuma confirmação em outra, para mandar à revisão todas as outras menções ligadas à pessoa. O partido entre parênteses depois do nome também conta como confirmação (`server/internal/publicdata/checks.go:299-310`, `376-382`, `410-414`).
- `Spec × código:` a spec não cita que `index/facts.json` traz a contagem `checks` por pessoa (`server/internal/publicdata/facts.go:98`). O app decodifica o campo em `PersonFacts.checks` (`FiscalKit/Sources/FiscalDomain/PublicData/PersonFacts.swift:58`), mas nenhuma tela o usa.
- `Spec × código:` a spec diz que a investigação mostra quantas checagens há "ou que não há nenhuma". Quando a leitura de `checks.json` falha (sem rede, 503), a pergunta simplesmente não aparece, sem frase de falha própria (`FiscalKit/Sources/FeatureSearch/InvestigationLinks+People.swift:19`, `FiscalKit/Sources/FeatureSearch/InvestigationEngine.swift:83-85`).
- `Playbook:` "plurais por variação" (Constituição 6) não é seguido. "O Projeto Comprova publicou %1$@ checagens que citam %2$@." e "checagens que citam %@" recebem o número já formatado como texto e não têm variação de plural no catálogo. Com uma checagem, a frase fica "publicou 1 checagens" (`FiscalKit/Sources/FeatureSearch/InvestigationLinks+People.swift:164-167` e `179`, `Fiscal/Fiscal/Localizable.xcstrings`).
- `Playbook:` a escolha de uma dependência externa (Projeto Comprova, CC BY-ND 4.0, e a exigência de autorização para as outras agências) não tem ADR. A decisão vive só em `docs/research/2026-10-25-fact-checks.md` e em `server/README.md`.
- `Sem teste:` a investigação de checagens não tem teste automatizado em `FiscalKit/Tests/FeatureSearchTests`. Faltam a frase com N, a frase sem checagens, as 3 primeiras linhas, a fonte, o aviso, a sugestão "Houve checagens sobre {nome}?" e as palavras "checag", "falso" e "comprova" de `QuestionReader`.
- `Sem teste:` a ausência da seção "Checagens" na tela do perfil não tem teste. Só o valor de `ProfileModel.showsFactChecks` é conferido (`FiscalKit/Tests/FeatureProfileTests/ProfileModelTests.swift:56`).

## Structure

Camadas tocadas e regra de dependência:

- **Servidor Go:**
  - `server/internal/sources/comprova` lê a fonte e não conhece pessoas.
  - `server/internal/publicdata` casa nomes e monta os arquivos, sem rede.
  - `server/internal/ingest` orquestra a leitura, o banco, a revisão e o job, e depende dos dois anteriores.
  - `server/internal/site` empacota o `v2`.
  - `server/cmd/ingest` valida a configuração.
- **Domínio:** `FiscalDomain` define `FactCheck`, `FactCheckList`, `PersonFacts.checks`, o protocolo `PublicDataService.checks(slug:)` e `PublicDataPath.checks(slug:)`.
- **Dados:** `FiscalData` implementa o protocolo em `PublicDataClient` e na vitrine de depuração `ShowcasePublicData`.
- **Features:** `FeatureSearch` (investigação) e `FeatureProfile` (seção desligada) dependem de `FeatureCore`, `FiscalDomain` e `FiscalDesignSystem` e recebem o serviço por injeção. Features não se importam: o atalho para o perfil sai por `Route`.
- **Textos:** chaves em inglês com só a tradução pt-BR em `Fiscal/Fiscal/Localizable.xcstrings`.
- **Fora do escopo:** widgets, App Intents, Live Activity e deep links não tocam checagens.

Árvore dos arquivos principais:

- `server/`
  - `cmd/ingest/main.go` (`COMPROVA_SINCE`, fonte `comprova` em `INGEST_SOURCES`)
  - `cmd/ingest/main_test.go` (`TestComprovaSource`, `TestInvalidConfigFailsClosed`)
  - `internal/sources/comprova/comprova.go`
  - `internal/sources/comprova/comprova_test.go`
  - `internal/sources/comprova/testdata/page1.json`, `page2.json`
  - `internal/publicdata/checks.go`
  - `internal/publicdata/checks_test.go`
  - `internal/publicdata/build.go` (`builder.checks`)
  - `internal/publicdata/facts.go` (`PersonFacts.Checks`)
  - `internal/publicdata/text.go` (`Fold`, `foldMap`)
  - `internal/ingest/checks.go` (`loadChecks`, `writeCheckReview`)
  - `internal/ingest/store.go` (`storeChecks`, `storedChecks`)
  - `internal/ingest/ingest.go`, `overlay.go` (onde a fonte `comprova` entra na carga)
  - `internal/ingest/cadence.go` (job `checagens`), `probe.go` (sonda), `phase.go` (fase `checagens`)
  - `internal/ingest/ingest_test.go` (`TestFullPublishesChecksAndKeepsThemWhenTheSourceFails`)
  - `internal/ingest/sync_test.go` (`TestOverlayJobsReuseTheSnapshotInsteadOfRestoringEverySource`)
  - `internal/site/bundle.go` (`writePerson`, que embute `checks.json` em `people/{slug}.json`)
  - `README.md` (seção "Checagens (Projeto Comprova)")
- `FiscalKit/Sources/`
  - `FiscalDomain/PublicData/FactCheck.swift`
  - `FiscalDomain/PublicData/PublicDataService.swift` (`checks(slug:)`, `PublicDataPath.checks(slug:)`)
  - `FiscalDomain/PublicData/PersonFacts.swift`
  - `FiscalData/PublicData/PublicDataClient.swift` (`checks(slug:)`)
  - `FiscalData/PublicData/PublicDataLayout.swift` (`people/{slug}/checks.json` vira membro `files` no `v2`)
  - `FiscalData/PublicData/Showcase/ShowcaseChecks.swift`, `ShowcasePublicData+Extras.swift`
  - `FeatureSearch/InvestigationPiece.swift` (caso `checks`, título "Checagens sobre {nome}", fonte "Projeto Comprova")
  - `FeatureSearch/InvestigationPlan.swift` (`QuestionReader.metricWords`, `InvestigationResolver`)
  - `FeatureSearch/InvestigationPlanner.swift` (`PlanMetric.factChecks`)
  - `FeatureSearch/InvestigationSuggestion.swift` (`personQuestion`)
  - `FeatureSearch/InvestigationDoors.swift` (porta "Checagens", "O que o Projeto Comprova checou")
  - `FeatureSearch/PiecePicker.swift`
  - `FeatureSearch/InvestigationEngine.swift`
  - `FeatureSearch/InvestigationLinks+People.swift` (`checks(_:)`)
  - `FeatureSearch/InvestigationLinks.swift` (fontes da investigação)
  - `FeatureSearch/InvestigationBoard.swift` (`CheckLine`, `Visual.checks`)
  - `FeatureSearch/InvestigationLinkSection.swift`, `InvestigationVisuals.swift` (`ChecksVisual`)
  - `FeatureProfile/ProfileModel.swift` (`showsFactChecks`)
  - `FeatureProfile/ProfileHistorySections.swift` (`ProfileFactChecksSection`)
  - `FeatureProfile/ProfileScreen.swift`
- `FiscalKit/Tests/`
  - `FiscalDataTests/FactCheckTests.swift`
  - `FiscalDataTests/PublishedCompletenessTests.swift` (leitura opcional de `checks` contra os dados reais)
  - `FeatureProfileTests/ProfileModelTests.swift`
- `Fiscal/Fiscal/Localizable.xcstrings`
- `docs/research/2026-10-25-fact-checks.md`

## Operations

1. **Leitura e selo de uma publicação** (`server/internal/sources/comprova/comprova.go`):
   - `Parse(data []byte) (Check, bool, error)`:
     - decodifica `id`, `date`, `modified_gmt`, `link`, `title.rendered`, `content.rendered`, `tags`, `image-masked` e `yoast_head_json.og_image`;
     - devolve `ok` falso para id menor ou igual a 0, link recusado por `CanonicalURL`, data fora de `2006-01-02T15:04:05`, título vazio depois de `PlainText` ou publicação institucional;
     - institucional quer dizer tag de `institutionalTags`, imagem `01-Site-…` ou imagem `02-Site-` seguida de Comunicado, Release, Retorno ou Vozes;
     - guarda as explicações das tags em texto puro e chama `Verdicts`.
   - `Verdicts(tags, content, images) []string` junta, sem repetir e em ordem alfabética, os rótulos de quatro sinais:
     - tag (`tagLabels`);
     - frase "<Rótulo>, para o Comprova, é/são" (`definitionLabels`);
     - cabeçalho em negrito seguido de ":" (`headerLabels`);
     - prefixo do nome da imagem `NN-Site-` (`imageLabels`).
   - O retorno de `Verdicts` define o selo:
     - um rótulo vira `Verdict`;
     - dois ou mais viram `Conflict`;
     - nenhum deixa `Verdict` nulo.
   - `CanonicalURL(raw string) (string, bool)` aceita só `https` em `projetocomprova.com.br`, sem usuário e com caminho além de "/", e tira a query e o fragmento.
   - Verificação: `cd server && go test ./internal/sources/comprova/...`.
2. **Leitura completa ou incremental** (`server/internal/sources/comprova/comprova.go`):
   - `Client.Update(ctx, prev *Store) (Store, Stats, error)`:
     - valida `Since` (padrão `DefaultSince` "2022-01-01");
     - `needsFull` decide pela leitura completa quando não há `prev`, quando `Since` mudou, quando `CompleteAt` está vazio ou é ilegível e quando já se passaram 7 dias (`Refresh`);
     - monta `per_page=100`, `orderby=id`, `order=asc`, `after=<since>T00:00:00` e `_fields`;
     - na incremental, acrescenta `modified_after` (a maior `modified` menos 1 h) e `dates_are_gmt=true` e parte das checagens anteriores;
     - lê página a página, até `MaxPages` (no máximo 200) ou até `X-WP-TotalPages`, falhando sem esse cabeçalho;
     - remove do mapa o que `Parse` recusou;
     - grava `CompleteAt` só quando uma leitura completa termina e conserva o anterior na incremental;
     - ordena por id.
   - `LoadStore(path)` devolve `nil` sem arquivo.
   - `SaveStore(path, s)` grava em `.tmp` com permissão 0600 e renomeia.
   - Depende de: 1. Verificação: `cd server && go test ./internal/sources/comprova/...`.
3. **Índice de nomes e leitura do texto** (`server/internal/publicdata/checks.go`):
   - `tokenize(s string) []token` dobra acentos e caixa (`foldMap`) e marca para cada palavra:
     - `upper` (inicial maiúscula);
     - `joined` (colada à anterior por espaço, hífen ou apóstrofo);
     - `hard` (depois de ".", "!", "?", ";" ou ":");
     - `paren` (depois de "(" ou "[");
     - `initial` (primeira palavra ou depois de pontuação forte).
   - `newNameIndex(people) nameIndex` indexa:
     - o nome de urna e o civil dobrados com `Fold`;
     - nome de uma palavra só quando é o de urna e tem pelo menos 4 letras (`minOneWordName`);
     - o último sobrenome do nome de urna com 4 letras ou mais e que não seja partícula.
   - `nameIndex.scan(text) []nameHit` faz o casamento:
     - procura, da maior para a menor, a sequência encadeada e capitalizada que não começa nem termina em partícula;
     - marca `standalone` quando o trecho tem 3 palavras significativas ou mais (`longName`) ou quando não está colado a outro nome com maiúscula;
     - para um dono único, calcula a evidência: o cargo nas 4 palavras antes do nome (`titleWindow`, anulado por "ex", "pré", "então" e afins, e "presidente da/do" não conta) contra `Person.Roles`, ou o partido entre parênteses depois do nome;
     - sem nome inteiro, registra o sobrenome solto.
   - Depende de: 2. Verificação: `cd server && go test ./internal/publicdata/... -run 'Checks|Tokenize'`.
4. **Casamento e revisão** (`server/internal/publicdata/checks.go`):
   - `MatchChecks(people []*Person, slugs map[*Person]string, checks []RawCheck) CheckMatch` lê o título e cada texto de cada checagem:
     - `surname` vira `surnameOnly`;
     - mais de um dono vira `ambiguousName`;
     - não solto vira `partOfLongerName`;
     - evidência contrária vira `officeMismatch` e marca a pessoa como contradita;
     - o resto liga, e a evidência a favor marca a pessoa como confirmada.
   - Na segunda passada, quem foi contradito e nunca confirmado vai para `possibleHomonym`, e os demais recebem o `FactCheck`.
   - `reviewsFor` cria uma revisão por motivo e nome, com os candidatos não publicados em ordem, mais `verdictConflict` com os rótulos quando há `Conflict`.
   - `sortChecks` ordena:
     - por data decrescente;
     - depois pelo id mais longo;
     - depois pelo id maior.
   - As revisões vão da data mais nova para a mais antiga, depois por id, motivo e nome.
   - Depende de: 3. Cobre: as linhas de ligação, de revisão, de cargo e de ordem e conflito da definição de pronto. Verificação: `cd server && go test ./internal/publicdata/...`.
5. **Arquivos públicos** (`server/internal/publicdata/build.go`, `facts.go`):
   - `builder.checks(people) []CheckReview`:
     - sem checagens, devolve lista vazia;
     - senão chama `MatchChecks`;
     - para cada pessoa com pelo menos 1 item, grava `checkCounts` e acrescenta `people/{slug}/checks.json` com `CheckList{Items, Sources}`, onde as fontes são as de `RawCheck.Source`.
   - `builder.facts` escreve `checks` (a contagem, 0 sem checagem) em cada item de `index/facts.json`.
   - Depende de: 4. Verificação: `cd server && go test ./internal/publicdata/... -run TestBuildPublishesChecksOnlyForLinkedPeople`.
6. **Carga, banco e revisão interna** (`server/internal/ingest/checks.go`, `store.go`, `ingest.go`, `overlay.go`):
   - `Ingest.loadChecks(ctx, rep, srcs) []RawCheck`:
     - lê `DATA_DIR/comprova.json`;
     - chama `Client.Update` com `ChecksSince` e `ChecksMaxPages`;
     - se a leitura falha, mantém o anterior ou devolve `nil` com aviso;
     - se dá certo, grava o armazenamento e registra no log só contagens (`full`, `pages`, `posts`, `skipped`, `stored`);
     - converte cada `Check` em `RawCheck` com id `comprova-<n>`, `Name`, `License` e `LicenseURL` do pacote.
   - `storeChecks`:
     - grava os snapshots `check:` e a série `checks.published` por mês (AAAA-MM);
     - sem leitura nova, publica a última guardada (`fallback`).
   - Com a fonte em dia, `storedChecks` reaproveita o banco sem rede.
   - `writeCheckReview(items)` grava `DATA_DIR/checks-review.json` (`generatedAt`, `items`) com permissão 0600, por troca atômica e só quando os itens mudaram.
   - `cmd/ingest` valida `COMPROVA_SINCE` entre 2018 e hoje.
   - Depende de: 2, 5. Cobre: as duas linhas de `Ingest.Full` da definição de pronto. Verificação: `cd server && go test ./internal/ingest/... ./cmd/ingest/...`.
7. **Job `checagens`** (`server/internal/ingest/cadence.go`, `probe.go`, `phase.go`):
   - o catálogo traz `checagens`, do tipo `JobSources`, com a fonte `comprova`;
   - a cadência é a cada 45 min na janela `daytime` (todos os dias, das 7 h às 24 h), com `ProbeAPI` e `MaxAge` de 24 h;
   - o job é `Overlay`: reaproveita o snapshot e troca só a parte da fonte;
   - a sonda pede `?per_page=1&orderby=modified&order=desc&_fields=id,modified_gmt`.
   - Depende de: 6. Verificação: `cd server && go test ./internal/ingest/... -run 'TestCatalogIsDocumented|TestOverlayJobsReuseTheSnapshotInsteadOfRestoringEverySource'`.
8. [P] **Pacote `v2`** (`server/internal/site/bundle.go`): `writePerson(slug, srcs, read, write)` põe `people/{slug}/checks.json` em `files["checks.json"]` de `people/{slug}.json`. Depende de: 5. Verificação: `cd server && go test ./internal/site/...`.
9. [P] **Tipo e contrato no domínio** (`FiscalKit/Sources/FiscalDomain/PublicData/FactCheck.swift`, `PublicDataService.swift`, `PersonFacts.swift`):
   - `FactCheck` tem `id`, `title`, `verdict: String?`, `date: CalendarDay`, `url: URL`, `publisher`, `license` e `licenseUrl: URL`;
   - `FactCheckList` tem `items` e `sources`;
   - o protocolo declara `checks(slug: String) async throws -> FactCheckList?`;
   - o caminho é `PublicDataPath.checks(slug:)`, que devolve "people/{slug}/checks.json";
   - `PersonFacts.checks` é `Int`.
   - Verificação: `scripts/test.sh --affected`.
10. **Leitura no app e vitrine** (`FiscalKit/Sources/FiscalData/PublicData/PublicDataClient.swift`, `PublicDataLayout.swift`, `Showcase/ShowcaseChecks.swift`):
    - `PublicDataClient.checks(slug:) async throws -> FactCheckList?` chama `get` e transforma `PublicDataError.notFound` em `nil`;
    - os demais erros sobem depois do pacote offline e do cache;
    - no `v2`, `PublicDataLayout.locate` resolve o caminho como membro `files` do arquivo da pessoa.
    - A vitrine `ShowcasePublicData.checks(slug:)` (só em `DEBUG`):
      - tem 4 checagens de `lula`, 2 de `nikolas-ferreira` e 1 de `tabata-amaral`;
      - devolve `nil` para os demais e no cenário `.empty`;
      - lança `.offline` no cenário `.offline`.
    - Depende de: 9. Cobre: as linhas de `FactCheckTests` da definição de pronto. Verificação: `scripts/test.sh --affected`.
11. **Peça e pergunta da investigação** (`FiscalKit/Sources/FeatureSearch/InvestigationPiece.swift`, `InvestigationPlan.swift`, `InvestigationPlanner.swift`, `InvestigationSuggestion.swift`, `InvestigationDoors.swift`, `PiecePicker.swift`):
    - `InvestigationPiece.checks(PersonCard)`:
      - id "checks-{slug}";
      - título "Checagens sobre {nome}";
      - fonte "Projeto Comprova";
      - símbolo `checkmark.shield` e cor `.retroRust`;
      - `needsPerson` verdadeiro.
    - `QuestionReader.metricWords` liga "checag", "falso" e "comprova" a `.checks`, e o planejador no aparelho liga `PlanMetric.factChecks`.
    - `InvestigationResolver` acrescenta `.checks(card)` para cada pessoa da pergunta.
    - A porta "Checagens" ("O que o Projeto Comprova checou") abre o seletor com todas as pessoas.
    - `personQuestion` sugere "Houve checagens sobre {nome}?" para quem não é deputado federal com votação recente.
    - Depende de: 9. Verificação: `scripts/test.sh --affected`.
12. **Evidência** (`FiscalKit/Sources/FeatureSearch/InvestigationEngine.swift`):
    - `InvestigationEngine.evidence(for:recent:) async throws -> InvestigationEvidence` chama `service.checks(slug:)` em paralelo para cada peça `.checks`;
    - uma resposta, mesmo `nil`, entra em `checked` e em `checks`;
    - uma falha conta em `failures`;
    - o motor só lança erro quando todas as leituras falham com erro diferente de `.notFound`.
    - Depende de: 10, 11. Verificação: `scripts/test.sh --affected`.
13. **Resposta e visual** (`FiscalKit/Sources/FeatureSearch/InvestigationLinks+People.swift`, `InvestigationBoard.swift`, `InvestigationVisuals.swift`, `InvestigationLinks.swift`):
    - `InvestigationLinks.checks(_ card: PersonCard) -> InvestigationLink` só entra quando a peça existe e o slug está em `checked`;
    - toma as 3 primeiras como `CheckLine`, com a data em `PublicFormat.updatedDay` (dia, mês abreviado e ano);
    - a frase é "O Projeto Comprova publicou {N} checagens que citam {nome}." ou "O Projeto Comprova não tem checagem publicada que cite {nome}.";
    - a pergunta é "Houve checagens sobre {nome}?";
    - a fonte é "Fonte: Projeto Comprova · CC BY-ND 4.0";
    - o número-chave {N} vem com o rótulo "checagens que citam {nome}", e só quando há itens;
    - a incerteza é "Uma checagem que cita alguém nem sempre é sobre algo que essa pessoa disse.";
    - as fontes do arquivo entram no rodapé da investigação.
    - `ChecksVisual` mostra cada linha como `Link` para a URL da agência, com:
      - `StatusCircle` do selo ("Sem selo" e borda tracejada quando nulo);
      - "selo · data" em `.caseKicker`;
      - o título em `.subheadline`;
      - espaçamentos `.spaceM`, `.spaceS` e `.space2XS`.
    - Depende de: 12. Cobre: a linha da investigação da definição de pronto (roteiro manual).
14. [P] **Seção do perfil desligada** (`FiscalKit/Sources/FeatureProfile/ProfileModel.swift`, `ProfileHistorySections.swift`, `ProfileScreen.swift`):
    - `ProfileModel.showsFactChecks` é a constante `false`;
    - `ProfileFactChecksSection` só desenharia, quando ligada, o cabeçalho "Checagens" e o item "Checagens" com "Checagens publicadas por agências de checagem.", sem ler `checks.json`.
    - Depende de: 9. Cobre: a linha do perfil da definição de pronto. Verificação: `scripts/test.sh --affected`.
15. **Textos** (`Fiscal/Fiscal/Localizable.xcstrings`): as chaves em inglês dos passos 11, 13 e 14 têm só a tradução pt-BR, `translated`, e nenhuma usa "Fato ou Fake". Depende de: 11, 13, 14. Verificação: `scripts/strings.sh` depois de `scripts/build.sh Debug ios`.

## Norms

- `Constituição 14:` o selo, o título, a data e o link vão como o Comprova publicou, com "Projeto Comprova", "CC BY-ND 4.0" e o link da licença em cada item. Sem selo, a tela mostra "Sem selo", nunca um selo nosso. Não há contagem de "mentiras", nota nem ranking: todas as checagens contam, do mesmo jeito e com a mesma regra de nome para todos os políticos e partidos. A investigação traz em uma linha o aviso "Uma checagem que cita alguém nem sempre é sobre algo que essa pessoa disse.".
- `Constituição 14:` na dúvida sobre o nome (homônimo, sobrenome, nome parcial, cargo contraditório), a checagem fica de fora da pessoa e vai só para a revisão interna.
- `Constituição 3:` features não se importam. `FeatureSearch` e `FeatureProfile` usam `PublicDataService` injetado. A lógica e os textos da resposta ficam fora das views (`InvestigationLinks`, `InvestigationEngine`), e `ProfileModel` é `@MainActor @Observable`.
- `Constituição 4:` zero comentários em Swift e Go, zero warnings, Swift Testing para a lógica do app, `go test` para o servidor e tokens do `FiscalDesignSystem` (`.spaceM`, `.spaceS`, `.space2XS`, `.caseKicker`, `.retroRust`) em vez de números soltos.
- `Constituição 6` e `docs/adr/0003-portuguese-only.md`:
  - chaves em inglês, só a tradução pt-BR no catálogo;
  - `String(appLocalized:)` fora das views;
  - `Text(verbatim:)` para o título e o selo, que são dados da agência.
- `Constituição 5:` componentes nativos (`Link`, `StatusCircle`) e Reduzir movimento respeitado. A seção não tem anel nem progresso circular.
- `Constituição 7:` `scripts/verify.sh --quick` durante o trabalho e `cd server && go test ./...` no servidor. Nunca dizer que verificou o que não verificou.
- `docs/adr/0002-static-first-server.md`: as checagens são arquivos estáticos pré-gerados pela carga, sem cálculo nem chamada à agência por requisição do app.
- `docs/adr/0006-ingest-sqlite-store.md`: cada leitura vira snapshot `check:` e série `checks.published`, e nada é apagado quando a fonte muda.
- `docs/adr/0007-pages-cdn-phased-ingest.md` e `docs/adr/0008-smart-sync.md`:
  - `checks.json` publicado em `v1` e embutido em `people/{slug}.json` no `v2`;
  - o job `checagens` é de sobreposição, com sonda mínima e idade máxima.
- Playbook `backend`:
  - configuração que falha fechada (`COMPROVA_SINCE`);
  - arquivos de estado com permissão 0600 e troca atômica;
  - logs só com contagens, sem título nem nome de pessoa.
- Nunca usar "Fato ou Fake", marca do g1, em texto, símbolo ou chave.
- Nenhuma outra agência (Lupa, Aos Fatos) nem a API do Google entra sem autorização por escrito do usuário e da agência (`docs/research/2026-10-25-fact-checks.md`).

## Safeguards

- **Funcional:**
  - **Revisão interna:** nunca publicar `checks-review.json` nem qualquer item da revisão.
  - **Nomes que nunca ligam:**
    - nome que mais de uma pessoa do escopo tem;
    - nome de uma palavra que não seja o de urna com pelo menos 4 letras;
    - sobrenome sozinho;
    - nome colado a outro nome com maiúscula (com menos de 3 palavras significativas);
    - palavra minúscula.
  - **Selo e conteúdo:**
    - nunca inventar selo sem um dos quatro sinais;
    - nunca reescrever o título;
    - nunca filtrar por selo (falsas e verdadeiras saem juntas).
  - **Arquivo e tela:**
    - `people/{slug}/checks.json` só existe com pelo menos 1 item;
    - a investigação mostra no máximo 3 checagens;
    - a seção do perfil fica desligada (`showsFactChecks` igual a `false`).
- **Desempenho:**
  - 100 publicações por página e no máximo 200 páginas (20.000 publicações) por leitura;
  - folga incremental de 1 h e releitura completa a cada 7 dias;
  - job a cada 45 min, das 7 h às 24 h, com idade máxima de 24 h;
  - a sonda pede 1 publicação;
  - a sobreposição leva cerca de 25 s (ADR 0008);
  - o intervalo entre requisições da carga fica entre 50 ms e 10 s (`INGEST_REQUEST_GAP`);
  - no app, as leituras das peças `.checks` rodam em paralelo num `TaskGroup`.
- **Privacidade:**
  - o app só faz GET do arquivo público da pessoa investigada, igual ao do perfil;
  - a pergunta e o plano da investigação ficam no aparelho (Foundation Models), e nenhuma checagem é salva no aparelho nem no iCloud;
  - no servidor, `comprova.json` e `checks-review.json` ficam em `DATA_DIR` com permissão 0600;
  - o log registra só contagens.
- **Dados:**
  - nada salvo se perde: uma leitura que falha mantém o último `comprova.json`, e a carga cai para os snapshots `check:` do SQLite;
  - `comprova.json` e `checks-review.json` são gravados por troca atômica;
  - nenhum schema SwiftData muda. A peça `.checks(PersonCard)` vai codificada em `InvestigationEntity.pieces` de `FiscalSchemaV3`, que sincroniza pelo CloudKit.
- **Compatibilidade da versão publicada:**
  - **Contrato de `checks.json`:** `people/{slug}/checks.json` tem o formato `{ items: [{ id, title, verdict | null, date (AAAA-MM-DD), url, publisher, license, licenseUrl }], sources }`. No `v2`, o mesmo objeto vai em `files["checks.json"]` de `people/{slug}.json`.
  - **Formato estável:** o id `comprova-<n>`, o `verdict` anulável e o 404 que quer dizer "sem checagens" não mudam.
  - **Índice:** o campo `checks` (inteiro) de `index/facts.json` continua.
  - **Investigações salvas:** o caso `checks` de `InvestigationPiece`, guardado em investigações sincronizadas, não pode ser renomeado.
  - **Textos:** as chaves de texto do catálogo ("Were there fact checks about %@?", "Projeto Comprova published %@ fact checks that name %@." e as demais) ficam.
  - Nenhuma **QUEBRA** hoje.
- **Fora do escopo:**
  - sem nova mudança, uma geração nesta área não pode acrescentar:
    - outra agência ou a API do Google;
    - raspagem de site;
    - placar, contagem por selo ou ranking de pessoas;
    - a ligação da seção do perfil (P2 do backlog);
    - lista completa de checagens na tela;
    - notificação, widget, App Intent ou deep link de checagens;
    - publicação da revisão interna;
    - tabela manual de apelidos.
  - Também não pode trocar a regra de nome por casamento aproximado.
