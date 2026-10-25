# 0001. Registrar decisões em ADRs

- **Estado:** Aceito
- **Data:** 2026-10-25
- **Mudança:** nenhuma

## Contexto

O Fiscal nasceu do template do plugin `byescaleira-workspace`, que trazia um único `docs/decisions.md` em ordem cronológica. Num arquivo único, as decisões se misturam, ficam longas e não dizem quais ainda valem; agentes sem contexto precisam ler tudo para achar a regra atual. O fluxo do repositório agora separa a verdade atual (`docs/specs/`), as mudanças (`docs/changes/`) e o porquê.

## Decisão

- Registre cada decisão de arquitetura, dados, dependências, plataforma, monetização ou exceção da auditoria num ADR em `docs/adr/NNNN-<titulo>.md`, a partir do modelo [0000-template.md](0000-template.md), e acrescente a linha no [índice](README.md).
- Um ADR por decisão, curto, em pt-BR, com título de arquivo em inglês.
- ADR aceito não é reescrito: quando a decisão muda, um ADR novo o substitui e o antigo ganha o estado **Substituído por NNNN**.
- O `docs/decisions.md` fica como histórico do que foi decidido antes deste ADR e não recebe entradas novas.

## Consequências

- Cada decisão tem um link estável, citável em propostas, specs, commits e revisões.
- O estado de cada decisão (proposta, aceita, substituída) fica explícito.
- Toda mudança com decisão que vale além dela inclui o ADR no mesmo commit; a etapa de fechamento do `tasks.md` confere isso.

## Alternativas consideradas

- **Continuar só com `docs/decisions.md`:** simples, mas mistura decisões vivas e substituídas e cresce sem índice.
- **Decisões só nas mensagens de commit ou nas propostas:** somem do caminho de quem lê o código e não têm estado.
