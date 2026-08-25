# syntax=docker/dockerfile:1

# ---------- Étape de compilation Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.38.9 AS build
WORKDIR /src

# `API_BASE_URL` est injecté à la compilation : Flutter Web produit des fichiers
# statiques, la valeur ne peut pas être lue à l'exécution.
ARG API_BASE_URL=https://api.partyplan.maxencecoeur.fr

# Identifiant client Google, vide par défaut : sans lui le bouton « Continuer avec
# Google » n'apparaît pas et l'inscription par mot de passe suffit (NF-DEV-05).
ARG GOOGLE_CLIENT_ID=

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Génération explicite plutôt qu'implicite : `flutter build` la déclenche, mais un
# échec de génération est plus lisible ici que noyé dans la compilation.
RUN flutter gen-l10n

RUN flutter build web \
      --release \
      --dart-define=API_BASE_URL=${API_BASE_URL} \
      --dart-define=GOOGLE_CLIENT_ID=${GOOGLE_CLIENT_ID}

# ---------- Image d'exécution ----------
FROM nginx:1.27-alpine AS runtime
COPY --from=build /src/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY nginx-securite.conf /etc/nginx/nginx-securite.conf
EXPOSE 80
