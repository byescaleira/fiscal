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
- [ ] 3.3 _Textos em pt-BR (`scripts/build.sh Debug`, `scripts/strings.sh`; plurais por variação, com `zero`)._
- [ ] 3.4 _Tela conferida no simulador em claro, escuro e AX3, e no iPhone físico._ Verificação: `scripts/verify.sh --quick`.

## 4. Fechamento

- [ ] 4.1 _`scripts/verify.sh --full` (lint, build das 3 plataformas, suíte inteira, web, admin, servidor Go, licenças da arte e auditoria)._
- [ ] 4.2 _Revisão única, lançada junta: `byescaleira-workspace:design-reviewer`, `byescaleira-workspace:accessibility-reviewer` e `byescaleira-workspace:code-reviewer`; `byescaleira-workspace:security-reviewer` se o diff mexer em rede, cripto, servidor, entitlements ou dependências. Correções na mesma fase._
- [ ] 4.3 _ADRs das decisões que valem além desta mudança._
- [ ] 4.4 _`CHANGELOG.md` com o que muda para quem usa em `Unreleased`._
- [ ] 4.5 _`byescaleira-workspace:spec-reviewer`; specs atualizadas, `backlog.md` e `roadmap.md` em dia, pasta movida para `docs/changes/archive/<AAAA-MM-DD>-<id>/`._
