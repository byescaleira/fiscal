# Revisão da FSC-013 contra o canvas

- **Canvas:** [FSC-013](../prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md)
- **Intervalo revisado:** `a83c9f5..b723091`
- **Veredito da rodada:** Needs Rework (3 críticos), com as correções abaixo no commit seguinte.

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 3 |
| Entities | desvio | 1 |
| Approach | ok | 1 |
| Structure | ok | 0 |
| Operations | ok | 0 |
| Norms | ok | 0 |
| Safeguards | desvio | 1 |

| Severidade | Achado | Próximo passo | Resultado |
| --- | --- | --- | --- |
| crítica | O gasto só tem o mês, mas a linha mostrava "1 de nov." | Corrigir o código | Corrigido: a linha mostra o mês e o ano, e o dia 1 só ordena |
| crítica | Cenário 21, Reduzir movimento, sem prova | Rodar o roteiro ou registrar | Executado no simulador; transição sem efeito com o ajuste; quadro a quadro não medido |
| crítica | Cenário 22, Duo aberto, iPad e Mac, sem prova | Rodar o roteiro ou registrar | Duo deitado visto; Duo aberto, iPad e Mac não executáveis aqui; decisão no PR |
| importante | Destaque de voto de quem a pessoa segue fica na lista e no topo | `spdd-prompt-update` | Intencional: a linha traz o voto; canvas e teste acrescentados |
| importante | Entities com `FeedKind` e sem `FeedExpenses`, `FeedRaceBoard` e membros de `FeedModel` | `spdd-sync` | Sincronizado |
| importante | Evento de apuração sempre descartado | Corrigir o código | Corrigido: `hidesRaces`, só some com apuração no topo |
| informativa | "Até 40 por pessoa" vem do servidor | `spdd-sync` | Registrado em Approach |

**Desvio de intenção:** sem acréscimo fora do canvas e sem omissão; as três divergências estão acima.

**Decisões implícitas registradas:** dia 1 só para ordenar o gasto; voto de destaque de quem a pessoa segue fica na lista; evento de votação do resumo sem `ref` não entra; o aviso de falha aparece no topo e no lugar do fim.

**Fora do escopo:** nada entrou. Sem página do político e sem `ShareSubject` novo.

**Painel de interface e código:** aprovado sem bloqueador. Os cinco "deveria" (alvo de toque do compartilhar, corrida entre `load` e `loadMore`, cabeçalho e filtros no maior tamanho de texto, tour com as abas antigas) foram corrigidos no mesmo commit, junto dos detalhes do widget e do traço de link.
