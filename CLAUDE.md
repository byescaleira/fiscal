@AGENTS.md

## Claude Code

- **Plugin:** `.claude/settings.json` registra o marketplace `byescaleira-workspace` (GitHub `byescaleira/byescaleira-workspace`) e liga o plugin `byescaleira-workspace@byescaleira-workspace` para todo o time. Ao abrir o repositório, aceite a confiança na pasta e a instalação do plugin; confira com `/plugin`.
- **Skills (SPDD):**
  - `/byescaleira-workspace:spdd-analysis`: análise em `spdd/analysis/`.
  - `/byescaleira-workspace:spdd-reasons-canvas`: canvas em `spdd/prompt/` e a parada para o ok.
  - `/byescaleira-workspace:spdd-generate`: gera operação por operação, revisa e abre o PR da fase.
  - `/byescaleira-workspace:spdd-prompt-update`: quando o requisito muda, o canvas muda antes do código.
  - `/byescaleira-workspace:spdd-sync`: depois de uma refatoração, o código muda e o canvas acompanha.
  - `/byescaleira-workspace:spdd-code-review`: desvio contra o canvas, em `spdd/review/`.
  - `/byescaleira-workspace:spdd-reverse`: canvas `[Codify]` de código sem canvas.
  - `/byescaleira-workspace:spdd-story`: histórias em `spdd/requirements/`.
  - `/byescaleira-workspace:spdd-api-test`: teste da ponte e da API em `scripts/test-api.sh`.
- **Outras skills:**
  - `/byescaleira-workspace:adr`: decisão em `docs/adr/`.
  - `/byescaleira-workspace:review`: revisão.
  - `/byescaleira-workspace:constitution`: regras em `docs/constitution.md`.
  - `/byescaleira-workspace:research`: pesquisa com fonte em `docs/research/`.
  - `/byescaleira-workspace:council`: conselho para uma decisão.
  - `/byescaleira-workspace:simulate`: reação de um público simulado.
- **Skill `byescaleira-sdd`:** a do plugin vale em todo trabalho Apple (processo, arquitetura, código, design, idiomas, testes, verificação e release).
- **Histórico congelado:** `docs/specs/`, `docs/changes/` e `docs/decisions.md` não recebem entrada nova ([ADR 0019](docs/adr/0019-spdd-process.md)).
- **Revisores:** no fim de cada fase rodam juntos, numa rodada só:
  - `byescaleira-workspace:spec-reviewer`, pelo `spdd-code-review`, contra o canvas;
  - `byescaleira-workspace:design-reviewer`, que registra a aprovação que libera o commit de interface;
  - `byescaleira-workspace:accessibility-reviewer`;
  - `byescaleira-workspace:code-reviewer`;
  - `byescaleira-workspace:security-reviewer`, quando o diff mexe em rede, cripto, servidor, ponte, admin, entitlements ou dependências.
- **Hooks do plugin:** ao encerrar (`Stop` e `SubagentStop`) roda a auditoria com `.byescaleira-sdd.json` e bloqueia com violações; antes de `git commit` ou `git merge` com interface, exige a aprovação do revisor de design.
- **Permissões:** `.claude/settings.json` libera os scripts do projeto, `node --test` e `git status`/`diff`/`log`, pergunta antes de `git push` e `ssh`, e bloqueia a leitura de `.env`, `secrets/`, `*.pem` e `*.p8`. Ajustes pessoais vão em `.claude/settings.local.json` e `CLAUDE.local.md`, os dois fora do git.
- **Sandbox:** desligado por padrão, porque `xcodebuild`, simuladores e o sim-monitor precisam de acesso amplo ao sistema. Quem quiser isolar o shell em trabalho só de docs, site ou ponte liga com `/sandbox` ou com `"sandbox": { "enabled": true }` no `.claude/settings.local.json`; o sandbox cobre só os comandos de shell, não as ferramentas de leitura e edição.
- **Preview:** a configuração `site` do `.claude/launch.json` sobe `node scripts/site-server.mjs` na porta 4173.
