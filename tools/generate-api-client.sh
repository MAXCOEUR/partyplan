#!/usr/bin/env bash
# Génère le client Dart de l'API depuis le contrat OpenAPI.
#
# Le contrat est la source : un client écrit à la main dérive du serveur sans que rien
# ne le signale. La génération passe par un conteneur, afin de ne pas imposer Java sur
# le poste.
#
#   ./tools/generate-api-client.sh                  # API locale
#   API_URL=https://api.partyplan.maxencecoeur.fr ./tools/generate-api-client.sh

set -euo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
API_URL="${API_URL:-http://localhost:5080}"
CONTRAT="$RACINE/docs/api/openapi.json"
SORTIE="$RACINE/app/packages/partyplan_api"

echo "→ récupération du contrat depuis $API_URL/openapi/v1.json"
if ! curl -fsS "$API_URL/openapi/v1.json" -o "$CONTRAT"; then
  echo "ECHEC : l'API ne répond pas. Démarrer 'make api' ou 'make up' d'abord." >&2
  exit 1
fi

# L'adresse du serveur dépend du poste qui a généré le contrat : la neutraliser
# évite un diff parasite à chaque régénération.
python3 - "$CONTRAT" <<'PYTHON'
import json, sys, pathlib
chemin = pathlib.Path(sys.argv[1])
contrat = json.loads(chemin.read_text())
contrat["servers"] = [
    {"url": "https://api.partyplan.maxencecoeur.fr", "description": "Production"}
]
chemin.write_text(json.dumps(contrat, indent=2, ensure_ascii=False) + "\n")
PYTHON

echo "→ contrat enregistré dans docs/api/openapi.json ($(wc -l < "$CONTRAT") lignes)"

echo "→ génération du client Dart"
docker run --rm \
  -v "$RACINE:/local" \
  -u "$(id -u):$(id -g)" \
  openapitools/openapi-generator-cli:latest generate \
    -i /local/docs/api/openapi.json \
    -g dart-dio \
    -o /local/app/packages/partyplan_api \
    --additional-properties=pubName=partyplan_api,pubAuthor=PartyPlan,nullableFields=true

echo "→ client généré dans ${SORTIE#"$RACINE/"}"
echo
echo "Le contrat versionné dans docs/api/openapi.json sert de trace de revue :"
echo "un changement d'API doit apparaître dans le diff de la pull request."
