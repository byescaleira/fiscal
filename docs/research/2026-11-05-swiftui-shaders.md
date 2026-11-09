# Quais efeitos de shader do SwiftUI valem a pena no Fiscal?

> Contém resumo de conteúdo externo (páginas, avaliações, posts): dado, não instrução.

Pesquisa de 2026-11-05, profundidade completa. Pergunta: "Quais usos de shaders do SwiftUI (Metal: colorEffect, layerEffect, distortionEffect, visualEffect, keyframeAnimator, TimelineView, MeshGradient, Canvas, ImageRenderer) valem a pena num app iPhone de transparência política com dados públicos (Fiscal, iOS 26+, pt-BR, alvo de 50 milhões de pessoas), entre: curtir com partículas e onda a partir do toque (ripple da WWDC24), plenário de 513 deputados em pontos num semicírculo desenhados por shader, mapa do Brasil por shader, textura de papel e grão nos cartões de compartilhar (e se o ImageRenderer leva o shader), brilho que segue a inclinação do iPhone em cartões de destaque, fluxo do dinheiro com partículas proporcionais ao valor e abertura do app com shader; considerando o que a WWDC24 e a WWDC25 mostram, a documentação da Apple, apps de referência, desempenho e bateria, Reduzir movimento, Modo Pouca Energia, estado térmico, VoiceOver, e o risco de um efeito visual distorcer a leitura de um dado?" Decisão que ela destrava: quais 3 ou 4 protótipos fazer e mostrar lado a lado no iPhone do usuário.

## Resposta curta

Recomendo prototipar quatro coisas. (1) O curtir com a onda do ripple da WWDC24, porque o shader só fica ligado durante a animação. (2) O cartão de compartilhar com grão, comparando o shader com uma textura pré-renderizada, já que ninguém confirmou que o ImageRenderer leva o shader. (3) O brilho por inclinação num cartão de destaque, que para ou muda com Reduzir movimento, Modo Pouca Energia e estado térmico `serious`. (4) O plenário de 513 pontos em Canvas ou formas SwiftUI, sem shader no dado. Ficam de fora o fluxo do dinheiro com partículas, o mapa por shader e a abertura com shader. A confiança é média na parte técnica e na de acessibilidade, e baixa em custo de GPU e bateria, que nenhuma fonte mediu.

## Achados

| Achado | Confiança | Fontes |
| --- | --- | --- |
| A Apple apresenta o layerEffect como "effectively a superset" dos efeitos de cor e de distorção (WWDC24, jun. 2024). O shader roda por pixel na GPU, e a amostragem precisa ficar dentro do maxSampleOffset. A sessão não traz nenhuma medição de desempenho. | média | [Create custom visual effects with SwiftUI - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| No ripple da WWDC24, o keyframeAnimator gera o tempo decorrido, porque o shader não tem noção de tempo. O código passa `isEnabled: 0 < elapsedTime && elapsedTime < duration`, então o shader fica desligado fora da animação. Dizer que isso tem "custo zero em repouso" é inferência do código: precisa ser medido. | média | [Create custom visual effects with SwiftUI - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| A sessão da WWDC24 não trata de Reduzir movimento nem de VoiceOver, então o tratamento fica por conta do app. A sessão também mostra o MeshGradient (grade de pontos com uma cor por ponto, animável) e apresenta o visualEffect como performático para efeitos ligados à posição na ScrollView. | média | [Create custom visual effects with SwiftUI - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| Na mesma sessão, uma animação por glifo perdeu impacto e foi reduzida ao essencial. A recomendação é testar os efeitos "ao longo do tempo", o que pesa contra uma abertura do app repetida todo dia. | média | [Create custom visual effects with SwiftUI - WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/) |
| Os três tipos: colorEffect muda a cor do pixel, distortionEffect diz de onde amostrar e layerEffect lê a camada e pode amostrar os vizinhos. A ideia de que o colorEffect "basta e é o mais barato" para grão ou pontos é inferência, sem medição. | média | [Compose advanced graphics effects with SwiftUI - WWDC26](https://developer.apple.com/videos/play/wwdc2026/322) |
| A WWDC25 (sessão 306) traz o instrumento SwiftUI no Instruments 26, com as faixas Update Groups, Long View Body Updates, Hangs e Hitches. É a ferramenta para medir cada protótipo. | média | [Optimize SwiftUI performance with Instruments - WWDC25](https://developer.apple.com/videos/play/wwdc2025/306/) |
| No Modo Pouca Energia, o sistema reduz as próprias animações e a Apple pede ao app que pause atividades opcionais, reduza as atualizações de tela e minimize animações, lendo `ProcessInfo.isLowPowerModeEnabled` depois de `NSProcessInfoPowerStateDidChange`. As animações de shader, TimelineView ou Canvas do app continuam sendo responsabilidade do app. | média | [Responding to power notifications](https://developer.apple.com/documentation/xcode/responding-to-power-notifications.md) |
| Orientação da Apple por estado térmico: `nominal` libera tudo, `fair` adia trabalho não imediato, `serious` reduz rede, localização, atualizações de tela e animações, e `critical` reduz ou para todo trabalho. Fazer o shader contínuo cair em `serious` é regra do projeto, não texto da Apple. | média | [Responding to power notifications](https://developer.apple.com/documentation/xcode/responding-to-power-notifications.md) |
| Critérios de Reduzir movimento do App Store Connect: simulação de profundidade (paralaxe, blur animado, profundidade de campo) e movimento em vários eixos, em várias velocidades, com giro ou vórtice devem ser desligados ou trocados. Para movimento contínuo, a página só diz "considere parar" ou oferecer um controle. | média | [Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) |
| Suportar Reduzir movimento não é exigido para publicar. É uma indicação opcional na ficha do app, e o risco é de acessibilidade e reputação. | média | [Reduced Motion evaluation criteria](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria) |
| A documentação de accessibilityReduceMotion diz para evitar animações grandes, sobretudo as que simulam a terceira dimensão, e para tratar à mão as animações personalizadas (não conferida). | baixa | [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion) |
| colorEffect, distortionEffect e layerEffect chegaram no iOS 17, e as funções Metal precisam de `[[stitchable]]`. Desde o iOS 18, chamar `compile()` prepara o shader e evita o engasgo no primeiro uso. | média | [How to add Metal shaders to SwiftUI views using layer effects](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-metal-shaders-to-swiftui-views-using-layer-effects) |
| Num iPhone 13, uma animação de tela cheia em Canvas teve energia "Very High", GPU alta e estado térmico "Serious". É o relato de uma pessoa, de maio de 2024, sem resposta da Apple (não conferida). | baixa | [SwiftUI full screen animation uses less energy than Metal Game template](https://developer.apple.com/forums/thread/756273) |
| Nenhuma fonte trouxe medição de bateria ou energia dos modificadores de shader, e as alegações de eficiência são genéricas. Um maxSampleOffset maior aumenta a área renderizada (não conferida). | baixa | [SwiftUI Metal shaders effects (Cindori)](https://cindori.com/developer/swiftui-metal-shaders-effects) |
| Guias da comunidade dizem que cada modificador de shader é uma passada de renderização, que empilhar vários multiplica o custo de GPU e que o shader só se justifica para efeito por pixel e animado. | baixa | [SwiftUI Metal Shaders: Creating Custom Visual Effects (Cindori)](https://cindori.com/developer/swiftui-metal-shaders-effects) |
| Escada recomendada por terceiros, não pela Apple: modificador nativo, depois visualEffect, depois Canvas e só então shader. Aplicada ao plenário, favorece Canvas ou formas SwiftUI. | baixa | [genjutsu swiftui-graphics](https://claudepluginhub.com/skills/athevon-genjutsu/swiftui-graphics) |
| Os testes da SwiftShaders (PR de 14/10/2026) registram que o ImageRenderer pode devolver uma imagem anterior quando a view não desenha e que o layerEffect roda num compositing group. Não dá para presumir que o shader sai na imagem (não conferida). | baixa | [Release 2.0.0 (SwiftShaders PR #3)](https://github.com/muhittincamdali/SwiftShaders/pull/3) |
| Segundo a documentação do ImageRenderer, citada no fórum, a imagem só inclui o que o SwiftUI desenha, e views de UIKit ou AppKit viram imagem de substituição. Isso não diz nada sobre os shaders (não conferida). | baixa | [Render a SwiftUI view into an image](https://developer.apple.com/forums/thread/741956) |
| Um wrapper de terceiros afirma que o ImageRenderer executa o shader. É hipótese, sem fonte da Apple. | baixa | [swiftui_native metal.rs](https://docs.rs/swiftui-native/latest/src/swiftui_native/metal.rs.html) |
| Relatos de 2023, talvez já corrigidos: o ImageRenderer deixa em branco o conteúdo de ScrollView e não funciona com views apoiadas em UIKit. | baixa | [ImageRenderer fails to render contents of ScrollViews](https://developer.apple.com/forums/thread/725196) |
| Num relato de 2024, o colorEffect ignorou o alfa no modo escuro. O contorno é pré-multiplicar o RGB pelo alfa. | baixa | [Bug: SwiftUI Metal shader doesn't respect alpha value in Dark Mode](https://developer.apple.com/forums/thread/742623) |
| A mesma cor pode sair diferente na view e como argumento do shader (FB21877364). Isso pesa para as cores de partido. | baixa | [Same Color in View and colorEffect shader argument produce different results](https://developer.apple.com/forums/thread/814762) |
| Um colorEffect numa Image grande saiu corrompido depois de girar o aparelho (2025). | baixa | [SwiftUI glitch with coloreffect shader & orientation change](https://developer.apple.com/forums/thread/771623) |
| Segundo um guia de terceiros, o MeshGradient roda na GPU, e mudar a estrutura da grade obriga a montar um novo pipeline. | baixa | [SwiftUI MeshGradient Guide (iOS 26)](https://swiftcrafted.dev/article/swiftui-meshgradient-animated-gradients-ios-26) |
| Prática num repositório (PR mesclada em 13/09/2026): com Reduzir movimento, Modo Pouca Energia ou pressão térmica, a animação fica parada ou cai para 30 fps, e os indicadores vão a 20 fps. A queda de cerca de 60% nos despertares é estimativa do autor. | baixa | [Honour Reduce Motion, Low Power Mode and thermal pressure in animations - PR #398](https://github.com/uttrflow/uttrflow-swift/pull/398) |
| Receita de uma biblioteca para Reduzir movimento: pausar a timeline e desligar o layerEffect, congelar os efeitos no primeiro quadro e fazer o ripple ignorar o toque. | baixa | [SwiftShaders](https://github.com/muhittincamdali/SwiftShaders) |
| Fluidez no simulador não substitui o teste de GPU real, térmica, ProMotion e Modo Pouca Energia no aparelho. | baixa | [feat: reduce animations in Low Power Mode - PR #688](https://github.com/driceroland/Search/pull/688) |
| O movimento nunca deve ser a única forma de passar uma informação (não conferida). | baixa | [Reducing Motion of Animations (Use Your Loaf)](https://useyourloaf.com/blog/reducing-motion-of-animations/) |
| Dataviz: 3D e perspectiva são o caso mais claro de distorção (uma coluna de 500 pode parecer alinhada a 400), e decoração vale só se ajuda a ler (não conferida, fonte secundária). | baixa | [10 Examples of Bad Data Visualization to Avoid in 2025](https://querio.ai/blogs/examples-of-bad-data-visualization) |
| Chart junk: a regra prática é manter o elemento só se tirá-lo custa informação, e a Kosara admite o "junk útil" como anotação (não conferida). | baixa | [Navigating Data Visualization: A Guide to Chart Junk Awareness](https://www.thedataschool.co.uk/calvin-gao/navigating-data-visualization-a-guide-to-chart-junk-awareness) |
| A Apple descreve "Dim flashing lights" no Mac, que escurece conteúdo piscante. Brilho e partículas com cintilação rápida são risco para quem tem sensibilidade. | média | [Stop or reduce onscreen motion on Mac](https://support.apple.com/en-in/guide/mac-help/stop-or-reduce-onscreen-motion-mchlc03f57a1/14.0/mac) |
| Na Ouvidoria da Câmara (2025), cerca de 16% das reclamações tratam do portal: links quebrados, falta de informação e acesso. A queixa registrada é de acesso e clareza. | média | [Relatório anual 2025 da Ouvidoria da Câmara dos Deputados](https://www2.camara.leg.br/a-camara/estruturaadm/ouvidoria/arquivos/relatorio-anual-2025) |
| O iPhone 16 foi o celular mais vendido de 2025, com 243 milhões de iPhones enviados, segundo a Counterpoint. Não há recorte da base instalada no Brasil. | média | [iPhone 16 foi o celular mais vendido de 2025 (Canaltech)](https://canaltech.com.br/smartphone/iphone-16-foi-o-celular-mais-vendido-de-2025-apple-e-samsung-dominam/) |
| Cerca de 60% de 370 votantes num fórum usavam Reduzir movimento (2014). A amostra é auto-selecionada e antiga. | baixa | [do you reduce motion or not (MacRumors)](https://forums.macrumors.com/threads/do-you-reduce-motion-or-not.1684619/) |
| No Hacker News, o nicho de shaders SwiftUI está ativo mas pequeno (Metal.graphics em 2025-08-28 e MetalGraph em 2026-01-30, com 1 a 2 pontos), e ninguém discute bateria ou produto. | baixa | [Hacker News Search: SwiftUI Metal shader](https://hn.algolia.com/api/v1/search?query=SwiftUI%20Metal%20shader&tags=story) |

## Referências do mercado

| Produto | O que faz bem | O que trazer |
| --- | --- | --- |
| Exemplo "Creating visual effects with SwiftUI" da Apple, da [WWDC24](https://developer.apple.com/videos/play/wwdc2024/10151/) | Ripple com layerEffect e keyframeAnimator, com o shader desligado fora da animação | A base do protótipo de curtir (o código não foi aberto) |
| [twostraws/Inferno](https://github.com/twostraws/Inferno) | Coleção aberta de shaders Metal para SwiftUI | O ponto de partida para o grão e o brilho (só apareceu na busca) |
| [SwiftShaders](https://github.com/muhittincamdali/SwiftShaders) | Testes com ImageRenderer e receita de Reduzir movimento | O roteiro do teste de exportação do cartão |
| [MetalRipples](https://swiftandcurious.com/2025/05/01/metalripples/) | Variações do ripple | Alternativas de onda (não foi aberto) |
| [Sparkling shiny things with Metal and SwiftUI](https://uvolchyk.me/blog/sparkling-shiny-things-with-metal-and-swiftui) | Brilho com shader | A base do brilho por inclinação (não foi aberto) |
| ColorfulX | Mesh gradient animado com modo de economia, segundo o autor | Nada por ora: a alegação não foi verificada |
| Metal.graphics e MetalGraph | Curso e editor de nós para shaders SwiftUI | Prototipar rápido, se for útil |
| Apple Wallet, Weather, Stocks, Fitness, Robinhood, Revolut, NYT, FT, Bloomberg | Não verificado | Nenhuma afirmação: nada foi aberto |

## O que trazer para o produto

1. **Curtir com onda a partir do toque:** a Apple mostra o padrão, e o `isEnabled` desliga o shader fora da animação. Chamar `compile()` no começo evita o engasgo no primeiro toque. Com Reduzir movimento, a onda vira estado estático (ícone cheio e haptic).
2. **Grão no cartão de compartilhar, em duas versões:** shader e textura pré-renderizada (Canvas ou asset), exportando as duas com o ImageRenderer e comparando com a tela. Nenhuma fonte primária confirma que o shader sai na imagem, e há relatos de imagem antiga e de problemas com ScrollView. Monte o cartão fora de ScrollView e teste em claro e escuro, por causa do bug do alfa.
3. **Brilho por inclinação num cartão de destaque, com degraus:** os critérios de Reduzir movimento tratam a paralaxe como algo a desligar ou trocar. O Modo Pouca Energia e o estado térmico `serious` pedem menos animação. Sem cintilação rápida.
4. **Plenário de 513 pontos em Canvas ou formas SwiftUI, sem shader no dado:** cada ponto precisa ser exato e contável, e o efeito não pode mudar o tamanho, a cor ou a posição. Os guias sobem para shader só no efeito por pixel e animado, e as cores de partido podem sair diferentes no shader (FB21877364). Os rótulos do VoiceOver levam os números.
5. **Uma regra única de degradação para todo efeito:** ler Reduzir movimento, `isLowPowerModeEnabled` e `thermalState` em um só lugar, seguindo a orientação de energia da Apple e a prática da PR #398.
6. **Medir cada protótipo no iPhone e num aparelho antigo:** com o instrumento SwiftUI do Instruments 26 e GPU/Energy, porque nenhuma fonte mediu o custo dos shaders, e o único relato real (Canvas no iPhone 13) chegou a "Serious".

## O que não trazer

- **Fluxo do dinheiro com partículas proporcionais ao valor:** a quantidade de partículas não se lê com precisão e induz erro. É um efeito contínuo, de custo térmico desconhecido, e o valor já precisa estar em número e texto.
- **Mapa do Brasil por shader:** distorção de área ou posição fere a leitura, não há referência de mapa feito assim, e Canvas ou formas atendem.
- **Abertura do app com shader:** a própria Apple viu um efeito perder impacto com a repetição, é decorativo (deve parar com Reduzir movimento) e o primeiro uso tem custo de compilação. A queixa do público é de acesso e clareza, não de falta de efeito.
- **Shader empilhado ou contínuo em telas de dado:** cada passada soma custo de GPU, e não há medição que garanta bateria em aparelho de 3 a 6 anos.

## Contradições e incertezas

- **A sessão 322 da WWDC26 foi refutada em parte:** o vídeo usa layerEffect (não "layerEffect de distorção") com TimelineView. A data não foi confirmada, e "sem orientação oficial de desempenho e acessibilidade" é amplo demais, porque existem a documentação de energia e a de Reduzir movimento.
- **Partículas, brilho e abertura nos critérios da Apple:** estender os critérios de Reduzir movimento a esses três efeitos foi refutado, porque a página não os cita. E "parar a animação decorativa" é recomendação ("considere"), não regra.
- **ImageRenderer com shader:** há só a alegação de um wrapper de terceiros contra testes que pedem cautela. Resolve exportando o cartão no aparelho.
- **Custo em repouso do ripple:** o "custo zero" vem do código, não de medição. Resolve com o Instruments.
- **Página da documentação do Shader:** a fetch veio vazia, e o resumo de que o layerEffect seria mais caro e de usar o Metal System Trace saiu do modelo. Não entrou como achado.
- **Achados decisivos não conferidos:** o relato de energia do Canvas, o comportamento da SwiftShaders e os critérios de dataviz.

## O que não foi pesquisado

- **Apps de referência:** Apple Wallet, Weather, Stocks, Fitness, Robinhood, Revolut, NYT, FT e Bloomberg não foram abertos, nem os apps nem as lojas.
- **WWDC25 sobre shaders:** só a sessão 306 (Instruments) entrou. Uma alegação de "até 40% menos GPU" de um post sem fonte foi descartada.
- **Medições:** nenhuma de bateria, fps ou GPU de shaders, MeshGradient ou TimelineView em aparelho antigo.
- **Páginas da Apple que vieram só com o título:** documentação de Shader e de ImageRenderer e o HIG de Motion.
- **VoiceOver:** nada sobre views com shader especificamente.
- **Público brasileiro:** nenhum dado sobre a geração dos iPhones em uso, nem pesquisa representativa sobre Reduzir movimento ou Modo Pouca Energia.
- **Fontes de público:** avaliações da App Store do app da Câmara e queixas no Hacker News sobre animações.
- **Lei e App Store:** nenhuma regra brasileira (LGPD, Lei Brasileira de Inclusão, eleitoral) nem da revisão da App Store que limite shaders.
- **Dataviz:** as fontes primárias (Tufte, Few, Kosara) não foram lidas.
- **Datas:** as de fórum e de comunidade são aproximadas, e as páginas da Apple trazem só o copyright de 2026.
- **Instruções embutidas:** nenhuma página trazia pedido tipo instrução.