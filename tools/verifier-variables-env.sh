#!/usr/bin/env bash
# Vérifie que toute clé de configuration lue par le code est déclarée dans les fichiers
# d'exemple, et inversement (NF-OPS-09, RG-DEV-02).
#
# Une variable ajoutée au code sans être déclarée se découvre au premier démarrage en
# production, au plus mauvais moment. Une variable déclarée que plus rien ne lit trompe
# la personne qui configure le serveur.

set -uo pipefail

RACINE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RACINE"

# Sections d'options liées par le code : `Bind(configuration.GetSection(X.SectionName))`.
# On relève les valeurs de SectionName déclarées dans les classes d'options.
sections_lues() {
  grep -rhoE 'SectionName = "[A-Za-z]+"' api/src --include="*.cs" \
    | grep -oE '"[A-Za-z]+"' | tr -d '"' | sort -u
}

# Clés lues directement, sous la forme configuration["Section:Cle"].
cles_directes() {
  grep -rhoE 'configuration\["[A-Za-z]+:[A-Za-z]+"\]' api/src --include="*.cs" \
    | sed 's/configuration\["//; s/"\]//' | sort -u
}

# Variables déclarées dans les fichiers d'exemple, converties en clés de configuration :
# la convention .NET veut que SECTION__CLE corresponde à Section:Cle.
declarees() {
  grep -hoE '^[A-Za-z_]+=' .env.example infra/compose/.env.example 2>/dev/null \
    | tr -d '=' | sort -u
}

# Variables réellement injectées dans le conteneur d'API par les fichiers Compose.
injectees() {
  grep -hoE '^ +[A-Za-z]+__[A-Za-z_]+:' infra/compose/compose.yml infra/compose/compose.example.yml 2>/dev/null \
    | tr -d ' :' | sort -u
}

manquantes=0

echo "Sections d'options déclarées par le code :"
for section in $(sections_lues); do
  # Une section est satisfaite si au moins une variable injectée la préfixe.
  if injectees | grep -q "^${section}__"; then
    printf "  OK  %s\n" "$section"
  else
    printf "  NON %s — aucune variable %s__* injectée par les fichiers Compose\n" \
      "$section" "$section"
    manquantes=$((manquantes + 1))
  fi
done

echo
echo "Clés lues directement :"
for cle in $(cles_directes); do
  variable="$(echo "$cle" | tr ':' '_' | tr '[:lower:]' '[:upper:]')"
  section="${cle%%:*}"
  if injectees | grep -q "^${section}__" || declarees | grep -qi "^${variable}$"; then
    printf "  OK  %s\n" "$cle"
  else
    printf "  NON %s — ni injectée, ni déclarée\n" "$cle"
    manquantes=$((manquantes + 1))
  fi
done

echo
echo "Variables déclarées mais jamais lues :"
inutilisees=0
for variable in $(declarees); do
  # Variables d'infrastructure, sans contrepartie dans le code applicatif.
  case "$variable" in
    ACME_EMAIL|DB_PORT|API_PORT|WEB_PORT|LANDING_PORT|MAILPIT_UI_PORT|MAILPIT_SMTP_PORT|\
    DOMAIN_APP|DOMAIN_API|DOMAIN_CDN|DOMAIN_LANDING|GHCR_OWNER|API_TAG|APP_TAG|LANDING_TAG|\
    POSTGRES_DB|POSTGRES_USER|POSTGRES_PASSWORD|ASPNETCORE_ENVIRONMENT|SEED_DEMO)
      continue
      ;;
  esac

  # Correspondance : JWT_SIGNING_KEY → Jwt__SigningKey, injecté par Compose.
  #
  # La comparaison se fait sur les suffixes : une variable peut porter un nom sans le
  # préfixe de sa section, comme FIREBASE_SERVICE_ACCOUNT_JSON injecté sous
  # Push__FirebaseServiceAccountJson. Exiger l'égalité stricte produirait un faux
  # positif, et un faux positif toléré finit par faire ignorer l'outil.
  compacte="$(echo "$variable" | tr -d '_' | tr '[:upper:]' '[:lower:]')"
  trouve=0

  while read -r injectee; do
    plate="$(echo "$injectee" | tr -d '_' | tr '[:upper:]' '[:lower:]')"
    case "$plate" in
      *"$compacte") trouve=1 ;;
    esac
  done < <(injectees)

  if [ "$trouve" -eq 0 ]; then
    printf "  --  %s — déclarée en avance, aucun code ne la lit encore\n" "$variable"
    inutilisees=$((inutilisees + 1))
  fi
done

[ "$inutilisees" -eq 0 ] && echo "  (aucune)"

echo
if [ "$manquantes" -gt 0 ]; then
  echo "$manquantes clé(s) lue(s) par le code sans être déclarée(s). Voir RG-DEV-02."
  exit 1
fi

echo "Toutes les clés lues par le code sont déclarées."
echo "Les variables marquées « -- » sont anticipées : voir docs/comptes-externes.md."
