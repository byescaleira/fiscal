#!/bin/sh
set -u
root="${FISCAL_ALERT_ROOT:-/opt/fiscal-api}"
state="${STATE_DIRECTORY:-/var/lib/fiscal-load-alert}"
ntfy="${FISCAL_NTFY_URL:-https://ntfy.sh}"
result="${SERVICE_RESULT:-}"
failure_limit=6
stale_hours=48

log() { echo "fiscal-load-alert: $1"; }

topic() {
  [ -r "$root/secrets/ntfy-topic" ] || return 1
  value="$(tr -d '[:space:]' < "$root/secrets/ntfy-topic" 2>/dev/null)"
  case "$value" in ""|*[!A-Za-z0-9_-]*) return 1 ;; esac
  printf '%s' "$value"
}

send() {
  name="$(topic)" || { log "tópico ausente ou inválido, aviso não enviado"; return 1; }
  printf 'url = "%s/%s"\n' "$ntfy" "$name" | curl -fsS --max-time 15 -K - -H "Title: $1" -d "$2" >/dev/null 2>&1 \
    || { log "ntfy não respondeu, tenta de novo na próxima execução"; return 1; }
}

data_age_hours() {
  python3 -I -c '
import datetime, json, sys
with open(sys.argv[1]) as meta:
    stamp = datetime.datetime.fromisoformat(json.load(meta)["generatedAt"])
print(int((datetime.datetime.now(datetime.timezone.utc) - stamp).total_seconds() // 3600))
' "$root/public/v1/meta.json" 2>/dev/null
}

if [ "${1:-}" = "--test" ]; then
  send "Fiscal: teste do alerta" "Este é um teste do alerta da carga de dados." || exit 1
  log "teste enviado"
  exit 0
fi

mkdir -p "$state" 2>/dev/null || { log "sem pasta de estado"; exit 0; }
[ -n "$result" ] || { log "sem resultado do serviço"; exit 0; }

failures="$(cat "$state/failures" 2>/dev/null || echo 0)"
case "$failures" in ""|*[!0-9]*) failures=0 ;; esac

if [ "$result" != "success" ]; then
  failures=$((failures + 1))
  echo "$failures" > "$state/failures" 2>/dev/null
  if [ "$failures" -ge "$failure_limit" ] && [ ! -e "$state/notified" ]; then
    send "Fiscal: carga de dados falhou" "A carga falhou $failures vezes seguidas." && touch "$state/notified"
  fi
  exit 0
fi

echo 0 > "$state/failures" 2>/dev/null
age="$(data_age_hours)"
case "$age" in
  ""|*[!0-9-]*)
    log "idade dos dados desconhecida"
    exit 0
    ;;
esac

if [ "$age" -ge "$stale_hours" ]; then
  if [ ! -e "$state/notified" ]; then
    send "Fiscal: dados sem mudar" "A carga termina, mas os dados estão velhos: $age horas sem mudar." && touch "$state/notified"
  fi
  exit 0
fi

if [ -e "$state/notified" ]; then
  send "Fiscal: carga de dados voltou" "A carga voltou a funcionar e os dados estão em dia." && rm -f "$state/notified"
fi
exit 0
