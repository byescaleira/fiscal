# Desenho: <Título da mudança>

_Como a mudança `<id>` é construída. Apague as instruções em itálico ao preencher. Mudança pequena pode ter só Contexto, Decisões e Testes._

## Contexto

_O estado atual do código e das specs que a mudança toca, com os tipos e arquivos pelo nome. Para tela existente, a crítica honesta antes de redesenhar: o que funciona, o que não funciona e por quê._

## Objetivos e não objetivos

- **Objetivo:** _o que tem de ser verdade no fim._
- **Não objetivo:** _o que fica de fora de propósito._

## Decisões

### <Decisão 1>

- **Escolha:** _o que será feito._
- **Por quê:** _o motivo em uma ou duas frases._
- **Alternativas descartadas:** _o que mais foi considerado e por que não._
- **ADR:** _`docs/adr/NNNN-<titulo>.md` quando a decisão vale além desta mudança; senão, "não precisa"._

## Onde fica

| Target | O que muda |
| --- | --- |
| `FiscalDomain` | _Entidades, valores e regras puras_ |
| `FiscalData` | _Modelos `@Model`, schema, migração, repositório_ |
| `Feature<Nome>` | _Model `@MainActor @Observable` e telas_ |
| `AppShell` | _Rotas, deep links e composição_ |

## Interface

_Telas e estados (vazio, carregando, erro, sem permissão, sem assinatura), componentes do design system usados, animações, layout por plataforma (iPhone retrato e paisagem, iPad, Mac, visionOS) e acessibilidade._

## Dados e migração

_Schema versionado, plano de migração, CloudKit, o que acontece com os dados já salvos e em outro aparelho com a versão antiga._

## Riscos

- _Risco → como é mitigado._

## Testes

- **Swift Testing:** _`<Assunto>Tests` em `<Target>Tests`, um por regra da spec._
- **Interface:** _`FiscalUITests`, se a mudança tiver fluxo novo._
- **Manual:** _o que entra no roteiro de [validation.md](../../validation.md) e em que aparelho._
