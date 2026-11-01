# SPDD Analysis: seguir no centro do Fiscal (aba Seguindo)

## Original Requirement

Pedido do usuário em 31/10/2026, literal:

> precisamos deixar mais claro a função de seguir um políticos no app (como se fosse o core do app, mais evidência)

Decisões que o usuário já tomou em 31/10/2026, em resposta ao plano:
- "Seguindo" vira a **primeira aba** e **absorve a Região**. As abas ficam Seguindo · Hoje · Votações · Dinheiro · Fiscalizar.
- A aba mostra **o que mudou com quem a pessoa segue**.
- Os representantes do estado aparecem como **sugestão de seguir**.

É a fase 2 do plano: 1) alinhamento, entregue (FSC-008, PR #6); 2) seguir; 3) compartilhar; 4) pesquisa web; 5) web.

Critérios de aceite, do pedido e do plano:

1. A primeira aba do app é Seguindo, com ícone e título próprios, no iPhone, no iPad, no Mac (primeiro item da lista de origem e ⌘1), no visionOS e na dobra do Duo.
2. Abrir a aba mostra, no topo, o que mudou desde a última visita com cada pessoa seguida: votos com o voto dela, gastos novos, presença e checagens do Comprova, cada item com fonte e data e um toque até o detalhe.
3. Sem ninguém seguido, a aba convida a seguir. Ela sugere os representantes do lugar escolhido e quem a pessoa apoia na Lente, com o botão Seguir na própria linha.
4. O que a Região mostra hoje continua acessível na aba Seguindo, numa seção "Sua região": lugar escolhido, governo, bancadas, quem representa e Memória do lugar.
5. Dá para seguir e deixar de seguir de qualquer lista de pessoas, sem abrir o perfil: resultados da busca, representantes, quem votou numa votação, Comparar, disputa e menu de contexto de qualquer linha de pessoa.
6. Seguir dá retorno visível: o botão muda de estado com animação discreta (com Reduzir movimento respeitado), há háptico e o VoiceOver anuncia.
7. Siri e Atalhos: intent "Seguir" e "Deixar de seguir" para uma pessoa, e "Quem eu sigo" abrindo a aba.
8. O widget de representantes pode mostrar quem a pessoa segue.
9. Os textos contraditórios saem:
   - "Who you follow stays on this device" (`MineSections.swift:114`);
   - "…on this device" (`MineSections.swift:102`), quando a lista sincroniza pelo iCloud;
   - o convite de Hoje que manda escolher o estado na Região para "seguir".
10. Hoje deixa de repetir a lista de seguidos e passa a apontar para a aba Seguindo.

## Domain Concept Identification

### Existing Concepts

- **Pessoa seguida:**
  - `FollowEntity` em `FiscalData/Store/Entities/FollowEntity.swift`: SwiftData no store "Fiscal", sincronizado pelo CloudKit `iCloud.fiscal`, com cópia do `PersonCard` e `followedAt`;
  - `FollowRepository` (`followed`, `isFollowing`, `follow`, `unfollow`) em `FiscalDomain/Repositories/FollowRepository.swift`.
- **Seguir hoje:**
  - só pelo botão Seguir/Seguindo do herói do perfil (`ProfileHero.swift:80-97`, `ProfileModel.toggleFollow`);
  - e pelo setup da Lente, que segue quem a pessoa apoia (`SupportedPeople.follow`).
- **Seguidos na tela hoje:**
  - a seção "Seguindo" é a **última** da aba Região (`MineFollowingSection`), um trilho de rostos;
  - o cartão "Seus representantes" de Hoje mostra até 4 seguidos com o último voto (`TodayRepresentativesSection`, `TodayModel.loadFollowed`).
- **Região** (`FeatureMine`, cerca de 2.200 linhas):
  - herói do lugar escolhido (`HomePlace`), representantes por cargo, governo, bancadas, "agora" da região, Memória do lugar e o seletor de lugar;
  - `MineModel` carrega `followed`, `representatives`, `activity` (`MineActivityLoader`: votos e destaques da região).
- **Atividade de uma pessoa** (`FiscalDomain/PublicData`):
  - `PersonVote` (voto, data, proposição, orientação do partido, temas);
  - perfil com gastos, presença e propostas (`Profile`, `PersonFacts`, `PersonContext`);
  - `FactCheck` (Comprova).
  - Tudo vem do arquivo agrupado `people/<slug>.json` da CDN, que o pacote offline já baixa para os seguidos (`OfflinePackPlan.people`).
- **Integrações:**
  - `RepresentativesWidget` (pelo estado escolhido, não pelos seguidos);
  - `OpenPersonIntent`, `RepresentativesVoteIntent`, `ShowRacesIntent`;
  - `PersonEntity.suggestedEntities` (recentes);
  - Spotlight indexa os seguidos.
- **Navegação:** `AppSection` (`today, mine, votes, money, search`), `DeepLink` (`fiscal://mine`), ⌘1…⌘5 e a lista de origem do Mac tirados de `AppSection.allCases` (FSC-008).

### New Concepts Required

- **Aba Seguindo** (`AppSection.following`): substitui `mine` na posição 1. `fiscal://mine` continua abrindo a aba, para não quebrar links e atalhos publicados.
- **Novidade de um seguido:** um item datado da atividade pública de uma pessoa seguida (voto, gastos do mês, presença, checagem), com fonte, ordenado do mais novo para o mais antigo.
- **Última visita por pessoa:** marca local, no aparelho, de até quando a pessoa já viu as novidades de cada seguido. Ela define o "desde a sua última visita".
- **Sugestões de seguir:** os representantes do lugar escolhido e quem a pessoa apoia, menos quem ela já segue.
- **Seguir em linha:** um botão ou ação de seguir reaproveitável em qualquer linha de pessoa, com o estado vindo do repositório.
- **Intents de seguir:** "Seguir", "Deixar de seguir" e "Quem eu sigo".

### Key Business Rules

- **Fatos só:** a aba mostra o que a pessoa fez, com fonte e data, sem nota, ranking nem adjetivo (memória "Fiscal: facts only").
- **Ordem:** novidades da mais recente para a mais antiga. Seguidos em ordem alfabética quando não há novidade. Nunca ranking.
- **Janela das novidades:**
  - até 30 dias para trás na primeira visita;
  - no máximo 50 itens na aba, com "Ver tudo" no perfil.
- **Sincronização:** quem a pessoa segue continua no iCloud dela (CloudKit privado); a marca de última visita fica só no aparelho, fora do iCloud e do backup.
- **Privacidade:** quem a pessoa segue nunca vai ao servidor, ao `EventLog` nem a alerta remoto. O pacote offline e as requisições usam os arquivos públicos por pessoa, como hoje (ADR 0017).
- **Apoiar ≠ seguir:** quem a pessoa apoia na Lente é seguido no setup, como hoje. A sugestão mostra quem ela apoia e ainda não segue.
- **Limite do pacote offline:** continua `OfflinePackPlan.peopleLimit`. Seguir mais gente que isso não quebra nada; só fica fora do offline.

## Strategic Approach

### Solution Direction

- **Aba Seguindo:**
  - nasce do `FeatureMine`, sem módulo novo de dados;
  - no topo, as novidades de quem a pessoa segue, montadas no aparelho a partir dos arquivos públicos de cada pessoa, que o pacote offline já mantém;
  - em seguida, os seguidos;
  - depois, as sugestões de seguir;
  - por fim, "Sua região", com o que a Região mostra hoje.
- **Seguir em todo lugar:** uma ação de seguir única, num componente de linha de pessoa já usado pelas listas, aparece em busca, representantes, votação, Comparar e disputa.
- **Hoje:** troca o cartão de seguidos por um atalho para a aba.
- **Integrações:** os intents e o widget passam a conhecer os seguidos.
- **Textos:** os contraditórios saem.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Identidade da aba | `AppSection.following` no lugar de `mine`, com `fiscal://mine` e `fiscal://following` abrindo a aba | Um caso renomeado; os links antigos continuam | `reversível` |
| Origem das novidades | No aparelho, a partir de `people/<slug>.json` (já no pacote offline) | Nada novo no servidor e privacidade intacta; custa uma leitura por seguido, com cache | `veto` |
| Marca de última visita | `UserDefaults` local por slug, fora do iCloud e do SwiftData | Sem migração de schema nem CloudKit; não acompanha entre aparelhos | `reversível` |
| Região dentro de Seguindo | Seção "Sua região", abaixo das novidades e sugestões, com o seletor de lugar | A aba fica longa; o iPad e o Mac a dividem em colunas pelo `AdaptiveList` | `veto` |
| Cartão de seguidos em Hoje | Sai; Hoje ganha uma linha "N novidades de quem você segue" que abre a aba | Hoje fica mais curto e sem duplicar | `veto` |
| Seguir em linha | Botão compacto (`person.badge.plus` / `checkmark`) no fim da linha de pessoa e ação no menu de contexto | Mais um controle por linha; alvo de 44 pt | `veto` |
| Siri e Atalhos | `FollowPersonIntent`, `UnfollowPersonIntent` e `OpenFollowingIntent`, com `PersonEntity` | Três intents novos | `reversível` |
| Widget | O `RepresentativesWidget` ganha a opção "Quem eu sigo" ao lado de "Meu estado" (configuração do widget) | O widget lê os seguidos do App Group, que hoje não os tem | `veto` |
| Alertas de quem a pessoa segue | Só o selo com o número de novidades na aba Seguindo (e as últimas no widget), sem notificação. Decisão do usuário em 31/10/2026 ("Só selo na aba, sem notificação"), que mantém as notificações iguais para todos (25/10/2026) | Quem quer aviso precisa abrir o app ou olhar o widget | `pergunta` (respondida) |

### Alternatives Considered

- **Seguindo como sexta aba, mantendo a Região:** o usuário escolheu absorver a Região.
- **Novidades calculadas no servidor:** exigiria mandar a lista de seguidos para fora do aparelho, contra o ADR 0017 e a arquitetura estática (ADR 0002).
- **Marca de última visita no `FollowEntity`:** mudaria o schema sincronizado (V4, CloudKit) por um dado que não precisa sair do aparelho.
- **Seguir só pelo perfil, com mais destaque:** não atende "como se fosse o core do app".

### Crítica honesta da tela atual (Região e seguidos)

- **Seguidos no fim:** a seção Seguindo é a última da Região, depois de herói, representantes, governo, bancadas e região agora. Quem segue alguém precisa rolar a aba inteira para achar a pessoa.
- **Trilho de rostos sem conteúdo:** ele não diz o que a pessoa fez. Para saber, é preciso abrir perfil por perfil.
- **Cartão de Hoje:** mostra só 4 seguidos e o convite vazio manda escolher o estado, o que não segue ninguém. A promessa e a ação não batem.
- **Texto errado:** "fica só neste aparelho" contradiz a sincronização pelo iCloud, que o próprio Ajustes explica.
- **Seguir escondido:** o botão só existe no herói do perfil. Da busca, da votação ou de Comparar são pelo menos 3 toques mais a digitação.
- **Região:** é forte para "quem me representa", mas não responde "o que fizeram as pessoas que eu acompanho".

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| 1. Primeira aba Seguindo em todas as plataformas | sim | Os atalhos ⌘1…⌘5 e a lista de origem do Mac vêm de `AppSection` (FSC-008); o grupo "Acompanhar" passa a ter Seguindo e Hoje |
| 2. Novidades desde a última visita | sim | Pessoa sem arquivo no pacote: leitura sob demanda com `PublicDataPhase`. Até 30 dias na primeira visita |
| 3. Convite e sugestões | sim | Sem lugar escolhido nem Lente, o convite pede o lugar, como a Região faz hoje |
| 4. Região dentro de Seguindo | sim | Tela longa; conferir no iPhone pequeno e em AX |
| 5. Seguir em qualquer lista | sim | Cada lista usa uma linha diferente (`PersonRow`, `MineRosterRow`, `BallotRow`, resultados da busca): a ação vai num modificador comum |
| 6. Retorno ao seguir | sim | — |
| 7. Siri e Atalhos | sim | Intents bloqueados pela atualização obrigatória, como os outros (`HoldGate`) |
| 8. Widget dos seguidos | parcial | O widget lê o App Group; publicar a lista de seguidos ali deixa o dado numa área compartilhada só com as extensões do próprio app |
| 9. Textos contraditórios | sim | — |
| 10. Hoje aponta para a aba | sim | — |

- **Riscos:**
  - **Leitura de muitos arquivos:** quem segue 40 pessoas carrega 40 arquivos. Mitigação: o pacote offline já os mantém e a leitura é concorrente e limitada, com o mesmo `settle` da FSC-002.
  - **Mudança de primeira aba:** quem já usa o app abre numa aba nova. Mitigação: a aba traz a Região dentro, e quem não segue ninguém vê o convite com os representantes do seu lugar.
  - **Escopo grande:** a fase toca aba, listas, Hoje, intents e widget. Mitigação: as operações em grupos, com a aba e o seguir em linha primeiro; widget e intents por último.
- **Lacunas:** nenhuma. A única decisão de porta `pergunta` (alertas) foi respondida em 31/10/2026: selo na aba, sem notificação.
- **Quebra:**
  - **Dados:** nenhum schema do SwiftData nem do CloudKit muda; entra só uma chave local nova (`fiscal.following.seen`).
  - **Links:** `fiscal://mine` continua funcionando.
  - **Textos:** os já traduzidos de Região e de Hoje mudam ("Region" vira "Following", e os textos de convite e de seguidos).
  - **App Group:** o widget passa a ler a lista de seguidos do App Group, dado novo na área compartilhada com as extensões.
