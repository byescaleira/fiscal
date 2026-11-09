# Revisão da FSC-012: fim da Lente e a página "Meu apoio"

- **Canvas:** [FSC-012](../prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md)
- **Análise:** [FSC-012](../analysis/FSC-012-202611012035-[Analysis]-end-of-lens-my-support.md)
- **QA:** [docs/evidence/FSC-012/qa.md](../../docs/evidence/FSC-012/qa.md)
- **Intervalo revisado:** `915c0ad` até o commit da QA
- **Veredito do revisor de canvas:** **Needs Rework** (1 crítico, 4 importantes, 2 informativos), por falta de prova e de sincronia
- **Painel de interface, código e segurança:** aprovado, sem bloqueador, com 4 itens de nível "deveria"

## Resumo por seção

| Seção | Estado | Achados |
| --- | --- | --- |
| Requirements | desvio | 3 (cenários 1, 19 e 23) |
| Entities | ok | 0 |
| Approach | desvio | 1 (estado do ADR) |
| Structure | desvio | 2 |
| Operations | ok | 0 |
| Norms | ok | 0 |
| Safeguards | ok para só fatos e neutralidade; privacidade corrigida | 1 |
| Sincronia | desvio | 2 |

## Achados

| Severidade | Origem | Achado | Resultado |
| --- | --- | --- | --- |
| crítica | canvas | Cenário 19 sem prova de acessibilidade | Corrigido em parte: `testMySupportRowsAreButtonsAtTheLargestTextSize` e captura no maior tamanho, que achou uma quebra de palavra, corrigida. **VoiceOver ligado não rodou** |
| deveria | segurança e código | Apoiar seguia sozinho, e seguidos vão ao iCloud e ao Spotlight, contra a promessa "só no aparelho" | Decisão do usuário: interruptor "Também seguir", desligado por padrão, com aviso. Canvas, ADR, brief e site atualizados |
| importante | canvas | Cenário 23 sem prova de leitura que falha | Corrigido: `aFailedReadReportsAndErasesNothing` |
| importante | canvas | Cenários 1, 5, 7, 12 e 18 sem tela | Segue registrado na QA |
| importante | canvas | Arquivos e correções fora de Structure | Canvas sincronizado |
| importante | canvas | ADR em Proposto no canvas e Aceito no arquivo | Canvas sincronizado |
| deveria | interface | Título sem `emphasisTitle` | Corrigido |
| deveria | interface | Linha da lista sem o traço de botão | Corrigido, com prova por XCUITest |
| detalhe | segurança | Captura com políticos reais sob "Meu apoio" num repositório público | Corrigido: arquivo tirado do histórico antes do primeiro push, com uma versão borrada |
| detalhe | segurança | Regra de lint sem cobrir `Fiscal/` | Corrigido |
| detalhe | segurança | Sem `privacySensitive` nas telas de apoio | Corrigido nas linhas, filtros, editor e votos |
| detalhe | segurança | `-wal` e `-shm` podem ficar sem a marca de fora do backup, e o `groupContainer` não foi conferido | Não verificado, anterior a esta fase; no backlog |
| detalhe | interface | Botão de limpar pequeno | Corrigido |
| informativa | canvas | Assinatura de `build` e arquivo da confirmação | Canvas sincronizado |

## Safeguards pedidos

- **Só fatos:** sem "a favor", "contra", alinhamento, percentual ou ranking. Sem violação.
- **Neutralidade:** só `FeatureSupport`, `VoteDetailModel`, a exportação e a montagem no `AppShell` leem o apoio, e a regra `support_stays_private` barra o resto; testei com um vazamento proposital. Sem violação.
- **Privacidade:** `SupportEntity` só em `deviceModels`, sem CloudKit e fora do backup. Apoiar não segue mais sozinho.

## Desvio de intenção

- **Acréscimo:** as correções pedidas pelo usuário (faixa de filtros e folha "Como medimos"), registradas no canvas.
- **Omissão:** só a prova com VoiceOver ligado e a instalação limpa de verdade.
- **Divergência:** nenhuma depois das correções.

## Portão de merge

Nenhum defeito de código aberto. **Resta uma lacuna de prova:** VoiceOver ligado, que só o aparelho físico mostra. O usuário pediu o merge sem esse teste, e a lacuna fica registrada na QA.
