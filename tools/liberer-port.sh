#!/usr/bin/env bash
# Vérifie qu'un port est libre avant de lancer un service, et nomme le coupable.
#
# Le message de Kestrel — « address already in use » — n'indique ni le processus
# fautif ni la commande pour le récupérer. Une session `dotnet watch` oubliée, ou
# lancée depuis Rider, laisse le port occupé et fait échouer le lancement suivant.
#
#   ./tools/liberer-port.sh 5080            diagnostic, échoue si occupé
#   ./tools/liberer-port.sh 5080 --tuer     termine le processus occupant

set -uo pipefail

PORT="${1:?Usage: liberer-port.sh <port> [--tuer]}"
ACTION="${2:-}"

occupants() {
  ss -ltnpH "sport = :$PORT" 2>/dev/null \
    | grep -oP 'pid=\K[0-9]+' \
    | sort -u
}

PIDS=$(occupants)

if [ -z "$PIDS" ]; then
  exit 0
fi

echo "Le port $PORT est déjà occupé :" >&2
for pid in $PIDS; do
  echo "  pid $pid — $(tr -d '\0' < "/proc/$pid/cmdline" 2>/dev/null | cut -c1-110)" >&2
done

if [ "$ACTION" = "--tuer" ]; then
  echo >&2
  for pid in $PIDS; do
    kill "$pid" 2>/dev/null && echo "  pid $pid terminé" >&2
  done
  sleep 2
  for pid in $(occupants); do
    kill -9 "$pid" 2>/dev/null && echo "  pid $pid forcé" >&2
  done
  sleep 1
  [ -z "$(occupants)" ] && { echo "Port $PORT libéré." >&2; exit 0; }
  echo "Le port $PORT reste occupé." >&2
  exit 1
fi

echo >&2
echo "Deux possibilités :" >&2
echo "  make stop-api     termine le processus qui occupe le port" >&2
echo "  API_PORT=5081 …   utilise un autre port" >&2
exit 1
