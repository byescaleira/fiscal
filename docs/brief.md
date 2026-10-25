# Brief do Fiscal

- **Data:** 2026-10-25
- **Estado:** proposta para aprovação do usuário
- **Base:** [pesquisa do Politicômetro](research/pesquisa-politicometro.md) e [API mapeada](research/api-politicometro.md)

## Em uma frase

O Fiscal mostra o que os seus representantes fazem com o seu voto, a partir do que importa para você, com os mesmos fatos oficiais para todo mundo.

## Problema

- Quem vota não sabe o que o eleito fez depois da posse. A informação existe, mas está espalhada em dez portais oficiais, em linguagem de diário oficial.
- Os apps e sites que tentam resolver isso caem em dois buracos:
  - parecem militância de um lado, e o outro lado para de confiar;
  - viram uma enciclopédia neutra que ninguém abre duas vezes.
- O Brasil está dividido em dois públicos grandes, com prioridades diferentes, e os dois querem fiscalizar. A direita costuma olhar para gasto público, impostos, segurança, corrupção e liberdade. A esquerda costuma olhar para desigualdade, programas sociais, meio ambiente, direitos e serviços públicos. Os dois olham para corrupção, privilégios de político e emendas.

## A ideia: uma Lente por pessoa, um fato para todos

A **Lente** é o conjunto de prioridades da pessoa, escolhido no primeiro uso e editável a qualquer momento.

1. **"O que mais importa para você?"** A pessoa escolhe de 3 a 5 temas numa grade de 12 cartões com nomes neutros:
   - Segurança pública
   - Impostos e gasto público
   - Combate à corrupção
   - Economia e emprego
   - Saúde
   - Educação
   - Família e costumes
   - Desigualdade e programas sociais
   - Meio ambiente
   - Agro e campo
   - Direitos e igualdade
   - Liberdade de expressão
2. **"Como você se vê na política?"** É opcional e vem com "Prefiro não dizer" em destaque. A escala vai de esquerda a direita, em 5 pontos. A resposta só **sugere** um pacote de temas, que a pessoa pode editar; ela nunca muda um número.

| Muda com a Lente | Nunca muda |
|---|---|
| A ordem dos temas em Hoje e nos perfis | Os números, os votos, os gastos e as fontes |
| Quais votações aparecem em destaque | O acesso a qualquer dado: tudo está a um toque |
| Os alertas e as notificações que a pessoa recebe | A ordem dos candidatos e dos políticos (por voto ou alfabética) |
| O resumo do perfil ("nos seus temas, ele votou assim") | A ausência de nota, ranking ou adjetivo |

- **Outra lente:** em qualquer votação ou perfil, um botão mostra o mesmo fato pelos temas do outro público. É o recurso de ponte do app: entender por que o outro lado se importa com aquela votação.
- **Privacidade:** a Lente e o posicionamento ficam **só no aparelho**. Nunca vão para o servidor, nunca entram em telemetria e nunca saem no backup do servidor. Opinião política é dado pessoal sensível na LGPD (art. 5º, II, e art. 11).
  - Os alertas por tema são filtrados no próprio aparelho. Uma alternativa a decidir é usar canais de push por tema (broadcast do APNs), em que o servidor não sabe quem assinou cada canal.

## Aparência pela Lente

O app tem a cara da pessoa; os dados continuam com a cara dos fatos.

- **Paletas:** cada uma tem cor de destaque, fundo dos cards e um par de cores para o compartilhamento. Há paletas inspiradas no imaginário de cada público, paletas neutras e paletas tiradas das obras dos artistas parceiros, com crédito. O posicionamento sugere uma paleta, mas qualquer pessoa pode escolher qualquer uma.
- **Símbolos:** um conjunto de SF Symbols por tema e por estilo, usado nos chips da Lente, nos cards e nos ícones alternativos do app. Sem logotipo de partido: é marca registrada e transformaria o app em material de campanha.
- **Ícone do app:** ícones alternativos combinando com as paletas.
- **O que a paleta nunca toca:** gráficos, placares e listas de políticos. Neles a cor marca dado (sim, não, ausente), cargo ou lugar, e nunca segue a paleta nem o partido. O mesmo gráfico tem a mesma cor para todo mundo.

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
- **A arte segue a Lente:** a pessoa escolhe a coleção de artistas que combina com ela. O dado não muda.
- **Galeria de artistas** dentro do app: quem é cada artista, as obras, a licença e o link para o portfólio. Crédito sempre visível, inclusive na imagem exportada, sem como remover.
- **Sem montagem enganosa:** o card nunca coloca palavra na boca de político e nunca recorta o placar. O dado sai inteiro ou não sai.

### Direitos das obras (vale para tudo)

Crédito não autoriza o uso. A Lei 9.610/98 exige autorização do autor, e a App Store exige que o app tenha os direitos do que mostra. Cada obra só entra no app com uma destas bases:

| Base | Exemplo | O que guardar |
|---|---|---|
| Domínio público | Autor morto há mais de 70 anos (Lei 9.610, art. 41), como Pedro Américo e Victor Meirelles | Data de morte do autor e fonte da imagem (acervo público) |
| Licença aberta compatível | CC BY ou CC BY-SA, por exemplo fotos da Agência Brasil (CC BY) | Link da licença e versão |
| Autorização por escrito | Licença de uso digital e de redes sociais, com prazo e escopo | Contrato assinado |
| Obra encomendada | Coleção feita para o Fiscal por artistas dos dois lados | Contrato de cessão ou licença |

O manifesto `art-credits.json` vai junto com o app e lista, por obra: autor, @, título, ano, base legal, link da licença e onde a obra pode aparecer. Obra sem linha no manifesto não aparece.

## Públicos

| Público | O que procura | O que o Fiscal entrega primeiro |
|---|---|---|
| Quem se vê à direita | Gasto público, impostos, privilégios, segurança, corrupção, ativismo do STF, liberdade | Cota e salários, emendas, votações de segurança e de tributos, presença |
| Quem se vê à esquerda | Desigualdade, programas sociais, meio ambiente, direitos, saúde e educação públicas | Votações sociais e ambientais, orçamento, financiamento de campanha, bancadas |
| Quem não se define | "O que meu deputado anda fazendo?" | Meus representantes, presença e últimos votos |

## Princípios (herdados da pesquisa, com o que muda)

1. **Mesmo fato para todo mundo.** A Lente ordena; ela não filtra nem reescreve.
2. **Fonte e data em cada bloco.** "—" quando o dado não existe, nunca 0.
3. **Sem nota, ranking ou cor de partido.** A cor marca lugar, cargo ou estado do dado.
4. **Linguagem simples.** A ementa oficial vira "o que muda para você", sempre com o texto original a um toque.
5. **Privacidade como recurso.** Sem conta para usar o app; seguir e a Lente ficam no aparelho; o iCloud é opcional.
6. **Nativo Apple.** Live Activities, widgets, App Intents com a Siri, Spotlight, Apple Intelligence no aparelho, VoiceOver nos gráficos e layouts para iPad, Mac e visionOS.

## As 5 abas

| # | Aba | Ícone | O que é |
|---|---|---|---|
| 1 | **Hoje** | `newspaper` | O resumo do dia pela Lente: votações nos seus temas, como votaram os seus representantes, eventos ao vivo (apuração, votação importante, CPI) e "o que muda para você" |
| 2 | **Meus** | `person.2` | Os seus representantes pelo endereço (do vereador ao presidente) e quem você segue. Cada perfil tem o resumo pela Lente, presença, votos, propostas, gastos e patrimônio |
| 3 | **Votações** | `checkmark.square` | A pauta do Congresso: o calendário, o placar por partido e por estado, quem votou como e "o que muda para você". Inclui a Live Activity da votação importante |
| 4 | **Dinheiro** | `brazilianrealsign` | Para onde vai o dinheiro público: cota, salários e benefícios, emendas (inclusive as "emendas Pix"), financiamento de campanha, patrimônio declarado e arrecadação |
| 5 | **Fiscalizar** (proeminente) | `magnifyingglass` | A busca universal: pessoa, partido, projeto, cidade, CNPJ de fornecedor. Também é a porta para Comparar e Eleições. É a aba com `Tab(role: .search)`, que o iOS 26+ mostra destacada, separada das outras na barra de Liquid Glass |

- **Ajustes** saem da barra de abas e viram um botão na toolbar de Hoje, onde a pessoa também edita a Lente.
- **Eleições** (apuração ao vivo, resultados e propostas de governo) aparecem em Hoje durante o período eleitoral e ficam sempre acessíveis em Fiscalizar.
- **Recomendação de aba proeminente:** usar Fiscalizar porque é o padrão nativo (`role: .search`) e o verbo que dá nome ao app. A alternativa, um "Ao vivo" central, só faz sentido em dia de evento e ficaria vazia no resto do ano.

## Apple Design Award: onde competimos

| Categoria | O que o Fiscal leva |
|---|---|
| Social Impact | Fiscalização para os dois públicos, a Lente com a ponte "Outra lente" e dados oficiais sem viés |
| Visuals and Graphics | Coleções de artistas brasileiros dos dois lados, com crédito, e cards compartilháveis com dado e arte |
| Interaction | Live Activity da apuração e de votações, App Intents ("Siri, como meu deputado votou hoje?"), widgets interativos e Spotlight |
| Inclusivity | VoiceOver nos gráficos (Audio Graphs), Dynamic Type até os tamanhos de acessibilidade, linguagem simples, leitura em voz alta e Reduzir movimento |
| Innovation | Resumo de projetos com o Foundation Models, no aparelho e sem enviar nada, sempre ao lado do texto oficial; Lente privada no aparelho |

## Arquitetura

- **App:** SwiftUI e o pacote `FiscalKit`, com um target por aba (`FeatureToday`, `FeatureMine`, `FeatureVotes`, `FeatureMoney`, `FeatureSearch`), mais `FeatureLens` (onboarding e edição da Lente) e `FeatureLiveResults`.
- **Servidor** (`server/`, Go, na VPS):
  - carga diária dos arquivos oficiais da Câmara, do Senado e do TSE;
  - a API `/api/v1` mapeada na pesquisa;
  - o push das Live Activities.
  - Nenhum dado da pessoa: só tokens de push anônimos.
- **Dados no aparelho:** SwiftData com a Lente, quem a pessoa segue e o cache das últimas respostas. O CloudKit privado é opcional.

## Riscos

| Risco | Como tratar |
|---|---|
| Parecer de um lado | Mesmo fato para todos, revisão de neutralidade em cada texto e "Outra lente" |
| Lei eleitoral em ano de eleição | Sem pesquisa, sem projeção, sem enquete e sem recomendação de voto; no 2º turno, candidatos em ordem de voto ou alfabética |
| LGPD (opinião política) | A Lente só no aparelho, com consentimento explícito para o posicionamento e "Prefiro não dizer" |
| Revisão da App Store | Fonte em cada tela, sem se apresentar como app do governo, sem brasão |
| Fontes instáveis | Carga que para e avisa em vez de gravar dado errado; "—" e a data da última carga |
| Resumo por IA errar | Gerado só a partir do texto oficial, marcado como resumo do aparelho, com o original ao lado; desligável |
