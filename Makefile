# PartyPlan — commandes de développement local
#
# Contrainte permanente : tout doit être exécutable en local avant d'être poussé
# (§13.4 du cahier des charges). Aucune cible ci-dessous ne requiert de compte
# externe ni d'accès à la production.

SHELL       := /bin/bash
COMPOSE_DEV := docker compose --env-file .env -f infra/compose/compose.yml
API_PROJ    := api/src/PartyPlan.Api

# Écoute sur toutes les interfaces : l'émulateur Android et un téléphone du réseau
# local doivent pouvoir joindre l'API. Uniquement en développement.
API_URLS    := http://0.0.0.0:5080

# Depuis l'émulateur Android, « localhost » désigne l'émulateur lui-même. L'hôte est
# accessible à l'adresse 10.0.2.2, câblée par Android.
API_EMU     := http://10.0.2.2:5080

# Port du serveur de développement Flutter Web. Fixe, et déclaré dans les origines
# autorisées de appsettings.Development.json : les deux valeurs doivent rester égales.
WEB_DEV_PORT := 5173

# Stockage des photos et pièces jointes, partagé entre l'API en conteneur et l'API
# lancée par « make api ». Le chemin est repris tel quel dans le montage du conteneur
# (infra/compose/compose.yml) : les deux valeurs doivent rester égales, faute de quoi
# chaque moitié écrit dans un stockage que l'autre ignore.
MEDIA_DIR := $(CURDIR)/.data/media

# Identifiant client Google, lu dans .env pour n'avoir qu'une source de vérité. Vide
# tant qu'il n'y est pas : l'application se lance alors sans bouton Google, et
# l'inscription par mot de passe suffit (NF-DEV-05).
#
# C'est l'identifiant du client **Web** qu'il faut, y compris sur Android : le jeton
# émis porte cette audience, et le client Android n'a pas d'identifiant à inscrire dans
# le code — il est reconnu par le nom du paquet et l'empreinte du certificat.
GOOGLE_CLIENT_ID := $(shell grep -E '^GOOGLE_CLIENT_ID=' .env 2>/dev/null | cut -d= -f2-)
GOOGLE_ANDROID_CLIENT_ID := $(shell grep -E '^GOOGLE_ANDROID_CLIENT_ID=' .env 2>/dev/null | cut -d= -f2-)

.DEFAULT_GOAL := aide

.PHONY: aide init up down restart logs ps api app web test test-api test-app \
        migration migrate reset-db seed mail openapi frontieres fmt lint verif clean \
        android apk aab emulateur lan devices inotify stop-api variables

aide: ## Affiche cette aide
	@echo "PartyPlan — cibles disponibles :"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## Prépare le poste : fichier .env, restauration des dépendances
	@test -f .env || (cp .env.example .env && echo "→ .env créé depuis .env.example")
	@command -v dotnet >/dev/null || { echo "dotnet absent"; exit 1; }
	@command -v flutter >/dev/null || { echo "flutter absent"; exit 1; }
	@test -f api/PartyPlan.slnx && dotnet restore api/PartyPlan.slnx || echo "→ solution API pas encore créée"
	@test -f app/pubspec.yaml && (cd app && flutter pub get) || echo "→ projet Flutter pas encore créé"

up: init ## Démarre la pile complète (base, courriel, API, web, vitrine)
	$(COMPOSE_DEV) up -d --build
	@echo ""
	@echo "  Application   http://localhost:8080"
	@echo "  API           http://localhost:5080"
	@echo "  Vitrine       http://localhost:8081"
	@echo "  Courriels     http://localhost:8025   (aucun envoi réel — NF-DEV-03)"
	@echo "  Administrateur  admin@partyplan.local / MotDePasseDeDeveloppement"

stop-api: ## Termine le processus qui occupe le port 5080
	@./tools/liberer-port.sh 5080 --tuer || true

down: ## Arrête la pile
	$(COMPOSE_DEV) down

restart: down up ## Redémarre la pile

logs: ## Suit les journaux de la pile
	$(COMPOSE_DEV) logs -f --tail=100

ps: ## Affiche l'état des conteneurs
	$(COMPOSE_DEV) ps

# --- Exécution hors conteneur, pour le rechargement à chaud (NF-DEV-09) ---

api: ## Lance l'API en rechargement à chaud (base et courriel en conteneur)
	@# Un « dotnet watch » oublié, ou lancé depuis Rider, occupe déjà le port : le
	@# message de Kestrel ne nomme pas le processus fautif.
	@./tools/liberer-port.sh 5080
	$(COMPOSE_DEV) up -d db mail
	@# Bascule en mode scrutation si les instances inotify du noyau sont saturées :
	@# sans cela, dotnet watch échoue avec un message qui n'indique pas la cause.
	@./tools/verifier-inotify.sh | head -2
	@# `env` est indispensable ici : le shell analyse les affectations de variables
	@# avant les substitutions de commande, si bien qu'un $$(...) placé en préfixe
	@# serait interprété comme un nom de commande et non comme une affectation.
	@# Le SDK .NET 10.0.400 mélange `obj\\Debug` et `obj/Debug` sous Linux dans la
	@# gestion spéciale des fichiers statiques de dotnet-watch. L'API n'en sert pas :
	@# la désactiver supprime ce faux échec sans toucher au hot reload du code C#.
	@# Les identifiants Google viennent de .env : appsettings.Development.json n'en
	@# porte pas, et sans eux l'API refuse tout jeton Google sans que le bouton de
	@# l'application le laisse deviner. Vides, la vérification reste simplement
	@# désactivée (NF-DEV-05).
	@# Même stockage que le conteneur, monté depuis .data/media : sans cela l'API
	@# locale écrirait dans /tmp et ne verrait pas les photos téléversées via
	@# « make up », ni l'inverse. /tmp est en outre purgé au redémarrage du poste.
	@mkdir -p $(MEDIA_DIR)
	ASPNETCORE_ENVIRONMENT=Development ASPNETCORE_URLS=$(API_URLS) \
	  env DOTNET_WATCH_SUPPRESS_STATIC_FILE_HANDLING=1 \
	  App__PublicBaseUrl=http://localhost:$(WEB_DEV_PORT) \
	  Media__RootPath=$(MEDIA_DIR) \
	  Google__ClientId=$(GOOGLE_CLIENT_ID) \
	  Google__AndroidClientId=$(GOOGLE_ANDROID_CLIENT_ID) \
	  $(if $(JETON_COURT),Jwt__AccessTokenMinutes=1,) \
	  $$(./tools/verifier-inotify.sh --env) \
	  dotnet watch --project $(API_PROJ) run

api-jeton-court: ## Comme `make api`, mais jeton d'accès d'une minute (essai du renouvellement)
	@# Le jeton d'accès dure quinze minutes en temps normal : vérifier le
	@# renouvellement à la main demanderait d'attendre un quart d'heure devant
	@# l'application. Une minute suffit à observer exactement le même parcours.
	@# Compter quatre-vingt-dix secondes avant le refus, et non soixante : la
	@# validation tolère trente secondes de dérive d'horloge (AuthenticationSetup).
	@# La durée de la session, elle, reste à quatre-vingt-dix jours.
	@# L'API du conteneur occupe déjà le port : `liberer-port.sh` ne connaît que les
	@# processus du poste, et Kestrel échouerait sur une adresse déjà utilisée sans
	@# nommer le conteneur fautif.
	@$(COMPOSE_DEV) stop api
	@$(MAKE) api JETON_COURT=1

app: ## Lance l'application Flutter sur Chrome, en rechargement à chaud
	@# Le port doit être fixe : sans --web-port, Chrome est servi sur un port
	@# tiré au hasard, jamais présent dans Cors:AllowedOrigins, et le navigateur
	@# bloque alors chaque appel à l'API sans que rien ne l'explique côté serveur.
	cd app && flutter run -d chrome --web-port=$(WEB_DEV_PORT) \
	  --dart-define=API_BASE_URL=http://localhost:5080 \
	  --dart-define=GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID)

android: ## Lance l'application sur l'émulateur ou le téléphone Android connecté
	cd app && flutter run --dart-define=API_BASE_URL=$(API_EMU) \
	  --dart-define=GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID)

emulateur: ## Démarre l'émulateur Android Pixel_7a
	flutter emulators --launch Pixel_7a

lan: ## Affiche la commande à utiliser pour un téléphone physique du réseau local
	@ip=$$(hostname -I | awk '{print $$1}'); \
	echo "API joignable sur http://$$ip:5080"; \
	echo "cd app && flutter run --dart-define=API_BASE_URL=http://$$ip:5080"; \
	echo; \
	echo "Penser à autoriser cette origine : ajouter http://$$ip:8080 à Cors:AllowedOrigins"; \
	echo "si l'application est servie en web depuis un autre appareil."

devices: ## Liste les appareils et émulateurs disponibles
	cd app && flutter devices
	@echo
	flutter emulators

web: ## Compile l'application Flutter Web en production, en local
	cd app && flutter build web --release \
	  --dart-define=API_BASE_URL=http://localhost:5080 \
	  --dart-define=GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID)

# L'adresse de l'API est obligatoire : sans elle, `AppConfig` retombe sur
# `http://localhost:5080`, qui depuis un téléphone désigne le téléphone lui-même.
# L'application s'installe, s'ouvre, et rien ne charge — sans message expliquant pourquoi.
API_PROD ?= https://api.partyplan.maxencecoeur.fr

aab: ## Construit l'App Bundle signé, à déposer sur Google Play
	@# Google Play n'accepte pas d'APK pour une nouvelle application : il exige un
	@# App Bundle, dont il dérive lui-même un APK par appareil.
	@test -f app/android/key.properties || { \
	  echo "key.properties absent : le bundle serait signé avec la clé de débogage,"; \
	  echo "et Google Play le refuserait. Voir docs/publication-play-store.md."; \
	  exit 1; }
	cd app && flutter build appbundle --release \
	  --dart-define=API_BASE_URL=$(API_PROD) \
	  --dart-define=GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID)
	@echo ""
	@echo "→ app/build/app/outputs/bundle/release/app-release.aab"
	@echo "  API : $(API_PROD)"

apk: ## Construit l'APK de production à installer sur un téléphone Android
	cd app && flutter build apk --release \
	  --dart-define=API_BASE_URL=$(API_PROD) \
	  --dart-define=GOOGLE_CLIENT_ID=$(GOOGLE_CLIENT_ID)
	@echo ""
	@echo "→ app/build/app/outputs/flutter-apk/app-release.apk"
	@echo "  API : $(API_PROD)"
	@echo "  Signature : clé de debug (voir android/app/build.gradle.kts)."
	@echo "  Notifications : elles ne partiront que si l'API a sa clé Firebase."

# --- Base de données ---

migration: ## Crée une migration : make migration NOM=AjoutTableX
	@test -n "$(NOM)" || { echo "Usage : make migration NOM=AjoutTableX"; exit 1; }
	dotnet ef migrations add $(NOM) \
	  --project api/src/PartyPlan.Infrastructure \
	  --startup-project $(API_PROJ)

migrate: ## Applique les migrations à la base locale
	dotnet ef database update \
	  --project api/src/PartyPlan.Infrastructure \
	  --startup-project $(API_PROJ)

reset-db: ## Détruit et recrée la base locale, puis rejoue les migrations et le jeu de démonstration
	$(COMPOSE_DEV) down -v db
	$(COMPOSE_DEV) up -d db
	@echo "→ attente de la base…"
	@until $(COMPOSE_DEV) exec -T db pg_isready -U partyplan -d partyplan >/dev/null 2>&1; do sleep 1; done
	$(MAKE) migrate
	$(MAKE) seed

seed: ## Installe le jeu de données de démonstration (NF-DEV-07)
	dotnet run --project api/tools/PartyPlan.Seed || echo "→ outil de jeu de données pas encore créé"

openapi: ## Régénère docs/api/openapi.json et le client Dart depuis l'API locale
	./tools/generate-api-client.sh

frontieres: ## Vérifie les frontières de modules (ADR 0002)
	./tools/verifier-frontieres-modules.sh

variables: ## Vérifie que toute clé lue par le code est déclarée (NF-OPS-09)
	@./tools/verifier-variables-env.sh

inotify: ## Diagnostique les limites inotify du noyau et donne le correctif
	@./tools/verifier-inotify.sh

mail: ## Ouvre l'interface de consultation des courriels
	@echo "http://localhost:8025"

# --- Qualité ---

test: test-api test-app ## Exécute toute la suite de tests

test-api: ## Tests de l'API
	dotnet test api/PartyPlan.slnx

test-app: l10n ## Tests Flutter
	cd app && flutter test

test-reel: ## Vérifie l'authentification contre l'API locale (exige `make up`)
	@# Hors de `make verif` : ces tests parlent à un vrai serveur, ce qu'aucune suite
	@# automatique ne doit supposer. Ils mesurent ce que les faux serveurs ne peuvent
	@# pas montrer — la rotation du jeton telle que l'API la pratique réellement.
	cd app && flutter test test_reel

fmt: ## Formate le code
	dotnet format api/PartyPlan.slnx
	cd app && dart format lib test

l10n: ## Régénère les chaînes traduites depuis lib/l10n/arb
	cd app && flutter gen-l10n

lint: l10n ## Analyse statique, frontières de modules, variables d'environnement
	dotnet build api/PartyPlan.slnx
	cd app && flutter analyze
	./tools/verifier-frontieres-modules.sh
	./tools/verifier-variables-env.sh

verif: fmt lint test ## À exécuter avant tout push : format, analyse, tests
	@echo ""
	@echo "→ vérification complète passée. Le push est légitime."

clean: ## Supprime les artefacts de compilation
	dotnet clean api/PartyPlan.slnx 2>/dev/null || true
	cd app && flutter clean 2>/dev/null || true
