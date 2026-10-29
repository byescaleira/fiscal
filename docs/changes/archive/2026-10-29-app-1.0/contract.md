# Contrato da 1.0: dados estáticos e mapa do app

Peça compartilhada pelas frentes paralelas da mudança [`app-1.0`](proposal.md). Toda frente lê este arquivo antes de começar. Mudar o contrato é decisão do coordenador; uma frente que precisar de um campo novo pede ao coordenador, sem inventar.

## 1. Regras de dados (valem para servidor e app)

- **Estático primeiro ([ADR 0002](../../../adr/0002-static-first-server.md)):**
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
| `votes/recent.json` | os 60 últimos grupos de votação do Plenário (Câmara e Senado), um item por grupo: `[VoteSummary]` com a votação principal do grupo, `relatedCount` e `related` (regra abaixo) | diária e a cada 5 min em dia de sessão (lido primeiro na origem, com cache de 30 s) |
| `votes/{id}.json` | `VoteDetail`, um para cada votação, inclusive as que não são a principal do grupo; traz `group` e as outras votações do grupo em `related` | quando muda |
| `agenda/today.json` | `{ date, houses: [{ house, inSession, nextSession, items: [AgendaItem] }] }` | a cada 5 min em dia de sessão, de hora em hora fora dela |
| `money/overview.json` | `MoneyOverview` | diária |
| `money/mandate-cost.json` | `MandateCost`: quanto custa um mandato por mês, item a item, com o ato oficial de cada valor; 404 quer dizer que a carga ainda não publicou, e o app esconde a seção | diária |
| `today.json` | `TodayDigest` (o que aconteceu, para a aba Hoje) | a cada 5 min em dia de sessão, de hora em hora fora dela |
| `people/{slug}/checks.json` | `{ items: [FactCheck], sources }`: checagens do Projeto Comprova que citam a pessoa pelo nome completo exato; só existe quando há ao menos uma | diária |
| `people/{slug}/actions.json` | `{ items: [Action], sources }`: o que a pessoa fez nos dois últimos anos, ordenado pelo peso ([weight.md](weight.md)); cada ação traz `measured`, `missing` e `confidence` (`full` \| `partial` \| `impactOnly`), e `repercussion` é `null` sem sinal medido; só existe quando há ação | diária |
| `highlights.json` | `{ generatedAt, items: [Highlight], method, sources }`: o Destaque do momento, nunca vazio quando há dado; cada item traz `measured`, `missing`, `confidence`, `themes`, `stage`, `house` e, em votação, `tally { yes, no, others }` | no máximo a cada 20 min, quando entra votação nova |
| `method/weight.json` | `WeightMethod` (versão 2): a regra do peso, para o "Como medimos", com `renormalization` (sinal ausente sai da conta, nunca vira zero), `confidence` e `alert { minWeight, maxAgeHours, text }`, `levels: [{ key ∈ high \| medium \| low, label, min, max }]` e `levelsText` (as faixas de relevância) | diária |
| `index/benchmarks.json` | `{ generatedAt, items: [Benchmark], sources }`: a referência dos colegas por cargo e casa (deputados federais, senadores e deputados estaduais por UF), com p25, mediana, p75 e `n` de presença, cota por mês de mandato, propostas e discursos no ano | a cada carga |
| `method/benchmarks.json` | `BenchmarkMethod` (versão 1): a regra da classificação em texto, para o "Como medimos" | a cada carga |
| `avatars/rig.json` | Lottie único do retrato: todas as partes uma vez só (rostos, cabelos, barbas, óculos, sobrancelhas, mãos), cada uma com o seletor `fx` do traço que a escolhe, cores por papel (`skin`, `hair`, `beard`, `brow`, `primary`, `secondary`) e as expressões como marcadores (`idle`, `wave`, `thumbsUp`, `nodYes`, `shakeNo`, `smile`, `celebrate`, `sad`, `think`, `thinkLoop` e `<expressão>Pose`) | quando muda |
| `avatars/traits.json` | `{ rigVersion, fields, values, people: [[slug, índices…]] }`: os traços de cada pessoa; sem linha, o app mostra o retrato genérico, neutro | quando muda |
| `races.json`, `races/{id}.json` | apuração (já existe, fase `live-results`) | 20 s em eleição |

### Tipos

```text
PersonCard { slug, name, office, uf, party, photo (URL ou null), status, gender (opcional) }
  gender ∈ f | m | null: vem do Senado (`SexoParlamentar`), da Câmara (`sexo` do detalhe) e, para os demais,
           do `DS_GENERO` da candidatura do TSE; sem dado, `null` (o app usa o cargo no masculino genérico)
  office ∈ president | vicePresident | senator | federalDeputy | governor | viceGovernor | stateDeputy
           | mayor | viceMayor | cityCouncilor
  status ∈ inOffice | electedAwaiting | onLeave

RepresentativeGroup { level ∈ country | state | city, office, title, people: [PersonCard] }
  no grupo "Prefeitura" (`office: mayor`) cada card traz o próprio cargo (prefeito ou vice)

CityRepresentatives { code, name, uf, groups: [RepresentativeGroup], note (string ou null), sources }

Profile {
  slug, name, civilName, office, uf, party, photo, status, gender (opcional, como no PersonCard),
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
  classification: Classification | null,
  sources
}

Classification {
  year, office, house ∈ camara | senado | assembleia, uf (só deputado estadual; senão null),
  presence | quota | proposals | speeches: { value, band, median, p25, p75, n } | null
}
  presence: value em % (uma casa decimal); band ∈ better | average | worse (mais alta é melhor)
  quota: value em centavos por mês de mandato no ano; band ∈ better | average | worse (mais baixa é melhor)
  proposals, speeches: value é a contagem no ano; band ∈ more | average | less (sem direção, sem cor)
  regra: acima do p75 / entre p25 e p75 (limites incluídos) / abaixo do p25, com a direção da métrica;
  quartis por interpolação linear entre os colegas em exercício com dado publicado; menos de 5 colegas
  com dado, a métrica sai null; o ano é o mais recente com dado para ao menos 5 colegas

Benchmark { office, house, uf | null, year,
            metrics: { presence, quota, proposals, speeches: { p25, median, p75, n } | null }, sources }

BenchmarkMethod { version, summary, groups, year, quartiles, minPeers,
                  metrics: [{ key, label, unit, direction ∈ higherIsBetter | lowerIsBetter | none, text,
                              bands: [{ key, label, rule }] }], limits, sources }

Action e Highlight ganham relevance ∈ high (peso 70 ou mais) | medium (40 a 69) | low (abaixo de 40);
  a tela mostra a faixa, e o número do peso fica no detalhe e no "Como medimos"


PersonVote { voteId, date, proposition, summary, vote, partyGuidance, approved, themes, turn? }
Proposal { id, kind, number, year, summary, plainSummary, canBecomeLaw, themes, url }
Speech { date, kind, summary, url }
Expense { id, year, month, category, supplier, document, cents, url }

VoteSummary { id, house ∈ camara | senado, date, time, proposition, kind, summary, plainSummary, themes,
              result, approved, nominal, yes, no, others, turn?,
              group?, relatedCount?, related?: [{ id, time, summary, nominal, approved }] }

`turn` (1 ou 2) sai quando o texto oficial da votação diz o turno ("em primeiro turno", "em segundo turno"); o app
mostra "PEC 221/2019 · 1º turno" para que os turnos do mesmo dia não pareçam repetidos. `proposition` nunca sai nula:
sem proposição, o servidor manda "Requerimento" ou "Votação em Plenário".

Grupo de votação: votações da mesma casa, da mesma proposição e do mesmo dia (`group`, id estável,
ex.: `camara-2026-10-15-pl-1123-2025`; sem proposição, o grupo é a própria votação). PEC com 1º e 2º turno
no mesmo dia vira um grupo por turno (`…-turno-1`, `…-turno-2`): são deliberações distintas, cada uma com
quórum de 3/5; votações sem turno no texto entram no turno em andamento na hora delas.
A principal do grupo é, nesta ordem: (1) a deliberação de mérito (projeto, substitutivo, subemenda
substitutiva, texto da MP ou da PEC em turno, emendas do Senado, "nos termos do parecer"); (2) emenda ou
subemenda de texto; (3) as procedimentais (requerimento, redação final, "mantido o texto", destaque,
pressupostos da MP, adiamento, preferência). Empate: a nominal, depois a mais tarde (hora e sequência do id).
`relatedCount` conta as outras votações do grupo; `related` lista até 10, em ordem de hora, com um resumo
curto ("Redação final", "Emenda nº 97", "Requerimento de urgência"). Os três campos são opcionais e somem
quando não há outra votação no grupo; apps antigos os ignoram.
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

MandateCost {
  checkedAt (AAAA-MM-DD em que os valores fixos foram conferidos na fonte),
  roles: [{
    role ∈ federalDeputy | senator | president | vicePresident | minister,
    items: [{
      kind ∈ salary | quota | staff | housing,
      monthlyCents (null quando o valor muda por UF),
      byState: [{ uf, monthlyCents }] | null (só a cota, as 27 UFs),
      act: { name, url, since (AAAA-MM-DD de vigência ou null) }
    }],
    unpublished: [kind] (itens sem tabela oficial atual publicada; o app diz que faltam, nunca soma zero)
  }],
  minimumWage: { monthlyCents, period: null, act } | null,
  laborIncome: { monthlyCents, period ("2º trimestre 2026", como o IBGE publica), act } | null,
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
- **Custo do mandato (2026-10-25, frente `mandate-cost`):**
  - valores fixos no servidor, conferidos em 25/10/2026: subsídio de R$ 46.366,19 desde 01/02/2025 (Decreto Legislativo nº 172/2022, o mesmo ato para deputados, senadores, presidente, vice e ministros); cota da Câmara por UF (Guia para jornalistas da Câmara, valores em vigor do Ato da Mesa nº 43/2009, de R$ 41.612,55 no DF a R$ 58.474,70 em RR); verba de gabinete de R$ 165.806,07 (Ato da Mesa nº 243/2026); auxílio-moradia de R$ 4.253,00, pago só a quem não ocupa imóvel funcional (Ato da Mesa nº 3/2015); salário mínimo de R$ 1.621,00 desde 01/01/2026 (Decreto nº 12.797/2025);
  - a renda média vem da API do SIDRA a cada carga (tabela 5436, variável 5933, rendimento médio mensal real habitual de todos os trabalhos, Brasil, sexo total, último trimestre); falhou, fica o último trimestre salvo; sem nenhum, `laborIncome` é `null`;
  - o Senado não publica a tabela atual da CEAPS por UF, nem verba de gabinete e auxílio-moradia em valor único: o senador sai só com o subsídio e `unpublished` lista o resto; governadores ficam fora (cada estado fixa o subsídio por lei própria, sem fonte única conferida).
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
- **Só português ([ADR 0003](../../../adr/0003-portuguese-only.md)):** o catálogo fica só com `pt-BR` (chaves em inglês) e sai a escolha de idioma dos Ajustes.
- **Gratuito** (decisão do usuário em 2026-10-25): sem assinatura, Pro, paywall nem StoreKit. Saem do template o `Fiscal.storekit`, `FiscalStoreTests`, os textos e as telas de compra, e o que mais depender disso.
