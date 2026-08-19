#!/usr/bin/env bash
# Diagnostic des limites inotify du noyau.
#
# `dotnet watch` et `flutter run` ouvrent chacun des instances inotify pour surveiller
# les fichiers. La limite par défaut de Debian est de 128 instances par utilisateur, que
# Rider, Android Studio, VS Code et le navigateur consomment déjà largement. Une fois
# la limite atteinte, dotnet watch échoue au démarrage avec un message qui n'indique pas
# la cause réelle.
#
#   ./tools/verifier-inotify.sh          diagnostic lisible
#   ./tools/verifier-inotify.sh --env    n'affiche que la variable de repli, ou rien

set -uo pipefail

LIMITE=$(cat /proc/sys/fs/inotify/max_user_instances 2>/dev/null || echo 0)
SURVEILLANCES=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo 0)

compter_instances() {
  local total=0 n
  for p in /proc/[0-9]*; do
    n=$(find "$p/fd" -maxdepth 1 -type l 2>/dev/null -exec readlink {} \; 2>/dev/null \
        | grep -c inotify) || n=0
    total=$((total + n))
  done
  echo "$total"
}

UTILISEES=$(compter_instances)
DISPONIBLES=$((LIMITE - UTILISEES))

# Marge exigée : dotnet watch en consomme plusieurs, et une session Flutter aussi.
MARGE_MINIMALE=99999

if [ "${1:-}" = "--env" ]; then
  if [ "$DISPONIBLES" -lt "$MARGE_MINIMALE" ]; then
    echo "DOTNET_USE_POLLING_FILE_WATCHER=1"
  fi
  exit 0
fi

echo "inotify : $UTILISEES instances utilisées sur $LIMITE ($DISPONIBLES disponibles)"
echo "          $SURVEILLANCES surveillances de fichiers autorisées"

if [ "$DISPONIBLES" -ge "$MARGE_MINIMALE" ] && [ "$SURVEILLANCES" -ge 262144 ]; then
  echo "          marge suffisante."
  exit 0
fi

echo
if [ "$DISPONIBLES" -lt "$MARGE_MINIMALE" ]; then
  echo "MARGE INSUFFISANTE. Le rechargement à chaud basculera en mode scrutation,"
  echo "plus lent et plus gourmand en processeur."
else
  echo "Nombre de surveillances faible pour un poste équipé d'IDE."
fi

echo
echo "Correctif permanent, à exécuter une fois (nécessite les droits d'administration) :"
echo
echo "  sudo tee /etc/sysctl.d/60-inotify-partyplan.conf > /dev/null <<'CONF'"
echo "  # Limites inotify relevées pour un poste de développement équipé d'IDE."
echo "  # Valeurs recommandées par JetBrains ; la valeur par défaut de Debian (128"
echo "  # instances) est saturée par Rider, Android Studio et le navigateur seuls."
echo "  fs.inotify.max_user_instances = 1024"
echo "  fs.inotify.max_user_watches = 524288"
echo "  CONF"
echo "  sudo sysctl --system"
echo
echo "Coût mémoire : environ 1 Ko de mémoire noyau par surveillance effectivement"
echo "posée, et non par surveillance autorisée. Relever le plafond ne consomme rien"
echo "en soi."
exit 0
