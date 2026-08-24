# Développer et tester en local

Poste de référence : Debian 13, .NET 10.0.302, Flutter 3.38.9, Rider 2026.1,
Android Studio, émulateur `Pixel_7a`, Docker.

Contrainte permanente : tout doit être exécutable et vérifiable en local avant d'être
poussé (`§13.4` du cahier des charges).

---

## 1. Première mise en route

```bash
cd /home/maxence/Dev/partyplan
make init        # crée .env depuis .env.example, restaure les dépendances
make up          # démarre la pile complète et construit les images
```

| Service | Adresse | Remarque |
|---|---|---|
| Application web | http://localhost:8080 | |
| API | http://localhost:5080 | |
| Vitrine | http://localhost:8081 | |
| Courriels capturés | http://localhost:8025 | aucun envoi réel |
| PostgreSQL | `localhost:5433` | **5433 et non 5432** : le port standard est déjà pris par `TableMasterDataBase-dev` |

Pour repartir d'une base propre avec le jeu de démonstration :

```bash
make reset-db
```

Cinq comptes sont alors créés (`maxence@partyplan.local`, `lucas@…`, `emma@…`,
`thomas@…`, `remi@…`), une soirée à venir avec dix articles de courses, et un
week-end passé. Aucun mot de passe : l'authentification arrive au lot 0.8.

---

## 2. Travail quotidien : rechargement à chaud

`make up` reconstruit les images, ce qui est inutile pour développer. Deux terminaux
suffisent.

**Terminal 1 — API**

```bash
make api
```

Démarre PostgreSQL et Mailpit en conteneur, puis l'API hors conteneur sous
`dotnet watch`. Toute modification de code C# est appliquée sans redémarrage.
L'API écoute sur `0.0.0.0:5080`, afin d'être joignable depuis l'émulateur.

**Terminal 2 — application**

```bash
make app         # Chrome
make android     # émulateur ou téléphone Android connecté
```

`r` recharge, `R` redémarre, `q` quitte.

---

## 3. Tester sur Android

```bash
make emulateur   # démarre le Pixel_7a
make devices     # vérifie qu'il est vu par Flutter
make android
```

**Point à connaître** : depuis l'émulateur, `localhost` désigne l'émulateur lui-même,
pas votre machine. L'hôte est joignable à l'adresse `10.0.2.2`, câblée par Android.
C'est pourquoi `make android` injecte `API_BASE_URL=http://10.0.2.2:5080` et non
`localhost`. Utiliser `localhost` donnerait une application qui se lance et ne peut
joindre aucune donnée.

**Téléphone physique** branché en USB, débogage activé :

```bash
make lan         # affiche l'adresse à utiliser et la commande complète
```

L'API doit alors être joignable sur le réseau local — elle écoute déjà sur toutes les
interfaces en développement — et le pare-feu du poste doit laisser passer le port 5080.

### Liens d'invitation Android

Les liens d'invitation canoniques ont la forme
`https://partyplan.maxencecoeur.fr/join/<jeton-long>`. Android les ouvre dans PartyPlan
grâce au filtre App Links de `MainActivity` et à l'association publiée à
`/.well-known/assetlinks.json` sur ce même domaine. Le filtre est volontairement limité
à `/join/` : `/rejoindre/` ne doit pas être ajouté.

Vérifier l'association locale avec le keystore utilisé pour l'APK debug :

```bash
./tools/verifier-app-links-android.sh "$HOME/.android/debug.keystore"
cd app && flutter build apk --debug
```

Le vérificateur recalcule l'empreinte SHA-256 du keystore, contrôle le JSON puis génère
et lit le manifeste debug fusionné. `assetlinks.json` peut contenir plusieurs empreintes
(par exemple debug et publication), mais doit toujours contenir celle du keystore passé
en argument.

Avant la publication Play, ajouter l'empreinte SHA-256 réelle de **Play App Signing** à
`app/web/.well-known/assetlinks.json` (sans retirer celle utile au développement), puis
redéployer ce fichier à `https://partyplan.maxencecoeur.fr/.well-known/assetlinks.json`.

Sur un appareil Android connecté, remettre l'APK et essayer un lien :

```bash
adb install -r app/build/app/outputs/flutter-apk/app-debug.apk
adb shell am start -W -a android.intent.action.VIEW \
  -d 'https://partyplan.maxencecoeur.fr/join/JETON-RECETTE' \
  fr.maxencecoeur.partyplan
```

---

## 4. Rider

Ouvrir **`api/PartyPlan.slnx`**. Rider 2026.1 lit ce format ; sur une version
antérieure à 2025.1, ouvrir directement `api/src/PartyPlan.Api/PartyPlan.Api.csproj`.

### Configuration de lancement

Le fichier `launchSettings.json` a été volontairement supprimé : la configuration vit
dans les variables d'environnement, source unique partagée avec Docker et la production
(`RG-DEV-02`). Créer donc une configuration Rider :

| Champ | Valeur |
|---|---|
| Type | .NET Project |
| Projet | `PartyPlan.Api` |
| URL | `http://0.0.0.0:5080` |
| Variables d'environnement | `ASPNETCORE_ENVIRONMENT=Development` |
| | `ASPNETCORE_URLS=http://0.0.0.0:5080` |
| | `ConnectionStrings__Default=Host=localhost;Port=5433;Database=partyplan;Username=partyplan;Password=partyplan` |

Sans `ASPNETCORE_ENVIRONMENT=Development`, l'hôte se croit en production et **refuse de
démarrer** en listant les secrets manquants. Ce n'est pas une panne : c'est `RG-DEV-01`
et `RG-ADM-11` qui font leur travail.

Démarrer d'abord la base : `docker compose --env-file .env -f infra/compose/compose.yml up -d db mail`.

### Exécuter les tests dans Rider

Les tests d'intégration démarrent un vrai PostgreSQL par Testcontainers : Docker doit
tourner. Le premier lancement télécharge `postgres:16-alpine`.

- `PartyPlan.UnitTests` — 36 tests, sans dépendance
- `PartyPlan.IntegrationTests` — 18 tests, PostgreSQL réel

### Base de données dans Rider

Fenêtre *Database* → PostgreSQL : hôte `localhost`, port `5433`, base `partyplan`,
utilisateur et mot de passe `partyplan`.

---

## 5. Android Studio

Utile pour l'émulateur, le *Device Manager* et le débogage natif. Le plugin Flutter est
nécessaire : *Settings → Plugins → Flutter*.

Ouvrir le dossier **`app`**, et non la racine du dépôt : Android Studio a besoin de voir
`pubspec.yaml` à la racine du projet ouvert.

### Configuration de lancement Flutter

*Run → Edit Configurations → Flutter*, puis dans **Additional run args** :

```
--dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Sans cet argument, l'application utilise `http://localhost:5080` par défaut et ne
joindra rien depuis l'émulateur.

---

## 6. Avant chaque poussée

```bash
make verif
```

Enchaîne format, analyse statique, contrôle des frontières de modules et l'ensemble des
tests. Le message final indique explicitement que la poussée est légitime. La même
chaîne tourne en intégration continue : y échouer en local, c'est y échouer sur GitHub.

Pour ne lancer qu'une partie :

```bash
make test-api    # 36 + 18 tests
make test-app    # 38 tests Flutter
make lint        # analyse et frontières
make fmt         # reformate
```

---

## 5 bis. Essayer le parcours de compte

Une fois `make api` lancé :

```bash
python3 tools/recette/parcours-comptes.py
```

Deux recettes sont disponibles :

```bash
python3 tools/recette/parcours-comptes.py      # comptes et administration
python3 tools/recette/parcours-evenement.py    # événements, invitations, présences
```

La première déroule 77 vérifications : politique de mot de passe, inscription,
vérification d'adresse par courriel, sessions et rotation des jetons, réinitialisation,
export et suppression, puis tout le back-office. Elle lit les courriels dans Mailpit, ce
qui la rend exécutable sans aucun service externe.

Depuis l'interface, avec `make app` :

| Écran | Chemin |
|---|---|
| Connexion | `/connexion` |
| Inscription | `/inscription` |
| Mot de passe oublié | `/mot-de-passe-oublie` |
| Profil (accueil) | `/` |
| Édition du profil | `/profil` |
| Sécurité et sessions | `/securite` |
| Mes données | `/mes-donnees` |
| Gestion des comptes | `/admin/comptes` |
| Journal d'audit | `/admin/audit` |

Les deux derniers n'apparaissent dans le menu que pour un rôle plateforme.

### Premier démarrage : l'administrateur amorcé

Se connecter avec `admin@partyplan.local` / `MotDePasseDeDeveloppement`. Une seule étape
est imposée : **changer le mot de passe**. Tant que ce n'est pas fait, seuls le profil, le
changement de mot de passe et la déconnexion répondent — tout le reste renvoie 403 avec
le code `auth.must_change_password` (`RG-ADM-10`). Le mot de passe d'amorçage figure dans
un fichier de configuration : le laisser actif reviendrait à ne pas avoir posé la
contrainte.

Le mot de passe changé, le rôle suffit à ouvrir l'administration. L'`ADR 0007` a retiré
la double authentification, et avec elle l'obligation `RG-ADM-04` : c'est précisément
elle qui faisait de ce premier démarrage une impasse, le compte amorcé devant accéder à
l'application pour activer un second facteur que l'application lui refusait.

Le code de vérification d'adresse arrive dans Mailpit : http://localhost:8025

---

## 6 bis. Limites inotify du noyau — à régler une fois

`dotnet watch` et `flutter run` surveillent les fichiers par **inotify**. Debian autorise
par défaut **128 instances par utilisateur**, et Rider, Android Studio, VS Code et le
navigateur en consomment déjà l'essentiel. Une fois la limite atteinte, `dotnet watch`
échoue au démarrage sur un message qui ne nomme pas la cause réelle :

```
An unexpected error occurred: System.IO.IOException: The configured user limit (128)
on the number of inotify instances has been reached
```

Diagnostic :

```bash
make inotify
```

### Correctif permanent

À exécuter une fois. Nécessite les droits d'administration, donc à lancer soi-même :

```bash
sudo tee /etc/sysctl.d/60-inotify-partyplan.conf > /dev/null <<'CONF'
# Limites inotify relevées pour un poste de développement équipé d'IDE.
# La valeur par défaut de Debian (128 instances) est saturée par Rider,
# Android Studio et le navigateur seuls.
fs.inotify.max_user_instances = 1024
fs.inotify.max_user_watches = 524288
CONF
sudo sysctl --system
```

Aucun redémarrage nécessaire. Le coût mémoire est d'environ 1 Ko de mémoire noyau par
surveillance **effectivement posée**, et non par surveillance autorisée : relever le
plafond ne consomme rien en soi. Ces valeurs sont celles que recommande JetBrains pour
ses propres outils.

### Repli automatique

En attendant, `make api` détecte la saturation et bascule `dotnet watch` en mode
scrutation (`DOTNET_USE_POLLING_FILE_WATCHER=1`). Le rechargement à chaud fonctionne
alors, au prix d'une consommation de processeur plus élevée et d'une détection des
modifications un peu plus lente. Le diagnostic est affiché à chaque lancement.

---

## 6 ter. Travailler hors ligne

Aucun accès Internet n'est nécessaire une fois les dépendances restaurées et les images
Docker en cache. Vérifié :

```bash
# Tests unitaires, réseau externe totalement coupé
unshare -rn sh -c 'ip link set lo up; dotnet test api/tests/PartyPlan.UnitTests --no-restore'

# Tests d'intégration, sortie Internet bloquée mais réseau local conservé
HTTPS_PROXY=http://127.0.0.1:9 dotnet test api/tests/PartyPlan.IntegrationTests --no-restore
```

Les tests d'intégration ont besoin de la mise en réseau Docker locale : le processus de
test dialogue en TCP avec le conteneur PostgreSQL. Un espace de noms réseau isolé les
coupe donc de la base, ce qui n'a rien à voir avec un accès Internet.

Prérequis à préparer une fois, connexion disponible : `make init` pour restaurer les
dépendances, et `docker pull postgres:16-alpine` pour l'image utilisée par les tests.

---

## 7. Problèmes courants

| Symptôme | Cause | Correction |
|---|---|---|
| « Démarrage refusé en production » | `ASPNETCORE_ENVIRONMENT` absent | Le fixer à `Development` dans la configuration de lancement |
| Port 5432 déjà alloué | Un autre projet occupe le port | Déjà traité : la base locale est sur 5433 |
| L'application se lance mais aucune donnée sur l'émulateur | `localhost` au lieu de `10.0.2.2` | `make android` |
| Migrations en attente | Schéma non à jour | `make migrate`, ou `make reset-db` |
| Aucun courriel reçu | Ils sont capturés, pas envoyés | http://localhost:8025 |
| Testcontainers échoue | Docker arrêté | Démarrer Docker |
| `make up` échoue sur l'image web | Compilation Flutter Web longue, mémoire | Utiliser `make api` et `make app` pour développer |
| « The configured user limit (128) on the number of inotify instances » | Limite noyau saturée par les IDE | Section 6 bis, puis `make inotify` pour contrôler |

---

## 8. Ce qu'il ne faut pas faire

- Se connecter à la base de production depuis le poste — `RG-DEV-03`.
- Commiter un fichier `.env`. Ils sont exclus ; toute nouvelle variable va dans
  `.env.example` sans valeur — `RG-DEV-02`, `NF-OPS-09`.
- Construire une image sur le serveur de production — `NF-OPS-08`.
- Contourner `make verif` avant une poussée.
