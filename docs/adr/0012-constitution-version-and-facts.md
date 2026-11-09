# 0012. Constituição: versão e "fato, não opinião"

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/archive/2026-10-29-align-workspace/proposal.md)

## Contexto

A constituição tinha 12 regras e duas decisões do usuário estavam fora dela:

- **Versão:** em 2026-10-28 o usuário decidiu, para todo o código dele, versionamento profissional sempre e apps Apple a partir do 26 com tudo do 27 (skill `sdd`, `references/versioning.md`). O Fiscal já roda do 26 (`IPHONEOS_DEPLOYMENT_TARGET = 26.0`, `MARKETING_VERSION = 1.0.0` em todos os alvos) e já tem `CHANGELOG.md`, mas nenhuma regra obrigava o `Unreleased` em todo PR nem pedia ok para a tag.
- **Credibilidade:** em 2026-10-26 o usuário pediu "só fatos" ([brief](../brief.md), "Credibilidade: só fatos"; README, "Princípios"): números e textos oficiais como vieram, fonte e data em cada bloco, "—" para dado ausente, nada de adjetivo de valor nem causa atribuída, e a explicação do motivo em tudo que é estimado. A regra vivia só no brief e nas specs, e um agente que não os lesse podia quebrá-la.

## Decisão

- Acrescente a regra 13, **Versão**, igual à do template do workspace: mínimo 26, tudo do 27 atrás de `#available` com alternativa no 26, `MARKETING_VERSION` SemVer igual em todos os alvos, `CHANGELOG.md` com `Unreleased` em todo PR e tag `vX.Y.Z` em cada versão da loja só com o ok do usuário.
- Acrescente a regra 14, **Fato, não opinião; incerteza explicada**, própria do Fiscal: fonte e data em cada número, "—" no lugar do dado ausente, nada de adjetivo de valor, causa atribuída, nota ou ranking de pessoas, a mesma regra para todos, e uma linha "Estimado: …" ao lado de tudo que não é número oficial, dizendo o que ficou sem medir.

## Consequências

- O revisor de código cobra o `CHANGELOG` em todo PR; a tag e a release entram na lista de aprovação humana do `AGENTS.md`.
- Texto, explicação gerada e cartaz que qualifiquem uma pessoa, um voto ou um partido são bloqueadores de revisão, mesmo fora do Fiscal na Web ou do site.
- A regra 14 é a que [credibility.md](../specs/credibility.md) detalha; mudar a spec não pode afrouxar a regra.

## Alternativas consideradas

- **Deixar a credibilidade só no brief:** o brief é visão de produto, não regra; agentes de frentes paralelas não o leem inteiro.
- **Regra de versão só no `AGENTS.md`:** a constituição é o que vence qualquer outro texto e o que o hook e os revisores conferem.
