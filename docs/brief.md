# Brief do Fiscal

- **Data:** 2026-10-25
- **Estado:** proposta para aprovação do usuário
- **Base:** [pesquisa do Politicômetro](research/2026-10-25-pesquisa-politicometro.md) e [API mapeada](research/2026-10-25-api-politicometro.md)

## Em uma frase

O Fiscal mostra o que os seus representantes fazem com o seu voto, a partir do que importa para você, com os mesmos fatos oficiais para todo mundo.

## Problema

- Quem vota não sabe o que o eleito fez depois da posse. A informação existe, mas está espalhada em dez portais oficiais, em linguagem de diário oficial.
- Os apps e sites que tentam resolver isso caem em dois buracos:
  - parecem militância de um lado, e o outro lado para de confiar;
  - viram uma enciclopédia neutra que ninguém abre duas vezes.
- O Brasil está dividido em dois públicos grandes, com prioridades diferentes, e os dois querem fiscalizar. A direita costuma olhar para gasto público, impostos, segurança, corrupção e liberdade. A esquerda costuma olhar para desigualdade, programas sociais, meio ambiente, direitos e serviços públicos. Os dois olham para corrupção, privilégios de político e emendas.

## Meu apoio (decisão do usuário em 2026-11-01; substitui a Lente, [ADR 0021](adr/0021-end-of-lens-support-on-device.md))

- **Sai a Lente:** o app é igual para todo mundo. Nenhuma tela muda de ordem, filtro ou destaque por causa do apoio, e o app abre sem setup nem pergunta política.
- **O que é:** uma página privada, "Meu apoio", com até 5 pessoas de qualquer cargo e até 5 causas, tudo opcional.
- **O que mostra:** uma linha do tempo por data, com filtros de pessoa e de causa: votos, propostas, discursos e destaques, com fonte. Uma votação em que duas pessoas apoiadas votaram diferente é uma linha só, com o voto de cada uma.
- **Causa é assunto, não posição:** o app nunca diz que alguém votou a favor ou contra uma causa, não calcula alinhamento, não dá nota e não compara apoiados.
- **Votações:** a tela da votação continua mostrando "como quem você apoia votou". É fato, e só a pessoa vê.
- **Apoiar e seguir são separados:** seguir é acompanhar qualquer pessoa, e seguidos vão ao iCloud e ao Spotlight. Apoiar não segue, a menos que a pessoa ligue "Também seguir" no editor, com esse aviso; deixar de apoiar não deixa de seguir.
- **Privacidade:** apoio político é dado sensível pela LGPD (art. 5º, II). Fica só no aparelho, num banco separado, fora do iCloud e do backup. Não vai para servidor, telemetria, notificação, Spotlight, widget, Siri nem cartaz. Só sai na exportação que a pessoa pede. "Apagar meu apoio" apaga de verdade, e quem a pessoa segue continua seguido.
- **Notificações não são personalizadas** (decisão do usuário em 2026-10-25): são por feature, iguais para todo mundo, e o apoio nunca vira alerta.
- **Visual:** a cor de destaque e o ícone ficam em Aparência e nunca vêm da cor do partido de alguém, porque isso viraria material de campanha.

## Aparência

O app tem a cara da pessoa; os dados continuam com a cara dos fatos.

- **Paletas:** cada uma tem cor de destaque, fundo dos cards e um par de cores para o compartilhamento. Há paletas inspiradas no imaginário de cada público, sempre em pares espelhados, paletas neutras e paletas tiradas das obras dos artistas parceiros, com crédito. Nenhuma paleta se apresenta como "a neutra", e o verde-amarelo não fica sem contraparte, porque os dois campos disputam essas cores. O posicionamento sugere uma paleta, mas qualquer pessoa pode escolher qualquer uma.
- **Bandeira e brasões:** nunca recoloridos, com inscrição ou usados como produto (Lei 5.700/1971; Lei 9.279/1996, art. 191).
- **Símbolos:** um conjunto de SF Symbols por tema e por estilo, usado nos chips e nos cards. Sem logotipo oficial de partido, que é marca registrada; os ícones de partido usam símbolos genéricos desenhados pelo Fiscal (ver "Ícone do app").
- **Ícone do app** (pedido do usuário em 2026-10-25: "design do ícone seguindo a identidade do projeto"; escolhido por ele no iPhone no mesmo dia, depois de sete rodadas em `docs/changes/archive/2026-10-29-app-1.0/icon/`):
  - **Principal:** a Amazônia ao amanhecer com o mapa do Brasil em vidro por cima. A estrela do template saiu.
  - **Alternativos, em Ajustes › Aparência › Ícone do app:**
    - Amazônia de dia e Amazônia com rio;
    - Temas: um por cor (8);
    - Fauna do Brasil (6);
    - Partidos (30, todos os registrados no TSE, em ordem alfabética), atrás da flag `partyIcons`, desligada por padrão.
  - **Ícones de partido** (decisão do usuário, que aceitou o risco da regra 5.2.1 da App Store sobre propriedade intelectual de terceiros):
    - faixas com as cores do partido e um símbolo genérico desenhado no estilo do Fiscal (estrela, tucano, chama e afins), nunca o logotipo oficial;
    - para partido que só tem letreiro, um selo com a sigla;
    - a mesma regra para todos e nenhum partido em destaque.
  - **Fora dos ícones de partido, continua proibido:** número de partido, mão em L, arma ou dedos, bandeira ou brasão (Lei 5.700/1971).
- **Retratos e marcas animados (pedido do usuário em 2026-10-25):** candidatos e partidos aparecem com imagem desenhada no estilo do Fiscal, em Lottie, nunca com a foto ou a logo oficial:
  - **Retrato de cada político:**
    - montado por um esqueleto de avatar único (rosto, olhos, boca, cabelo, barba, óculos, roupa), com os traços de cada pessoa num arquivo de dados;
    - a foto pública serve só de referência; nada é decalcado nem gerado por IA a partir dela;
    - anima em loop com piscar, respiração, leve giro de cabeça e expressões;
    - a roupa e o fundo usam a cor do partido (`PartyPalette`).
  - **Mesmas regras para todos:**
    - o mesmo esqueleto, as mesmas expressões e o mesmo ritmo para todo mundo, sem depender de quem a pessoa apoia;
    - as expressões são neutras ou simpáticas (piscar, sorriso leve, aceno), sem raiva, choro ou deboche;
    - a expressão nunca muda conforme o dado (gasto, falta, voto);
    - nada de balão de fala nem frase que a pessoa não disse;
    - o nome aparece sempre ao lado, e o retrato é marcado como "Ilustração do Fiscal".
  - **Marca do partido:** um selo próprio com a sigla e as cores do partido, com movimento simples (pulso, onda). A forma da logo (estrela, tucano, número, mascote) não é recriada nem "no nosso estilo": continua sendo a marca registrada do partido e faria o app parecer material de campanha.
  - **Escala:** o retrato vem do identificador da pessoa, com a cor do partido que o dado traz ([ADR 0025](adr/0025-portrait-by-slug-and-hero-cards-follow-the-mode.md)); quem ainda não tem traços cadastrados aparece com um retrato genérico (silhueta, iniciais e cor do partido). A ordem de cadastro é presidente e candidatos, governadores, senadores e deputados.
  - **Publicação:** os retratos saem do servidor como arquivo estático (`v1/avatars/{slug}.json`), para crescer sem atualizar o app.
  - **Nos cards:** o retrato animado vira imagem parada no compartilhamento, com a marca "Ilustração do Fiscal". Nas 72 horas antes e nas 24 horas depois de uma votação, os cards de candidato saem sem retrato (Res. TSE sobre conteúdo sintético; confirmar com a pesquisa jurídica).
- **O que a paleta nunca toca:** gráficos, placares e listas de políticos. Neles a cor marca o partido de cada candidato (`PartyPalette`) ou o dado (sim, não, ausente), e nunca segue a paleta da pessoa. O mesmo gráfico tem a mesma cor para todo mundo.

## Compartilhar com arte

A parte social é o principal canal de crescimento: o Fiscal vira o lugar de onde sai o card bonito e confiável que circula no WhatsApp, no Instagram e no X.

- **Cards prontos** para Stories (9:16), feed (4:5) e mensagem (1:1):
  - como o seu deputado votou;
  - quanto ele gastou;
  - placar da votação;
  - apuração ao vivo;
  - comparação entre políticos;
  - "meus representantes".
- **Cada card traz:**
  - o dado com a fonte oficial e a data;
  - a arte de um artista, com nome e @, e a licença;
  - o QR code ou link para o perfil no app.
- **A arte é escolha do cartaz:** a pessoa escolhe a obra na galeria, em cada cartaz. O dado não muda.
- **Galeria de artistas** dentro do app: quem é cada artista, as obras, a licença e o link para o portfólio. Crédito sempre visível, inclusive na imagem exportada, sem como remover.
- **Sem montagem enganosa:** o card nunca coloca palavra na boca de político e nunca recorta o placar. O dado sai inteiro ou não sai.

### Direitos das obras (vale para tudo)

Crédito não autoriza o uso. A Lei 9.610/98 exige autorização do autor, e a App Store exige que o app tenha os direitos do que mostra. Cada obra só entra no app com uma destas bases:

| Base | Exemplo | O que guardar |
|---|---|---|
| Domínio público | Autor morto há mais de 70 anos (Lei 9.610, art. 41), como Pedro Américo e Victor Meirelles | Data de morte do autor e fonte da imagem (acervo público) |
| Licença aberta compatível | CC BY ou CC BY-SA, conferida arquivo a arquivo; fotos da Câmara só depois de confirmar a licença na página oficial (Agência Brasil e Agência Senado não servem: uso só jornalístico e veto a uso comercial ou político) | Link da licença e versão |
| Autorização por escrito | Licença de uso digital e de redes sociais, com prazo e escopo | Contrato assinado |
| Obra encomendada | Coleção feita para o Fiscal por artistas dos dois lados | Contrato de cessão ou licença |

### De onde vem a arte na 1.0 (decisão do usuário em 2026-10-25)

O usuário quer arte contemporânea, de artistas de agora. A pesquisa de [artistas em alta](research/2026-10-25-contemporary-artists.md) mostrou que nenhum artista atual publica licença aberta nesses temas e que os posts em alta com autor são de um lado só. Por isso a 1.0 usa só o que é livre, sem custo:

1. **Arte própria do Fiscal:**
   - mapas do Brasil e dos estados gerados das malhas do IBGE;
   - composições com as cores dos partidos;
   - os retratos e selos animados em Lottie.
2. **Fotos recentes com licença aberta:** florestas, paisagens e unidades de conservação de cada estado do Wiki Loves Earth Brasil 2026 (CC BY-SA 4.0), conferidas arquivo a arquivo e usadas sem recorte nem cor nova, para não gerar obra derivada.
3. **Acervo histórico** em domínio público: as 20 obras já conferidas, como coleção de reserva.

A encomenda a artistas atuais (3 a 6 nomes equilibrados entre direita, centro e esquerda, com contrato) fica para depois da 1.0, no roadmap.

O manifesto `art-credits.json` vai junto com o app e lista, por obra: autor, @, título, ano, base legal, link da licença e onde a obra pode aparecer. Obra sem linha no manifesto não aparece.

## Públicos

| Público | O que procura | O que o Fiscal entrega primeiro |
|---|---|---|
| Quem se vê à direita | Gasto público, impostos, privilégios, segurança, corrupção, ativismo do STF, liberdade | Cota e salários, emendas, votações de segurança e de tributos, presença |
| Quem se vê à esquerda | Desigualdade, programas sociais, meio ambiente, direitos, saúde e educação públicas | Votações sociais e ambientais, orçamento, financiamento de campanha, bancadas |
| Quem não se define | "O que meu deputado anda fazendo?" | Meus representantes, presença e últimos votos |

## Princípios (herdados da pesquisa, com o que muda)

1. **Mesmo fato para todo mundo.** A mesma ordem, os mesmos filtros e os mesmos textos, com ou sem apoio.
2. **Fonte e data em cada bloco.** "—" quando o dado não existe, nunca 0.
3. **Sem nota nem ranking.** Cada candidato e cada partido têm sempre a mesma cor (a do próprio partido, `PartyPalette`), igual para todo mundo; o apoio e a aparência nunca mudam a cor de um candidato. Decisão do usuário em 2026-10-25, depois de ver a Live Activity.
4. **Linguagem simples.** A ementa oficial vira "o que muda para você", sempre com o texto original a um toque.
5. **Privacidade como recurso.** Sem conta para usar o app; o apoio fica só no aparelho, e seguir pode sincronizar pelo iCloud privado; o iCloud é opcional.
6. **Nativo Apple.** Live Activities, widgets, App Intents com a Siri, Spotlight, Apple Intelligence no aparelho, VoiceOver nos gráficos e layouts para iPad, Mac e visionOS.

## As 5 abas

| # | Aba | Ícone | O que é |
|---|---|---|---|
| 1 | **Feed** | `person.2` | O que aconteceu, por data, com o motivo de cada linha: o que fizeram as pessoas que você segue e o que é relevante, com a apuração ao vivo e o destaque do momento no topo ([ADR 0022](adr/0022-feed-first-tab-and-region.md)). Pelo filtro Seguindo, abre a tela de quem você segue, com as sugestões ([ADR 0024](adr/0024-reveal-bar-following-and-ballots-screens.md)) |
| 2 | **Votações** | `checkmark.square` | O que o Congresso votou, com a próxima sessão numa linha que abre a pauta: o placar por partido e por estado, quem votou como e "o que muda para você". Inclui a Live Activity da votação importante |
| 3 | **Dinheiro** | `brazilianrealsign` | Para onde vai o dinheiro público: cota, salários e benefícios, emendas (inclusive as "emendas Pix"), financiamento de campanha, patrimônio declarado e arrecadação |
| 4 | **Região** | `mappin.and.ellipse` | Os seus representantes pelo lugar (do vereador ao presidente). Cada perfil tem presença, votos, propostas, gastos e patrimônio |
| 5 | **Fiscalizar** (proeminente) | `binoculars` | A busca universal: pessoa, partido, projeto, cidade, CNPJ de fornecedor. Também é a porta para Comparar e Eleições. É a aba com `Tab(role: .search)`, que o iOS 26+ mostra destacada, separada das outras na barra de Liquid Glass |

- **Checagens no perfil** (pedido do usuário em 2026-10-25, no lugar de mostrar posts das redes; piloto só com o Projeto Comprova, decisão do usuário no mesmo dia, depois da [pesquisa de checagens](research/2026-10-25-fact-checks.md)):
  - **Fonte:** o Comprova publica sob CC BY-ND 4.0 (conferido na página de metodologia em 2026-10-25: uso comercial permitido, com crédito, link da licença e sem alterar o conteúdo). A carga lê a API pública do site (`/wp-json/wp/v2/publicacoes`), sem raspar HTML. Lupa, Aos Fatos e a API do Google ficam de fora até haver autorização por escrito.
  - **O que o Comprova checa:** quase sempre conteúdo que circula sobre um político (post, vídeo, montagem), e não o que o político disse. Por isso a seção se chama "O que circulou sobre <nome>" e diz que o veredito vale para o conteúdo checado, não para a pessoa. Nunca "o que ele disse é falso".
  - **Cada item:**
    - o título da checagem como o Comprova escreveu, sem reescrever;
    - o selo da agência como veio (Falso, Enganoso, Comprovado, Sátira, Contextualizando), sem nota nossa;
    - a data e o link;
    - o crédito "Projeto Comprova · CC BY-ND 4.0", com o link da licença.
  - **Associação à pessoa:** só com o nome completo exato (de urna ou civil) no título ou na explicação da checagem, único entre as pessoas do escopo. Homônimo, nome parcial ou mais de uma pessoa possível fica de fora (vai para uma lista interna de revisão, não publicada).
  - **Neutralidade:**
    - todas as checagens da janela, não só as falsas, em ordem de data e com a mesma regra para todos;
    - sem contagem de "mentiras" nem ranking;
    - um aviso de cobertura: a lista mostra só o que a agência escolheu checar, e ausência de checagem não quer dizer nada sobre a pessoa;
  - **Nome:** a seção não usa "Fato ou Fake", que é marca da seção do g1.
- **Ajustes** saem da barra de abas e viram um botão na toolbar do Feed, ao lado do coração de "Meu apoio".
- **Eleições** (apuração ao vivo, resultados e propostas de governo) aparecem no topo do Feed durante o período eleitoral e ficam sempre acessíveis em Fiscalizar.
- **Recomendação de aba proeminente:** usar Fiscalizar porque é o padrão nativo (`role: .search`) e o verbo que dá nome ao app. A alternativa, um "Ao vivo" central, só faz sentido em dia de evento e ficaria vazia no resto do ano.

## Destaque do momento, antes e durante o mandato, e o peso do que cada um faz (pedido do usuário em 2026-10-25)

- **Destaque do momento no topo do Feed, sempre presente:** o assunto, o número de dinheiro ou o dado de maior peso agora. Não precisa ser do dia: "momento" depende do peso e de quanto se fala do assunto. Um exemplo é a alta do preço da gasolina com a série histórica. Quando não houver nada novo, fica o de maior peso recente, e a seção nunca some.
- **Preços e bens de consumo com base histórica:**
  - **Fontes:** gasolina, diesel, etanol e GLP pela ANP, e a cesta e os itens do IPCA pelo IBGE (SIDRA), por UF e no Brasil.
  - **Na tela:** sempre com a série longa.
- **Antes e durante o mandato, para todos:**
  - **Comparação:** para cada político, o mesmo indicador no período antes da posse e durante o mandato, na sua jurisdição (Brasil para presidente e vice; a UF para governador, senador e deputados; o município para prefeito e vereadores, quando houver dado), com a data da posse marcada no gráfico.
  - **Sem causalidade:** o texto diz o que mudou, não que foi por causa do político.
  - **Onde aparece (decisão do usuário em 2026-11-02):** saiu da página do político, porque o componente não se encaixava no app, embora os dados importem. Segue na Investigação, e repensar a forma dele está no [backlog](backlog.md).
- **O que cada político está fazendo e o peso disso:**
  - **O que entra:** projetos apresentados, votos, discursos e cargos, todos com o texto oficial (a ementa, sem resumo opinativo).
  - **Como se calcula o peso:** a repercussão (volume nas redes e na imprensa) somada ao impacto social (alcance da medida, tipo de proposição, tema).
  - **Regra única:** a mesma regra, pública e explicada no app, vale para todos os políticos e temas.
  - **Exemplo do usuário:** um projeto de lei sobre o uso de banheiros por mulheres trans pesa pela repercussão e pelo impacto.
  - **Neutralidade:** o peso ordena e destaca, nunca qualifica (nada de "polêmico", "bom" ou "ruim").
- **Fontes de repercussão:**
  - **Gratuitas e abertas:** volume na imprensa (GDELT), páginas da Wikipédia, Bluesky e YouTube, e o interesse de busca.
  - **Pagas:** X, Instagram e TikTok não têm busca aberta gratuita. Entrar com uma delas é decisão do usuário, porque tem custo.

## Credibilidade: só fatos (pedido do usuário em 2026-10-26)

- **Só fatos:** o app mostra números oficiais e textos oficiais como vieram. Nada de opinião, adjetivo de valor ou causa atribuída.
- **Quando houver estimativa, dizer o motivo:** tudo que não é número oficial (peso das ações, repercussão, explicação gerada) mostra ao lado, em uma linha, por que é estimado e o que ficou sem medir. Exemplo: "Repercussão medida só pela Wikipédia; notícias indisponíveis nesta carga".
- **Sinal ausente não conta como zero:** se uma fonte de repercussão falhar, a fórmula usa só os sinais medidos e avisa quais faltaram.
- **Compartilhar é o motor:** dados bem trabalhados e bem interpretados, em cards bonitos, fazem as pessoas compartilharem. O social e o design são o que atrai.

## Classificar os números (decisão do usuário em 2026-10-26)

- **Por que classificar:** para quem lê, um número solto não diz nada. Cada indicador ganha uma classificação com regra pública, explicada no "Como medimos", e o número continua ao lado.
- **Desempenho comparado aos colegas do mesmo cargo e casa:**
  - **Com direção clara para o cidadão:**
    - **Presença:** mais alta é melhor.
    - **Gasto da cota:** mais baixo é melhor.
    - **Rótulos e cores:** "Melhor que a média" em verde, "Na média" em cinza, "Pior que a média" em vermelho.
    - **Faixas:** pelo quartil da casa.
  - **Sem direção clara (propostas, discursos):** só a posição, como "Mais ativo que a média", "Na média" ou "Menos ativo que a média", sem cor de bom ou ruim. Mais projetos não quer dizer projetos melhores.
- **Peso das ações:**
  - **Faixas:** "Alta relevância" (70 ou mais), "Média relevância" (de 40 a 69) e "Baixa relevância" (menos de 40).
  - **O número:** fica no detalhe.
- **Conteúdo:** projetos e votos nunca são chamados de bons ou ruins. Isso é opinião, e a regra de credibilidade continua valendo.

## Apple Design Award: onde competimos

| Categoria | O que o Fiscal leva |
|---|---|
| Social Impact | Fiscalização para todos os públicos, com os mesmos fatos para todo mundo e dados oficiais sem viés |
| Visuals and Graphics | Coleções de artistas brasileiros dos dois lados, com crédito, e cards compartilháveis com dado e arte |
| Interaction | Live Activity da apuração e de votações, App Intents ("Siri, como meu deputado votou hoje?"), widgets interativos e Spotlight |
| Inclusivity | VoiceOver nos gráficos (Audio Graphs), Dynamic Type até os tamanhos de acessibilidade, linguagem simples, leitura em voz alta e Reduzir movimento |
| Innovation | Resumo de projetos com o Foundation Models, no aparelho e sem enviar nada, sempre ao lado do texto oficial; apoio privado no aparelho |

## Arquitetura

- **App:** SwiftUI e o pacote `FiscalKit`, com um target por aba (`FeatureFeed`, `FeatureRegion`, `FeatureVotes`, `FeatureMoney`, `FeatureSearch`), mais `FeatureSupport` (a página "Meu apoio") e `FeatureLiveResults`.
- **Servidor** (`server/`, Go, na VPS):
  - carga diária dos arquivos oficiais da Câmara, do Senado e do TSE;
  - a API `/api/v1` mapeada na pesquisa;
  - o push das Live Activities.
  - Nenhum dado da pessoa: só tokens de push anônimos.
- **Dados no aparelho:** SwiftData com o apoio, quem a pessoa segue e o cache das últimas respostas. O CloudKit privado é opcional.

## Riscos

| Risco | Como tratar |
|---|---|
| Parecer de um lado | O app é igual para todo mundo: mesmo fato, mesma ordem, sem adjetivo |
| Lei eleitoral em ano de eleição | Sem pesquisa, sem projeção, sem enquete e sem recomendação de voto; no 2º turno, candidatos em ordem de voto ou alfabética |
| LGPD (opinião política) | O apoio é opcional, fica só no aparelho e pode ser apagado a qualquer momento |
| Revisão da App Store | Fonte em cada tela, sem se apresentar como app do governo, sem brasão |
| Fontes instáveis | Carga que para e avisa em vez de gravar dado errado; "—" e a data da última carga |
| Retrato desenhado ser lido como deboche ou propaganda | Mesmo esqueleto, expressões e ritmo para todos, sem expressão ligada a dado, marca "Ilustração do Fiscal" e nome sempre visível; retrato fora dos cards perto da votação |
| Resumo por IA errar | Gerado só a partir do texto oficial, marcado como resumo do aparelho, com o original ao lado; desligável |
