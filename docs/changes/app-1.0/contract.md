# Contrato da 1.0: dados estáticos e mapa do app

Peça compartilhada pelas frentes paralelas da mudança [`app-1.0`](proposal.md). Toda frente lê este arquivo antes de começar. Mudar o contrato é decisão do coordenador; uma frente que precisar de um campo novo pede ao coordenador, sem inventar.

## 1. Regras de dados (valem para servidor e app)

- **Estático primeiro ([ADR 0002](../../adr/0002-static-first-server.md)):**
  - todo dado é um arquivo JSON pronto, com o `.gz` ao lado, publicado em `PUBLIC_DIR/v1/` e servido pelo Caddy em `https://fiscal.byescaleira.com/api/v1/<caminho>.json`;
  - nenhuma rota calcula nada por acesso;
  - a busca roda no aparelho, sobre o índice.
- **Campos:**
  - **nomes em camelCase, em inglês;**
  - **dinheiro em centavos** (`Int`, campos terminados em `Cents`);
  - **datas** em ISO 8601 com fuso (`2026-10-25T17:42:10-03:00`) ou só a data (`2026-10-25`);
  - **dado ausente é `null`**, e o app mostra "—"; nunca 0 inventado.
- **Fonte em cada bloco:** todo arquivo tem `sources: [Source]`.
  ```json
  { "id": "camara", "name": "Câmara dos Deputados", "url": "https://dadosabertos.camara.leg.br", "updatedAt": "2026-10-25T05:42:00-03:00" }
  ```
- **Identificadores:**
  - `slug` em kebab-case sem acento, único: o nome de urna, com `-<uf>` quando o mesmo nome aparece em mais de uma UF; quem tem cargo municipal ganha `<nome-de-urna>-<cidade>-<uf>` (`joao-campos-recife-pe`), com `-2`, `-3`… só se repetir, num espaço que nunca colide com os slugs nacionais;
  - `uf` em minúsculas (`br` para o país);
  - IBGE para município (`code`, 7 dígitos).
- **Escopo da 1.0** (decisão do usuário em 2026-10-25, "federal + estados"):
  - presidente e vice;
  - 81 senadores;
  - 513 deputados federais;
  - 27 governadores e vices;
  - deputados estaduais e distritais;
  - os eleitos de 2026 aguardando posse;
  - prefeitos, vice-prefeitos e vereadores dos 5.571 municípios, eleitos em 2024 (pedido do usuário em 2026-10-25, "tem que cobrir tudo", no lugar de "prefeitos e vereadores ficam para depois da 1.0").
- **Atividade das assembleias:** só onde há dado aberto (presença, votos, propostas ou gastos); fora disso `null`, e o perfil diz que a casa não publica.
- **Neutralidade:**
  - sem nota, ranking ou "mais e menos" entre políticos;
  - listas em ordem alfabética;
  - a cor do candidato é a do partido (`PartyPalette`), a mesma para todo mundo.

## 2. Arquivos publicados

| Caminho em `v1/` | Conteúdo | Gerado |
| --- | --- | --- |
| `meta.json` | `{ generatedAt, sources[], counts{ people, federal, state, places } }` | a cada carga |
| `index/people.json` | índice de busca: `[PersonCard]` de todo o escopo, em ordem alfabética | a cada carga |
| `index/places.json` | `[{ code, name, uf }]`: os 5.571 municípios mais as 27 UFs (`code` = sigla da UF, em minúsculas) | anual (IBGE) |
| `places/{uf}.json` | quem representa a UF: `{ uf, name, groups: [RepresentativeGroup], sources }` | a cada carga |
| `places/city/{ibge}.json` | quem representa o município: `{ code, name, uf, groups: [RepresentativeGroup], note, sources }`, com os grupos "Prefeitura" (prefeito e vice, nessa ordem) e "Câmara Municipal" (vereadores em ordem alfabética); `note` (texto pronto ou `null`) explica o que falta: Brasília e Fernando de Noronha não elegem prefeito nem vereadores, e alguns municípios estão sem prefeito ou sem vereadores nos dados abertos do TSE. Um arquivo para cada um dos municípios do IBGE | na carga completa (TSE, eleição municipal de 2024) |
| `people/{slug}.json` | perfil completo: `Profile`. Prefeito, vice e vereador ganham um perfil leve, só com o que o TSE publica (candidatura de 2024, partido, votos, bens; mandato de 01/01/2025 a 31/12/2028), sem arquivos de atividade | quando muda |
| `people/{slug}/votes-{year}.json` | `{ items: [PersonVote], total }` | quando muda |
| `people/{slug}/proposals-{year}.json` | `{ items: [Proposal], total }` | quando muda |
| `people/{slug}/speeches-{year}.json` | `{ items: [Speech], total }` | quando muda |
| `people/{slug}/expenses-{year}.json` | `{ items: [Expense], totalCents, byMonth: [{ month, cents }], byCategory: [{ category, cents, count }] }` | quando muda |
| `votes/recent.json` | as 60 últimas votações do Plenário (Câmara e Senado): `[VoteSummary]` | diária e a cada 10 min em dia de sessão |
| `votes/{id}.json` | `VoteDetail` | quando muda |
| `agenda/today.json` | `{ date, houses: [{ house, inSession, nextSession, items: [AgendaItem] }] }` | a cada 10 min |
| `money/overview.json` | `MoneyOverview` | diária |
| `today.json` | `TodayDigest` (o que aconteceu, para a aba Hoje) | a cada 10 min |
| `people/{slug}/checks.json` | `{ items: [FactCheck], sources }`: checagens do Projeto Comprova que citam a pessoa pelo nome completo exato; só existe quando há ao menos uma | diária |
| `avatars/index.json` | `{ rigVersion, people: [{ slug, updatedAt }] }`: quem já tem retrato desenhado | quando muda |
| `avatars/{slug}.json` | Lottie do retrato animado (esqueleto do Fiscal com os traços da pessoa e a cor do partido); sem arquivo, o app mostra o retrato genérico | quando muda |
| `races.json`, `races/{id}.json` | apuração (já existe, fase `live-results`) | 20 s em eleição |

### Tipos

```text
PersonCard { slug, name, office, uf, party, photo (URL ou null), status }
  office ∈ president | vicePresident | senator | federalDeputy | governor | viceGovernor | stateDeputy
           | mayor | viceMayor | cityCouncilor
  status ∈ inOffice | electedAwaiting | onLeave

RepresentativeGroup { level ∈ country | state | city, office, title, people: [PersonCard] }
  no grupo "Prefeitura" (`office: mayor`) cada card traz o próprio cargo (prefeito ou vice)

CityRepresentatives { code, name, uf, groups: [RepresentativeGroup], note (string ou null), sources }

Profile {
  slug, name, civilName, office, uf, party, photo, status,
  mandate { start, end }, birthDate, birthPlace, education,
  contact { email, phone, office } | null,
  salary { monthlyCents, law } | null,
  numbers {
    attendance { present, eligible } | null, proposals, laws, speeches, votes,
    quotaCents | null, assetsCents | null, campaignRevenueCents | null, lastElectionVotes | null
  },
  years: [{ year, present, eligible, proposals, laws, speeches, votes, quotaCents }],
  themes: [{ key, proposals, speeches }],
  committees: [{ name, role, start, end }],
  assets: [{ year, totalCents, items: [{ kind, cents }] }],
  campaigns: [{ year, office, result, revenueCents, expenseCents }],
  timeline: [{ year, office, place, party, result, votes }],
  coverage: [{ kind, status ∈ available | notPublished | notLoaded, source }],
  sources
}

PersonVote { voteId, date, proposition, summary, vote, partyGuidance, approved, themes }
Proposal { id, kind, number, year, summary, plainSummary, canBecomeLaw, themes, url }
Speech { date, kind, summary, url }
Expense { id, year, month, category, supplier, document, cents, url }

VoteSummary { id, house ∈ camara | senado, date, time, proposition, kind, summary, plainSummary, themes,
              result, approved, nominal, yes, no, others }
VoteDetail extends VoteSummary + { quorum, guidance: [{ party, guidance }],
              parties: [{ party, yes, no, others }], people: [{ slug, name, party, uf, vote }], sources }

AgendaItem { proposition, summary, status, themes, url }

FactCheck { id, title, verdict (rótulo da agência como veio, ou null), date, url, publisher, license, licenseUrl }

MoneyOverview {
  year, quota: { federalDeputiesCents, senatorsCents, byCategory: [{ category, cents }] },
  salaries: [{ office, monthlyCents, law }],
  campaigns: { year, revenueCents, expenseCents, byOrigin: [{ origin, cents }] },
  revenue: { year, totalCents, byState: [{ uf, cents }] } | null,
  sources
}

TodayDigest {
  date, events: [{ kind ∈ vote | session | race | law, title, summary, themes, ref }],
  sources
}
```

- **Ajustes aceitos pelo coordenador depois da carga real (2026-10-25):**
  - `VoteDetail.people[].slug` pode ser `null` (votou, mas está fora do escopo, por exemplo quem deixou o cargo); a linha aparece sem link;
  - `index/places.json`: `code` é sempre string, inclusive para município (`"1100015"`);
  - `numbers.proposals`, `laws`, `speeches` e `votes`, `campaigns` em `money/overview.json` e `mandate.start`/`end` de deputado estadual são `null` quando a casa não publica ou o cargo não tem o dado;
  - `Expense.document` é o CNPJ do fornecedor; fornecedor pessoa física sai `null`;
  - `revenue` usa o último ano completo da Receita.
- **Municípios (2026-10-25, frente `city`):**
  - `index/people.json`, `meta.json › counts` e `places/{uf}.json` continuam só com o escopo federal e estadual; prefeitos, vices e vereadores (por volta de 69 mil pessoas) só aparecem em `places/city/{ibge}.json` e no próprio perfil, para o índice de busca não crescer 40 vezes e para versões do app que não conhecem os cargos novos continuarem lendo o índice;
  - o app abre `places/city/{ibge}.json` primeiro e mostra depois os grupos do estado e de Brasília; um 404 quer dizer que a carga de municípios ainda não rodou, e o app segue só com o estado;
  - `photo` é `null` (o TSE publica as fotos só em ZIPs por UF, sem URL por pessoa); campanha (`revenueCents`, `expenseCents`) fica `null`, com `coverage` `notLoaded`, porque a prestação de contas municipal tem 1,3 GB;
  - a lista vem dos eleitos de 2024 como o TSE os publica hoje: quando há eleição suplementar com eleito, vale a mais recente; cassação, renúncia ou posse do vice depois da eleição não aparecem.
- **`themes`:** as 17 chaves da apuração:
  - `saude`, `educacao`, `seguranca`, `economia`, `impostos`, `ambiente`;
  - `cidade`, `transporte`, `social`, `mulheres`, `campo`, `cultura`;
  - `direitos`, `consumidor`, `tecnologia`, `politica`, `homenagens`.
  
  A classificação é por radicais nossos, sem copiar listas de terceiros, gravada pela carga.
- **`plainSummary`:** a ementa reescrita em linguagem simples por regras nossas ("Altera a Lei X para…" vira "Muda uma lei para…"), sempre com a ementa oficial ao lado.

## 3. Mapa do app

- **5 abas** (`AppSection`), ordem e nomes:
  1. **Hoje** (`newspaper`);
  2. **Meus** (`person.2`);
  3. **Votações** (`checkmark.square`);
  4. **Dinheiro** (`brazilianrealsign`);
  5. **Fiscalizar** (`magnifyingglass`, `Tab(role: .search)`).
- **Ajustes** saem da barra: botão na toolbar de Hoje, com a Lente, Aparência e Sobre.
- **Apuração** (`FeatureLiveResults`): card em Hoje durante eleição e entrada em Fiscalizar › Eleições.
- **Targets novos no `FiscalKit`**, um por feature; features não se importam, e a navegação é por `Route`:

| Target | Conteúdo |
| --- | --- |
| `FeatureToday` | aba Hoje: resumo pela Lente, eventos do dia, card da apuração |
| `FeatureMine` | aba Meus: escolha da UF ou cidade, grupos de representantes, seguidos |
| `FeatureProfile` | perfil (`Route.person(slug)`), aberto por qualquer aba |
| `FeatureVotes` | aba Votações: recentes, pauta do dia e detalhe (`Route.vote(id)`) |
| `FeatureMoney` | aba Dinheiro |
| `FeatureSearch` | aba Fiscalizar: busca no índice, Comparar, Eleições |
| `FeatureLens` | setup inicial (3 passos: lado, temas, visual), edição da Lente, Aparência, coleções de arte, o selo "Lente: …" usado pelas outras abas (via `FeatureCore`) |
| `FeatureShare` | cards de compartilhar (`ImageRenderer`/`ShareLink`) e galeria de artistas |

- **Rotas:** `Route` ganha `.person(slug:)`, `.vote(id:)`, `.compare(slugs:)`, `.races`, `.lens`, `.artists` e `.settings`. O caso `.item` sai com o exemplo do template.
- **Domínio** (`FiscalDomain/PublicData/`):
  - os tipos da seção 2 em Swift, `Codable` e `Sendable`;
  - `Theme` (as 17 chaves, com nome e símbolo);
  - `Lens` (lado: `right`, `centerRight`, `center`, `centerLeft`, `left`, `impartial` ou `preferNotToSay` (que se comporta como `impartial`), escolhido no primeiro passo do setup, com as seis primeiras opções do mesmo tamanho; `center` tem pacote de temas próprio; `impartial` alterna os destaques dos dois públicos, mostra as comparações lado a lado, usa paleta e arte neutras e deixa a "Outra lente" sempre aberta; temas escolhidos, de 3 a 5, pré-marcados pelo lado; coleção de arte; paleta). O lado adapta a ordem, os destaques, a paleta, a arte e os cards, e aparece num selo visível ("Lente: Direita"). Os fatos nunca mudam (brief, "A ideia");
  - o protocolo `PublicDataService`.
- **Dados:**
  - `FiscalData/PublicData/PublicDataClient`, com `URLCache` e `ETag`, a partir da base `FiscalAPIURL` do Info.plist;
  - `ShowcasePublicData` em debug, com cenários por `-FiscalDataScenario <nome>`;
  - **a Lente só no aparelho:**
    - num `ModelContainer` SwiftData separado e local (`cloudKitDatabase: .none`), com o arquivo marcado `isExcludedFromBackup`;
    - nunca em requisição, log, telemetria, notificação ou card;
    - "Apagar minha escolha" em Ajustes;
    - teste que garante que o store da Lente não usa CloudKit e está fora do backup;
  - os seguidos ficam no aparelho; o iCloud privado é opcional e nunca leva a Lente.
- **Aparência:** `PartyPalette` para candidatos; paletas da Lente em pares espelhados; arte via `art-credits.json` no `FiscalResource`.
- **Só português ([ADR 0003](../../adr/0003-portuguese-only.md)):** o catálogo fica só com `pt-BR` (chaves em inglês) e sai a escolha de idioma dos Ajustes.
- **Gratuito** (decisão do usuário em 2026-10-25): sem assinatura, Pro, paywall nem StoreKit. Saem do template o `Fiscal.storekit`, `FiscalStoreTests`, os textos e as telas de compra, e o que mais depender disso.
