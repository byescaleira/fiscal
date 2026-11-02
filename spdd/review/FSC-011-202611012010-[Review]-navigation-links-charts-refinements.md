# Revisão da FSC-011: conteúdo, links dentro do app, Quem governa e gráficos

- **Canvas:** [FSC-011](../prompt/FSC-011-202611011855-[Feat]-navigation-links-charts-refinements.md)
- **Análise:** [FSC-011](../analysis/FSC-011-202611011850-[Analysis]-feed-profile-and-end-of-lens.md)
- **QA:** [docs/evidence/FSC-011/qa.md](../../docs/evidence/FSC-011/qa.md)
- **Intervalo revisado:** `f7ed1ed..fc26044`, com as peças do kit em `byescaleira-kit` v0.8.0
- **Veredito do revisor de canvas:** **Needs Rework** (3 críticos, 3 importantes, 2 informativos), por falta de prova, sem defeito de código
- **Painel de interface, código e segurança:** aprovado, sem bloqueador, com 4 itens de nível "deveria"

## Resumo por seção

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 3 (cenários 2, 8 e 22 sem prova) |
| Entities | ok | 1 informativo |
| Approach | desvio | 1 (etapa da proposta) |
| Structure | ok | 1 informativo |
| Operations | ok | 0 |
| Norms | ok | 0 |
| Safeguards | ok | 0 |
| Sincronia | ok | 0 |

## Achados do canvas

| Severidade | Onde | Achado | Resultado |
| --- | --- | --- | --- |
| crítica | Cenário 2 | Link sobre folha aberta sem prova | Corrigido: provado no simulador com uma folha temporária, fora do commit |
| crítica | Cenário 8 | VoiceOver no link sem prova | Corrigido em parte: `LinkAccessibilityTests` prova o traço de link e o rótulo. **A dica falada e o VoiceOver ligado seguem sem prova** |
| crítica | Cenário 22 | Leitura de cada estado sem prova | Corrigido: `LinkAccessibilityTests` acha a barra "São Paulo" com o valor. O VoiceOver ligado não rodou |
| importante | `ContentDetail`, `ProfileModel+Activity` | "Pode virar lei" aparecia como "Estágio" | Corrigido: bloco próprio, "Efeito", e o canvas atualizado |
| importante | `Route.destination` | Assinatura diferente do canvas | Canvas sincronizado |
| importante | `spdd/README.md` | Linha sem PR | Preenchida neste commit |
| informativa | Structure, Entities | `kindColor`, `mandateRowHeight`, `isEmpty` e `kicker` fora do canvas | Canvas sincronizado |

## Achados do painel

| Severidade | Onde | Achado | Resultado |
| --- | --- | --- | --- |
| deveria | `ContentDetail.swift` | Dado público podia virar `tel:`, `sms:` ou esquema de outro app na fonte | Corrigido na tela de conteúdo, com teste. A validação na publicação em Go fica fora desta fase, que não toca o servidor; registrada no backlog |
| deveria | `ContentDetailScreen.swift` | Rótulo do bloco cortado em fonte de acessibilidade | Corrigido |
| deveria | `ContentDetailScreen.swift` | Só o miolo do cartão do autor recebia o toque | Corrigido e conferido no simulador |
| deveria | Testes | Rotas de perfil e região sem teste | Corrigido: `ProfileModelTests` e `MineFollowingTests` |
| detalhe | `ContentDetailModel.swift` | Cache velho sem conexão pode dizer "saiu da lista" | Não conferido; fica como está |
| detalhe | `ContentDetailScreen.swift` | Estado vazio sem botão para Hoje | Fica como está; voltar já leva a Hoje |
| detalhe | `MandateCharts.swift` | Sem siglas, o estado só aparece ao tocar | Pedido do usuário e decisão do canvas |

## Desvio de intenção

- **Acréscimo:** o bloco "Efeito" e a checagem de esquema na fonte, ambos registrados no canvas; pular o setup da Lente nos testes de interface.
- **Omissão:** nenhuma no código; só a prova do VoiceOver ligado.
- **Divergência:** nenhuma depois das correções.

## Decisões implícitas da IA

- Tocar de novo num link com o navegador já aberto não abre outro.
- Todo destaque que não é voto usa `fiscal://highlight/<id>` no widget.

## Portão de merge

Nenhum defeito de código aberto. **Resta uma lacuna de prova:** a dica "Abre no navegador" e a leitura com o VoiceOver ligado, que só o aparelho físico mostra. O merge espera o ok do usuário.

## Verificação depois das correções

`scripts/verify.sh --full` passou: lint, build das plataformas, suíte inteira, web, admin, servidor e auditoria. `scripts/ui-test.sh`: 2 de 3 passam; `testTodayOpensTheLiveResults` já falhava antes e está no backlog.
