# Changelog

Todas as mudanças relevantes do Fiscal. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa [versão semântica](https://semver.org/lang/pt-BR/): o `MARKETING_VERSION` do app (igual em todos os alvos) é a versão deste arquivo, e cada versão enviada à loja ganha a tag `vX.Y.Z`.

## [Unreleased]

Primeira versão, a 1.0.0.

### Added

- Site público e arquivo dos links universais prontos para a Cloudflare Pages, no projeto `fiscal-site`: página 404, montagem com teste (`scripts/site-build.mjs`) e publicação com plano e `--apply` (`scripts/site-publish.sh`). A publicação e a troca do DNS de `fiscal.byescaleira.com` vêm depois do deploy da FSC-020, com o ok do usuário ([ADR 0030](docs/adr/0030-site-on-cloudflare-pages.md)).
- Feed, Votações, Dinheiro, Região e Fiscalizar com dados oficiais da Câmara, do Senado, do TSE, do Portal da Transparência e dos municípios.
- Apuração ao vivo das eleições, com os números do TSE.
- Meu apoio: uma página privada com as pessoas e as causas que você escolhe, numa linha do tempo por data, só com fatos, guardada só no aparelho e que pode ser apagada. O resto do app é igual para todo mundo.
- Cartões de compartilhar com arte brasileira de licença livre e o que circulou sobre cada político segundo o Projeto Comprova.
- Widgets, atalhos da Siri e busca no Spotlight.
- Ícone da Amazônia ao amanhecer vista de cima, com ícones alternativos de temas, fauna e partidos. Os ícones principais e os temas mostram lugares do Brasil vistos de cima, cada tema com o nome do lugar: Cataratas do Iguaçu, Jalapão, Pantanal, Ipês em flor, Chapada dos Veadeiros, Fernando de Noronha, Pão de Açúcar e Lençóis Maranhenses ([FSC-022](spdd/prompt/FSC-022-202611051909-[Feat]-icons-aerial-brazil-landscapes.md)).
- Roda a partir do iOS, iPadOS, macOS e visionOS 26, com o que é do 27 quando o aparelho tem.
- Cores com contraste de texto conferido, botões e superfícies opacos com Reduzir transparência e barras de progresso lidas pelo VoiceOver.
- Fundo branco no claro e preto no escuro em todas as telas, com os cartões em cinza do sistema.
- Ajustes com o interruptor de sincronização com o iCloud, Notificações e Privacidade em páginas próprias, e a seção Desenvolvedor completa nas builds de desenvolvimento.
- Filtros de recibos e da lista de representantes de Região na barra de ferramentas, com o escopo escrito sob o título.
- Gráfico mensal de gastos do perfil com a média e o valor de cada mês ao tocar.
- Site só em português, com o que o app faz de verdade, a fonte Bricolage e a lista real do que sai do aparelho.
- No iPhone dobrável meio aberto, toda aba fica com a lista de um lado da dobra e o que se abre nela do outro (em pé, lado a lado; deitado, o detalhe em cima), com um estado vazio por aba ([FSC-008](spdd/prompt/FSC-008-202610311530-[Feat]-shell-fold-mac-vision-developer.md)).
- No Mac, lista de origem com Acompanhar, Congresso e Explorar, menu Ir com ⌘1 a ⌘5, recibos, votos e representantes em tabelas ordenáveis e cartões em `GroupBox`.
- No visionOS, a rota aberta ao lado vira uma janela vizinha.
- Página Desenvolvedor com flags em três estados, registro de eventos sem dado pessoal, diagnóstico e a medida da tela.
- Envio das capturas da loja pela API do App Store Connect (`scripts/store-media.py`).
- O Feed é a primeira aba e o app abre nele: o que fizeram as pessoas que você segue e o que é relevante, só por data, com os filtros Tudo, Seguindo e Relevante e o motivo de cada linha. No topo, a apuração ao vivo e o destaque do momento. A lista cresce conforme você desce, até os dados de 2023, e diz onde acaba ([FSC-013](spdd/prompt/FSC-013-202611012300-[Feat]-feed-first-tab-and-region.md)).
- A página do político virou uma rolagem em capítulos que dependem do cargo e do que existe (Como vota, O que propõe, Quanto gasta, De onde vem, O que circulou, Quem é), com um resumo no topo, sem traços, e uma frase dizendo o que a fonte não publica. Ao rolar, um cabeçalho fixo mostra o bonequinho, que faz um gesto neutro por capítulo, e os atalhos ([FSC-014](spdd/prompt/FSC-014-202611020300-[Feat]-politician-page-and-share-an-item.md)).
- Quanto gasta abre no ano mais recente com gasto, troca de ano e leva a todas as notas. O que circulou mostra as checagens do Projeto Comprova na página, só por data.
- Compartilhar uma nota, um mês, o voto de uma pessoa ou uma proposta. A nota diz de quantas faz parte e o total do ano, e nota de pessoa física não vira cartão.
- Cartões e linhas que abrem outra tela mostram a setinha à direita, e o toque principal abre o conteúdo. No Feed, a pessoa abre o próprio perfil.
- A aba Região guarda quem você segue, até oito sugestões entre quem representa o seu lugar, quem governa e as bancadas ([FSC-009](spdd/prompt/FSC-009-202610312200-[Feat]-following-tab-and-follow-everywhere.md)).
- Seguir e deixar de seguir em qualquer linha de pessoa (botão ao lado do nome e menu de contexto), no perfil e nas tabelas do Mac.
- Siri e Atalhos seguem e deixam de seguir um político sem abrir o app, com o aparelho desbloqueado, e "Quem eu sigo" abre a aba Região.
- Tela própria para propostas e destaques: o toque em "Destaque do momento", "Na sua região agora" e nas propostas do perfil abre o conteúdo, com o texto simples, a ementa, o estágio, a data e a fonte, e o autor vira um botão à parte.
- Todo link externo abre dentro do app no iPhone, no iPad e no visionOS, e mostra a seta que avisa que sai para a web.
- Widget "Quem eu sigo", com as últimas novidades de até seis pessoas seguidas, e o número de novidades na aba Feed.
- Compartilhar virou um estúdio: o cartão fica grande no topo, com os estilos Folha, Dados e Pôster num carrossel, e os controles num painel separado: arte, rede e lugar (Instagram, TikTok, Facebook, WhatsApp e outros) e fatos a mostrar ou esconder, com legenda editável e o botão de postar na barra de cima.
- Vídeo animado de 5 s para Stories, Reels, TikTok e Status: fundos e blocos aparecem em sequência e os números rolam até o valor real, com progresso e cancelamento.
- Envio direto aos Stories do Instagram e do Facebook com o App ID da Meta; TikTok pelo Fotos, abrindo o app.
- Links do site abrem o app no conteúdo, pelos links universais, assim que a nova AASA for publicada.
- Convite dispensável na aba Região para compartilhar quem você acompanha, com o novo cartão "Quem eu sigo".

- Plenário no detalhe da votação: um ponto por cadeira (513 na Câmara, 81 no Senado), com sim à esquerda, não à direita, quem não votou no meio e a linha de quórum da PEC. A contagem anima uma vez e fica parada com Reduzir movimento ([FSC-023](spdd/prompt/FSC-023-202611052151-[Feat]-plenary-and-holographic-card.md)).
- O cartão do político virou uma carta colecionável, igual para todos: moldura metalizada, o retrato numa janela holográfica com brilhos e a carta girando com a inclinação do iPhone.
- Curtir no Feed: um coração no cabeçalho de cada item, ao lado da data, e no destaque do topo, que explode em confete de corações nas cores do partido, ou em vermelho, com um toque háptico. As curtidas são privadas, sem contagem, ficam só no aparelho, fora do iCloud e do backup, e aparecem em "Curtidas", no menu do coração da barra do Feed ([FSC-024](spdd/prompt/FSC-024-202611061418-[Feat]-feed-like-with-ripple.md)).
- Notificação de destaque, em Ajustes › Notificações: desligada por padrão, leva o destaque seguinte em peso, sem som. A pergunta do iOS só aparece quando você liga o interruptor ([FSC-020](spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)).
- A Atividade ao Vivo do destaque mostra o bonequinho do político na tela de bloqueio e na Ilha Dinâmica expandida.

### Changed

- O app lê os dados públicos e a apuração só da Cloudflare e não chama mais o servidor do Fiscal. Sem a Cloudflare, usa a cópia guardada e o pacote offline.
- A Atividade ao Vivo do destaque é agendada no próprio aparelho, uma vez por dia, num horário que o aparelho aprende pelo seu uso do app. Abrir o app não a inicia mais na hora. O histórico de aberturas fica só no aparelho, fora do iCloud, e nunca sai dele.
- Nada sai do aparelho para o servidor do Fiscal: saíram o código de push, o App Attest e o registro. O servidor só carrega as fontes, lê o TSE e publica na Cloudflare.
- A pauta, as votações recentes e o resumo de hoje passam a vir só da Cloudflare, para a VPS não ser o caminho de cada abertura do app. Esses dados podem atrasar até uns 10 minutos.
- A Atividade ao Vivo do destaque passa a aceitar peso 70, no servidor e no app. Com o limite de 85, nenhum destaque entrou nos 30 dias medidos.
- O Feed virou uma lista contínua, com divisórias entre os itens no lugar dos cartões. O destaque e a apuração no topo continuam como cartões.
- As checagens do Projeto Comprova no Feed mostram a imagem da própria publicação, inteira e com crédito, buscada no aparelho.
- Quem tem traços aparece sempre desenhado, mesmo quando o partido no dado muda; antes, Eduardo Riedel e outros caíam no rosto genérico ([FSC-016](spdd/prompt/FSC-016-202611021923-[Feat]-light-cards-and-portraits.md)).
- O placar da votação, "Na sua região agora", a conclusão da investigação e o comparar não têm mais fundo preto no modo claro. No escuro e nos cartões coloridos, nada muda.
- A barra que aparece ao rolar passou a valer também no detalhe da votação (proposta, placar e atalhos), no detalhe da corrida (corrida e apurado) e nas notas (nome, ano e total) ([FSC-015](spdd/prompt/FSC-015-202611021500-[Feat]-sticky-bar-votes-region-tabs.md)).
- O detalhe da votação ficou mais curto: placar em círculos, o que muda antes da explicação e a lista de votos em tela própria, com busca e filtros. Votação simbólica diz o que a casa registrou, sem traços.
- Votações começa pelo que foi votado, com linhas mais curtas. A próxima sessão fica numa linha que abre a pauta, e pauta de data passada não aparece.
- Região começa pelo lugar. Quem você segue, as sugestões e o convite de compartilhar foram para uma tela própria, aberta pelo filtro Seguindo do Feed, por `fiscal://following`, pelo widget "Quem eu sigo" e pela Siri.
- Novos símbolos nas abas: duas pessoas no Feed, o pin com um círculo em Região e o binóculo em Fiscalizar.

- Placar das telas acompanha o tamanho de texto do aparelho; o tamanho fixo fica nos widgets, na Live Activity e nos cartões.
- "Como medimos" e a confirmação de apagar os dados offline viram guias curtos.
- Toda animação para com Reduzir movimento ou com o Modo econômico (pouca energia ou aparelho quente).
- Mudanças vindas do iCloud chegam à tela sem reabrir o app, e cada carga de dados ignora resposta atrasada.
- Todos os cartões de compartilhar têm o mesmo sistema de blocos de ponta a ponta, sem retrato, com as cores do partido na zona que as redes cobrem. Os cartões de vitória e de investigação passam a usar esse sistema.
- O cartão não mostra dado ausente: ele some também da legenda e das opções, um zero nunca é o número principal, e sem dado ou sem fonte não há cartão.
- O cartão traz a mediana dos colegas no lugar de "Melhor" ou "Pior que a média", que fica só no perfil.
- byescaleira-kit 0.7.2; a verificação completa roda o servidor com `-race` e o `govulncheck`.

### Removed

- A Atividade ao Vivo da apuração e o botão de acompanhar uma disputa, até a próxima eleição. A apuração continua nas telas.

### Fixed

- Os gastos dos deputados não perdem mais linhas quando a Câmara repete o número do documento, como numa passagem e no reembolso dela.
- A conferência semanal dos dados roda numa cópia, avisa no celular quando diverge e só publica o que divergiu com um comando explícito.
- A mesma pessoa como prefeita e vereadora na mesma cidade não perde mais um dos cargos.
- A mesma pessoa não aparece mais com dois partidos: governador, vice e deputado estadual em exercício usam o partido da candidatura mais recente, e o histórico de cada eleição continua como foi.
- Eliane Leal, Gustavo Rocha, Jessica Sales e Larissa ganharam retrato próprio.
- A carga de dados avisa no celular quando falha ou quando os dados ficam velhos, e a limpeza do Docker não apaga mais as imagens da carga.
- O app do Mac carrega os dados: o sandbox ganhou a rede de saída.
- Com a atualização obrigatória, atalhos, alertas de destaque e a atualização em segundo plano também param.
- Contagens no plural certo, inclusive no zero.
- O desenvolvimento passa a seguir o SPDD (open-spdd): análises e canvases em `spdd/`, um canvas `[Codify]` por capacidade e as specs e mudanças antigas congeladas como histórico ([ADR 0019](docs/adr/0019-spdd-process.md)).
