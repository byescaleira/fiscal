# 0027. Curtir é privado e fica só no aparelho

- **Estado:** Aceito (2026-11-06)
- **Data:** 2026-11-06
- **Mudança:** [FSC-024](../../spdd/prompt/FSC-024-202611061418-[Feat]-feed-like-with-ripple.md)

## Contexto

O usuário pediu o curtir com a onda escolhida na FSC-023. Curtir uma votação, uma proposta ou um gasto pode ser lido como opinião política, que é dado sensível pela LGPD (art. 5º, II, e art. 11). O "Meu apoio" já fica só no aparelho pelo mesmo motivo ([ADR 0021](0021-end-of-lens-support-on-device.md)). O Fiscal mostra fatos, e um número de curtidas numa votação seria lido como aprovação pública. Em 06/11/2026, o usuário escolheu o curtir privado, sem contagem, só no aparelho e com a lista "Curtidas" no Feed.

## Decisão

1. **O curtir é uma marca privada.** O app nunca mostra quantas pessoas curtiram, e nenhum número de curtidas existe fora do aparelho.
2. **As curtidas ficam em `Device.store`,** sem CloudKit e fora do backup, como o apoio. A `FiscalSchemaV5` acrescenta a entidade numa migração leve.
3. **As curtidas nunca saem do aparelho para:**
   - servidor;
   - telemetria;
   - notificação;
   - Spotlight;
   - widget;
   - Siri;
   - cartaz de compartilhar.

   Só saem na exportação de dados pedida pela pessoa.
4. **Curtir não muda nada no app.** Não muda a ordem, o filtro, o destaque, as sugestões nem o que o Fiscal mostra a outra pessoa.
5. **A onda vai numa camada de fundo** que aparece só durante a animação. Ela nunca envolve o texto, os números ou o retrato da linha ([ADR 0026](0026-shader-effects-never-carry-data.md), regra 3).

## Consequências

- O curtir não aparece nos outros aparelhos da pessoa e some ao trocar de iPhone sem exportar.
- O rótulo de privacidade da App Store não muda.
- Uma contagem pública no futuro pede um ADR novo, servidor e revisão de segurança.

## Alternativas consideradas

- **Contagem pública:** pede servidor, identificador, proteção contra fraude e moderação, e guarda opinião política fora do aparelho.
- **iCloud privado, como o seguir:** daria o curtir em todos os aparelhos, mas leva a opinião política para fora do aparelho.
- **"Salvar" no lugar de "Curtir":** tira o tom de aprovação, mas não é o que o usuário pediu.
