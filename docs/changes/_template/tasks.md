# Etapas: <Título da mudança>

_Etapas da mudança `<id>`, na ordem de execução. Cada etapa termina com o app compilando e com a verificação escrita nela. Marque `[x]` no commit da etapa. Em trabalho "em etapas", pare e espere o ok depois de cada fase. Apague as instruções em itálico ao preencher._

## 1. Domínio

- [ ] 1.1 _Tipos e regras puras em `FiscalDomain`._
- [ ] 1.2 _Testes `<Assunto>Tests` cobrindo cada regra da spec._ Verificação: `scripts/verify.sh --quick`.

## 2. Dados

- [ ] 2.1 _Modelos, schema versionado e migração em `FiscalData`._
- [ ] 2.2 _Repositório e testes com banco em memória._ Verificação: `scripts/verify.sh --quick`.

## 3. Feature

- [ ] 3.1 _Model `@MainActor @Observable` com a lógica, os textos e as ações._
- [ ] 3.2 _Telas curtas, uma subview por seção, só tokens do design system._
- [ ] 3.3 _Textos nos 10 idiomas (`scripts/build.sh Debug`, `scripts/strings.sh`)._
- [ ] 3.4 _Revisão do `byescaleira-workspace:design-reviewer`._ Verificação: `scripts/verify.sh --quick` e o iPhone físico.

## 4. Fechamento

- [ ] 4.1 _`scripts/verify.sh --full` (lint, build das 3 plataformas, suíte inteira, web, admin e auditoria)._
- [ ] 4.2 _Revisão do `byescaleira-workspace:code-reviewer`._
- [ ] 4.3 _ADRs das decisões que valem além desta mudança._
- [ ] 4.4 _Specs atualizadas, `backlog.md` e `roadmap.md` em dia, pasta movida para `docs/changes/archive/<AAAA-MM-DD>-<id>/`._
