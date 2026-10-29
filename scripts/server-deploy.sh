#!/bin/bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
server="$project_root/server"
host="${FISCAL_VPS:-root@179.198.114.91}"
remote="${FISCAL_REMOTE_DIR:-/opt/fiscal-api}"
goarch="${FISCAL_GOARCH:-amd64}"
apply=0
only="api ingest pages units"
usage() {
  cat <<'EOF'
Uso: scripts/server-deploy.sh [--apply] [--only "api ingest pages units"]

Sem --apply, só imprime o plano (nada é enviado nem executado na VPS).
Com --apply, precisa do ok explícito do usuário a cada vez (AGENTS.md).

  api     imagem fiscal-api, troca sem queda com healthcheck e rollback automático
  ingest  imagem fiscal-ingest (o timer usa a nova na próxima execução)
  pages   imagem fiscal-pages (wrangler fixado no Dockerfile)
  units   compose.yaml e as units do systemd (fiscal-sync.timer, a cada 5 min)
EOF
}
while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1 ;;
    --only) shift; only="$1" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Opção desconhecida: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done
for part in $only; do
  case "$part" in api|ingest|pages|units) ;; *) echo "Parte desconhecida: $part" >&2; exit 2 ;; esac
done
want() { case " $only " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
sha="$(git -C "$project_root" rev-parse --short=12 HEAD)"
marketing="$(sed -n 's/.*MARKETING_VERSION = \([0-9][0-9.]*\);.*/\1/p' "$project_root/Fiscal/Fiscal.xcodeproj/project.pbxproj" | head -n 1)"
version="$(git -C "$project_root" describe --tags --match 'v[0-9]*' --exact-match 2>/dev/null | sed 's/^v//' || true)"
[ -n "$version" ] || version="${marketing:-0.0.0}+$sha"
if [ -n "$(git -C "$project_root" status --porcelain -- server scripts/server-deploy.sh)" ]; then
  echo "server/ tem mudanças sem commit; faça o commit antes do deploy." >&2
  [ "$apply" = 1 ] && exit 1
fi
stage="$project_root/server/.dist/$sha"
plan() { printf '  %s\n' "$*"; }
run() {
  if [ "$apply" = 1 ]; then "$@"; else plan "$*"; fi
}
remote_run() {
  if [ "$apply" = 1 ]; then ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" "$1"; else plan "ssh $host '$1'"; fi
}
echo "Fiscal deploy $version ($sha) -> $host:$remote (linux/$goarch)"
[ "$apply" = 1 ] || echo "Modo plano (sem --apply): nada é executado."
echo "1. Compilar no Mac (sem compilar na VPS)"
run rm -rf "$stage"
run mkdir -p "$stage/bin" "$stage/docker" "$stage/systemd"
for target in "server:liveresults-server" "ingest:fiscal-ingest" "pages:fiscal-pages"; do
  pkg="${target%%:*}"
  bin="${target##*:}"
  if [ "$apply" = 1 ]; then
    (cd "$server" && GOTOOLCHAIN=go1.26.10 CGO_ENABLED=0 GOOS=linux GOARCH="$goarch" go build -trimpath -ldflags="-s -w -X main.version=$version" -o "$stage/bin/$bin" "./cmd/$pkg")
  else
    plan "(cd server && GOTOOLCHAIN=go1.26.10 CGO_ENABLED=0 GOOS=linux GOARCH=$goarch go build -trimpath -ldflags='-s -w -X main.version=$version' -o .dist/$sha/bin/$bin ./cmd/$pkg)"
  fi
done
run cp "$server"/deploy/docker/*.Dockerfile "$stage/docker/"
run cp "$server"/deploy/systemd/* "$stage/systemd/"
run cp "$server/compose.yaml" "$stage/compose.yaml"
run cp "$server/deploy/promote-image.sh" "$stage/promote-image.sh"
echo "2. Enviar binários, Dockerfiles, compose e units (sem tocar em .env, secrets/, data/, ingest-data/, public/)"
remote_run "mkdir -p $remote/builds/$sha"
run rsync -a --delete "$stage/" "$host:$remote/builds/$sha/"
echo "3. Montar as imagens na VPS com prioridade mínima (só COPY dos binários; sem go build)"
build_image() {
  remote_run "cd $remote/builds/$sha && nice -n 19 ionice -c3 docker build -q --label fiscal.sha=$sha -f docker/$1.Dockerfile -t fiscal-$1:$sha ."
}
want api && build_image api
want ingest && build_image ingest
want pages && build_image pages
promote() {
  remote_run "sh $remote/builds/$sha/promote-image.sh $1 $sha"
}
if want units; then
  echo "4. compose.yaml e units"
  remote_run "cd $remote && cp -p compose.yaml compose.yaml.bak.$sha 2>/dev/null; install -m 0644 builds/$sha/compose.yaml compose.yaml && mkdir -p pages-data && chown 1000:1000 pages-data && chmod 700 pages-data"
  remote_run "install -m 0644 $remote/builds/$sha/systemd/* /etc/systemd/system/ && systemctl daemon-reload"
  remote_run "docker rm -f fiscal-ingest 2>/dev/null || true"
  remote_run "for t in /etc/systemd/system/fiscal-phase-*.timer /etc/systemd/system/fiscal-live.timer; do [ -e \$t ] || continue; systemctl disable --now \$(basename \$t); rm -f \$t; done; rm -f /etc/systemd/system/fiscal-live.service; systemctl daemon-reload"
  remote_run "systemctl enable --now fiscal-sync.timer"
  plan "(fiscal-pages.timer fica desligado; ligue só em dia de apuração: systemctl enable --now fiscal-pages.timer)"
fi
if want ingest; then
  echo "5. fiscal-ingest: promover e conferir a configuração"
  promote ingest
  remote_run "cd $remote && docker compose --profile jobs run --rm --no-deps -T fiscal-ingest -config-check"
fi
if want pages; then
  echo "6. fiscal-pages: promover e conferir a configuração e o token"
  promote pages
  remote_run "cd $remote && docker compose --profile jobs run --rm --no-deps -T fiscal-pages -config-check"
fi
if want api; then
  echo "7. fiscal-api: troca com healthcheck e rollback automático"
  promote api
  remote_run "cd $remote && docker compose up -d --no-deps fiscal-api"
  check="for i in \$(seq 1 30); do s=\$(docker inspect -f '{{.State.Health.Status}}' fiscal-api 2>/dev/null); [ \"\$s\" = healthy ] && exit 0; sleep 3; done; exit 1"
  if [ "$apply" = 1 ]; then
    if ! ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" "$check"; then
      echo "fiscal-api não ficou saudável; voltando para a imagem anterior." >&2
      ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" "docker tag fiscal-api:previous fiscal-api:current && cd $remote && docker compose up -d --no-deps fiscal-api"
      exit 1
    fi
    ssh -o BatchMode=yes -o ConnectTimeout=15 "$host" "curl -fsS http://127.0.0.1:3130/api/health"
    echo
  else
    plan "ssh $host '<espera até 90 s por healthy; se falhar: docker tag fiscal-api:previous fiscal-api:current && docker compose up -d --no-deps fiscal-api>'"
    plan "ssh $host 'curl -fsS http://127.0.0.1:3130/api/health'"
  fi
fi
echo "Pronto. Voltar uma imagem: ssh $host 'docker tag fiscal-<api|ingest|pages>:previous fiscal-<...>:current' (e, para a api, docker compose up -d --no-deps fiscal-api)."
