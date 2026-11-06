# Metal no Fiscal

## Original Requirement

Pedido do usuário em 05/11/2026, ao rever a tela Dinheiro:

> Não sei se tem mais coisa que podemos fazer com o metal, acho que não estamos explorando bem isso!

Depois, sobre a recomendação de uma exploração própria com pesquisa e protótipos lado a lado no iPhone:

> pode seguir com o que você recomenda

**Tamanho:** exploração (pesquisa, protótipos e escolha), sem mudança de comportamento no app de quem usa. O que o usuário escolher vira uma ou mais mudanças M com canvas próprio. O mapa da arrecadação continua na `FSC-021` (Dinheiro e Região) e só aparece aqui como referência.

**Pesquisa:** [Efeitos de shader do SwiftUI no Fiscal](../../docs/research/2026-11-05-swiftui-shaders.md) (05/11/2026, profundidade completa, 4 ângulos).

## Domain Concept Identification

**Crítica honesta do que existe hoje (05/11/2026):**
- **Nenhum shader no projeto.** Nem o Fiscal nem o `byescaleira-kit` 0.9.0 têm um arquivo `.metal`, um `ShaderLibrary` ou um `colorEffect`, `layerEffect` ou `distortionEffect`. Todo o movimento vem de Lottie (`scripts/animations.py`), `symbolEffect`, `CelebrationBurst` e `CelebrationConfetti`.
- **A regra de energia já existe e vale para tudo.** `MotionBudget.isConstrained` (Modo Pouca Energia ou aparelho quente) e `@ReducesMotion` (Reduzir movimento ou o modo leve) param retratos, selo do partido e animações em loop. Um shader novo entra nessa mesma regra, sem uma segunda.
- **O dado mais forte do app não tem forma própria.** Uma votação nominal é mostrada como `TallyBar` e números. A barra é exata, mas não mostra que são 513 pessoas, nem a linha de quantos votos eram precisos, que é o que decide se passou.
- **Os cartazes de compartilhar são lisos.** O fundo é cor chapada ou arte do acervo; a pesquisa de cartazes (`2026-11-01-share-card-references.md`) já apontava textura e luz como o que faz um cartaz parecer impresso.
- **Curtir ainda não existe.** O Feed lista votações, checagens e destaques sem nenhuma reação; a mudança de curtir e compartilhar ainda vai ser feita.

| Conceito | O que é | Regra que não muda |
| --- | --- | --- |
| **Efeito** | Movimento, luz ou textura desenhados por um shader | Nunca representa um número que não existe, nunca muda a ordem, a cor ou o tamanho de um dado |
| **Shader** | Função Metal `[[stitchable]]` chamada por `colorEffect`, `layerEffect` ou `distortionEffect` | Roda só enquanto anima (`isEnabled`), compilado antes do primeiro uso (`compile()`) |
| **Plenário** | Um ponto por parlamentar (513 na Câmara, 81 no Senado), agrupados pelo voto | Cada ponto é uma pessoa; a contagem bate com o dado oficial; a linha marca o quórum que a regra da votação pede |
| **Textura de papel** | Grão, fibra e luz no fundo de um cartaz | Só no fundo: o texto e os números ficam fora do efeito |
| **Brilho** | Faixa de luz que segue a inclinação do iPhone | Igual para todo político, partido e lado; não sinaliza valor |
| **Degradação** | O que o efeito vira com Reduzir movimento, Pouca Energia ou aparelho quente | O efeito para, o dado continua inteiro e o VoiceOver lê os números |

**Os 7 usos levantados, com a leitura da pesquisa:**

| Uso | Leitura | Vai para protótipo? |
| --- | --- | --- |
| 1. Curtir com onda e partículas | Padrão da Apple (WWDC24), roda só durante a animação | Sim |
| 2. Plenário de pontos | Forma nova e honesta para o dado mais forte; a pesquisa pede Canvas, não shader, no dado | Sim, em shader e em Canvas, lado a lado |
| 3. Mapa por shader | Fica na `FSC-021`; distorcer área ou posição fere a leitura | Não (referência) |
| 4. Papel nos cartazes | Nenhuma fonte confirma que o `ImageRenderer` leva o shader | Sim, com o teste da exportação e a textura pronta como alternativa |
| 5. Brilho pela inclinação | Paralaxe é o caso clássico de Reduzir movimento; custo do sensor | Sim, com a leitura do sensor só na tela e só com o movimento liberado |
| 6. Fluxo do dinheiro em partículas | Quantidade de partículas não se lê com precisão; efeito contínuo | Não |
| 7. Abertura com shader | Decorativo, repetido todo dia, custo de compilação no pior momento | Não |

## Strategic Approach

**Protótipos (só em builds de desenvolvimento):** Ajustes › Desenvolvedor › Metal, em `FeatureSettings/MetalLab/`, todos atrás de `#if DEBUG`. Cada um tem a variante de hoje para comparar, a leitura de Reduzir movimento, Pouca Energia e temperatura, e um medidor de quadros. Dados reais da CDN do Fiscal: a votação `camara-2236186-60` (PLP 281/2019, 14/10/2026: 252 sim, 176 não, 1 outro, 84 não votaram, precisava de 257) e a `senado-7107` (PEC 221/2019: 75 sim, 1 não, 3 outros, precisava de 49).

| Protótipo | O que mostra | Variantes |
| --- | --- | --- |
| **Curtir** | Cartão do Feed com a votação real; toque no coração ou dois toques no cartão | Onda + partículas, só partículas, hoje |
| **Plenário** | Semicírculo com um ponto por parlamentar, sim da esquerda e não da direita contando juntos, e a linha do quórum | Shader, Canvas, hoje (`TallyBar`) |
| **Papel no cartão** | Cartaz da votação com o fundo de papel, ao lado da imagem exportada pelo `ImageRenderer` e a medida do ruído do fundo | Shader, textura pronta, hoje |
| **Brilho na inclinação** | Cartão do político com o retrato e a cor do partido | Brilho branco, holográfico, hoje |

**Como abrir:** Ajustes › Desenvolvedor › Metal, ou abrir o app com `-FiscalMetalLab lab|like|plenary|paper|sheen` (só em DEBUG, para captura e medição).

**O que os protótipos mostraram (simulador iPhone Duo, iOS 27.1, 05/11/2026):**

| Achado | Medida | O que muda na decisão |
| --- | --- | --- |
| **O `ImageRenderer` leva o shader** | Ruído do fundo do cartaz exportado: 4,8 com o shader contra 0,0 no liso; render de 57 a 170 ms por cartaz | O papel pode ser shader também no compartilhar; a textura pronta deixa de ser necessária. A pesquisa não tinha fonte para isso |
| **Shader não passa por cima de Lottie** | O retrato animado (Lottie, view do UIKit) virou o símbolo 🚫 sob o `colorEffect` | Brilho e onda nunca envolvem o retrato animado: o brilho vira uma camada por cima (`blendMode(.screen)`), e a onda só entra em cartões com retrato parado, que é o caso das linhas do Feed (`portraitAnimated` é 72) |
| **Plenário em shader e em Canvas dão o mesmo desenho** | 513 e 81 pontos, sim da esquerda e não da direita contando juntos, linha do quórum em 257 e em 49; 5 testes da disposição | Fica em Canvas, como a pesquisa pede: o dado não depende de cor resolvida no shader (FB21877364) e o ganho do shader não foi medido |
| **Quórum no centro** | Na Câmara, 257 cai na coluna do meio, onde fileiras diferentes têm o mesmo ângulo | A linha passa pela coluna do meio; o número escrito ("257 para aprovar") é o que vale, e o VoiceOver lê a frase inteira |
| **Degradação** | Reduzir movimento, Pouca Energia e temperatura lidos na própria tela; o brilho para o sensor fora da tela | A regra única funciona sem peça nova; falta ligá-la ao `MotionBudget` do kit |

**O que não foi medido:** Instruments no iPhone (o `xctrace` não alcançou o aparelho bloqueado), bateria, aparelho antigo, Mac e visionOS. Cada protótipo tem "Medir quadros" (quadros por segundo e pior quadro) para conferir no iPhone.

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Quais protótipos viram mudança | pergunta | **Escolha do usuário (05/11/2026): plenário, onda do curtir e cartão do político holográfico.** Recomendação de antes, nesta ordem: (1) o plenário em Canvas no detalhe da votação, porque mostra as 513 pessoas e a linha do quórum, que hoje não aparece; (2) o papel nos cartazes de compartilhar, agora que a exportação leva o shader; (3) a onda do curtir, dentro da mudança de curtir e compartilhar. **Não recomendado:** o brilho na inclinação, que é decorativo, liga o sensor e esbarra na regra de que brilho só representa número real |
| O efeito não muda o dado | veto | Cor, brilho e espessura só representam números reais; nenhum efeito muda a ordem, a cor ou o tamanho de um ponto, barra ou número |
| Degradação única | veto | Reduzir movimento, `MotionBudget.isConstrained` e o estado térmico `serious` param o efeito pela regra que já existe, sem segunda regra; o VoiceOver lê os números |
| Shader só enquanto anima | veto | `isEnabled` desligado fora da animação, e `compile()` antes do primeiro uso |
| Dado em Canvas, efeito em shader | reversível | O plenário fica em Canvas (mesmo desenho, sem a dúvida de cor resolvida no shader); o shader fica para textura e onda |
| Peça genérica no kit | veto | Onda, papel e brilho são genéricos e vão para o `byescaleira-kit` num PR de lá (`ByescaleiraDesign`), com o `.metal` no pacote; o plenário é do Fiscal e fica no `FiscalDesignSystem` |
| Medir antes de ampliar | veto | Instruments (SwiftUI, Hitches e Power) no iPhone e num aparelho antigo antes de levar um efeito para mais de uma tela |
| Mac e visionOS | reversível | Mesmo efeito onde o SwiftUI suporta; sem sensor de inclinação no Mac, o brilho fica parado |

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Efeito sugerir valor | Um cartão mais brilhante parece "melhor" | Brilho igual para todos; nada de efeito por partido, lado ou resultado |
| Ordem do plenário lida como espectro | Sim à esquerda parece "esquerda política" | A ordem é de voto, dita no rodapé e no VoiceOver; nenhum partido entra na posição |
| Quórum errado | Linha no lugar errado muda a leitura de "passou ou não" | O número vem da regra da votação (maioria absoluta, 3/5, maioria simples), com a fonte; sem regra conhecida, sem linha |
| Exportação sem o efeito | Cartaz compartilhado diferente da tela | Medido: o `ImageRenderer` leva o `colorEffect`; o teste da exportação entra no canvas para não regredir |
| Bateria e calor em escala | 50 milhões de pessoas, aparelhos de 3 a 6 anos | Nenhum efeito contínuo em tela de dado; medição com Instruments antes de ampliar |
| Shader sobre Lottie | O retrato animado vira 🚫 | Efeito nunca envolve view do UIKit: camada por cima ou retrato parado |
| Primeiro uso engasgar | Compilação do shader no toque | `compile()` na abertura da tela ou do app, medido |
| Cor do shader diferente da view | Relato FB21877364 sobre a mesma cor em view e em shader | Comparar o plenário em shader e em Canvas lado a lado; cor de voto e de partido no Canvas se divergir |
| Sensibilidade a cintilação | Brilho e partículas rápidas | Sem cintilação; tudo para com Reduzir movimento |

**O que não foi verificado:** aparelho antigo (só o iPhone do usuário), Instruments com o Power Profiler, Mac e visionOS, VoiceOver em cada protótipo de ponta a ponta.

**Critérios de aceite (para o canvas, por protótipo escolhido):**

| Cenário | Prova |
| --- | --- |
| O efeito para com Reduzir movimento, Pouca Energia e aparelho quente | Teste do modelo e captura |
| O dado é o mesmo com e sem o efeito | Teste (contagem do plenário) e comparação de capturas |
| O VoiceOver lê os números | Rótulo testado e conferido no iPhone |
| O shader não roda parado | Instruments sem quadros com o efeito fora da animação |
| Cartaz exportado igual à tela | Medida do ruído do fundo na imagem exportada |

**Fora de escopo:** o mapa da arrecadação (`FSC-021`), fluxo do dinheiro em partículas, abertura do app, widgets e Atividade ao Vivo, o site.

## Escolha do usuário

Resposta do usuário em 05/11/2026, depois dos protótipos instalados no iPhone:

> Plenário, Onda do curtir, Cartão do político pode ter o mesmo efeito que tem as cartas de Pokémon raras e holográficas, como se fosse um card colecionável também

| Escolha | O que entra no canvas | Salvaguarda |
| --- | --- | --- |
| **Plenário** | Um ponto por parlamentar no detalhe da votação, em Canvas, com a linha do quórum que a regra da votação pede | Contagem igual ao dado oficial, testada; sem regra de quórum conhecida, sem linha |
| **Onda do curtir** | Onda a partir do toque e partículas no coração, na mudança de curtir e compartilhar | Só durante a animação; nunca sobre retrato animado |
| **Cartão do político holográfico** | O cartão do político como carta colecionável: faixa holográfica que segue a inclinação, como as cartas raras | **Igual para todo político, partido e lado:** nenhuma "raridade" por dado, cargo, resultado ou popularidade; o efeito fica numa camada por cima e nunca envolve o retrato animado; para com Reduzir movimento, Pouca Energia e aparelho quente, e o sensor só liga com a tela à vista |

**Fica de fora:** o papel no cartaz (não escolhido), o mapa por shader (`FSC-021`), o fluxo do dinheiro em partículas e a abertura com shader.

**Decisão do usuário sobre a regra do brilho:** o holográfico entra como acabamento de carta colecionável, não como sinal de valor. Por isso ele é o mesmo em todos os cartões; um brilho que variasse com o político viraria juízo e fica proibido.

**Sigo para o canvas?**
