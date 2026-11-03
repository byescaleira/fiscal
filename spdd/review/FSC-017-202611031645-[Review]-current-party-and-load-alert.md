# Revisão da FSC-017 contra o canvas

- **Canvas:** [FSC-017](../prompt/FSC-017-202611031133-[Feat]-current-party-and-load-alert.md)
- **Intervalo:** `658dea0..4f039ab`
- **Veredito do revisor:** Needs Rework (5 críticos). Depois da conferência e das correções, ficam 1 pendência e 1 decisão do usuário.

| Severidade | Achado | Conferência | Próximo passo |
| --- | --- | --- | --- |
| crítica | Cenário 23 sem prova | Procede em parte: existe `fallsBackWhenTheCDNIsDown`, que o QA não citava | QA corrigido |
| crítica | Cenários 7 e 8 pendentes | Procede: depende da reconstrução de 04/11 | Teste novo para o 8. Conferir o publicado antes do merge |
| crítica | QA errado sobre o `verify --full` | Não procede: `dc0598a` é das 12:43, e o build rodou às 12:48. A frase seguinte do QA era imprecisa | QA corrigido |
| crítica | Tópico do ntfy no chat | Procede | Exceção registrada no Safeguard por `spdd-prompt-update`; o usuário decide se troca |
| crítica | `party-check.py` sem `--published` | Procede | Código: `--published` e `--dir` |
| importante | Lista antes do deploy sem registro | Não procede: o usuário viu o CSV com 427 pessoas e disse "sim" | Registrado no QA |
| importante | Dependência `FeatureLiveResults` fora de Structure | Procede | Registrada em Structure |
| importante | Push real da Atividade ao Vivo não verificado | Procede | Declarado no QA e no PR |
| informativa | Nome do teste em Structure | Procede | Corrigido |
| informativa | Cenário 19 depois do 23 | Procede, sem efeito | Mantido: renumerar quebraria as referências |

## Decisões implícitas apontadas

| Decisão | Conferência |
| --- | --- |
| Partido novo vale para cargo que não seja `electedAwaiting`, inclusive `onLeave` | Mantida: a mesma pessoa não deve ter dois partidos, e a licença não muda isso |
| Título do aviso de dados velhos dizia "falhou" | Corrigido, com o cenário 14 atualizado: pode ser só um período sem novidade |
| `generatedAt` muda a cada execução? | Não: ficou em 11:44 com várias execuções e releases quentes depois, então o aviso de 48 horas pode disparar. Pode disparar também sem falha, e o runbook avisa |
| Dependência de `python3` no host | Conferida: existe em `/usr/bin/python3`. O runbook agora cita, junto do `curl` |

## Painel (código, segurança e interface)

Aprovado, sem bloqueador. Um "deveria", sobre o tópico exposto, e três detalhes (`python3` no host, duas vezes, e partido de candidatura derrotada, que é a regra do canvas).
