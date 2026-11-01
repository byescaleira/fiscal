# SPDD Analysis: Fiscal no padrão atual do byescaleira-workspace (dobrável, Mac, visionOS e ferramentas)

## Original Requirement

Pedido do usuário em 31/10/2026, literal:

> antes de qualquer coisa, precisamos adequar o app ao byescaleira-workspace que trouxe muito coisa, como spm, iphone duo, diretrizes de desgin para cada plataforma, entre diversas outras coisas de performance, segurança da informação;

É a fase 1 de um plano de cinco: 1) alinhamento ao workspace, 2) seguir no centro do app, 3) compartilhar como fluxo completo, 4) pesquisa de UX e UI web premiadas no workspace, 5) Fiscal na Web completo. A ordem foi aprovada pelo usuário em 31/10/2026, junto com o merge do PR #5 (SPDD).

Critérios de aceite, tirados do workspace (CHANGELOG `Unreleased` do plugin; byescaleira-kit 0.6.0 a 0.7.2) e do levantamento de 31/10/2026, já que a `bin/audit --all` passa e não cobre estes itens:

1. O Fiscal usa o byescaleira-kit 0.7.2.
2. Com o iPhone Duo meio aberto, toda aba fica com a raiz num lado da dobra e a rota no outro: em pé, a raiz à esquerda; deitado, a rota em cima. Nada atravessa a dobra (`adaptive-layout.md` §7.2.2, regra 5 da skill, bloqueador do `design-reviewer`).
3. Dobrar e desdobrar não perde nada do que a pessoa abriu, e em tamanho de acessibilidade a tela não se divide.
4. Nos Ajustes divididos, a página aberta vai para o outro lado, com a linha marcada e o aviso ao VoiceOver (`paneDestination`, kit 0.7.0 e 0.7.2).
5. O lado vazio mostra o estado vazio animado da aba.
6. As imagens de herói passam por baixo da barra vertical do Duo fechado (`.extendsUnderVerticalBar()`).
7. No Mac: `NavigationSplitView` com lista de origem em seções, em vez de abas; registros em `Table` com `tableCell()`; painéis em `GroupBox`; menu com atalhos (⌘1…) e Close com `.cancelAction` (§7.4).
8. No visionOS: janelas vizinhas em vez de folhas para as rotas, e a barra inferior no ornamento (`platformBottomBar`) (§7.4).
9. Developer com as ferramentas do kit:
   - flags em três estados (padrão, ligado e desligado);
   - registro de eventos;
   - diagnóstico com o `LayoutContext` e as `divisions` medidas (`settings-structure.md`, verificação §6.1).
10. Itens pequenos do workspace:
    - `scripts/store-media.py` e `scripts/asc.py`;
    - `go test -race` e `govulncheck` no `verify.sh`;
    - a regra do dobrável na constituição;
    - o texto vindo do model no `EmptyStateView` da falha de abertura;
    - versão SemVer do servidor Go e da ponte no `/health` (já atendida: o deploy injeta a tag ou o `MARKETING_VERSION`, e a ponte lê o `package.json`).
11. Testes de navegação nas duas posturas, na volta para a pilha e no caso AX. Capturas do Duo nas cinco formas, pedindo a troca de postura ao usuário (`verification.md` §6.1).
12. Fechamento no processo atual do workspace (31/10/2026): roteiros manuais registrados em `docs/evidence/FSC-008/qa.md` antes da revisão, e a revisão pelo `review-panel` (`ui`, `code`) com o `spdd-code-review` na mesma mensagem.

## Domain Concept Identification

### Existing Concepts

- **Seção do app** (`AppSection` em `FeatureCore/Navigation/AppSection.swift`): as cinco abas, Hoje, Região, Votações, Dinheiro e Fiscalizar, esta com papel `.search`.
- **Navegação** (`FiscalNavigation` em `FeatureCore/Navigation/FiscalNavigation.swift`):
  - guarda uma pilha por aba e o inspector da rota ao lado;
  - `fit(_:)` lê só `opensRoutesBeside` (960 pt) e ignora postura e divisões.
- **Shell** (`MainScreen`, `SectionStack`, `View+RouteInspector` e `InspectorScreen` em `AppShell/`):
  - `TabView` `.sidebarAdaptable`, com uma `NavigationStack(path:)` por aba;
  - a rota ao lado vai num `.inspector`;
  - no visionOS, a rota ao lado vira `sheet`;
  - `.readsLayoutContext()` já fica na raiz.
- **Ajustes** (`SettingsScreen`, `SettingsRow` com `DisclosureLink`): cena `Settings` no Mac com `Form .grouped`.
- **Developer** (`DeveloperScreen` e `DeveloperModel` em `FeatureSettings/`): override próprio das flags, só liga e desliga, sem registro de eventos nem diagnóstico.
- **Registros que no Mac pedem tabela:**
  - recibos de gastos (`FeatureMoney`, `Expenses*`);
  - votações (`FeatureVotes`, lista e placar);
  - pessoas de um lugar (`FeatureMine`, roster).
- **Kit:**
  - `LayoutContext` com postura, divisões e `verticalBarEdge`;
  - `FoldAwareArrangement(.split)`;
  - `PaneDestinationAction`;
  - `.extendsUnderVerticalBar()`;
  - `FlagOverrides`, `EventLog` e `DiagnosticReport` (`ByescaleiraFoundation`), com os models de Developer do `ByescaleiraUI`.
- **Ferramentas:** `scripts/verify.sh` roda `go vet` e `go test` no `server/`; `bridge/package.json` e `site/package.json` estão em 0.1.0; `server/go.mod` não tem versão própria.

### New Concepts Required

- **Forma da leitura** (`ReadingLayout`: pilha, colunas ou dobra num eixo):
  - decidida pela navegação a partir do `LayoutContext` inteiro;
  - com o estado de navegação mudando de lugar nos dois sentidos.
- **Lado da rota numa aba dividida:** a rota aberta de cada aba numa pilha própria, no outro lado da dobra.
- **Estado vazio por aba** para o lado sem rota (por exemplo, "Escolha uma votação").
- **Shell do Mac:**
  - lista de origem com as seções;
  - comandos de menu com atalhos;
  - tabelas dos registros.
- **Janela vizinha no visionOS** para abrir uma rota (`openWindow` com a rota como valor).
- **Registro de eventos do Fiscal:** o que entra no `EventLog` do kit, como abertura, carga de dados, falhas de rede, alertas recebidos e deep links, sempre sem dado pessoal e sem a Lente.

### Key Business Rules

- **Divisão:** a dobra só existe no iOS 27.1 no iPhone Duo. Fora dele a postura é `.flat` e vale a regra de largura atual: rota ao lado a partir de 960 pt.
- **Ordem dos lados:**
  - em pé, a raiz à esquerda e a rota à direita;
  - deitado, a rota em cima e a raiz embaixo.
- **AX:** a tela não se divide em tamanho de acessibilidade.
- **Fundo:** o fundo de cada lado cobre o vinco e fica branco ou preto (`GroupedSurface.plain`, decisão de 29/10/2026).
- **Mac:**
  - corpo de 13 pt e alvo de 28 pt;
  - célula de tabela com 8 pt de padding vertical (`tableCell()`);
  - total no subtítulo da tabela;
  - até três grupos na toolbar, com uma ação primária;
  - toda ação também no menu.
- **visionOS:** alvo de 60 pt e texto de 17 pt.
- **Privacidade do registro de eventos:** só no aparelho e só em `#if DEBUG`. Nunca grava a Lente, quem a pessoa apoia ou segue, nem o texto da busca (ADR 0017 e a promessa de 29/10/2026).
- **Versões:** o servidor e a ponte seguem SemVer, com a versão no `/health`, que já existe.

## Strategic Approach

### Solution Direction

- **Kit:** primeiro sobe para 0.7.2, que corrige a divisão na dobra e traz o `paneDestination` e as ferramentas de Developer.
- **Navegação e shell do iPhone e iPad:**
  - a navegação passa a escolher a forma da leitura pelo `LayoutContext` (pilha, colunas ou dobra);
  - no shell, cada aba é um arranjo com dois lados quando a tela está dobrada, com o mesmo estado movido nos dois sentidos;
  - assim o iPad e o iPhone de tela plana ficam como hoje, e o Duo dobrado ganha a divisão.
- **Mac:**
  - ganha um shell próprio: lista de origem com as mesmas seções, tabelas nos registros que pedem tabela e menu com atalhos;
  - as telas e os models continuam os mesmos.
- **visionOS:** troca a folha da rota por janela vizinha.
- **Developer:** adota as peças do kit em vez do override próprio.
- **Itens pequenos:** entram junto, cada um pelo caminho mais curto.

### Key Design Decisions

| Decisão | Escolha | Trade-off | Porta |
| --- | --- | --- | --- |
| Uma mudança ou duas | Uma só (`FSC-008`), com as operações em grupos: kit e dobra, Mac, visionOS, Developer e itens pequenos | Um PR e uma rodada de revisão; o canvas fica longo, mas é um só | `reversível` |
| Shell do Mac | `NavigationSplitView` próprio em `#if os(macOS)`, com lista de origem em duas seções ("Acompanhar": Hoje e Região; "Congresso": Votações, Dinheiro e Fiscalizar), reaproveitando as telas raiz e o `FiscalNavigation` | Duas raízes de shell para manter, mas é o que o §7.4 pede | `veto` |
| Registros em `Table` no Mac | Recibos, votos de uma votação e representantes de um lugar | Variante de lista só no Mac para três telas; o resto segue em lista e cartão | `veto` |
| Rota no visionOS | Janela vizinha (§7.4) no lugar da folha (§8, mais antigo) | Precisa de uma cena `WindowGroup(for: UUID.self)`; o §7.4 é o mais recente | `veto` |
| Ajustes na dobra | Sem `\.paneDestination`: Ajustes é uma `Route` de Hoje, abre no painel da rota e empilha as páginas ali | A linha marcada (`.isSelected`) não se aplica; evita transformar Ajustes em aba | `veto` |
| Developer | `FlagOverrides`, `EventLog` e `DiagnosticReport` do kit, sem manter o override próprio | Some o código local; a chave `fiscal.flags.overrides` e o formato continuam os mesmos | `reversível` |
| Estado vazio do lado da rota | Uma frase por aba, com o estado vazio animado do kit | Cinco textos novos em pt-BR | `reversível` |
| `go test -race` e `govulncheck` | Só no `--full` | O `--quick` continua rápido | `reversível` |

### Alternatives Considered

- **Dividir só as abas de leitura (Votações e Hoje):** o §7.2.2 manda dividir toda aba, e o revisor de design trata como bloqueador.
- **Calcular a dobra pelo `UIHingeInteraction`:** ele só dá estado e ângulo, sem a posição da dobra, e o workspace proíbe usá-lo para layout.
- **Deixar Mac e visionOS para depois da 1.0, como dizia o roadmap:** o usuário pediu as diretrizes de cada plataforma antes de qualquer coisa.
- **Duas mudanças, uma para a dobra e outra para Mac e visionOS:** mais uma parada e mais um PR, sem ganho, porque as duas mexem no mesmo shell.

## Risk & Gap Analysis

| Critério de aceite | Coberto pela direção? | Lacuna ou risco |
| --- | --- | --- |
| 1. Kit 0.7.2 | sim | A 0.6.0 trocou o `EmptyStateView` e o `GuideSheet` (texto do model, `isDismissible`): conferir as chamadas |
| 2. Toda aba dividida na dobra | sim | Fiscalizar é a aba de busca (`Tab(role: .search)`): a divisão precisa manter o campo de busca no lado da raiz |
| 3. Nada se perde ao dobrar; uma coluna em AX | sim | O inspector de hoje e o lado da rota disputam a mesma rota: o model precisa de uma fonte só |
| 4. Ajustes com `paneDestination` | sim | Os Ajustes abrem como folha no iPhone e como cena no Mac; a divisão vale onde eles são uma rota |
| 5. Lado vazio animado | sim | — |
| 6. `.extendsUnderVerticalBar()` | sim | Hoje e perfil são os heróis com imagem; conferir os cartazes de compartilhar, que não são tela |
| 7. Receita do Mac | sim | Os atalhos ⌘1…⌘5 seguem a ordem das abas, que a fase 2 vai mudar: os atalhos vêm de `AppSection`, não de números fixos |
| 8. visionOS | parcial | Janela vizinha muda a forma de fechar a rota; o fechar da janela fica com o sistema |
| 9. Developer | sim | O registro de eventos não pode receber dado pessoal: a lista de eventos fica fechada no canvas |
| 10. Itens pequenos | sim | `asc.py` precisa da chave da API do App Store Connect, que fica com o usuário: o script vem sem uso nesta fase |
| 11. Testes e capturas do Duo | parcial | A postura só muda à mão no Device Hub: as capturas do meio aberto dependem do usuário trocar a postura no simulador |

- **Riscos:**
  - A rota ao lado de hoje (inspector a partir de 960 pt) e o Duo aberto, com 951 pt em pé, ficam a 9 pt do limite. Mitigação: o canvas registra o comportamento de cada perfil do Duo, aberto e fechado, e o teste cobre os perfis do kit (`PlatformProfile`).
  - A fase 2 vai trocar Região por Seguindo. Mitigação: nada desta fase depende da lista de abas, e tudo sai de `AppSection.allCases`.
  - O Mac nunca foi verificado como produto. Mitigação: capturas no Mac no fim da fase e a revisão de design com o §7.4.
- **Lacunas:** nenhuma decisão de porta `pergunta`. As de porta `veto` (shell do Mac, tabelas, janela vizinha no visionOS e Ajustes na dobra) vão listadas na parada; as escolhas seguem o §7.2.2, o §7.4 e `defaults.md`.
- **Quebra:**
  - Os dados salvos não mudam.
  - As chaves de override das flags mudam de formato, mas só em Debug.
  - O CloudKit e os links não mudam.
  - Entram até seis textos novos em pt-BR.
  - Nenhum contrato de API muda; a versão do servidor e da ponte já é SemVer no `/health` (o servidor recebe a tag ou o `MARKETING_VERSION` no deploy).
