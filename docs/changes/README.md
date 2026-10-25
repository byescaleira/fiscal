# Mudanças

Toda mudança de comportamento do Fiscal (feature nova, tela refeita, regra alterada, integração, migração de dados) passa por uma pasta aqui antes de virar código. A pasta junta o porquê, o como e as etapas; ao terminar, ela atualiza as [specs](../specs/README.md) e vai para o arquivo. Correção pequena sem mudança de comportamento (bug, texto, lint) não precisa de pasta.

## Ciclo

1. **Proposta.** Copie `_template/` para `docs/changes/<id>/`, com `<id>` em inglês, kebab-case e começando por verbo (`add-reminders`, `redesign-home`, `migrate-items-v2`). Preencha `proposal.md`: por quê, o que muda, o que fica de fora, specs afetadas e o que é do usuário. Decisões genuínas são perguntadas antes de seguir, com a opção recomendada primeiro.
2. **Desenho.** `design.md` com o contexto, as decisões técnicas e as alternativas descartadas, os targets e tipos, os dados e a migração, os riscos e como testar. Tela existente começa pela crítica honesta. Decisão que vale além desta mudança vira um [ADR](../adr/README.md).
3. **Etapas.** `tasks.md` com as fases na ordem, cada etapa verificável e com a verificação escrita. "Em etapas" = parar e esperar o ok depois de cada uma.
4. **Implementação.** Uma etapa por vez, marcando `[x]` no mesmo commit da etapa, em `feature/<assunto>`.
5. **Arquivamento.** Com tudo entregue e verificado: aplique as mudanças de spec em `docs/specs/`, atualize `backlog.md` e `roadmap.md`, e mova a pasta para `archive/<AAAA-MM-DD>-<id>/` (a data é a do arquivamento). A pasta arquivada não muda mais.

## Em andamento

| Mudança | Estado |
| --- | --- |
| _nenhuma_ | |

## Modelos

- [_template/proposal.md](_template/proposal.md)
- [_template/design.md](_template/design.md)
- [_template/tasks.md](_template/tasks.md)
