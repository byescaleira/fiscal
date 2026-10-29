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
└── docs/                        constitution, specs/, changes/, adr/, este arquivo, design-system, backlog, roadmap
```

## Targets

| Target | Responsabilidade | Depende de |
| --- | --- | --- |
| `FiscalDomain` | Valores (`CalendarDay`; `YearMonth`, `GregorianCalendar` e o idioma vêm do `ByescaleiraFoundation`, reexportado, com o pt-BR fixado por `FiscalLanguage.install()`), protocolos de repositório (`LensRepository`, `FollowRepository`), `FiscalError`, `RemoteFlag`; em `PublicData/`, os tipos dos [dados públicos](specs/public-data-api.md) (`PersonCard`, `Profile`, `VoteSummary`, `VoteDetail`, `MoneyOverview`, `TodayDigest`…), `Theme`, `Lens`, `PublicDataService`, `PublicDataError` e `PublicFormat` (centavos em reais, "—" para dado ausente); em `LiveResults/`, `Race` e a Atividade ao Vivo; em `Integrations/`, o que widgets e intents compartilham | `ByescaleiraFoundation` |
| `FiscalData` | `FiscalDatabase` (SwiftData em duas configurações: `Fiscal` com CloudKit `iCloud.fiscal` para os seguidos e as investigações e `Device`, só no aparelho, para a Lente; [ADR 0004](adr/0004-lens-on-device-store.md)), `FiscalStore` (`@ModelActor`), entidades `@Model`, schema versionado, repositórios, `CloudKitFlagSource`; em `PublicData/`, o `PublicDataClient`, o `PublicDataLayout` (`v2`), o pacote offline e, em Debug, o `ShowcasePublicData` com `-FiscalDataScenario normal\|empty\|offline\|longNames\|unavailable`; em `LiveResults/`, o `LiveResultsClient` e o `AppAttestor` | Domain |
| `FiscalDesignSystem` | Reexporta `ByescaleiraDesign`, `ByescaleiraCharts`, `ByescaleiraAccessibility` e `ByescaleiraPlatform` e guarda só o que é do Fiscal: partidos, placar, retratos, paletas da Lente e tokens dos cartazes | byescaleira-kit |
| `FiscalResource` | Animações Lottie (`FiscalResourceAnimation`), acervo de arte (`art-credits.json`, `Art.xcassets`), mapas do Brasil, molde e traços dos retratos, selo de partido e os dados de teste do showcase | nada |
| `FeatureCore` | `SessionModel`, navegação (`Route`, `AppSection`, `FiscalNavigation`, `\.open`, `\.close`), `FeatureFlag`/`FeatureFlags`, atualização obrigatória, exportação, explicações no aparelho (`Explain/`), componentes de dados públicos (`SourceFootnote`, `PeerBadge`, `PublicDataContent`), retratos e `FiscalAnimationView`; reexporta o `ByescaleiraUI` | Domain, DesignSystem, Resource, `ByescaleiraUI`, Lottie |
| `FeatureGuides` | `GuideScreen` e páginas dos tutoriais | Domain, DesignSystem, FeatureCore |
| `FeatureToday` | Aba Hoje: destaque do momento, resumo do Congresso, votações recentes, card da apuração e os botões da Lente e de Ajustes ([ADR 0014](adr/0014-settings-in-today-toolbar.md)) | Domain, DesignSystem, FeatureCore |
| `FeatureMine` | Aba Região: lugar de casa, quem governa a cidade, o estado e o país, bancadas e seguidos | Domain, DesignSystem, FeatureCore |
| `FeatureProfile` | Perfil (`Route.person(slug:)`), aberto por qualquer aba | Domain, DesignSystem, FeatureCore |
| `FeatureVotes` | Aba Votações: recentes, pauta do dia e detalhe (`Route.vote(id:)`) | Domain, DesignSystem, FeatureCore |
| `FeatureMoney` | Aba Dinheiro e recibos (`Route.expenses`) | Domain, DesignSystem, FeatureCore |
| `FeatureSearch` | Aba Fiscalizar (`Tab(role: .search)`): busca no índice, Comparar (`Route.compare(slugs:)`), Eleições e investigações | Domain, DesignSystem, FeatureCore |
| `FeatureMemory` | Memória, em Fiscalizar: eleições desde 1989, períodos da política e guias de estudo (`Route.memory`, `pastElection`, `period`, `studyGuide`) | Domain, DesignSystem, FeatureCore |
| `FeatureLens` | Lente (`Route.lens`): setup, edição, aparência e "Outra lente" ([lens.md](specs/lens.md)) | Domain, DesignSystem, Resource, FeatureCore |
| `FeatureShare` | Cartazes de compartilhar e galeria de artistas (`Route.artists`) ([share-cards-and-art.md](specs/share-cards-and-art.md)) | Domain, DesignSystem, Resource, FeatureCore |
| `FeatureLiveResults` | Apuração (`Route.races`) e as Atividades ao Vivo da disputa e do destaque ([live-results.md](specs/live-results.md), [notifications.md](specs/notifications.md)) | Domain, DesignSystem, FeatureCore |
| `FeatureSettings` | Ajustes: Seu Fiscal, Aparência, Seus dados e privacidade, Fontes e método, Sobre e Desenvolvedor | Domain, DesignSystem, Resource, FeatureCore |
| `AppShell` | `FiscalWindow`, `MainScreen`, `SectionStack`, `SectionScreen`, `RouteScreen`, `InspectorScreen`, `SplashScreen`/`LaunchProgress`, `DeepLinks`, `FiscalServices`, `OfflineDataCenter`, App Intents e Spotlight | todas as features |

Os models das abas e das rotas recebem o `PublicDataService` do `FiscalServices.publicData()` (o `PublicDataClient`, ou o `ShowcasePublicData` quando o app abre com `-FiscalDataScenario <nome>` em Debug) e os repositórios da `SessionModel`. Cada um guarda a fase (`PublicDataPhase`: carregando, carregado ou o `PublicDataError`) e a tela usa o `PublicDataContent` para mostrar carregando, erro com "Tentar novamente" ou o estado vazio honesto.

## Widgets

A extensão `FiscalWidgets` (só iOS) usa o produto `FiscalWidgetKit` do pacote (`FiscalDomain`, `FiscalData` e `FiscalDesignSystem`), sem as features. Traz os widgets de representantes, da votação e do destaque e as Atividades ao Vivo da disputa e do destaque. Lê o App Group `group.com.byescaleira` (lugar de casa, política de versão) e os dados públicos pelos mesmos endereços do app; o idioma é fixado em pt-BR por `FiscalLanguage.install()`.

## Servidor e dados públicos

```text
fontes oficiais ─▶ fiscal-ingest (cadência, SQLite) ─▶ release v2 ─▶ fiscal-pages ─▶ Cloudflare Pages (dados.fiscal.byescaleira.com) ─▶ app
                                                    └▶ arquivos do dia na VPS (fiscal.byescaleira.com/api) ─▶ app
TSE ao vivo ─▶ fiscal-api (apuração, App Attest, registros) ─▶ APNs ─▶ Atividades ao Vivo
```

- Nada é calculado por acesso: o servidor prepara e publica arquivos estáticos ([ADR 0002](adr/0002-static-first-server.md)); cada fonte é lida no seu ritmo e só quando muda ([ADR 0008](adr/0008-smart-sync.md)), com o histórico num SQLite ([ADR 0006](adr/0006-ingest-sqlite-store.md)) e a CDN no Pages ([ADR 0007](adr/0007-pages-cdn-phased-ingest.md)).
- O único endpoint que recebe dado do aparelho é o `fiscal-api`: tokens de push das Atividades ao Vivo, protegidos por App Attest ([ADR 0017](adr/0017-app-store-privacy-label.md)).
- Os detalhes estão em [public-data-api.md](specs/public-data-api.md), [live-results.md](specs/live-results.md), no `server/README.md` e no [runbook](server-runbook.md).

## Links

| Link | Abre |
| --- | --- |
| `fiscal://today`, `mine`, `votes`, `money`, `search` | A aba (Hoje, Região, Votações, Dinheiro, Fiscalizar) |
| `fiscal://person/<slug>` | Perfil, na aba Região |
| `fiscal://vote/<id>` | Votação, na aba Votações |
| `fiscal://expenses/<slug>?year=<ano>` | Recibos, na aba Dinheiro |
| `fiscal://compare?slugs=<a>,<b>` | Comparar, em Fiscalizar |
| `fiscal://races` | Apuração, em Fiscalizar |
| `fiscal://memory`, `election/<ano>`, `period/<id>`, `study/<id>` | Memória, em Fiscalizar |
| `fiscal://lens`, `fiscal://artists` | Lente e artistas, em Hoje |
| `fiscal://settings` | Ajustes, em Hoje |

Link com host desconhecido abre Hoje.

## Receita: nova feature

Siga `references/architecture.md › Receita: adicionar uma feature` da skill `byescaleira-sdd`: domínio, dados, target `Feature<Nome>` com model e telas, `Package.swift`, `Route`/`AppSection`, flag se não estiver pronta, testes e `TestableReference` no scheme `FiscalKitTests`, textos em pt-BR (`scripts/strings.sh`). A mudança começa em `docs/changes/<id>/`, termina com a spec da capacidade em `docs/specs/` e as decisões em `docs/adr/`.
