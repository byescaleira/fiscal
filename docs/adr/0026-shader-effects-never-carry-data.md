# 0026. Efeito de shader nunca carrega dado

- **Estado:** Aceito
- **Data:** 2026-11-05
- **Mudança:** [FSC-023](../../spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)

## Contexto

O usuário pediu para explorar melhor o Metal. A pesquisa de 05/11/2026 ([relatório](../research/2026-11-05-swiftui-shaders.md)) e quatro protótipos no iPhone mostraram três coisas. O `ImageRenderer` leva o shader para a imagem exportada. Um shader não passa por cima de uma view do UIKit, como o retrato animado em Lottie, que vira o símbolo 🚫. E nenhuma fonte mediu o custo de GPU e de bateria dos shaders do SwiftUI. O usuário escolheu o plenário em pontos, a onda do curtir e o cartão do político holográfico, como uma carta colecionável.

## Decisão

1. **O dado é desenhado em Canvas ou em formas do SwiftUI, nunca em shader.** O plenário usa `Canvas`, com um ponto por parlamentar. A cor, a ordem e o tamanho de cada ponto vêm só do voto.
2. **Shader só para efeito decorativo, e igual para todos.** Holográfico e onda têm os mesmos parâmetros para todo político, partido, lado e resultado. Nenhum efeito varia com um dado, e nenhuma "raridade" é dada por cargo, resultado ou popularidade.
3. **O efeito fica fora do conteúdo.** O efeito entra como camada de fundo ou por cima, nunca envolvendo texto, número ou retrato animado.
4. **Uma regra de degradação.** Com Reduzir movimento ou o modo leve do kit (`LiteMode.reducesMotion`: Pouca Energia, aparelho quente ou a escolha da pessoa), o efeito fica parado e o sensor de movimento não liga. O VoiceOver lê os números de qualquer jeito.
5. **O shader só roda quando precisa.** Com `isEnabled` desligado fora da animação, o sensor ligado só com a tela à vista e o shader compilado antes do primeiro uso.
6. **A peça genérica vai para o kit.** Holográfico, onda e leitura da inclinação ficam num módulo `ByescaleiraEffects` do `byescaleira-kit`, com canvas próprio lá. O plenário é do Fiscal e fica no `FiscalDesignSystem`.

## Consequências

- Um efeito novo passa pelas seis regras acima antes de entrar no canvas.
- O app ganha um arquivo `.metal` pela dependência do kit. O Fiscal em si não tem shader.
- Os cartões com retrato animado só recebem efeito em camada, nunca um `layerEffect` em volta.
- A bateria e os quadros por segundo são medidos no iPhone antes de levar um efeito para outra tela.

## Alternativas consideradas

- **Plenário em shader:** dá o mesmo desenho, mas a cor resolvida no shader pode sair diferente da view (FB21877364), e o ganho não foi medido.
- **Holográfico que muda com o político:** parece um cartão "mais raro" para alguns e vira juízo de valor. Fica proibido.
- **Shaders no Fiscal:** mais rápido hoje, mas a regra do workspace manda a peça genérica para o kit.
- **Papel nos cartazes:** funciona na exportação, mas o usuário não escolheu.
