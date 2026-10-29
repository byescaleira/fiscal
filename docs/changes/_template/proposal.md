# <Título da mudança>

_Proposta da mudança `<id>`. Apague as instruções em itálico ao preencher._

- **Estado:** rascunho | aprovada | em andamento | entregue
- **Data:** _AAAA-MM-DD_
- **Branch:** `feature/<assunto>`

## Por quê

_O problema ou a oportunidade, em duas a quatro frases, do ponto de vista de quem usa o app. Cite o item do [backlog](../../backlog.md) ou do [roadmap](../../roadmap.md) de onde veio._

## O que muda

- _O que a pessoa passa a ver ou fazer, uma linha por mudança._
- _Marque **QUEBRA** no que muda dados salvos, links (`fiscal://`), textos já traduzidos ou o comportamento de uma versão publicada._

## Fora do escopo

- _O que parece fazer parte e não faz. Vai para o backlog se for para depois._

## Specs afetadas

_Uma subseção por arquivo de `docs/specs/`. Escreva só a diferença; o texto final entra na spec ao arquivar._

### `docs/specs/<capacidade>.md`

- **Adicionado:** _regra ou mecânica nova, com os números exatos._
- **Alterado:** _regra antiga → regra nova._
- **Removido:** _regra que deixa de valer e por quê._
- **Renomeado:** _nome antigo → nome novo._

## Critérios de aceite

_Em EARS, um `Requirement` por regra com gatilho e resposta que vira teste; cada um com pelo menos um cenário com valores concretos. Seção só descritiva não precisa._

### Requirement: <nome curto>

WHEN <gatilho> THE SYSTEM SHALL <resposta observável>.

#### Scenario: <caso>

- **WHEN** _<ação ou estado concreto, com valores>_
- **THEN** _<resultado observável, com valores>_

## Impacto

- **Targets:** _`FiscalDomain`, `FiscalData`, `Feature<Nome>`, `AppShell`, app, widgets, site, ponte, admin, servidor (`server/`)._
- **Dados:** _schema novo, migração, CloudKit (Development e Production)._
- **Textos:** _chaves novas em inglês com a tradução pt-BR, no app e no site ([ADR 0003](../../adr/0003-portuguese-only.md))._
- **Flags e loja:** _`FeatureFlag`, flags remotas do admin, App Store Connect, rótulo de privacidade._

## Decisões pendentes

1. _Pergunta genuína, com a opção recomendada primeiro e o porquê._

## O que fica com você

- _Tarefas que só o usuário faz (App Store Connect, CloudKit Console, portal da Apple, preços, aprovação visual), com onde fazer._
