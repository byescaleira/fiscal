# Feed, página do político, navegação e fim da Lente

## Original Requirement

Pedido do usuário em 01/11/2026:

> agora precisamos refinar alguns pontos:
>
> * primeira tab não deve ser seguindo, mas sim feed. Nela tem que ter um comportamento de feed, foco no que estou seguindo e no que é relevante, o ideal é que esse feed seja infinito e bonito.
> * o card de "quem governa" e não tem vice, deve ser centralizado.
> * o card "na sua região agora" ao clicar nele vai para a pagina do político, sendo que o foco é o conteudo dele, deveria ir para outro lugar - o mesmo acontece no card "destaque do momento" e em propostas;
> * Os links estão saindo do app e abrindo o app do safari, o safari deve ser aberto dentro do app e todo componente que abrir link deve ter o ícone para sinalizar isso;
> * O grafico em "quanto custa um mandato" está com um espaçamento estranho entre a legenda e a barra;
> * O grafico em "teto da cota por estado" está com as legendas em baixo tudo se misturando, pode removelas;
> * temos que repensar a pagina de detalhes do politico, torna-la mais didática e interessante. brincar mais com o rosto e as espressões do bonequinho (talvez deixa-lo fixado no header fazendo algo em quanto o usuário vai dando scroll), mostrar só as informações que existem, pagina é dinamica e varia conforme o politico, não tem notas fiscais nessa pagina nem o touchpoint para direcionar. as vezes é interessante compartilhar um gasto especifico ou o usuário quer compartilhar algo espeficido daquele politico também;
> * Vamos acabar com esse questão de lente, isso não tem mais sentido no app. com isso podemos melhorar e criar algo interessante com o que eu apoio;

**Tamanho:** L. Toca a estrutura das abas, cerca de 83 arquivos da Lente, o contrato do [brief](../../docs/brief.md) e o site.

## Domain Concept Identification

| Conceito | Hoje | Lacuna |
| --- | --- | --- |
| **Feed** | `FollowingFeed` no cliente: voto, gasto e checagem de quem a pessoa segue, em 30 dias e até 50 itens, dentro de Seguindo | Sem seguidos, não há feed. Fora dele: propostas e discursos. Sem paginação em nenhum serviço |
| **Relevante** | `highlights.json` com até 4 itens, peso de repercussão e impacto, janela de 90 dias | Poucos itens e nenhum arquivo global de linha do tempo |
| **Região** | Sugestões, "Quem governa", bancadas e "Na sua região agora" moram só em Seguindo | Precisam de outra casa |
| **Hoje** | Apuração, destaques, resumo, Congresso e votações recentes | Se sobrepõe ao Feed |
| **Conteúdo** (proposta, destaque, ação) | Não existe rota própria. O servidor grava o slug do autor em `route`, e por isso o toque abre o perfil | Falta a tela de detalhe. Há título, resumo, estágio, data e URL oficial para ações; não há histórico de tramitação |
| **Link externo** | `Link` e `openURL` em cerca de 18 lugares, sem componente comum, sem `SFSafariViewController` | Sai do app e não sinaliza |
| **Página do político** | 16 seções numa lista, com o retrato só no herói. A cota é a 9ª seção, com caminho próprio, sem usar `Route.expenses`, e o número "Cota" não é tocável | "Mandato em números" mostra traço. A troca de ano só existe fora do perfil |
| **Bonequinho** | Rig único com 8 expressões e 5 gestos, trocáveis em tempo real, animado a partir de 72 pt | Regra do projeto: expressão **nunca** ligada a dado |
| **Compartilhar um item** | `ShareSubject` tem o agregado de gastos e a votação inteira | Faltam um gasto, uma proposta e o voto de uma pessoa |
| **Lente** | Temas, ordem, selo, 8 paletas, arte, ícone e "Outra lente", além do apoio | "Apoio" é a parte que pode sobreviver: cerca de 24 arquivos; os outros cerca de 60 são só visual ou plumbing. Loja só no aparelho, fora do backup |

**Achados que corrigem o pedido ou o site:**
- **Notas:** elas existem no perfil, escondidas na 9ª seção, e somem para quem não tem cota ou não tem gasto no ano corrente. O problema real é a descoberta.
- **Promessa sem botão:** `site/support.html` e `site/privacy.html` prometem apagar a Lente, e nenhum botão faz isso hoje. O fim da Lente precisa resolver essa promessa.
- **Cobertura por cargo:** presidente, governador e prefeito não têm votos nem gastos no servidor. A página dinâmica precisa prever cargos com pouca informação.

## Strategic Approach

**Quatro fases, nesta ordem**, cada uma com canvas e PR próprios. As fases 4 e 5 antigas, da web, ficam depois delas.

| Fase | ID | Conteúdo | Tamanho |
| --- | --- | --- | --- |
| 1 | `FSC-011` | Refinos: "Quem governa" centrado, os dois gráficos, navegador dentro do app com ícone, tela de detalhe do conteúdo e os toques corrigidos | M |
| 2 | `FSC-012` | Fim da Lente e o novo apoio | L |
| 3 | `FSC-013` | Aba Feed, região e Hoje reorganizados, feed montado só no app | L |
| 4 | `FSC-014` | Nova página do político e compartilhar um item específico | L |

**Decisões:**

| Decisão | Porta | Escolha e motivo |
| --- | --- | --- |
| Quem governa | reversível | Sem vice, o conteúdo fica centralizado no cartão |
| Gráfico do mandato | reversível | Reduzir o espaço entre barra e legenda, medindo a altura real |
| Gráfico da cota por UF | veto | Tirar as siglas do eixo, como pedido. A UF aparece ao tocar na barra, e o VoiceOver segue lendo todas |
| Link externo | veto | Componente único com ícone `arrow.up.right` no kit. No iPhone, no iPad e no visionOS abre em `SFSafariViewController`; no Mac, no navegador do sistema. App Store segue abrindo a loja |
| Toque em conteúdo | veto | Abre uma tela nova de detalhe, com o fato, o resumo, o estágio, a data e "Ver a fonte oficial". O autor vira um botão à parte, que abre o perfil. Voto continua abrindo a votação, onde já está o placar. Sem histórico de tramitação, porque esse dado não existe |
| Fim da Lente | veto | Saem o setup inicial, os temas, a ordem por tema, o selo, a arte adaptada, "Outra lente" e `LensScreen`. Paleta e ícone continuam em Ajustes > Aparência. O app abre direto, sem setup |
| Dados da Lente já salvos | reversível | Quem já apoiava mantém esse apoio, numa migração de `LensEntity`. Temas somem. Só no aparelho e fora do backup, como manda o ADR 0017 |
| Novo apoio | respondida | **Pessoas e causas.** Uma página privada "Meu apoio", guardada só no aparelho, com as pessoas e as causas apoiadas e o que aconteceu com elas (como votaram, o que propuseram). Só fatos, sem nota nem ranking |
| Site e documentos | veto | Brief, ADRs 0004 e 0014, site, App Store e FSC-003 passam a dizer a verdade na mesma fase. Publicar o site espera o ok |
| Abas | respondida | **Feed absorve Hoje:** Feed, Votações, Dinheiro, Região e Fiscalizar. Apuração e destaques entram no Feed. A aba Região guarda quem a pessoa segue, as sugestões, quem governa e as bancadas |
| Feed infinito | respondida | **Só no app:** junta os arquivos por pessoa desde 2023, os destaques e as votações recentes, sem mudar o servidor. O limite aceito: quem segue pouca gente vê o feed acabar, e o fim é mostrado com clareza. As páginas no servidor ficam como melhoria futura |
| Formato do feed | reversível | Cartões grandes de formas diferentes por tipo, com pessoa, fato, fonte, data e compartilhar. Referências visuais reais no ciclo de design |
| Ordem do feed | veto | Primeiro o recente de quem a pessoa segue, intercalado com o relevante pelo peso já público, com critério visível e sem apoio influenciando o que é "relevante" |
| Retrato fixo no perfil | veto | Bonequinho fixo no cabeçalho ao rolar. Ele reage à **rolagem e à seção**, nunca ao valor do dado: nada de joinha para presença alta nem de tristeza para gasto alto. Parado com Reduzir movimento |
| Página dinâmica | reversível | Só mostra o que existe, ordena por cargo e explica em linguagem simples. O número "Cota" abre `Route.expenses`, com notas e troca de ano |
| Compartilhar item | reversível | Novos assuntos: um gasto, uma proposta e o voto de uma pessoa. Uma ação por peça, com as regras da FSC-010 |
| Cartões sem bonequinho | veto | O bonequinho volta só nas telas do app; os cartões de compartilhar seguem sem ele |
| Ordem das fases | reversível | Refinos primeiro por serem rápidos e independentes |

## Risk & Gap Analysis

| Risco | Efeito | Tratamento |
| --- | --- | --- |
| Lente espalhada por cerca de 83 arquivos e 25 testes | Regressão em Hoje, Votações e Dinheiro | Fase própria; retirar por camada, com a ordem padrão de cada tela conferida |
| Migração do banco `Device` | Perda do apoio salvo | Teste de migração e guarda de privacidade (`LensPrivacyTests`) |
| Feed montado só no app | Muitos arquivos por pessoa e por ano gastam dados, e o feed tem um fim real | Carregar aos poucos, ano a ano, com cache e limite de pedidos simultâneos, e mostrar o fim com clareza |
| Feed para cargos sem atividade | Quem segue só governador vê pouco | O relevante preenche, com a explicação de por que falta |
| Bonequinho fixo e `AdaptiveList` | O cabeçalho da seção não fixa, e animar custa energia | Testar `safeAreaInset`, parar fora da tela e respeitar `MotionBudget` |
| Expressão parecer julgamento | Fere "só fatos" e a neutralidade | Regra de veto acima, com teste no modelo |
| `highlights.json` muda a cada carga | Link antigo de destaque deixa de achar o item | O detalhe recebe o conteúdo já carregado e, por link, cai numa tela explicando |
| Testes de interface já quebrados | Mudar a primeira aba sem rede de segurança | Corrigir os dois testes na fase do Feed |
| Promessa do site de apagar a Lente | App em desacordo com a política | Botão real de apagar o apoio, ou texto novo, na fase 2 |

**Critérios de aceite (fase 1, para o canvas):**

| Cenário | Prova |
| --- | --- |
| Cartão de "Quem governa" sem vice fica centrado | Captura |
| Gráficos sem espaço estranho e sem siglas misturadas | Captura |
| Todo link externo abre dentro do app no iPhone e mostra o ícone | Lint ou teste contra `Link` solto, e roteiro |
| Tocar em "Destaque do momento", "Na sua região agora" e propostas abre o conteúdo, e o autor abre o perfil | Teste de rota e roteiro |
| Voto continua abrindo a votação | `TodayModel` e `MineModel` |

**Fora de escopo da fase 1:** Feed, fim da Lente, nova página do político, mudança no servidor e web.
