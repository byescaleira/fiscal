# Fiscal

Guia para qualquer agente de código (Claude Code, Codex, Cursor e afins) e para quem chega ao repositório. É a fonte compartilhada das regras, dos comandos e da estrutura; o `CLAUDE.md` importa este arquivo e acrescenta só o que é do Claude Code.

App SwiftUI para iOS, iPadOS, macOS e visionOS 27, com SwiftData local e sincronização CloudKit (`iCloud.fiscal`) em aparelhos assinados, site público em `fiscal.byescaleira.com` e o Fiscal na Web em `/app`.

## Regras

- **Constituição:** [docs/constitution.md](docs/constitution.md) traz as regras inegociáveis (processo, arquitetura, código, design, textos, verificação, git, aprovação humana). Ela vence qualquer outro texto do repositório.
- **Idioma:** responda em pt-BR, inclusive nas notas de andamento; código, chaves de texto, nomes de tipos e commits em inglês.
- **Código:** zero comentários, zero warnings, Swift Testing para toda lógica nova, tokens do design system em vez de números soltos.
- **Aprovação humana:** push para `main` ou `development`, merge na `main`, envio para a App Store ou o TestFlight, publicação do site e deploy na VPS só com o ok explícito do usuário, pedido a cada vez.
- **CI:** Xcode Cloud (`ci_scripts/`). O repositório não usa GitHub Actions.
- **Simulador:** só pelo sim-monitor ou por `scripts/simulator.sh acquire/release <udid>`, no máximo dois ligados na máquina; verificação visual no iPhone físico quando houver.
- **Cache de build:** `~/Library/Developer/FiscalBuild`, ou `FISCAL_BUILD_ROOT` próprio por agente em paralelo; um build pesado por vez.

## Fluxo de trabalho (spec-driven)

1. **Specs vivas** em [docs/specs/](docs/specs/README.md): um arquivo por capacidade, sempre com a verdade atual do app.
2. **Mudanças** em [docs/changes/](docs/changes/README.md): cada mudança ganha `docs/changes/<id>/` com `proposal.md` (por quê e o quê), `design.md` (como) e `tasks.md` (etapas), copiados de `docs/changes/_template/`. Para tela existente, crítica honesta antes de redesenhar.
3. **Implementação** seguindo o `tasks.md`, com verificação por etapa. "Em etapas" quer dizer parar e esperar o ok entre uma etapa e outra.
4. **Arquivamento:** com a mudança entregue, aplique o que ela muda em `docs/specs/` e mova a pasta para `docs/changes/archive/<AAAA-MM-DD>-<id>/`.
5. **Decisões** de arquitetura, dados, dependências, plataforma ou exceções do lint e da auditoria viram um ADR em [docs/adr/](docs/adr/README.md). O `docs/decisions.md` é só o histórico de antes dos ADRs.

## Caminho rápido

1. **Dimensione antes de começar:** S (uma sessão, sem dado nem tela nova), M (duas ou três etapas) ou L (quatro ou mais, dado novo, serviço externo ou plataforma). S vai direto ao código com uma linha no `tasks.md` ou no commit; M e L passam por `docs/changes/<id>/`. O tamanho de cada fase fica no [roadmap](docs/roadmap.md), com a 1.0 em até ~8 fases.
2. **Padrão em vez de pergunta:** quando a constituição, a skill `byescaleira-sdd` ou o template já respondem, siga e diga o que escolheu no relatório. Pergunte só o que muda produto, dinheiro, dados da pessoa ou o que é publicado, com a opção recomendada primeiro.
3. **Uma rodada de revisão por fase:** revisores de código e de design uma vez, no fim da fase, com as correções na mesma fase; não reabra etapas já aprovadas.
4. **Checkpoint no fim da fase:** `scripts/verify.sh --full`, commit da fase, `tasks.md` e specs em dia, e um relatório curto (o que mudou, o que não foi verificado, decisões pendentes). Em trabalho "em etapas", pare ali e espere o ok.

## Comandos

| Comando | Para quê |
| --- | --- |
| `scripts/verify.sh --quick [ios\|macos\|visionos]` | Durante o trabalho: build da plataforma (iOS por padrão), testes dos alvos afetados e checagens da web |
| `scripts/verify.sh --full` | Uma vez, antes do merge da fase: lint, build das três plataformas, suíte inteira, web, admin e auditoria |
| `scripts/format.sh` | Formata o Swift (`--check` só confere) |
| `scripts/lint.sh` | Formatação e SwiftLint estrito (`.swiftlint.yml`) |
| `scripts/build.sh Debug [ios\|macos\|visionos]` | Build das três plataformas, ou de uma |
| `scripts/test.sh [--affected]` | Suíte `FiscalKitTests` no simulador (só os alvos afetados com `--affected`) |
| `scripts/ui-test.sh` | `FiscalUITests` |
| `scripts/strings.sh` | Sincroniza o `Localizable.xcstrings` com os textos do último `scripts/build.sh Debug`; o catálogo é só `pt-BR` ([ADR 0003](docs/adr/0003-portuguese-only.md)) |
| `scripts/audit.sh` | Auditoria do pacote (pula enquanto não houver o `FiscalAudit`) |
| `scripts/simulator.sh acquire\|release <udid>`, `status` | Reserva, devolve e lista simuladores (limite de 2) |
| `scripts/icons.sh`, `python3 scripts/animations.py` | Ícone e animações Lottie |
| `python3 -I scripts/art.py check\|fetch` | Checa a licença e baixa o acervo em domínio público (`art-credits.json`, `Art.xcassets`) |
| `node scripts/site-server.mjs` | Site e ponte em `http://127.0.0.1:4173` |
| `python3 scripts/site-i18n.py extract\|check` | Textos do site nos 10 idiomas |
| `node --test bridge/server.test.mjs site/web-crypto.test.mjs` | Testes da ponte e da cifra |
| `cd admin && npm ci --ignore-scripts && node --test test/*.test.mjs` | Testes do admin |

Durante o trabalho e antes de cada commit, `scripts/verify.sh --quick`; uma vez antes do merge da fase, `scripts/verify.sh --full` (`scripts/ui-test.sh` quando a mudança tocar fluxos de interface). Nunca diga que verificou o que não verificou.

## Estrutura

```text
fiscal/
├── AGENTS.md, CLAUDE.md           regras para agentes (este arquivo e as notas do Claude Code)
├── .claude/                       settings.json (permissões e plugin) e launch.json (preview do site)
├── .byescaleira-sdd.json                configuração da auditoria do plugin
├── Fiscal.xcworkspace            projeto + pacote; scheme compartilhado FiscalKitTests
├── Fiscal/                       projeto Xcode fino, app, FiscalWidgets e FiscalUITests
├── FiscalKit/                    pacote com um target por feature (Sources/<Target>, Tests/<Target>Tests)
├── site/, bridge/, admin/         site público com o Fiscal na Web, ponte cifrada e painel na VPS
├── scripts/, ci_scripts/          ferramentas locais e Xcode Cloud
└── docs/                          constituição, specs, mudanças, ADRs e guias
```

## Documentação

- [Constituição](docs/constitution.md), [specs](docs/specs/README.md), [mudanças](docs/changes/README.md), [ADRs](docs/adr/README.md) e o [histórico de decisões](docs/decisions.md).
- [Arquitetura](docs/architecture.md), [design system](docs/design-system.md), [modelo de spec](docs/spec-template.md), [backlog](docs/backlog.md) e [roadmap](docs/roadmap.md).
- [Atualização obrigatória](docs/force-update.md), [site e web](docs/web.md), [admin](docs/admin.md), [validação antes de distribuir](docs/validation.md) e [App Store](docs/app-store/README.md).
- Padrão completo dos apps (processo, arquitetura, design, textos, testes, release): skill `byescaleira-sdd` do plugin `byescaleira-workspace`.

## Git flow

`main` (loja), `development` (integração) e `feature/<assunto>` saindo da `development` e voltando com `git merge --no-ff`. Nunca commite direto na `main` ou na `development`; `main` só por merge pedido pelo usuário. Frentes independentes em paralelo usam um worktree por frente, com `FISCAL_BUILD_ROOT` próprio e sem simulador.
