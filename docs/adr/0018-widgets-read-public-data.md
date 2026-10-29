# 0018. Os widgets leem os dados públicos direto, sem retrato escrito pelo app

- **Estado:** Proposto
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/align-workspace/proposal.md)

## Contexto

O padrão da skill `byescaleira-sdd` (`platform-integrations.md`) manda o widget ler só um retrato (`WidgetSnapshot`) que o app grava no App Group; sem retrato, o widget pede para abrir o app. Isso existe porque nos outros apps o widget mostra dado da pessoa, guardado no banco do app.

No Fiscal, os widgets de Votações, Destaque do momento e Seus representantes mostram só dados públicos: os mesmos arquivos estáticos do CDN que o app baixa ([ADR 0002](0002-static-first-server.md), [ADR 0007](0007-pages-cdn-phased-ingest.md)). Hoje cada provedor de linha do tempo monta um `WidgetFeed` sobre o `PublicDataClient.fromBundle()` e busca os arquivos na hora, com a agenda do `WidgetSchedule` (de hora em hora nas sessões, a cada 30 minutos no destaque, a cada 12 horas nos representantes). Do App Group o widget lê só a UF escolhida (`HomePlace`) e os retratos já baixados (`PortraitShelf`). Nenhum widget abre o SwiftData.

## Decisão

1. Os widgets do Fiscal buscam os dados públicos direto do CDN pelo `WidgetFeed`, sem retrato gravado pelo app.
2. O que vem do App Group é só o que a pessoa escolheu ou o que já foi baixado: a UF (`HomePlace`, `UserDefaults` da suíte `group.com.byescaleira`) e os retratos (`PortraitShelf`). Nada do banco do app.
3. Os widgets nunca abrem o SwiftData nem o CloudKit, e nunca leem dado da pessoa além da UF.
4. A resposta fica no cache HTTP do `PublicDataClient` (`URLCache`, com `ETag`) dentro do processo do widget; sem rede, o estado vira `WidgetState.unavailable(offline: true)` e o widget diz isso e tenta de novo no próximo horário do `WidgetSchedule`.
5. A Live Activity da apuração continua recebendo os números por push, sem buscar nada.

## Consequências

- O widget fica certo mesmo se o app não for aberto há dias: a votação de ontem à noite aparece de manhã sem depender do app em segundo plano.
- O app não precisa gravar retrato a cada carga nem manter um formato de retrato em versão.
- Cada widget faz a própria requisição: mais acessos ao CDN (absorvidos pelo cache estático, sem custo por acesso no servidor) e o orçamento de atualização do WidgetKit vira o limite.
- Os dois processos podem mostrar números de horários diferentes por alguns minutos; a linha de fonte com o horário do arquivo ("arquivo do TSE das …", "atualizado …") deixa isso claro.
- Sem rede e sem cache, o widget mostra o estado sem conexão em vez do último retrato do app.
- A auditoria do plugin e o `.byescaleira-sdd.json` precisam aceitar essa exceção ao padrão `WidgetSnapshot`, citando este ADR.

## Alternativas consideradas

- **Retrato `WidgetSnapshot` gravado pelo app no App Group (padrão da skill):** o widget ficaria parado até a próxima abertura do app ou tarefa em segundo plano, o que não serve para votações e destaques que mudam durante o dia, e duplicaria num formato próprio dados que já são públicos e versionados no CDN.
- **Retrato do app com atualização pelo widget:** dois caminhos de escrita para o mesmo dado e conflito de versão entre app e extensão, sem ganho para quem usa.
- **Cache compartilhado no App Group:** guardar as respostas do CDN num diretório do App Group deixaria app e widget lendo o mesmo arquivo, mas exige coordenação de escrita entre processos; fica para depois, se o orçamento de atualização do WidgetKit ou o consumo de dados mostrarem necessidade.
