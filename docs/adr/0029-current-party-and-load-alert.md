# 0029. O cargo em exercício usa o partido mais recente, e a carga avisa quando falha

- **Estado:** Aceito
- **Data:** 2026-11-03
- **Mudança:** [FSC-017](../../spdd/prompt/FSC-017-202611031133-[Feat]-current-party-and-load-alert.md)

## Contexto

A mesma pessoa aparecia com dois partidos em 259 casos, porque o cargo em exercício de governador, vice e deputado estadual guarda o partido da candidatura de 2022. E a carga ficou 6 dias parada sem ninguém saber, porque a limpeza diária do Docker apagou as imagens.

## Decisão

1. Quando o cargo em exercício vem do TSE, o partido dele é o da candidatura mais recente da pessoa. Cargo que vem da Câmara ou do Senado mantém o partido da API.
2. O histórico de candidaturas não muda: cada eleição mantém o seu partido.
3. As imagens do Fiscal têm o rótulo `fiscal.sha`, e a limpeza do Docker não as apaga.
4. Depois de cada execução, um script conta as falhas seguidas e a idade dos dados. Com 6 falhas ou dados com mais de 48 horas, avisa uma vez por um tópico privado do ntfy, e avisa de novo quando volta.

## Consequências

- Quem trocou de partido e disputou de novo aparece com o partido novo em todas as telas.
- Quem trocou de partido e não disputou continua com o da última candidatura, até uma fonte mais nova.
- Entra um serviço de terceiro, o ntfy. A mensagem não leva dado de ninguém, e o tópico fica em `secrets/`.

## Alternativas consideradas

- **Mostrar os dois partidos, por mandato:** mais exato para o passado, mas é o que confundia, e o usuário quer uma resposta só.
- **E-mail ou só o painel:** o e-mail passa despercebido, e o painel não teria evitado os 6 dias parados. O usuário escolheu a notificação.
