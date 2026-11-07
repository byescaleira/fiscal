# Revisão da FSC-008: dobrável, Mac, visionOS e Developer

Canvas: [FSC-008](../prompt/FSC-008-202610311530-[Feat]-shell-fold-mac-vision-developer.md). Escopo da primeira rodada: `development..feature/platform-alignment` (`5976586..495ab5d`, 65 arquivos). Correções em `860c8b4` (`Canvas-update: sync`).

## Resumo

| Revisor | Primeira rodada | Depois das correções |
| --- | --- | --- |
| spec (`spdd-code-review`) | Needs Rework: 2 críticos, 3 importantes, 2 informativos | Needs Attention, 0 críticos: os dois resolvidos; o resíduo do Approach (frase do `GridCard`) corrigido no sync final |
| design | Reprovado: 1 bloqueador (auditoria), 2 deveria, 2 detalhes | Aprovado: auditoria ok (50 arquivos), sem bloqueador novo |
| acessibilidade | Aprovado: 2 deveria, 4 detalhes | — |
| código | Reprovado: 1 bloqueador (a mesma auditoria), 2 deveria, 6 detalhes | — |
| segurança | Aprovado: 4 detalhes | — |

## Checagem por seção do canvas

| Seção | Primeira rodada | Correção |
| --- | --- | --- |
| Requirements | Omissão: painéis de Hoje e Dinheiro sem `GroupBox` no Mac | `todayCard()` e `MoneyCard` em `GroupBox` no Mac; o `CardGrid` foi para o backlog, registrado no canvas |
| Entities | `RouteWindows` e os métodos novos do `FiscalNavigation` fora do diagrama | Diagrama e texto sincronizados (`Entry`, `store`, `entry`, `remove`, `closePane`, `pane(for:)`, `openRoutes`) |
| Approach | `.searchable` da janela no Mac não existia; janela do visionOS só a partir de 960 pt | Approach corrigido: a busca fica na `SearchScreen`; o limite de 960 pt do visionOS está escrito |
| Structure | Arquivos tocados ausentes; `FiscalCommands.swift` não existe | Structure lista todos os arquivos; o menu Ir mora no `MacShell.swift` |
| Operations, Norms, Safeguards | ok | — |

## Desvio de intenção

- **Acréscimos aceitos:**
  - duplo clique abre recibo e perfil;
  - o subtítulo dos recibos traz o total;
  - Esc fecha o painel da dobra também no iOS;
  - `FeatureFlags.remoteValue` público para o `DeveloperFlagsModel`.
- **Omissão resolvida:** `GroupBox` no Mac.
- **Divergências resolvidas pelo sync:** a busca no Mac e o limite de 960 pt do visionOS.

## Decisões implícitas registradas

- `FiscalEvents.networkError` só para `PublicDataError.rejected` (sem código HTTP confiável nos outros casos).
- Seleção única nas tabelas de votos e de representantes, múltipla nos recibos.
- `DeepLinkKind.unknown` como último caso.

## Correções da rodada (`860c8b4`)

- Auditoria `view-model-state`: estado de ordenação com o tipo declarado nas tabelas de recibos e de votos.
- Lista de representantes do Mac: contagem e "Em ordem alfabética. Ninguém é ranqueado." sob a tabela.
- `BallotMark`: símbolo oculto do VoiceOver.
- `RoutePane`: avisa o VoiceOver também ao fechar o painel.
- Janela vizinha do visionOS: `readsLayoutContext()` e guias pela própria janela.
- `CHANGELOG.md`, `docs/roadmap.md` e `docs/backlog.md` em dia.

## Ficou como detalhe (sem correção nesta fase)

- O atalho de `AppSection.shortcut` só vale até 9 seções.
- A lista de origem do Mac usa os tokens do inspector para a largura.
- Duplo clique com vários recibos abre todos.
- A UF "—" do Brasil ordena pelo código cru.
- O texto "toque na outra metade" não vale para teclado.
- `asc.py`: URLs restritas à API da Apple e sem `assert`, no template do workspace (backlog).
- `.gitignore` com `*.p8`, `*.pem` e `.env`.
- `govulncheck` com versão fixa na instrução de instalar.
