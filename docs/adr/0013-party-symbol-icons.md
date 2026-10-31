# 0013. Ícones alternativos de partido com símbolos genéricos, atrás de flag

- **Estado:** Aceito
- **Data:** 2026-10-29
- **Mudança:** [`align-workspace`](../changes/archive/2026-10-29-align-workspace/proposal.md)

## Contexto

O usuário pediu, em 2026-10-25, ícones alternativos com as cores de cada partido ([brief](../brief.md), "Ícone do app"). Logotipo, número e mascote de partido são marca registrada (Lei 9.279/1996), e a diretriz 5.2.1 da App Store recusa app que usa propriedade intelectual de terceiros sem autorização. Ícone de partido também pode fazer o app parecer material de campanha, contra a neutralidade do Fiscal. O usuário aceitou o risco da 5.2.1 com as regras abaixo.

## Decisão

- Ofereça 30 ícones de partido (todos os registrados no TSE, em ordem alfabética) em Ajustes › Aparência › Ícone do app, atrás da flag `partyIcons`, **desligada por padrão**.
- Cada ícone usa faixas com as cores do partido (`PartyPalette`) e um símbolo genérico desenhado no estilo do Fiscal (estrela, tucano, chama e afins); partido que só tem letreiro ganha um selo com a sigla.
- Nunca use o logotipo oficial, o número do partido, mão em L, arma, dedos, bandeira ou brasão (Lei 5.700/1971). A mesma regra vale para todos, sem partido em destaque.
- Se a revisão da Apple citar a 5.2.1, mantenha a flag desligada na build enviada e responda que os símbolos são genéricos e desenhados pelo Fiscal; se a recusa continuar, retire os ícones de partido da versão.

## Consequências

- O ícone principal (Amazônia com o Brasil em vidro), os 2 de Amazônia, os 8 de tema e os 6 de fauna não dependem desta decisão.
- A flag `partyIcons` precisa existir no app e no catálogo de flags do admin com o mesmo nome e o mesmo padrão.
- Ícone novo de partido segue o desenho da rodada aprovada (`docs/changes/archive/2026-10-29-app-1.0/icon/`) e passa pelo revisor de design.

## Alternativas consideradas

- **Logotipos oficiais:** marca registrada; recusa certa na 5.2.1 e cara de campanha.
- **Sem ícones de partido:** mais seguro, mas o usuário quis oferecer a escolha com a regra de neutralidade.
- **Ícones ligados por padrão:** expõe todo usuário e a revisão ao risco; a flag permite desligar sem nova versão.
