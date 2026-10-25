@AGENTS.md

## Claude Code

- **Plugin:** `.claude/settings.json` registra o marketplace `byescaleira-workspace` (GitHub `byescaleira/byescaleira-workspace`) e liga o plugin `byescaleira-workspace@byescaleira-workspace` para todo o time. Ao abrir o repositório, aceite a confiança na pasta e a instalação do plugin; confira com `/plugin`.
- **Skills:** `/byescaleira-workspace:specify` (proposta em `docs/changes/<id>/`), `/byescaleira-workspace:plan` (`design.md`), `/byescaleira-workspace:tasks` (`tasks.md`), `/byescaleira-workspace:implement` (executa as etapas), `/byescaleira-workspace:adr` (decisão em `docs/adr/`), `/byescaleira-workspace:archive` (atualiza `docs/specs/` e arquiva a mudança) e `/byescaleira-workspace:review`. A skill `byescaleira-sdd` do plugin vale em todo trabalho Apple (processo, arquitetura, código, design, idiomas, testes, verificação e release).
- **Revisores:** `byescaleira-workspace:design-reviewer` antes de commitar ou integrar interface (registra a aprovação que libera o commit); `byescaleira-workspace:code-reviewer` ao fim de cada fase ou antes de integrar uma frente.
- **Hooks do plugin:** ao encerrar (`Stop` e `SubagentStop`) roda a auditoria com `.byescaleira-sdd.json` e bloqueia com violações; antes de `git commit` ou `git merge` com interface, exige a aprovação do revisor de design.
- **Permissões:** `.claude/settings.json` libera os scripts do projeto, `node --test` e `git status`/`diff`/`log`, pergunta antes de `git push` e `ssh`, e bloqueia a leitura de `.env`, `secrets/`, `*.pem` e `*.p8`. Ajustes pessoais vão em `.claude/settings.local.json` e `CLAUDE.local.md`, os dois fora do git.
- **Sandbox:** desligado por padrão, porque `xcodebuild`, simuladores e o sim-monitor precisam de acesso amplo ao sistema. Quem quiser isolar o shell em trabalho só de docs, site ou ponte liga com `/sandbox` ou com `"sandbox": { "enabled": true }` no `.claude/settings.local.json`; o sandbox cobre só os comandos de shell, não as ferramentas de leitura e edição.
- **Preview:** a configuração `site` do `.claude/launch.json` sobe `node scripts/site-server.mjs` na porta 4173.
