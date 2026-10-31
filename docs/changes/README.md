# Mudanças (histórico)

Congelado em 2026-10-29. Desde então, as mudanças do Fiscal seguem o SPDD: análise e canvas em [spdd/](../../spdd/README.md), com o ID `FSC-<NNN>` ([ADR 0019](../adr/0019-spdd-process.md)). Esta pasta guarda as mudanças de antes do SPDD, todas arquivadas em [archive/](archive/), e não recebe pasta nova.

Arquivadas: `live-results`, `app-1.0`, `setup-lens-art` (substituída pela `app-1.0`), `kit-adoption` e `align-workspace`. As duas últimas foram entregues nas branches `feature/kit-adoption` e `feature/workspace-alignment` e arquivadas em 2026-10-29, antes da migração para o SPDD.

O ciclo abaixo é o que valia até a migração.

## Ciclo

1. **Proposta.** Copie `_template/` para `docs/changes/<id>/`, com `<id>` em inglês, kebab-case e começando por verbo (`add-reminders`, `redesign-home`, `migrate-items-v2`). Preencha `proposal.md`: por quê, o que muda, o que fica de fora, specs afetadas, critérios de aceite em EARS e o que é do usuário. Decisões genuínas são perguntadas antes de seguir, com a opção recomendada primeiro.
2. **Desenho.** `design.md` com o contexto, as decisões técnicas e as alternativas descartadas, os targets e tipos, os dados e a migração, os riscos e como testar. Tela existente começa pela crítica honesta. Decisão que vale além desta mudança vira um [ADR](../adr/README.md).
3. **Etapas.** `tasks.md` com as fases na ordem, cada etapa verificável e com a verificação escrita. "Em etapas" = parar e esperar o ok depois de cada uma.
4. **Implementação.** Uma etapa por vez, marcando `[x]` no mesmo commit da etapa, em `feature/<assunto>`.
5. **Arquivamento.** Com tudo entregue, verificado e conferido pelo `byescaleira-workspace:spec-reviewer`, e com o `CHANGELOG.md` em dia: aplique as mudanças de spec em `docs/specs/`, atualize `backlog.md` e `roadmap.md`, e mova a pasta para `archive/<AAAA-MM-DD>-<id>/` (a data é a do arquivamento). A pasta arquivada não muda mais.

## Modelos

- [_template/proposal.md](_template/proposal.md)
- [_template/design.md](_template/design.md)
- [_template/tasks.md](_template/tasks.md)
