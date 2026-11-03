# 0025. O retrato vem do identificador, e os cartões de destaque seguem o modo

- **Estado:** Aceito
- **Data:** 2026-11-02
- **Mudança:** [FSC-016](../../spdd/prompt/FSC-016-202611021923-[Feat]-light-cards-and-portraits.md)

## Contexto

O usuário viu políticos que assumem em 2027 com o rosto genérico, como Eduardo Riedel, e cartões escuros no modo claro, como o placar da votação. Todas as 2.356 pessoas publicadas têm traços, mas o app exigia o mesmo partido nos traços e no dado, e a mesma pessoa aparece com partidos diferentes em 264 casos. E 13 cartões têm fundo escuro fixo.

## Decisão

1. Os traços de uma pessoa são achados só pelo identificador. A roupa e o fundo do retrato usam o partido que o dado traz. Quem não tem traços continua com o rosto neutro.
2. Um script confere se cada identificador aponta para o mesmo nome nos traços: nos dados de teste, em toda verificação completa, e nos dados publicados, no fechamento e depois de uma carga.
3. Os cartões de destaque dentro das telas seguem o modo do aparelho. No claro, superfície clara com a cor suave nas laterais, centro neutro, texto escuro e a cor forte só nos sinais. No escuro, como hoje.
4. Os cartazes de compartilhar, os widgets e a Atividade ao Vivo não mudam.

## Consequências

- Uma troca de partido não apaga mais o rosto de ninguém.
- Um identificador reaproveitado para outra pessoa mostraria o rosto errado se ninguém conferisse; o script existe por isso.
- Um contraste por superfície entra nos testes, com todas as cores de partido.
- O partido divergente entre os arquivos continua visível até uma mudança separada no servidor.

## Alternativas consideradas

- **Atualizar o partido nos traços:** resolve hoje, mas volta a cada troca de partido, e o mesmo dado traz dois partidos para a mesma pessoa.
- **Conferir pelo nome no app:** os traços do app não guardam o nome, e o arquivo cresceria para 8.055 pessoas.
- **Cor viva com texto escuro:** mais marcante, mas o contraste fica difícil com as cores de partido, e o usuário escolheu a superfície clara.
