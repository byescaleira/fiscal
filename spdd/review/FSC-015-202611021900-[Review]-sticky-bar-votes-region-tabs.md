# Revisão da FSC-015: barra do topo, votações, região e ícones das abas

- **Canvas:** [FSC-015](../prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md)
- **Intervalo revisado:** `ff0ee03..18af608`, numa rodada só, com o `spec-reviewer` e o painel de interface, código e segurança.
- **Veredito do canvas:** Needs Rework (3 críticos, 5 importantes, 1 informativo). **Veredito do painel:** aprovado, sem bloqueador, com 1 "deveria" e 6 detalhes.
- **Limite:** os revisores só leram o código; não rodaram build nem testes.

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 3 |
| Entities | desvio estrutural | 1 |
| Approach | desvio | 1 |
| Structure | desvio estrutural | 1 |
| Operations | ok | 0 |
| Norms | desvio | 1 |
| Safeguards | ok | 0 |
| Sincronia | desvio | 2 |

## Achados do canvas

| Severidade | Onde | Achado | Próximo passo |
| --- | --- | --- | --- |
| crítica | `VotesModel+Agenda.swift`, `VotesAgendaScreen.swift` | A linha da sessão futura aparece sem quantidade nem seta quando os itens não são daquela sessão, e o canvas não dizia isso | Canvas atualizado nos cenários 20 e 22 |
| crítica | `RevealPage.swift`, `VoteStickyHeader.swift` | A barra limita o texto a `xxxLarge`, contra a Norm de Dynamic Type, e nenhum commit atualizou o canvas | Exceção registrada em Norms e no cenário 31 |
| crítica | Histórico | Comportamento mudou depois do ok sem `Canvas-update` | `prompt-update` neste commit, `spdd-sync` para a estrutura |
| importante | Commit `653a05b` e tutorial | Telas de Memória e Compartilhar fora da Structure | Pedido do usuário ("tomar cuidado com isso em todo app"), agora em Norms; entra na Structure pelo sync |
| importante | `qa.md` | Itens 3, 4, 6, 14, 17, 19 e 20 diziam "passou" além da evidência | Corrigidos para "passou em parte" |
| importante | Approach | `FollowingModel` guarda um `RegionModel` em vez de ler `HomePlace` | `spdd-sync` |
| importante | Operação 3 | Sem teste do plural "1 outro voto" | Lacuna aceita e declarada: só a entrada no catálogo prova o singular |
| importante | Structure | `site/llms.txt` não tinha mudado | Atualizado neste commit |
| informativa | `spdd/README.md` | Vira "entregue" depois do merge | Fechamento |

**Conferido à parte:** o revisor não achou registro do ok do kit 0.9.0. O usuário respondeu "sim" ao merge e à tag nesta fase, na conversa, em 02/11/2026.

## Achados do painel

| Severidade | Onde | Achado | Decisão |
| --- | --- | --- | --- |
| deveria | `RevealPage.swift:103` | A barra não cresce nos tamanhos de acessibilidade | Mantido e registrado em Norms: sem o limite, ela ocupava a tela e travava a rolagem. Conferido em `AccessibilityXXXL` no simulador; falta o iPhone |
| detalhe | `RevealPage.swift:77` | Estimativa de 112 pt até a primeira medida | Mantido |
| detalhe | `FollowingModel.swift:55` | Erro das sugestões não aparece | Mantido: sugestões são opcionais |
| detalhe | `FollowingScreen.swift:40` | Lista sem `privacySensitive()`, como já era em Região | Fora de escopo |
| detalhe | `FollowingScreen.swift:66` | Rótulo "Not Now" no botão de ícone | Mantido |
| detalhe | `VoteScoreRow.swift:63` | Linha sem o traço de botão para o VoiceOver, a confirmar | VoiceOver ligado não foi usado |
| detalhe | `VoteStickyHeader.swift:16` | Título encolhe na barra | Mantido, para não cortar o número da proposta |

## Sincronia

O usuário aprovou o plano do `spdd-sync`, e o canvas foi sincronizado. Cobriu: `RevealPage` e modificadores, `AgendaLine`, `VoteCompactScore`, testes novos, `VoteBoard.swift` no lugar de `RepresentativesDigest.swift`, `FiscalEvents`, `SectionScreen`, `PeerBadge`, os dados de teste e os arquivos de Memória e Compartilhar.
