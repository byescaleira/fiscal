# Arquitetura

O Fiscal segue a arquitetura padrão dos apps do Rafael (skill `byescaleira-sdd`, `references/architecture.md`): um projeto Xcode fino que abre o banco e entrega a janela ao pacote `FiscalKit`, com um target por feature. As features não se importam; navegam pedindo uma `Route` ao `AppShell`. Models `@MainActor @Observable` chegam às telas pelo `Environment`. O app é só em pt-BR ([ADR 0003](adr/0003-portuguese-only.md)); design, componentes e idioma vêm do `byescaleira-kit` ([ADR 0010](adr/0010-byescaleira-kit.md)).

## Repositório

```text
fiscal/
├── Fiscal.xcworkspace          projeto + pacote; scheme compartilhado FiscalKitTests
├── Fiscal/
│   ├── Fiscal.xcodeproj        targets Fiscal, FiscalWidgets e FiscalUITests (pastas sincronizadas); scheme Production
│   ├── Fiscal/                 FiscalApp.swift, FiscalShortcuts.swift, Info.plist, entitlements, PrivacyInfo.xcprivacy, ícones, catálogos de texto
│   └── FiscalWidgets/          widgets e Atividades ao Vivo, com Info.plist, entitlements e PrivacyInfo.xcprivacy próprios
├── FiscalKit/                  Package.swift, Sources/<Target>, Tests/<Target>Tests
├── server/                     Go: fiscal-ingest, fiscal-api e fiscal-pages
├── site/, bridge/, admin/      site público, ponte do Fiscal na Web (não publicada) e painel na VPS
├── scripts/                     build, lint, format, test, verify, strings, icons, animations, art, simulator, deploy do servidor
├── ci_scripts/                  Xcode Cloud
├── spdd/                        índice, análises, canvases (prompt/) e revisões do SPDD
└── docs/                        constitution, adr/, specs/ e changes/ (histórico congelado), este arquivo, design-system, backlog, roadmap
```

## Targets

| Target | Responsabilidade | Depende de |
| --- | --- | --- |
| `FiscalDomain` | Valores (`CalendarDay`; `YearMonth`, `GregorianCalendar` e o idioma vêm do `ByescaleiraFoundation`, reexportado, com o pt-BR fixado por `FiscalLanguage.install()`), protocolos de repositório (`LensRepository`, `FollowRepository`), `FiscalError`, `RemoteFlag`; em `PublicData/`, os tipos dos [dados públicos](specs/public-data-api.md) (`PersonCard`, `Profile`, `VoteSummary`, `VoteDetail`, `MoneyOverview`, `TodayDigest`…), `Theme`, `Lens`, `PublicDataService`, `PublicDataError` e `PublicFormat` (centavos em reais, "—" para dado ausente); em `LiveResults/`, `Race` e a Atividade ao Vivo do destaque; em `PublicData/`, também a regra, o plano e o hábito dos alertas do destaque (`HighlightAlertRule`, `HighlightAlertPlan`, `HighlightAlertHabit`); em `Integrations/`, o que widgets e intents compartilham | `ByescaleiraFoundation` |
| `FiscalData` | `FiscalDatabase` (SwiftData em duas configurações: `Fiscal` com CloudKit `iCloud.fiscal` para os seguidos e as investigações e `Device`, só no aparelho, para o apoio; [ADR 0004](adr/0004-lens-on-device-store.md)), `FiscalStore` (`@ModelActor`), entidades `@Model`, schema versionado, repositórios, `CloudKitFlagSource`; em `PublicData/`, o `PublicDataClient`, o `PublicDataLayout` (`v2`), o pacote offline e, em Debug, o `ShowcasePublicData` com `-FiscalDataScenario normal\|empty\|offline\|longNames\|unavailable`; em `LiveResults/`, o `LiveResultsClient`, que lê só `v2/races.json` na CDN | Domain |
| `FiscalDesignSystem` | Reexporta `ByescaleiraDesign`, `ByescaleiraCharts`, `ByescaleiraAccessibility` e `ByescaleiraPlatform` e guarda só o que é do Fiscal: partidos, placar, retratos e tokens dos cartazes | byescaleira-kit |
| `FiscalResource` | Animações Lottie (`FiscalResourceAnimation`), acervo de arte (`art-credits.json`, `Art.xcassets`), mapas do Brasil, molde e traços dos retratos, selo de partido e os dados de teste do showcase | nada |
| `FeatureCore` | `SessionModel`, navegação (`Route`, `AppSection`, `FiscalNavigation`, `\.open`, `\.close`), `FeatureFlag`/`FeatureFlags`, atualização obrigatória, exportação, explicações no aparelho (`Explain/`), componentes de dados públicos (`SourceFootnote`, `PeerBadge`, `PublicDataContent`), retratos e `FiscalAnimationView`; reexporta o `ByescaleiraUI` | Domain, DesignSystem, Resource, `ByescaleiraUI`, Lottie |
| `FeatureGuides` | `GuideScreen` e páginas dos tutoriais | Domain, DesignSystem, FeatureCore |
| `FeatureFeed` | Aba Feed: apuração e destaque do momento no topo, lista por data com os filtros Tudo, Seguindo e Relevante, selo de novidades, retrato do widget e os botões de "Meu apoio" e de Ajustes ([ADR 0022](adr/0022-feed-first-tab-and-region.md)) | Domain, DesignSystem, FeatureCore |
| `FeatureRegion` | Aba Região: lugar de casa, quem governa a cidade, o estado e o país, e bancadas. Também a tela de quem a pessoa segue (`Route.following`), com sugestões e convite de compartilhar ([ADR 0024](adr/0024-reveal-bar-following-and-ballots-screens.md)) | Domain, DesignSystem, FeatureCore |
| `FeatureProfile` | Perfil (`Route.person(slug:)`), aberto por qualquer aba: capítulos por cargo, cabeçalho fixo com o retrato e notas pela `Route.expenses` | Domain, DesignSystem, FeatureCore |
| `FeatureVotes` | Aba Votações: recentes, linha da próxima sessão, pauta (`Route.agenda`), detalhe (`Route.vote(id:)`) e lista de votos (`Route.voteBallots`) | Domain, DesignSystem, FeatureCore |
| `FeatureMoney` | Aba Dinheiro e recibos (`Route.expenses`) | Domain, DesignSystem, FeatureCore |
| `FeatureSearch` | Aba Fiscalizar (`Tab(role: .search)`): busca no índice, Comparar (`Route.compare(slugs:)`), Eleições e investigações | Domain, DesignSystem, FeatureCore |
| `FeatureMemory` | Memória, em Fiscalizar: eleições desde 1989, períodos da política e guias de estudo (`Route.memory`, `pastElection`, `period`, `studyGuide`) | Domain, DesignSystem, FeatureCore |
| `FeatureSupport` | "Meu apoio" (`Route.support`): linha do tempo por data, filtros, editor de pessoas e causas e apagar ([`FSC-012`](../spdd/prompt/FSC-012-202611012040-[Feat]-end-of-lens-my-support.md)) | Domain, DesignSystem, Resource, FeatureCore |
| `FeatureShare` | Cartazes de compartilhar e galeria de artistas (`Route.artists`) ([`FSC-005`](../spdd/prompt/FSC-005-202610291700-[Codify]-share-cards-and-art.md)) | Domain, DesignSystem, Resource, FeatureCore |
| `FeatureLiveResults` | Apuração (`Route.races`), lida na CDN, e o agendamento da Atividade ao Vivo do destaque ([`FSC-001`](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md), [`FSC-007`](../spdd/prompt/FSC-007-202610291700-[Codify]-notifications.md)) | Domain, DesignSystem, FeatureCore |
| `FeatureSettings` | Ajustes: Seu Fiscal, Aparência, Seus dados e privacidade, Fontes e método, Sobre e Desenvolvedor | Domain, DesignSystem, Resource, FeatureCore |
| `AppShell` | `FiscalWindow`, `MainScreen`, `SectionStack`, `SectionScreen`, `RouteScreen`, `InspectorScreen`, `SplashScreen`/`LaunchProgress`, `DeepLinks`, `FiscalServices`, `OfflineDataCenter`, App Intents, Spotlight e os alertas do destaque (`HighlightAlertCenter`, `HighlightNotifications`, [FSC-020](../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)) | todas as features |

Os models das abas e das rotas recebem o `PublicDataService` do `FiscalServices.publicData()` (o `PublicDataClient`, ou o `ShowcasePublicData` quando o app abre com `-FiscalDataScenario <nome>` em Debug) e os repositórios da `SessionModel`. Cada um guarda a fase (`PublicDataPhase`: carregando, carregado ou o `PublicDataError`) e a tela usa o `PublicDataContent` para mostrar carregando, erro com "Tentar novamente" ou o estado vazio honesto.

## Widgets

A extensão `FiscalWidgets` (só iOS) usa o produto `FiscalWidgetKit` do pacote (`FiscalDomain`, `FiscalData` e `FiscalDesignSystem`), sem as features. Traz os widgets de representantes, da votação e do destaque e a Atividade ao Vivo do destaque, com o bonequinho gravado pelo app no App Group. A Atividade da disputa saiu até a próxima eleição ([ADR 0028](adr/0028-app-reads-only-from-cdn-and-local-alerts.md)). Lê o App Group `group.com.byescaleira` (lugar de casa, política de versão, retratos) e os dados públicos pela mesma CDN do app (`FiscalDataURL`); o idioma é fixado em pt-BR por `FiscalLanguage.install()`.

## Servidor e dados públicos

```text
fontes oficiais ─▶ fiscal-ingest (cadência, SQLite) ─▶ release v2 ─┐
TSE ao vivo ─▶ fiscal-api (races.json) ─────────────────────────────┴▶ fiscal-pages ─▶ Cloudflare Pages (dados.fiscal.byescaleira.com/v2) ─▶ app
```

- Nada é calculado por acesso: o servidor prepara e publica arquivos estáticos ([ADR 0002](adr/0002-static-first-server.md)); cada fonte é lida no seu ritmo e só quando muda ([ADR 0008](adr/0008-smart-sync.md)), com o histórico num SQLite ([ADR 0006](adr/0006-ingest-sqlite-store.md)) e a CDN no Pages ([ADR 0007](adr/0007-pages-cdn-phased-ingest.md)).
- O app só lê a CDN: o único endereço de dados é `FiscalDataURL`, na pasta `v2`, sem reserva na VPS. Se a CDN cair, o app usa o cache HTTP, depois o pacote offline e depois mostra o erro ([ADR 0028](adr/0028-app-reads-only-from-cdn-and-local-alerts.md)).
- Nenhum dado sai do aparelho para o servidor: não há registro de token, App Attest nem push. A VPS só alimenta a CDN, com o `fiscal-ingest` (carga), o `fiscal-api` (leitura do TSE, publica `races.json` e responde a saúde só em `127.0.0.1`) e o `fiscal-pages` (publicação). O servidor sem push vale na VPS depois do deploy desta mudança, que ainda não aconteceu.
- Os alertas do destaque são agendados no aparelho: a cada abertura, o app lê `highlights.json` na CDN e agenda a próxima Atividade ao Vivo e, se a pessoa ligou "Notificação de destaque", uma notificação local com o segundo destaque. O horário é o que o aparelho aprende pelo hábito de abertura, com 08:00 e 19:00 só sem histórico. O histórico de aberturas, o plano e os ids já mostrados ficam no App Group, fora do iCloud, e nunca saem do aparelho ([FSC-020](../spdd/prompt/FSC-020-202611042045-[Feat]-app-reads-only-from-cdn-and-local-alerts.md)).
- Os detalhes estão em [`FSC-002`](../spdd/prompt/FSC-002-202610291700-[Codify]-public-data-api.md), [`FSC-001`](../spdd/prompt/FSC-001-202610291700-[Codify]-live-results.md), no `server/README.md` e no [runbook](server-runbook.md).

## Links

| Link | Abre |
| --- | --- |
| `fiscal://feed`, `votes`, `money`, `region`, `search` | A aba (Feed, Votações, Dinheiro, Região, Fiscalizar) |
| `fiscal://today`, `mine` | Apelidos antigos: Feed e Região |
| `fiscal://following` | Quem você segue, no Feed |
| `fiscal://person/<slug>` | Perfil, na aba Região |
| `fiscal://vote/<id>` | Votação, na aba Votações |
| `fiscal://expenses/<slug>?year=<ano>` | Recibos, na aba Dinheiro |
| `fiscal://compare?slugs=<a>,<b>` | Comparar, em Fiscalizar |
| `fiscal://races` | Apuração, em Fiscalizar |
| `fiscal://memory`, `election/<ano>`, `period/<id>`, `study/<id>` | Memória, em Fiscalizar |
| `fiscal://support` (e o antigo `fiscal://lens`), `fiscal://artists` | "Meu apoio" e artistas, no Feed |
| `fiscal://settings` | Ajustes, no Feed |

Link com host desconhecido abre o Feed.

## Receita: nova feature

Siga `references/architecture.md › Receita: adicionar uma feature` da skill `byescaleira-sdd`: domínio, dados, target `Feature<Nome>` com model e telas, `Package.swift`, `Route`/`AppSection`, flag se não estiver pronta, testes e `TestableReference` no scheme `FiscalKitTests`, textos em pt-BR (`scripts/strings.sh`). A mudança começa em `docs/changes/<id>/`, termina com a spec da capacidade em `docs/specs/` e as decisões em `docs/adr/`.
