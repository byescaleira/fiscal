# Changelog

Todas as mudanças relevantes do Fiscal. O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/) e o projeto usa [versão semântica](https://semver.org/lang/pt-BR/): o `MARKETING_VERSION` do app (igual em todos os alvos) é a versão deste arquivo, e cada versão enviada à loja ganha a tag `vX.Y.Z`.

## [Unreleased]

Primeira versão, a 1.0.0.

### Added

- Seguindo, Hoje, Votações, Dinheiro e Fiscalizar com dados oficiais da Câmara, do Senado, do TSE, do Portal da Transparência e dos municípios.
- Apuração ao vivo das eleições, com Live Activity e Ilha Dinâmica.
- Meu apoio: uma página privada com as pessoas e as causas que você escolhe, numa linha do tempo por data, só com fatos, guardada só no aparelho e que pode ser apagada. O resto do app é igual para todo mundo.
- Cartões de compartilhar com arte brasileira de licença livre e o que circulou sobre cada político segundo o Projeto Comprova.
- Widgets, atalhos da Siri e busca no Spotlight.
- Ícone da Amazônia ao amanhecer, com ícones alternativos de temas, fauna e partidos.
- Roda a partir do iOS, iPadOS, macOS e visionOS 26, com o que é do 27 quando o aparelho tem.
- Cores com contraste de texto conferido, botões e superfícies opacos com Reduzir transparência e barras de progresso lidas pelo VoiceOver.
- Fundo branco no claro e preto no escuro em todas as telas, com os cartões em cinza do sistema.
- Ajustes com o interruptor de sincronização com o iCloud, Notificações e Privacidade em páginas próprias, e a seção Desenvolvedor completa nas builds de desenvolvimento.
- Filtros de recibos e da lista de representantes de Seguindo na barra de ferramentas, com o escopo escrito sob o título.
- Gráfico mensal de gastos do perfil com a média e o valor de cada mês ao tocar.
- Site só em português, com o que o app faz de verdade, a fonte Bricolage e a lista real do que sai do aparelho.
- No iPhone dobrável meio aberto, toda aba fica com a lista de um lado da dobra e o que se abre nela do outro (em pé, lado a lado; deitado, o detalhe em cima), com um estado vazio por aba ([FSC-008](spdd/prompt/FSC-008-202610311530-[Feat]-shell-fold-mac-vision-developer.md)).
- No Mac, lista de origem com Acompanhar e Congresso, menu Ir com ⌘1 a ⌘5, recibos, votos e representantes em tabelas ordenáveis e cartões em `GroupBox`.
- No visionOS, a rota aberta ao lado vira uma janela vizinha.
- Página Desenvolvedor com flags em três estados, registro de eventos sem dado pessoal, diagnóstico e a medida da tela.
- Envio das capturas da loja pela API do App Store Connect (`scripts/store-media.py`).
- Seguindo é a primeira aba e o app abre nela: as novidades dos últimos 30 dias de quem você segue (votos, gastos e checagens, com a fonte de cada uma e o selo "Novo" até você sair da aba), quem você segue, até oito sugestões entre quem representa o seu lugar e quem você apoia, e Sua região logo abaixo ([FSC-009](spdd/prompt/FSC-009-202610312200-[Feat]-following-tab-and-follow-everywhere.md)).
- Seguir e deixar de seguir em qualquer linha de pessoa (botão ao lado do nome e menu de contexto), no perfil e nas tabelas do Mac.
- Siri e Atalhos seguem e deixam de seguir um político sem abrir o app, com o aparelho desbloqueado, e "Quem eu sigo" abre a aba Seguindo.
- Tela própria para propostas e destaques: o toque em "Destaque do momento", "Na sua região agora" e nas propostas do perfil abre o conteúdo, com o texto simples, a ementa, o estágio, a data e a fonte, e o autor vira um botão à parte.
- Todo link externo abre dentro do app no iPhone, no iPad e no visionOS, e mostra a seta que avisa que sai para a web.
- Widget "Quem eu sigo", com as últimas novidades de até seis pessoas seguidas, e o atalho de Seguindo no Hoje com o número de novidades.
- Compartilhar virou um estúdio: o cartão fica grande no topo, com os estilos Folha, Dados e Pôster num carrossel, e os controles num painel separado: arte, rede e lugar (Instagram, TikTok, Facebook, WhatsApp e outros) e fatos a mostrar ou esconder, com legenda editável e o botão de postar na barra de cima.
- Vídeo animado de 5 s para Stories, Reels, TikTok e Status: fundos e blocos aparecem em sequência e os números rolam até o valor real, com progresso e cancelamento.
- Envio direto aos Stories do Instagram e do Facebook com o App ID da Meta; TikTok pelo Fotos, abrindo o app.
- Links do site abrem o app no conteúdo, pelos links universais, assim que a nova AASA for publicada.
- Convite dispensável na aba Seguindo para compartilhar quem você acompanha, com o novo cartão "Quem eu sigo".

### Changed

- Placar das telas acompanha o tamanho de texto do aparelho; o tamanho fixo fica nos widgets, na Live Activity e nos cartões.
- "Como medimos" e a confirmação de apagar os dados offline viram guias curtos.
- Toda animação para com Reduzir movimento ou com o Modo econômico (pouca energia ou aparelho quente).
- Mudanças vindas do iCloud chegam à tela sem reabrir o app, e cada carga de dados ignora resposta atrasada.
- Todos os cartões de compartilhar têm o mesmo sistema de blocos de ponta a ponta, sem retrato, com as cores do partido na zona que as redes cobrem. Os cartões de vitória e de investigação passam a usar esse sistema.
- O cartão não mostra dado ausente: ele some também da legenda e das opções, um zero nunca é o número principal, e sem dado ou sem fonte não há cartão.
- O cartão traz a mediana dos colegas no lugar de "Melhor" ou "Pior que a média", que fica só no perfil.
- byescaleira-kit 0.7.2; a verificação completa roda o servidor com `-race` e o `govulncheck`.

### Fixed

- O app do Mac carrega os dados: o sandbox ganhou a rede de saída.
- Com a atualização obrigatória, atalhos, alertas de destaque, registro da Live Activity e a atualização em segundo plano também param.
- A Live Activity da apuração abre a Apuração, não a tela inicial.
- Contagens no plural certo, inclusive no zero.
- O desenvolvimento passa a seguir o SPDD (open-spdd): análises e canvases em `spdd/`, um canvas `[Codify]` por capacidade e as specs e mudanças antigas congeladas como histórico ([ADR 0019](docs/adr/0019-spdd-process.md)).
