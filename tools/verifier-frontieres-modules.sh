#!/usr/bin/env bash
# Vérifie les frontières de modules imposées par l'ADR 0002.
#
# Deux règles :
#   1. un module ne référence jamais un autre module ;
#   2. un module ne référence jamais l'Infrastructure — la dépendance va dans l'autre
#      sens, l'Infrastructure implémentant les contrats des modules.
#
# Contrôle statique sur les fichiers projet : plus rapide et plus lisible qu'une analyse
# d'assemblages, et suffisant puisque toute dépendance passe par une ProjectReference.

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API="$RACINE/api/src"
violations=0

for projet in "$API"/PartyPlan.Modules.*/*.csproj; do
  module="$(basename "$(dirname "$projet")")"

  while read -r reference; do
    [ -z "$reference" ] && continue
    cible="$(basename "$reference" .csproj)"

    case "$cible" in
      PartyPlan.SharedKernel)
        ;;
      "$module")
        ;;
      PartyPlan.Modules.*)
        echo "VIOLATION : $module référence $cible (ADR 0002 : passer par l'interface publique)."
        violations=$((violations + 1))
        ;;
      PartyPlan.Infrastructure)
        echo "VIOLATION : $module référence l'Infrastructure (la dépendance va dans l'autre sens)."
        violations=$((violations + 1))
        ;;
      *)
        echo "VIOLATION : $module référence $cible, hors des dépendances autorisées."
        violations=$((violations + 1))
        ;;
    esac
  done < <(grep -oP '(?<=ProjectReference Include=")[^"]+' "$projet" 2>/dev/null | tr '\\' '/')
done

if [ "$violations" -gt 0 ]; then
  echo
  echo "$violations violation(s) des frontières de modules."
  exit 1
fi

echo "Frontières de modules respectées : $(ls -d "$API"/PartyPlan.Modules.* | wc -l) modules contrôlés."
