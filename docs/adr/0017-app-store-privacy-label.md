# 0017. Rótulo de privacidade da loja com os tokens e as chaves guardados no servidor

- **Estado:** Proposto
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/align-workspace/proposal.md)

## Contexto

O brief e a página da loja contavam com o rótulo "Dados não coletados". O app não tem conta, anúncio nem análise de terceiros, e a Lente nunca sai do aparelho. Mas o servidor (`server/`, `fiscal-api`) guarda três coisas que vêm do aparelho:

| O quê | Quando | Por quanto tempo |
| --- | --- | --- |
| Token de push da Atividade ao Vivo da apuração, com a corrida e o ambiente | A pessoa segue uma corrida | Até a corrida acabar ou 12 h (`registrationTTL`); 50.000 no total, 20 por origem |
| Token de push-to-start da Atividade ao Vivo do destaque, com o ambiente | Ligado por padrão em Ajustes › Seus dados e privacidade | 30 dias sem renovação; 200.000 no total, 100 por origem |
| Chave pública do App Attest e o id da chave | Antes do primeiro registro de token | Até 400 dias sem uso (`appattest/service.go`) |

O IP entra só como hash com sal para o limite por origem e não é gravado. Nada disso é ligado a nome, conta ou Lente. A Apple define "coletar" como transmitir dado para fora do aparelho e guardá-lo além do tempo de atender o pedido; tokens e chaves guardados por dias ou meses entram nessa definição, mesmo anônimos.

## Decisão

- Declare no App Store Connect, em App Privacy: **Identificadores › ID do dispositivo**, **não vinculado à pessoa**, **sem rastreamento**, finalidade **Funcionalidade do app**. Nenhuma outra categoria.
- Na política de privacidade do site, liste as três saídas acima com o prazo de cada uma, e diga como desligar o destaque na tela de bloqueio.
- Toda saída nova de dado do aparelho (token, chave, identificador, relatório) muda este ADR, a política e o rótulo antes de ir para a loja.

## Consequências

- O selo "Dados não coletados" deixa de valer; o texto da loja, do site e do brief diz "sem conta, sem anúncio e sem rastreamento", que continua verdade.
- O revisor de segurança confere, a cada mudança no servidor, se os prazos da tabela continuam os do código.
- Se a Apple aceitar tokens de push como dado não coletado, basta um ADR novo que substitua este e a troca do rótulo; o contrário (declarar menos do que guarda) arrisca recusa e quebra a regra de credibilidade.

## Alternativas consideradas

- **"Dados não coletados":** simples e bonito, mas impreciso enquanto o servidor guarda tokens por até 30 dias e chaves por até 400 dias.
- **Encurtar os prazos até caberem em "não coletado":** a chave do App Attest precisa durar enquanto o app estiver instalado, ou cada registro pediria uma atestação nova à Apple.
- **Desligar o destaque por padrão:** reduz quem envia token, mas não muda a categoria do rótulo; fica como decisão de produto separada.
