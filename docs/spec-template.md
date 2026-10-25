# Modelo de spec viva

Copie este arquivo para `docs/specs/<capacidade>.md` (ex.: `docs/specs/reminders.md`) ao arquivar a primeira mudança de uma capacidade do Fiscal, e acrescente a linha no [índice das specs](specs/README.md). A spec guarda só a verdade atual; a proposta, o desenho e as etapas de cada mudança ficam em `docs/changes/<id>/`, a partir de [changes/_template/](changes/README.md), e as decisões vão em [adr/](adr/README.md). O que fica fora da capacidade vai em [backlog.md](backlog.md). Apague as instruções em itálico ao preencher. Quando a spec nova substituir uma antiga, apague a antiga.

---

# <Nome da área>

_Uma ou duas frases: o que a área entrega para a pessoa e onde ela aparece no app. Termine linkando os vizinhos, por exemplo: "As decisões estão em [adr/](../adr/README.md); o que falta fazer está em [backlog.md](../backlog.md)."_

## Princípios

_De três a seis regras de produto que valem para toda a área e servem de critério quando surgir um caso novo. Cada uma em uma frase, com o porquê._

- **<Regra em negrito, terminada em ponto.>** _Por que ela existe._
- **Os dados nunca ficam presos.** _Exemplo de princípio que vale para todo app: ler e exportar continuam livres em qualquer estado._

## Onde fica

_Os targets e tipos envolvidos. Nada de arquivo que ainda não existe sem dizer que é planejado._

| Target | O que fica nele |
| --- | --- |
| `FiscalDomain` | _Entidades, valores e regras puras da área_ |
| `FiscalData` | _Modelos `@Model`, repositório, serviços externos_ |
| `Feature<Area>` | _Model `@MainActor @Observable`, telas e `<Area>Model+<Assunto>.swift`_ |
| `AppShell` | _Rotas, deep links (`fiscal://<area>`) e composição_ |

## Mecânicas e regras

_O comportamento completo, com números exatos: limites, faixas, prazos, preços, intervalos, quantidades, textos fixos. O código lê estes números e os testes os conferem; se um número muda, muda aqui primeiro._

### <Mecânica 1>

- _Quando acontece, o que muda, o que a pessoa vê._
- _Casos de borda: vazio, offline, sem permissão, sem assinatura, dado inválido, outro aparelho._

| <Entrada> | <Resultado> |
| --- | --- |
| _ex.: 0 itens_ | _ex.: estado vazio com exemplo e guia_ |

### <Mecânica 2>

- _..._

## Construção

_Como a área é montada em camadas e como é testada. Cite os tipos e os testes pelo nome._

1. **Domínio:** _tipos e regras puras; testes `<Assunto>Tests` em `FiscalDomainTests`._
2. **Dados:** _modelos, migração do schema (se houver) e repositório; testes com banco em memória._
3. **Feature:** _model com a lógica e os textos; a view só desenha. Testes do model com fontes falsas._
4. **Integrações:** _widgets, App Intents, notificações, flags (`FeatureFlag`), assinatura (`ProAccess`)._
5. **Textos:** _chaves em inglês no `Localizable.xcstrings`, com as 9 traduções._

## O que fica com você

_Tarefas que só o usuário pode fazer: App Store Connect, CloudKit Console (Deploy to Production), portal da Apple, contas de teste, preços, aprovações de direção visual. Uma linha por tarefa, com onde fazer._

- _ex.: criar o tipo `<Registro>` no CloudKit Console (banco público, Development) e publicar em Production._

## Histórico

_Os links das mudanças arquivadas e dos ADRs que formaram a capacidade, do mais recente para o mais antigo. As etapas de cada mudança ficam no `tasks.md` dela, não aqui._

| Data | Mudança ou ADR |
| --- | --- |
| _AAAA-MM-DD_ | _[`<id>`](../changes/archive/AAAA-MM-DD-<id>/proposal.md)_ |
| _AAAA-MM-DD_ | _[NNNN](../adr/NNNN-<titulo>.md)_ |
