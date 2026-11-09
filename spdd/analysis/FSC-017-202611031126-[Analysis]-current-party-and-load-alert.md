# Partido atual, retratos novos e alerta de carga

## Original Requirement

Pedidos e decisões do usuário em 02 e 03/11/2026:

> Outra coisa devemos ter o boquinho para todos os políticos que vão assumir em 2027, vi aqui que tem vario que não tem (estão genéricos), como o Eduardo Riedel

Na `FSC-016`, ele escolheu tratar a mesma pessoa com dois partidos numa "mudança separada logo depois, junto com a causa dos dados parados". Depois autorizou olhar a VPS, mudar o cron, recriar as imagens e começar esta análise. Sobre a Atividade ao Vivo, relatou:

> notei que não apareceu live activity para mim mais sobreo assunto do momento

Sobre a Meta, decidiu:

> não preciso de app id da meta nao

**Tamanho:** M, uma fase. Mexe no servidor e no dado publicado, sem esquema novo.

## Domain Concept Identification

**Crítica honesta, com o que foi medido em 03/11/2026, com os dados recém-publicados:**

- **A mesma pessoa com dois partidos:** 259 pessoas. Em 235, é deputado estadual em exercício eleito de novo; o resto são governadores, vices e deputados que mudaram de cargo.
- **Causa:** o cargo em exercício de governador, vice e deputado estadual guarda o partido da candidatura de 2022. O cargo eleito guarda o de 2026. O índice geral prioriza o cargo em exercício, e as listas mostram o eleito. Riedel é PSDB no perfil e PP na lista.
- **Quem não sofre:** deputados federais e senadores não aparecem na lista, porque o cargo deles vem da API da Câmara e do Senado.
- **Retratos novos:** a carga trouxe 6 pessoas a mais. Eliane Leal, Gustavo Rocha, Jessica Sales e Larissa não têm traços e aparecem com o rosto genérico.
- **Carga parada sem ninguém saber:** de 28/10 a 03/11, o `fiscal-sync` falhou a cada 5 minutos, porque a limpeza diária do Docker apagou as imagens. Corrigido no cron e no deploy em 03/11, com o ok do usuário. Faltam o registro no runbook e um alerta.
- **Atividade ao Vivo:** o aviso de destaque só abre com peso 85 ou mais. Na publicação de hoje, os pesos são 75, 73, 72 e 58. Mesmo com os dados de volta, nenhum atinge o limite. Há também registros de token recusados com erro 401, sem causa conhecida.
- **App ID da Meta:** continua no backlog como P1, e o usuário não quer criar. Os Stories seguem pela folha do sistema.

| Conceito | Hoje | O que muda |
| --- | --- | --- |
| **Partido no cargo em exercício** | O da candidatura de 2022 | O da candidatura mais recente, quando a fonte do cargo é o TSE |
| **Histórico de candidaturas** | Partido de cada eleição | Igual: 2022 continua PSDB no histórico |
| **Quem não tem traços** | Rosto genérico | Traços descritos a partir da foto oficial, e o script avisando na carga |
| **Falha da carga** | Só no log | Aviso ao usuário depois de falhas seguidas |

## Strategic Approach

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Como avisar da falha da carga | pergunta | **Recomendado: notificação no celular por um tópico privado do ntfy**, depois de 6 falhas seguidas (30 minutos). Não leva dado de ninguém, e é simples de manter |
| Limite da Atividade ao Vivo | pergunta | **Recomendado: medir antes** quantos destaques passariam de 70, 75 e 85 nos últimos 30 dias e decidir com o número. Mudar o limite muda quantas notificações as pessoas recebem |
| Partido mais recente | veto | Vale só onde a fonte do cargo é o TSE. Câmara e Senado continuam com o partido atual da API |
| Histórico intacto | veto | O partido de cada candidatura não muda; só o cargo em exercício |
| Só fatos | veto | Mostra o partido que a fonte traz, com a fonte e a data. Nada de inferir filiação fora do TSE |
| Traços novos | veto | Descritos a partir da foto oficial, como os outros, sem IA gerando imagem |
| Deploy e publicação | veto | Cada um com o ok do usuário, pedido na hora |
| Comparar a carga antes de publicar | reversível | Rodar localmente com a fixture e listar quantas pessoas mudam de partido |
| Causa dos 401 | reversível | Investigar nos testes do aviso; se pedir mudança grande, vira item próprio |
| Runbook | reversível | Registrar o caso das imagens, o filtro do cron e como conferir |

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Candidatura de 2026 não vencedora muda o partido de quem está no cargo | O partido atual fica certo, mas a página mostra o partido da última eleição disputada | É o dado mais recente do TSE; declarar a fonte e testar o caso |
| Mudança de partido depois da candidatura | O dado fica velho até a próxima fonte | Declarado na fonte; sem inferência |
| Deputado estadual com fonte própria da assembleia | Pode haver partido mais novo na assembleia | Conferir `link.go` e dar prioridade à assembleia quando ela publicar |
| O ntfy cair ou o tópico vazar | Sem aviso, ou aviso para outra pessoa | Tópico com nome longo, em `secrets/`, e nenhuma informação pessoal na mensagem |
| Alerta repetido | Barulho | Um aviso ao entrar em falha e um ao voltar |
| Baixar o limite do destaque | Mais notificações para todos | Decisão com o número na mão |

**Critérios de aceite (para o canvas):**

| Cenário | Prova |
| --- | --- |
| Riedel com o mesmo partido no perfil e nas listas | Teste no servidor e dado publicado |
| Histórico de 2022 continua PSDB | Teste no servidor |
| Deputado federal segue com o partido da Câmara | Teste no servidor |
| Número de pessoas com dois partidos cai a zero, ou a uma lista explicada | Script sobre o dado publicado |
| As 4 pessoas novas aparecem desenhadas | `portrait-check --published` |
| Seis falhas seguidas geram um aviso, e a volta gera outro | Teste do script e um disparo real, com o ok do usuário |
| Runbook e backlog atualizados, sem o App ID da Meta | Leitura |

**Fora de escopo:** curtir e compartilhar no Feed, sugestões e algoritmo do Feed (mudanças próprias), Web e publicação do site.
