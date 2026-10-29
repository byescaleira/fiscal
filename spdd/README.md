# SPDD

As análises, os canvases e as revisões do Fiscal no método SPDD (open-spdd). O processo está na skill `sdd`, `references/process.md`, e, no app Apple, na skill `byescaleira-sdd`, `references/process.md`. A troca do ciclo antigo está no [ADR 0019](../docs/adr/0019-spdd-process.md). `docs/specs/`, `docs/changes/` e `docs/decisions.md` são histórico congelado.

- **Código do projeto:** `FSC`
- **Próxima sequência:** `FSC-008`

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
| `FSC-001` | [Apuração ao vivo e Atividade ao Vivo da disputa](prompt/FSC-001-202610291700-[Codify]-live-results.md) | entregue | `feature/spdd-migration` | — |
| `FSC-002` | [Dados públicos: arquivos, CDN, cache, erros, pacote offline e carga](prompt/FSC-002-202610291700-[Codify]-public-data-api.md) | entregue | `feature/spdd-migration` | — |
| `FSC-003` | [Lente: quem você apoia, temas e visual, só no aparelho](prompt/FSC-003-202610291700-[Codify]-lens.md) | entregue | `feature/spdd-migration` | — |
| `FSC-004` | [Credibilidade: fonte, "—", colegas, peso, "Estimado" e explicações](prompt/FSC-004-202610291700-[Codify]-credibility.md) | entregue | `feature/spdd-migration` | — |
| `FSC-005` | [Cartazes de compartilhar, acervo de arte e créditos](prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md) | entregue | `feature/spdd-migration` | — |
| `FSC-006` | [Checagens do Projeto Comprova](prompt/FSC-006-202610291700-[Codify]-fact-checks.md) | entregue | `feature/spdd-migration` | — |
| `FSC-007` | [Alertas: destaque do momento e resultado da disputa](prompt/FSC-007-202610291700-[Codify]-notifications.md) | entregue | `feature/spdd-migration` | — |

As capacidades que ainda vivem em guias de recurso (atualização obrigatória em [force-update.md](../docs/force-update.md), site e Fiscal na Web em [web.md](../docs/web.md), admin e flags em [admin.md](../docs/admin.md)) ganham um canvas `[Codify]` na primeira mudança da área.
