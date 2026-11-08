# 0028. O app só lê a CDN, e os alertas de destaque são locais

- **Estado:** Aceito
- **Data:** 2026-11-05
- **Mudança:** [FSC-020](../../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)

## Contexto

O destaque saía por push da VPS, com um código por aparelho guardado no servidor. A estimativa de 03/11/2026 no backlog diz que 50 milhões de aparelhos levariam dias para receber um envio, e a lista não cabe na VPS. O usuário pediu para disparar no iPhone, uma vez por dia, com um horário para a Atividade ao Vivo e outro para uma notificação. Depois pediu para tirar toda chamada direta do app à VPS, que passa a só alimentar a CDN, porque a próxima eleição ainda demora.

Medido em 04/11/2026: o iOS aceita agendar uma Atividade com o app em primeiro plano, recusa em segundo plano (`visibility`) e recusou depois de 5 agendadas no iPhone (`targetMaximumExceeded`). Atualizar uma pendente não teve efeito. No simulador, ela apareceu a até cerca de 40 s do horário, com o app fechado e a tela bloqueada. Nada disso mede uso real, porque o app ainda não saiu.

## Decisão

1. A cada abertura, o app lê os destaques na CDN e agenda só o próximo horário da Atividade e o da notificação. Cada um sai no horário que o aparelho aprende pelo hábito de abertura do app, guardado só no aparelho; com 08:00 e 19:00, no relógio do aparelho, só sem histórico. Soma-se um atraso fixo por aparelho de até 10 minutos. O usuário escolheu o hábito em 2026-11-05 ("Pelo hábito da pessoa"), e nenhum texto do app cita a hora.
2. A Atividade leva o destaque de maior peso que ainda vale no horário dela. A notificação leva o seguinte; com um só destaque, não sai notificação. Com as Atividades desligadas, a notificação leva o primeiro.
3. A notificação tem interruptor próprio, desligado por padrão, e a pergunta do iOS só aparece quando a pessoa o liga. Isso encerra a regra "só por Atividades ao Vivo, nunca por notificação comum" da `FSC-007`, só para esta notificação.
4. Abrir o app não inicia mais a Atividade na hora.
5. O app só conhece `FiscalDataURL`. Saem do app a leitura de reserva na VPS, o registro, o App Attest e a Atividade da disputa; a apuração continua nas telas, pela CDN. A Atividade da disputa volta pelo git quando a próxima eleição se aproximar.
6. A escolha só usa peso, data e o que já apareceu no aparelho; nada sobre quem a pessoa segue ou apoia.
7. A VPS só alimenta a CDN: ficam a carga, a leitura do TSE sem rota pública e a publicação no Pages. Saem o APNs, o App Attest, as rotas e os arquivos de registro.
8. Sem código de aparelho no servidor, o rótulo proposto na loja é "Dados não coletados", no lugar do [ADR 0017](0017-app-store-privacy-label.md).

## Consequências

- A VPS deixa de receber o app, e nenhum código de aparelho fica no servidor.
- Se a CDN cair, não há reserva: o app usa o cache e o pacote offline, e depois mostra o erro.
- Até a próxima eleição, a apuração não aparece na tela de bloqueio.
- Quem não abre o app para de receber a partir do próximo horário sem plano.
- A Atividade fica congelada desde a última abertura, e o conteúdo pode ter até um dia.
- Não há mais alerta urgente de destaque com o app fechado.
- Os toques nos alertas podem chegar juntos à CDN; o atraso reduz esse pico, numa estimativa sem medição.

## Alternativas consideradas

- **Manter a VPS como reserva da leitura:** é o que o usuário pediu para tirar, e ela não aguentaria todo o tráfego se a CDN caísse (estimativa).
- **Manter o push com um envio a cada 8 horas:** continua dependendo de um código por aparelho e de uma lista que não escala.
- **Canal de broadcast da Apple:** o canal atualiza uma Atividade já iniciada, mas o início segue exigindo código por aparelho.
- **Agendar vários dias:** o conteúdo envelhece, e o limite medido é de 5.
- **Notificação como pergunta na primeira abertura:** alcança mais gente, mas chega antes de a pessoa conhecer o app. O usuário escolheu só ao ligar o interruptor.
