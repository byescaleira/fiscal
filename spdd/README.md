# SPDD

As análises, os canvases e as revisões do Fiscal no método SPDD (open-spdd). O processo está na skill `sdd`, `references/process.md`, e, no app Apple, na skill `byescaleira-sdd`, `references/process.md`. A troca do ciclo antigo está no [ADR 0019](../docs/adr/0019-spdd-process.md). `docs/specs/`, `docs/changes/` e `docs/decisions.md` são histórico congelado.

- **Código do projeto:** `FSC`
- **Próxima sequência:** `FSC-026` (`FSC-017` a `FSC-024` estão em outras branches e sessões)

## Pastas

| Pasta | O que guarda |
| --- | --- |
| [analysis/](analysis/) | A análise de cada mudança (`<ID>-<AAAAMMDDHHmm>-[Analysis]-<descricao>.md`): o quê e o porquê, sem código |
| [prompt/](prompt/) | O REASONS Canvas de cada mudança ou capacidade (`<ID>-<AAAAMMDDHHmm>-[<Tipo>]-<escopo>-<descricao>.md`), que é a verdade viva do código |
| [review/](review/) | O relatório de desvio do `spdd-code-review` (`<ID>-<AAAAMMDDHHmm>-[Review]-<descricao>.md`) |
| [requirements/](requirements/) | As histórias INVEST do `spdd-story` (`[User-story-<N>]<titulo>.md`), quando uma L pedir |

No shell, ponha esses caminhos entre aspas: o zsh trata `[...]` como padrão de busca.

## Índice

| ID | Canvas | Estado | Branch | PR |
| --- | --- | --- | --- | --- |
| `FSC-001` | [Apuração ao vivo e Atividade ao Vivo da disputa](prompt/FSC-001-202610291700-[Codify]-live-results.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-002` | [Dados públicos: arquivos, CDN, cache, erros, pacote offline e carga](prompt/FSC-002-202610291700-[Codify]-public-data-api.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-003` | [Lente: quem você apoia, temas e visual, só no aparelho](prompt/FSC-003-202610291700-[Codify]-lens.md) | substituído pela `FSC-012` | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-004` | [Credibilidade: fonte, "—", colegas, peso, "Estimado" e explicações](prompt/FSC-004-202610291700-[Codify]-credibility.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-005` | [Cartazes de compartilhar, acervo de arte e créditos](prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-006` | [Checagens do Projeto Comprova](prompt/FSC-006-202610291700-[Codify]-fact-checks.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-007` | [Alertas: destaque do momento e resultado da disputa](prompt/FSC-007-202610291700-[Codify]-notifications.md) | entregue | `feature/spdd-migration` | [#5](https://github.com/byescaleira/fiscal/pull/5) |
| `FSC-008` | [Fiscal no padrão atual do workspace: dobrável, Mac, visionOS e ferramentas](prompt/FSC-008-202610311530-[Feat]-shell-fold-mac-vision-developer.md) | entregue | `feature/platform-alignment` | [#6](https://github.com/byescaleira/fiscal/pull/6) |
| `FSC-009` | [Seguir no centro do Fiscal: aba Seguindo](prompt/FSC-009-202610312200-[Feat]-following-tab-and-follow-everywhere.md) | entregue | `feature/following-core` | [#7](https://github.com/byescaleira/fiscal/pull/7) |
| `FSC-010` | [Compartilhar como fluxo completo, por rede social](prompt/FSC-010-202610312345-[Feat]-share-flow-by-network.md) | entregue | `feature/share-flow` | [#8](https://github.com/byescaleira/fiscal/pull/8) |
| `FSC-011` | [Refinos: conteúdo com tela própria, links dentro do app, Quem governa e gráficos](prompt/FSC-011-202611011855-[Feat]-navigation-links-charts-refinements.md) | entregue | `feature/app-refinements` | [#9](https://github.com/byescaleira/fiscal/pull/9) |
| `FSC-012` | [Fim da Lente e a página "Meu apoio"](prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md) | entregue | `feature/end-of-lens` | [#10](https://github.com/byescaleira/fiscal/pull/10) |
| `FSC-013` | [Feed como primeira aba e a aba Região](prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md) | entregue | `feature/feed` | [#11](https://github.com/byescaleira/fiscal/pull/11) |
| `FSC-014` | [Nova página do político e compartilhar um item](prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md) | entregue | `feature/politician-page` | [#12](https://github.com/byescaleira/fiscal/pull/12) |
| `FSC-015` | [Barra do topo, votações, região e ícones das abas](prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md) | entregue | `feature/sticky-bar-and-screens` | [#13](https://github.com/byescaleira/fiscal/pull/13) |
| `FSC-016` | [Cartões no modo claro e bonequinho de todos](prompt/FSC-016-202611021923-[Feat]-light-cards-and-portraits.md) | entregue | `feature/light-cards-and-portraits` | [#14](https://github.com/byescaleira/fiscal/pull/14) |
| `FSC-022` | [Ícones do app com paisagens do Brasil vistas de cima](prompt/FSC-022-202611051909-[Feat]-icons-aerial-brazil-landscapes.md) | entregue | `feature/app-icon-landscapes` | [#17](https://github.com/byescaleira/fiscal/pull/17) |
| `FSC-025` | [Bonequinhos em Metal, fase 1: prova de viabilidade](prompt/FSC-025-202611061422-[Feat]-portraits-metal-proof.md) | entregue: prova concluída; Lottie segue como motor geral e o Metal fica no cabeçalho do perfil | `feature/metal-portraits` | — |

As capacidades que ainda vivem em guias de recurso (atualização obrigatória em [force-update.md](../docs/force-update.md), site e Fiscal na Web em [web.md](../docs/web.md), admin e flags em [admin.md](../docs/admin.md)) ganham um canvas `[Codify]` na primeira mudança da área.
