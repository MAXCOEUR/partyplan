#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    printf 'Usage : %s CHEMIN_VERS_KEYSTORE\n' "$0" >&2
    exit 64
fi

for commande in keytool python3; do
    if ! command -v "$commande" >/dev/null 2>&1; then
        printf 'Échec : la commande requise « %s » est introuvable.\n' "$commande" >&2
        exit 69
    fi
done

racine_depot=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
repertoire_android="$racine_depot/app/android"
repertoire_build="$racine_depot/app/build/app"
keystore=$1
fichier_assetlinks="$racine_depot/app/web/.well-known/assetlinks.json"
package_android='fr.maxencecoeur.partyplan'
domaine='partyplan.maxencecoeur.fr'
prefixe='/join/'

if [[ ! -f $keystore ]]; then
    printf 'Échec : keystore introuvable : %s\n' "$keystore" >&2
    exit 66
fi

if [[ ! -x "$repertoire_android/gradlew" ]]; then
    printf 'Échec : wrapper Gradle introuvable ou non exécutable : %s/gradlew\n' \
        "$repertoire_android" >&2
    exit 66
fi

version_java_majeure() {
    local java_home=$1
    local version

    version=$("$java_home/bin/java" -version 2>&1 \
        | awk -F '"' '/version "/ { print $2; exit }')
    if [[ $version == 1.* ]]; then
        version=${version#1.}
    fi
    printf '%s\n' "${version%%.*}"
}

java_home_gradle=''
for candidat in "${JAVA_HOME:-}" /usr/lib/jvm/default-java /usr/lib/jvm/java-21-openjdk-amd64 \
    /opt/android-studio/jbr; do
    [[ -n $candidat && -x $candidat/bin/java ]] || continue
    version_majeure=$(version_java_majeure "$candidat")
    if [[ $version_majeure =~ ^(17|18|19|20|21)$ ]]; then
        java_home_gradle=$candidat
        break
    fi
done

if [[ -z $java_home_gradle ]]; then
    printf 'Échec : Gradle requiert un JDK 17 à 21 ; définissez JAVA_HOME vers un JDK compatible.\n' >&2
    exit 69
fi

empreinte_sha256=$(keytool -list -v -keystore "$keystore" -alias androiddebugkey \
    -storepass android -keypass android 2>/dev/null \
    | awk -F': ' '/SHA256:/{print $2; exit}')

if [[ -z $empreinte_sha256 ]]; then
    printf 'Échec : impossible de lire l’empreinte SHA-256 de %s avec l’alias androiddebugkey.\n' \
        "$keystore" >&2
    exit 65
fi

printf 'Empreinte SHA-256 calculée : %s\n' "$empreinte_sha256"

if [[ ! -f $fichier_assetlinks ]]; then
    printf 'Échec : association Android manquante : %s\n' "$fichier_assetlinks" >&2
    exit 66
fi

python3 - "$fichier_assetlinks" "$package_android" "$empreinte_sha256" <<'PYTHON'
import json
import re
import sys
from pathlib import Path

assetlinks_path = Path(sys.argv[1])
package_name = sys.argv[2]
fingerprint = sys.argv[3]
relation = "delegate_permission/common.handle_all_urls"
fingerprint_pattern = re.compile(r"^(?:[0-9A-F]{2}:){31}[0-9A-F]{2}$")

try:
    document = json.loads(assetlinks_path.read_text(encoding="utf-8"))
except (OSError, json.JSONDecodeError) as error:
    raise SystemExit(f"Échec : assetlinks.json invalide : {error}")

if not isinstance(document, list):
    raise SystemExit("Échec : assetlinks.json doit contenir une liste d’associations.")

associations = []
for entry in document:
    if not isinstance(entry, dict):
        continue
    target = entry.get("target")
    if not isinstance(target, dict):
        continue
    if entry.get("relation") != [relation]:
        continue
    if target.get("namespace") != "android_app" or target.get("package_name") != package_name:
        continue
    fingerprints = target.get("sha256_cert_fingerprints")
    if not isinstance(fingerprints, list) or not all(
        isinstance(value, str) and fingerprint_pattern.fullmatch(value) for value in fingerprints
    ):
        raise SystemExit(
            "Échec : les empreintes SHA-256 de l’association Android sont invalides."
        )
    associations.append(fingerprints)

if not associations:
    raise SystemExit(
        "Échec : aucune association avec la relation, le package et l’espace de noms attendus."
    )

if not any(fingerprint in fingerprints for fingerprints in associations):
    raise SystemExit(
        "Échec : l’empreinte du keystore testé est absente de l’association Android."
    )

print(
    "assetlinks.json valide : relation delegate_permission/common.handle_all_urls, "
    f"package {package_name}, empreinte du keystore présente."
)
PYTHON

printf 'Construction du manifeste debug fusionné…\n'
printf 'JDK Gradle : %s (Java %s)\n' "$java_home_gradle" \
    "$(version_java_majeure "$java_home_gradle")"
(cd "$repertoire_android" && JAVA_HOME="$java_home_gradle" PATH="$java_home_gradle/bin:$PATH" \
    ./gradlew :app:processDebugMainManifest)

manifeste_fusionne=''
for candidat in \
    "$repertoire_build/intermediates/merged_manifest/debug/processDebugMainManifest/AndroidManifest.xml" \
    "$repertoire_build/intermediates/merged_manifests/debug/processDebugManifest/AndroidManifest.xml"; do
    if [[ -f $candidat ]]; then
        manifeste_fusionne=$candidat
        break
    fi
done

if [[ -z $manifeste_fusionne ]]; then
    if [[ -d "$repertoire_build/intermediates" ]]; then
        manifeste_fusionne=$(find "$repertoire_build/intermediates" -type f \
            \( -path '*/merged_manifest/debug/*/AndroidManifest.xml' \
            -o -path '*/merged_manifests/debug/*/AndroidManifest.xml' \) \
            -print -quit)
    fi
fi

if [[ -z $manifeste_fusionne ]]; then
    printf 'Échec : manifeste debug fusionné introuvable après la construction Gradle.\n' >&2
    exit 70
fi

python3 - "$manifeste_fusionne" "$package_android" "$domaine" "$prefixe" <<'PYTHON'
import sys
import xml.etree.ElementTree as ET

manifest_path, package_name, domain, prefix = sys.argv[1:]
android = "{http://schemas.android.com/apk/res/android}"

try:
    root = ET.parse(manifest_path).getroot()
except (OSError, ET.ParseError) as error:
    raise SystemExit(f"Échec : manifeste fusionné invalide : {error}")

if root.get("package") != package_name:
    raise SystemExit(
        f"Échec : package du manifeste fusionné inattendu : {root.get('package')!r}."
    )

main_activity = next(
    (
        activity
        for activity in root.findall("./application/activity")
        if activity.get(android + "name") in {".MainActivity", "fr.maxencecoeur.partyplan.MainActivity"}
    ),
    None,
)
if main_activity is None:
    raise SystemExit("Échec : MainActivity absente du manifeste debug fusionné.")
if main_activity.get(android + "exported") != "true":
    raise SystemExit("Échec : MainActivity doit définir android:exported=\"true\".")

view_action = "android.intent.action.VIEW"
required_categories = {
    "android.intent.category.DEFAULT",
    "android.intent.category.BROWSABLE",
}
domain_associations = []

for index, intent_filter in enumerate(main_activity.findall("intent-filter"), start=1):
    if intent_filter.get(android + "autoVerify") != "true":
        continue
    actions = {node.get(android + "name") for node in intent_filter.findall("action")}
    categories = {node.get(android + "name") for node in intent_filter.findall("category")}
    if view_action not in actions or not required_categories.issubset(categories):
        continue

    data_nodes = intent_filter.findall("data")
    # Android fusionne les attributs de tous les nœuds <data> d’un même filtre :
    # les schémas, hôtes et préfixes forment des ensembles combinés, pas des triplets
    # indépendants par nœud XML.
    schemes = {data.get(android + "scheme") for data in data_nodes if data.get(android + "scheme")}
    hosts = {data.get(android + "host") for data in data_nodes if data.get(android + "host")}
    path_prefixes = {
        data.get(android + "pathPrefix")
        for data in data_nodes
        if data.get(android + "pathPrefix")
    }
    unsupported_attributes = {
        attribute
        for data in data_nodes
        for attribute in data.attrib
        if attribute not in {
            android + "scheme",
            android + "host",
            android + "pathPrefix",
        }
    }

    if "https" in schemes and domain in hosts:
        domain_associations.append(
            (index, schemes, hosts, path_prefixes, unsupported_attributes)
        )

if len(domain_associations) != 1:
    raise SystemExit(
        "Échec : MainActivity doit avoir une unique association HTTPS autoVerify "
        f"pour {domain}."
    )

index, schemes, hosts, path_prefixes, unsupported_attributes = domain_associations[0]
if schemes != {"https"} or hosts != {domain} or path_prefixes != {prefix}:
    raise SystemExit(
        "Échec : le filtre HTTPS autoVerify pertinent doit se limiter exactement à "
        f"https://{domain}{prefix} (filtre {index})."
    )
if unsupported_attributes:
    raise SystemExit(
        "Échec : le filtre HTTPS autoVerify pertinent contient des attributs data "
        f"non autorisés : {sorted(unsupported_attributes)!r}."
    )

print(f"Manifeste debug fusionné valide : https://{domain}{prefix} sur MainActivity.")
PYTHON

printf 'Vérification Android App Links réussie.\n'
