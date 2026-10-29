# Etapas: Enquadrar o Fiscal no byescaleira-workspace

Etapas da mudança `align-workspace`. A fase 1 roda na branch principal da frente; a fase 2 em sete frentes paralelas, cada uma num worktree com `FISCAL_BUILD_ROOT` próprio e sem simulador, donas de pastas que não se cruzam; a fase 3 integra, verifica e revisa uma vez. Nenhuma frente mexe em `*.xcstrings`: o catálogo é sincronizado na integração.

## 1. Base

- [x] 1.1 Superfície lisa no kit (`GroupedSurface`, `.listSurface()`, `.surfaceRows()`, branch `feature/plain-surface`) e o Fiscal inteiro em branco ou preto.
- [x] 1.2 Modo econômico lido na raiz (`.readsLiteMode()`), símbolo da aba Dinheiro sem `.fill`, efeitos em loop com `MotionBudget`, placar das telas em `.scoreboardTitle` (Dynamic Type; o fixo fica em widget, Live Activity e cartaz).

## 2. Frentes

### 2.A Núcleo (`FiscalDomain`, `FiscalData`, `FeatureCore`, `FiscalDesignSystem`, `AppShell`, `Fiscal/Fiscal/*.swift`, `FiscalKit/Package.swift`)

- [ ] A.1 `FiscalAnimationView` sobre o `PaletteAnimationView` do kit; apagar `RankedChartTokens.swift`; `ShareFormat` e o PNG do kit (o `FeatureShare` adapta na frente F3, aqui só o que é do núcleo).
- [ ] A.2 `opensRoutesBeside` do `LayoutContext` no lugar da regra própria em `FiscalNavigation`.
- [ ] A.3 `reduceMotion || liteMode.reducesMotion` nos componentes do núcleo (`IndicatorCard`, `TallyChart`, `PartyMark`, `OfflineNoticeBar` com `.opacity`).
- [ ] A.4 Rotas novas (`race(id:)`, `roster`, `spenders`, `awaiting`) com deep link, e os `NavigationLink` diretos de Apuração, Região, Dinheiro e Memória trocados por `RouteLink`.
- [ ] A.5 Um `PublicDataClient` por processo em `FiscalServices` e um `LiveResultsModel` por janela.
- [ ] A.6 Onboarding da Lente como folha global da navegação, apresentada pela `MainScreen`; aviso recomendado só com a tela livre.
- [ ] A.7 Proteção contra resposta atrasada no `PublicDataPhase.settle` (contador de pedido e `checkCancellation`) para todos os models que o usam.
- [ ] A.8 `FiscalChangeHub` no `FiscalData` (mudanças locais e `NSPersistentStoreRemoteChange`), `SessionModel.start()` com espera de 120 ms.
- [ ] A.9 Preferência `fiscal.settings.cloudSync` lida antes de abrir o banco.
- [ ] A.10 Schemas V1 a V3 congelados conforme o histórico do git (cópias aninhadas do que cada versão distribuída tinha).
- [ ] A.11 `AppGroup` no domínio (suite e diretório), manifesto do grupo, chaves `fiscal.` com migração única (`HomePlace`).
- [ ] A.12 Atualização obrigatória: intents recusam no bloqueio, `UpdateHoldModel` com conexões para destaques, Live Activity e atualização em segundo plano.
- [ ] A.13 Flags remotas `liveResults`, `highlightAlerts` e `intelligence` no catálogo, com o portão na composição.
- [ ] A.14 Estados de erro e vazio do núcleo pelo `EmptyStateView` do kit (`PublicDataContent`, falha de abertura no app); "Como medimos" (`PeerMethodSheet`, `WeightMethodSheet`) como `GuideSheet` de páginas curtas.
- [ ] A.15 Inspector avisa o VoiceOver ao trocar de conteúdo; apagar o editor do template sem uso; `AnyView` só no `RouteView`.
- [ ] A.16 Testes: `SessionModel`, hub de mudanças, intent recusando no bloqueio, conexões do hold, settle com pedido atrasado.

### 2.B Ajustes (`FeatureSettings`)

- [ ] B.1 Leitura da Lente e catálogo de arte no `SettingsModel`; folhas e flags lidas pelo model; gancho estático trocado por injeção.
- [ ] B.2 Interruptor "Sincronizar com o iCloud" em Dados, com rodapé "vale na próxima abertura" (usa a preferência da A.9).
- [ ] B.3 Seção Desenvolvedor completa (`DeveloperModel`): flags com "Restaurar padrões", simular atualização recomendada e obrigatória, cenários de dados públicos e Lente, apagar preferências `fiscal.*`, recarregar dados, informações do app.
- [ ] B.4 Confirmação de apagar dados offline como `GuideSheet`; cor de destaque pelo `RetroColorPicker` do kit; Reduzir movimento nas transições de ícone, cor, aparência e offline.
- [ ] B.5 `AboutModel` e `SourcesModel` públicos e testados; `OfflineDataModel` testado.

### 2.C Hoje, Votações, Apuração e widgets (`FeatureToday`, `FeatureVotes`, `FeatureLiveResults`, `Fiscal/FiscalWidgets`)

- [ ] C.1 Barras de divisão pelo `TallyBar` ou `ShareBarChart`; chips e status pelo `Chip`/`StatusCircle`; títulos de seção por `sectionTitle()`; nomes e títulos de destaque em Bricolage; sobretítulos por token.
- [ ] C.2 `navigationSubtitle` com o escopo na Apuração; `FixedToolbarSpacer` na toolbar de Hoje; botão "Abrir Meus" grande.
- [ ] C.3 Estado de carga e textos da apuração no model (`RaceDetailScreen`); formatação fora das views; telas longas quebradas por seção.
- [ ] C.4 Texto visível alcançável pelo VoiceOver; Reduzir movimento nas transições; barras que preenchem ao abrir.
- [ ] C.5 Live Activity com o link pelo tipo de links; widgets sem números soltos (tokens de escala); ADR da exceção dos widgets lendo dados públicos direto.

### 2.D Dinheiro, Perfil, Região e Memória (`FeatureMoney`, `FeatureProfile`, `FeatureMine`, `FeatureMemory`)

- [ ] D.1 Filtro de recibos num `Menu` na toolbar com `badge`, `navigationSubtitle` e `FixedToolbarSpacer`; subtítulo de escopo em Dinheiro, Região, turno da Memória.
- [ ] D.2 Botão "Ver recibos" grande; chips pelo `Chip`; herói com a etiqueta em `Chip`; gráfico mensal do perfil na receita de série no tempo; trilho de linha do tempo como um componente.
- [ ] D.3 Estados vazios pelo `EmptyStateView`; campo de busca da Região pelo seletor de lugar; tokens no lugar de multiplicadores soltos.
- [ ] D.4 Formatação e contas fora das views; telas longas quebradas; contagens com plural.
- [ ] D.5 Texto visível alcançável pelo VoiceOver; Reduzir movimento nas transições.

### 2.E Buscar, Lente e Compartilhar (`FeatureSearch`, `FeatureLens`, `FeatureShare`)

- [ ] E.1 `ShareFormat` e `ShareImage` do kit (extensão Fiscal só com o que é dele); render no `ShareModel`.
- [ ] E.2 Botões redondos da Lente no padrão (`.bordered`, `.circle`, `.large`, 44 pt) e reordenar com ações de acessibilidade; barras de ranking pelo `RankedBarChart`/`ShareBarChart`.
- [ ] E.3 Folhas e renomear ligados ao model; formatação fora das views; `@unchecked Sendable` sem trava resolvido; chaves `fiscal.search.*` com migração.
- [ ] E.4 Estados vazios pelo `EmptyStateView`; texto visível alcançável; Reduzir movimento nas transições; chips pelo `Chip`.

### 2.F Documentos, processo e publicação (`docs/`, `AGENTS.md`, `CLAUDE.md`, `README.md`, `scripts/`, `ci_scripts/`, `.swiftlint.yml`, `.byescaleira-sdd.json`, `Fiscal/Fiscal/Info.plist`, `*.entitlements`, `PrivacyInfo.xcprivacy`)

- [ ] F.1 `AGENTS.md`, `CLAUDE.md` e constituição: seção e regra de versão, revisores de acessibilidade, segurança e spec, servidor Go na estrutura e nos comandos, PR de fase, skills do plugin.
- [ ] F.2 Specs vivas (`live-results`, `public-data-api`, `lens`, `credibility`, `share-cards-and-art`, `fact-checks`, `notifications`) e o índice.
- [ ] F.3 Arquivar `live-results`, `app-1.0` e `setup-lens-art`; tabela "Em andamento" real; modelo de proposta com critérios de aceite e de etapas com `CHANGELOG`; roadmap e backlog reais; pesquisa com data no nome.
- [ ] F.4 ADRs: app gratuito sem StoreKit, licença PolyForm, ícones de partido, Ajustes na toolbar, modo `fetch` em segundo plano, Fiscal na Web depois da 1.0, rótulo de privacidade (proposto).
- [ ] F.5 Documentos que contradizem o app (`architecture.md`, `validation.md` com o roteiro do Fiscal e o de acessibilidade, `force-update.md`, mídia da loja).
- [ ] F.6 `verify.sh` com o servidor Go e as licenças da arte; regra `emphasis_font` no lint; `.byescaleira-sdd.json` sem pastas que não existem; padrão do `scripts/test.sh` no simulador que existe.
- [ ] F.7 Publicação: entitlement do App Attest, manifesto dos widgets e `1C8F.1` no do app, links do Sobre no `Info.plist`, notas de revisão e descrição corretas, "What to Test" em pt-BR.

### 2.G Site, admin, ponte e servidor (`site/`, `admin/`, `bridge/`, `server/`, `scripts/site-server.mjs`, `scripts/server-deploy.sh`, `docs/web.md`, `docs/server-runbook.md`)

- [ ] G.1 Landing do Fiscal só em pt-BR: herói, mockups e FAQ reais; sem Pro; sem anunciar a Web; link `id6826982117`; `llms.txt` reescrito.
- [ ] G.2 Privacidade com as saídas de rede reais; suporte com dúvidas reais; Bricolage no site; `:focus-visible`.
- [ ] G.3 `/health` com a versão no servidor Go (`-ldflags -X main.version`), na ponte e no admin; `package.json` com versão.
- [ ] G.4 Catálogo de flags do admin igual ao do app; receita de publicação e bloco do Caddy no runbook.

## 3. Integração e fechamento

- [ ] 3.1 Integrar as frentes uma por vez; `scripts/strings.sh` e plurais (`zero`, contagens) no catálogo; chaves antigas removidas.
- [ ] 3.2 Arrumar as branches locais já integradas e os worktrees.
- [ ] 3.3 `scripts/verify.sh --full`, telas no simulador em claro, escuro e AX.
- [ ] 3.4 Revisão única de design, acessibilidade e código sobre o diff; correções na mesma fase.
- [ ] 3.5 `CHANGELOG.md` Unreleased, specs e backlog em dia, PR aberto para a `development`.
