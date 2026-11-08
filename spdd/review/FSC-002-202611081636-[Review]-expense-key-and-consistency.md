# Revisão: chave própria da cota e conferência isolada

- **Canvas:** `spdd/prompt/FSC-002-202610291700-[Codify]-public-data-api.md`
- **Branch:** `feature/expense-key-and-consistency`
- **Intervalo revisado:** `c6f3179..de9d1d4`. As correções desta revisão entram no commit seguinte.
- **Revisores, numa rodada só:** `spec-reviewer` contra o canvas, `code-reviewer` e `security-reviewer`. O diff não toca interface, então não houve revisão de design nem de acessibilidade. O painel por workflow não rodou; os três revisores foram chamados direto.

## Resumo

| Revisor | Veredito | Crítico ou bloqueador | Importante ou deveria | Informativo ou detalhe |
| --- | --- | --- | --- | --- |
| Canvas | Needs Attention | 0 | 4 | 1 |
| Código | Reprovado | 1 | 7 | 1 |
| Segurança | Reprovado | 2 | 5 | 3 |

**Veredito depois das correções:** Ready to Merge, com os achados não corrigidos registrados abaixo e no canvas.

## Bloqueadores

| Achado | Revisor | Correção |
| --- | --- | --- |
| A `memoria` apontava o `ready` para a reconstrução antes de comparar. Sem passada incremental, ou com uma queda entre a montagem e a volta, o `fiscal-pages` publicava a reconstrução divergente. | Segurança | A reconstrução roda numa cópia do preparo (`public/check`, com links físicos) e monta a release com `Stager.Detached`, sem mover o `ready`. Sem divergência, `adoptCheck` leva os caminhos mudados ao preparo e `Promote` aponta o `ready`. Teste: `TestADivergenceWithoutAnIncrementalPassKeepsTheReadySite`. |
| Com caminhos retidos no preparo, uma mudança nos membros do índice caía na montagem completa e publicava tudo. | Segurança | O preparo não recebe mais nada da reconstrução divergente, então não há o que vazar. Teste: `TestADivergentCheckLeavesTheStagingAndTheSiteUntilPublishedByHand`, com um trabalho derivado depois da divergência. |
| Divergência e falha na mesma execução saíam com 3, e o alerta zerava a contagem de falhas. | Código e segurança | `syncExit` sai com 4 nesse caso, e o alerta avisa a divergência e conta a falha. Testes: `TestSyncExitKeepsAFailureNextToADivergence` e `TestLoadAlertCountsTheFailureThatCameWithADivergence`. |

## Deveria e importante

| Achado | Revisor | Próximo passo | Feito |
| --- | --- | --- | --- |
| O canvas dizia que os retidos "nunca saem sozinhos", e o runbook admitia vazamento. | Canvas e segurança | Atualizar o canvas | Sim. Com a cópia isolada, o texto do canvas, do runbook, do README e do CHANGELOG descreve o comportamento real. |
| Ids dependem da ordem das linhas, e a troca única de ids não estava registrada. | Canvas e código | Atualizar o canvas | Sim, em "Known divergences". Teste da migração: `TestReadingWithTheNewExpenseIDsClosesTheOldKeys`. |
| Structure e Operations não citavam os arquivos novos nem o script de alerta. | Canvas | Atualizar o canvas | Sim. |
| `Repeated` em toda tabela poderia dar falso alarme. | Código | Medir em produção | Medido no backup de 08/11/2026: só `expenses` (Câmara), `mandates` e `city_officials` repetem chave na mesma escrita. `city_officials` perdia o cargo de prefeito ou vice de quem também é vereador na mesma cidade, em 27 casos; a chave passou a levar o cargo, e a guarda cobre as cidades. `mandates` não volta do banco e ficou fora da guarda, registrado em "Known divergences". |
| A impressão digital da fonte é gravada mesmo com `Repeated`. | Código | Decidir | Mantido: não gravar faria uma fonte com sonda, como o TSE, rodar a cada 5 minutos. Registrado no canvas. |
| `-once` e `-phase` não avisam. | Código | Documentar | Sim, no canvas e no runbook. |
| Memória do mapa de chaves no gravador. | Código | Medir | Estimado, não medido: cerca de 40 B por chave, menos de 100 MB com as 2,3 milhões de linhas atuais somadas. A leitura real da Câmara no Mac terminou sem erro. |
| `PublishStaging` gravava o registro depois de mover o `ready` e saía com erro sem dizer que o `ready` já tinha mudado. | Código e segurança | Corrigir | Sim. As mensagens de erro de `PublishHeld` dizem que o `ready` já mudou. |
| Uma `memoria` seguinte apagava o `held` sem publicar. | Segurança | Corrigir | Resolvido pela cópia isolada: o preparo nunca recebe o conteúdo retido, então uma `memoria` sem divergência não esconde nada. |
| O Caddy servia o preparo com os retidos na origem `v1`. | Segurança | Corrigir | Resolvido: o preparo fica igual ao publicado. |
| `ALERT store` não aparecia no `-site status`. | Segurança | Corrigir | Não feito: aparece no log e no aviso pelo código 3. O runbook explica o que fazer. |

## Detalhes

- **`held` sem teto:** mantido, para o operador ver a lista inteira; a amostra de 30 continua no log.
- **Título com acento no cabeçalho do ntfy:** trocado por "Fiscal: dados divergiram", só em ASCII.
- **Kind da release publicada:** `memoria`, como antes; o `released` do `consistency.json` registra a origem.

## Checagem por seção do canvas

| Seção | Estado |
| --- | --- |
| Requirements | Cenários novos da cópia isolada, do código 4, das cidades e da migração, cada um com teste nomeado |
| Approach | Riscos e "Known divergences" atualizados |
| Structure | Arquivos novos listados |
| Operations | Operação 2 cobre `Verify`, `PublishHeld`, `syncExit` e o script de alerta |
| Norms e Safeguards | Sem mudança; nenhum comentário no código, nenhum deploy |

## Desvio de intenção

- **Acréscimo:** a correção da chave das cidades e a guarda nas cidades. Vieram da medição pedida pela revisão de código e são a mesma classe de bug.
- **Omissão:** nenhuma.
- **Decisões implícitas:** a ordem das linhas define o sufixo do id; a impressão digital é gravada mesmo com repetição.

## O que não foi verificado

- `publish-held` com uma cópia real do preparo. O ensaio de 05/11 usou o comando anterior; o comando novo só rodou em testes.
- A reconstrução completa contra o banco de produção, porque precisaria da chave do pseudônimo.
- A migração das chaves das cidades em produção.
