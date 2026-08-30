# syntax=docker/dockerfile:1

# ---------- Étape de compilation Flutter Web ----------
#
# `--platform=$BUILDPLATFORM` : la compilation tourne nativement sur la machine de
# construction. Sa sortie est du HTML, du CSS et du JavaScript, identiques quelle que
# soit l'architecture visée — seule l'image nginx qui les sert en dépend. L'image
# Flutter n'est d'ailleurs publiée qu'en amd64.
FROM --platform=$BUILDPLATFORM ghcr.io/cirruslabs/flutter:3.38.9 AS build
WORKDIR /src

# `API_BASE_URL` est injecté à la compilation : Flutter Web produit des fichiers
# statiques, la valeur ne peut pas être lue à l'exécution.
ARG API_BASE_URL=https://api.partyplan.maxencecoeur.fr

# Identifiant client Google. De même nature que l'adresse ci-dessus : public, inscrit
# dans le JavaScript livré, lisible par n'importe quel visiteur. Il porte donc la même
# valeur par défaut plutôt qu'une case à remplir ailleurs.
#
# Vide, le bouton « Continuer avec Google » n'apparaît pas et l'inscription par mot de
# passe suffit (NF-DEV-05). C'est un repli, pas le cas courant : laissé vide par
# inadvertance, il ne produit aucun message — seulement un bouton manquant, qu'on peut
# chercher longtemps.
ARG GOOGLE_CLIENT_ID=146275272251-adq6bsorokpqd9fqknmafhpckns9ijts.apps.googleusercontent.com

# Configuration Firebase du Web. Ces valeurs ne sont pas des secrets : elles sont
# publiques dans toute application web livrée, et la clé d'API est restreinte par domaine.
# Vides par défaut : l'image compile sans Firebase, et l'application tourne sans
# notifications (règle 5).
ARG FIREBASE_API_KEY=""
ARG FIREBASE_PROJECT_ID=""
ARG FIREBASE_SENDER_ID=""
ARG FIREBASE_APP_ID=""
ARG FIREBASE_VAPID_KEY=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Génération explicite plutôt qu'implicite : `flutter build` la déclenche, mais un
# échec de génération est plus lisible ici que noyé dans la compilation.
RUN flutter gen-l10n

# Le service worker n'est engendré que si la configuration est fournie : sans lui, le
# navigateur n'enregistre aucun appareil et l'application fonctionne sans notifications.
#
# Le gabarit vit hors de `web/` : Flutter recopie ce répertoire tel quel dans
# `build/web`, et un gabarit à marqueurs se retrouverait servi publiquement.
RUN if [ -n "$FIREBASE_API_KEY" ]; then \
      sed -e "s|__FIREBASE_API_KEY__|$FIREBASE_API_KEY|" \
          -e "s|__FIREBASE_PROJECT_ID__|$FIREBASE_PROJECT_ID|" \
          -e "s|__FIREBASE_SENDER_ID__|$FIREBASE_SENDER_ID|" \
          -e "s|__FIREBASE_APP_ID__|$FIREBASE_APP_ID|" \
          firebase-messaging-sw.js.template > web/firebase-messaging-sw.js ; \
    else \
      echo "Configuration Firebase absente : compilation web sans notifications." ; \
    fi

RUN flutter build web \
      --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID} \
      --dart-define=FIREBASE_API_KEY=${FIREBASE_API_KEY} \
      --dart-define=FIREBASE_PROJECT_ID=${FIREBASE_PROJECT_ID} \
      --dart-define=FIREBASE_SENDER_ID=${FIREBASE_SENDER_ID} \
      --dart-define=FIREBASE_APP_ID=${FIREBASE_APP_ID} \
      --dart-define=FIREBASE_VAPID_KEY=${FIREBASE_VAPID_KEY}

# ---------- Image d'exécution ----------
FROM nginx:1.27-alpine AS runtime
COPY --from=build /src/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY nginx-securite.conf /etc/nginx/nginx-securite.conf
EXPOSE 80
