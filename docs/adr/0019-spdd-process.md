# 0019. Processo SPDD no lugar de specs e mudanças

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** nenhuma (migração do processo, canvases `FSC-001` a `FSC-007` em [spdd/](../../spdd/README.md))

## Contexto

O Fiscal seguia o ciclo antigo do workspace: specs vivas em `docs/specs/`, uma pasta por mudança em `docs/changes/<id>/` com `proposal.md`, `design.md` e `tasks.md`, critérios em EARS e arquivamento que reescrevia a spec. Em 2026-10-29 o usuário trocou esse ciclo, em todo o workspace `byescaleira-workspace` (PR byescaleira/byescaleira-workspace#9), pelo SPDD do [open-spdd](https://github.com/gszhangwei/open-spdd) ([artigo](https://martinfowler.com/articles/structured-prompt-driven/)). Também decidiu migrar já os projetos que usavam o formato antigo, entre eles o Fiscal. Regra do usuário: onde o processo do workspace e o open-spdd divergirem, vale o open-spdd.

## Decisão

- Siga o SPDD (skill `sdd`, `references/process.md`, e skill `byescaleira-sdd`, `references/process.md`):
  - análise em `spdd/analysis/`;
  - REASONS Canvas em `spdd/prompt/`, com o ok do usuário antes do código;
  - `spdd-prompt-update` antes do código quando o comportamento muda;
  - `spdd-sync` depois de refatorar;
  - revisão contra o canvas pelo `spec-reviewer`;
  - índice em `spdd/README.md`.
- O código do projeto é `FSC`. Os IDs são `FSC-<NNN>`.
- Cada spec viva vira um canvas `[Codify]` por capacidade (`FSC-001` a `FSC-007`):
  - o canvas registra o código como ele é;
  - as divergências ficam em "Known divergences", sem correção.
- `docs/specs/` fica congelada como histórico, assim como `docs/changes/` (com as mudanças `kit-adoption` e `align-workspace` arquivadas em 2026-10-29) e `docs/decisions.md`. Nenhuma das três recebe entrada nova.
- A regra 2 da constituição e a tabela "Onde cada coisa fica" passam a descrever esse fluxo. As outras regras não mudam, inclusive a 9: push na `development` continua pedindo o ok do usuário.

## Consequências

- O que o código faz e por quê mora no canvas da capacidade, que a próxima mudança da área atualiza pelo `spdd-prompt-update` ou pelo `spdd-sync`. O canvas não é arquivado.
- Toda mudança M ou L ganha análise e canvas com ID próprio, e todo commit dela traz `Canvas: spdd/prompt/<arquivo>.md` no corpo.
- As divergências dos canvases `[Codify]` viram itens do [backlog](../backlog.md). Cada correção é uma mudança ou um S.
- `docs/spec-template.md` e `docs/changes/_template/` ficam só como referência do histórico.
- Os links de `docs/architecture.md` passam a apontar para os canvases.

## Alternativas consideradas

- **Manter o ciclo antigo no Fiscal:** contraria a decisão do usuário para todo o workspace e deixaria o Fiscal com um processo diferente do resto.
- **Apagar `docs/specs/` e `docs/changes/`:** perde o histórico e quebra os links dos ADRs. Congelar custa pouco.
