#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
project="fiscal-site"
wrangler="wrangler@4.149.0"
apply=0
usage() {
  cat <<'EOF'
Uso: scripts/site-publish.sh [--apply]

Monta o site numa pasta temporária e mostra o plano da publicação no
projeto fiscal-site da Cloudflare Pages. Sem --apply, nada é enviado.
Com --apply, precisa do ok explícito do usuário a cada vez (AGENTS.md)
e do login do wrangler, feito pelo usuário no app Terminal.
EOF
}
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
cd "$project_root"
problems=()
branch="$(git branch --show-current)"
[ "$branch" = development ] || problems+=("a branch é '$branch'; publique da 'development'")
if [ -n "$(git status --porcelain -- site scripts/site-build.mjs scripts/site-publish.sh scripts/site-i18n.py)" ]; then
  problems+=("há mudanças sem commit em site/ ou nos scripts do site")
fi
if ! python3 scripts/site-i18n.py check >/dev/null; then
  problems+=("o scripts/site-i18n.py check encontrou problemas")
fi
if [ ${#problems[@]} -gt 0 ]; then
  echo "Nada foi publicado:" >&2
  printf '  - %s\n' "${problems[@]}" >&2
  exit 1
fi
output="$(mktemp -d)"
trap 'rm -rf "$output"' EXIT
if ! files="$(node scripts/site-build.mjs "$output")"; then
  echo "Nada foi publicado: a montagem falhou." >&2
  exit 1
fi
sha="$(git rev-parse HEAD)"
echo "Projeto: $project (Cloudflare Pages), branch main"
echo "Commit: $sha"
echo "Arquivos ($(printf '%s\n' "$files" | wc -l | tr -d ' ')):"
printf '%s\n' "$files" | sed 's/^/  /'
if [ "$apply" = 0 ]; then
  echo "Modo plano (sem --apply): nada foi enviado."
  exit 0
fi
if ! npx --yes "$wrangler" whoami >/dev/null 2>&1; then
  echo "Não deu para confirmar o login do wrangler (login ou rede). Se faltar o login, faça no app Terminal: npx --yes $wrangler login" >&2
  exit 1
fi
npx --yes "$wrangler" pages deploy "$output" --project-name "$project" --branch main --commit-hash "$sha" --commit-dirty=false
