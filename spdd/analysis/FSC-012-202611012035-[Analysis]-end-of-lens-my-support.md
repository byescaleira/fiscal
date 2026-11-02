# Fim da Lente e a página "Meu apoio"

Segunda das quatro fases da [análise FSC-011](FSC-011-202611011850-[Analysis]-feed-profile-and-end-of-lens.md).

## Original Requirement

Pedido do usuário em 01/11/2026:

> Vamos acabar com esse questão de lente, isso não tem mais sentido no app. com isso podemos melhorar e criar algo interessante com o que eu apoio;

Resposta do usuário na análise FSC-011: **Pessoas e causas.** Uma página privada "Meu apoio", guardada só no aparelho, com as pessoas e as causas apoiadas e o que aconteceu com elas (como votaram, o que propuseram). Só fatos, sem nota nem ranking.

**Tamanho:** L, já no [roadmap](../../docs/roadmap.md) como etapa 8.3.6. Muda o contrato do [brief](../../docs/brief.md), o banco do aparelho, cerca de 83 arquivos e o site.

## Domain Concept Identification

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Lente** | Junta num só objeto temas, apoiados, "Prefiro não dizer", arte, paleta e ícone; ordena telas e abre um setup na primeira vez | Deixa de existir, no app e no vocabulário |
| **Apoio** | Até 5 pessoas, só no aparelho; apoiar também passa a seguir; muda a ordem de Hoje | Passa a ser uma escolha opcional, sem efeito na ordem de nenhuma tela |
| **Causa** | Os "temas" da Lente: de 3 a 5, entre os 17 de `Theme` | Até 5 temas, opcionais. **Tema é assunto, não posição:** "Saúde" não diz o que é bom para a saúde |
| **Página "Meu apoio"** | Não existe. A tela da Lente mistura escolha, visual e "Outra lente" | Tela nova com as pessoas, as causas e o que aconteceu com elas |
| **Atividade** | `SupportActivity` já junta as ações de cada apoiado (`actions.json`, 40 por pessoa) | Base da página |
| **Fato por causa** | `VoteSummary`, `PersonVote`, `Proposal`, `ActionItem` e `Highlight` já têm `themes`; `votes/recent.json` tem as últimas 60 votações | Dá para cruzar sem servidor novo, sem arquivo global por tema |
| **Aparência** | Ajustes já tem tema, cor de destaque e ícone, mas a paleta da Lente passa por cima da cor de destaque | A cor de destaque volta a mandar |
| **Arte** | A arte sugerida depende da Lente | O estúdio segue com a galeria inteira, sem sugestão por pessoa |

**Achados:**
- **Apagar:** `LensModel.erase()` e a confirmação existem, mas nenhuma tela liga `isConfirmingErase`. O site promete apagar "no próprio app", e hoje não dá. A página nova resolve isso de verdade.
- **Divergência antiga:** `docs/brief.md` e o ADR 0014 dizem que Hoje é a primeira aba, e o código abre em Seguindo. A `FSC-013` resolve; aqui o brief só perde a Lente.
- **Sem usuários na loja:** a 1.0 ainda não saiu (`CHANGELOG`: "Primeira versão"). A migração protege quem testa, sem risco a uma base real.
- **Correção da análise FSC-011:** ela dizia que a paleta continuava em Aparência. Como já existe a cor de destaque, as 8 paletas saem e a escolhida vira a cor de destaque.

## Strategic Approach

**Decisões:**

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| O que sai | veto | Setup inicial, ordem por tema, selo "Por quem você apoia", "Outra lente", "Prefiro não dizer", arte por Lente, as 8 paletas, `LensScreen`, `Route.lens` e o target `FeatureLens` |
| Abertura do app | veto | Abre direto, sem setup e sem pedir escolha política |
| Apoio não ordena nada | veto | Destaques, votações, gastos e busca ficam na mesma ordem para todo mundo. O Feed da `FSC-013` também não usa o apoio; quem é apoiado aparece nele por ser seguido |
| Seção de voto | reversível | "Como quem você apoia votou" continua na tela da votação: é fato, e só a pessoa vê |
| Causa sem direção | veto | O app nunca diz "votou a favor da causa", nunca dá percentual de alinhamento e nunca compara apoiados. Mostra o voto e a votação, com fonte. Uma votação de saúde pode ser boa ou ruim conforme quem lê |
| Privacidade | veto | Pessoas e causas seguem só no aparelho, fora do iCloud e do backup, como no ADR 0004. Não entram em servidor, notificação, Spotlight, widget, Siri nem cartaz. Só saem na exportação que a pessoa pede |
| Apagar de verdade | veto | Botão "Apagar meu apoio" na página, com confirmação. Apaga as pessoas e as causas, e não mexe em quem a pessoa segue, o que é dito na confirmação |
| Seguir | reversível | Apoiar continua seguindo; deixar de apoiar não deixa de seguir |
| Limites | reversível | Até 5 pessoas e até 5 causas, sem mínimo |
| Dados | reversível | Sem servidor novo. A página lê `actions.json`, os votos do ano de cada apoiado, `votes/recent.json` e `highlights.json`, com o cache atual |
| Dados salvos | reversível | Apoiados e temas viram pessoas e causas; a paleta vira a cor de destaque; "Prefiro não dizer" e a arte somem. Tudo aparece na página e pode ser apagado. Uma etapa nova do `FiscalMigrationPlan`, com teste |
| `fiscal://lens` | reversível | Passa a abrir "Meu apoio", para não quebrar link salvo |
| Formato da página | respondida | **Linha do tempo única:** tudo por data, com filtros de pessoa e causa em cima. Mesmo fato de duas pessoas vira uma linha só |
| Entrada | respondida | **Coração na barra e Ajustes:** o coração que já existe em Hoje e Votações abre a página, e Ajustes troca o cartão "Seu Fiscal" por uma linha. Na `FSC-013`, o coração vai para o Feed |
| Design | reversível | Referências reais antes de desenhar, com iteração no iPhone até o ok. O bonequinho aparece nas pessoas, sem expressão ligada a dado |
| Documentos | veto | ADR novo substitui o 0004 na parte da Lente e corrige o 0014. Brief, `README`, `docs/architecture.md`, metadados da App Store e o texto do site passam a dizer a verdade. O canvas `FSC-003` fica marcado como substituído. **Publicar o site espera o ok** |

**Etapas do canvas:** domínio e banco; a página; a retirada da Lente tela por tela; documentos e site. Paro na página para o ok no iPhone.

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Lente em cerca de 83 arquivos e 25 testes | Regressão em Hoje, Votações, Dinheiro, Perfil, Busca e Compartilhar | Retirar por camada, com a ordem neutra de cada tela conferida por teste antes de remover |
| Parecer campanha ou julgamento | Fere "só fatos" e a neutralidade | Regra de causa sem direção, teste de que os mesmos dados dão a mesma ordem com e sem apoio, e texto revisado |
| Dado sensível vazar | Apoio político é dado sensível na LGPD | Manter a guarda de `LensPrivacyTests` e `DeviceStoreTests` na entidade nova, e conferir que nada de apoio entra em cartaz, Spotlight ou widget |
| Migração do banco `Device` | Perda da escolha de quem testa | Teste de migração a partir do esquema atual |
| Causa sem atividade recente | Bloco vazio | Só mostra o que existe e explica de forma simples por que não há nada |
| Cargo sem votos no servidor | Governador ou prefeito apoiado mostra pouco | Mostra o que há em `actions.json` e diz que a fonte não publica votos desse cargo |
| Muitos pedidos na página | Consumo de dados | Até 5 pessoas, cache atual e carga em paralelo limitada |
| Site em desacordo com o app | Promessa falsa até publicar | Texto muda na fase; a publicação espera o ok, e o relatório da fase diz se saiu |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| Instalação nova abre direto, sem setup | Teste de interface e captura |
| Hoje, Votações, Dinheiro e Busca têm a mesma ordem com e sem apoio | Teste de modelo |
| Nenhuma tela mostra "Lente", "lente" ou o selo | Busca no catálogo e no código, e captura |
| Escolher pessoas e causas, e ver o que aconteceu com elas | Teste de modelo e captura com dados reais |
| Causa sem atividade e pessoa sem votos explicam o motivo | Teste de modelo e captura |
| "Apagar meu apoio" apaga pessoas e causas, e mantém quem a pessoa segue | Teste de modelo e roteiro |
| Apoio não entra em iCloud, backup, cartaz, Spotlight, widget ou notificação | Testes de privacidade |
| Quem já tinha Lente mantém pessoas e causas | Teste de migração |
| `fiscal://lens` abre "Meu apoio" | `DeepLinkTests` |

**Fora de escopo:** aba Feed e reorganização das abas (`FSC-013`), nova página do político (`FSC-014`), web e publicação do site sem ok.
