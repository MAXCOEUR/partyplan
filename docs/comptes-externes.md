# Comptes et clés externes — quoi fournir, et quand

Ce document répond à une seule question : **de quoi ai-je besoin de l'extérieur, et à
quel moment ?**

## En un mot : rien pour l'instant

Au 19/08/2026, **aucune clé externe n'est nécessaire pour développer**. Les variables
`GOOGLE_*`, `APPLE_*` et `FIREBASE_*` figurent dans `.env.example` par anticipation,
mais aucun code ne les lit encore. Les laisser vides est le comportement attendu
(`NF-DEV-02`).

C'est un choix d'architecture, pas un hasard : le `§13.4` du cahier des charges impose
que toute fonctionnalité soit développable sans compte externe. Chaque service tiers a
un substitut local.

| Service | À quoi il sert | Substitut local actuel | Devient nécessaire |
|---|---|---|---|
| Google Cloud | Connexion Google | Connexion par mot de passe | Lot 0.9 restant |
| Firebase / FCM | Notifications poussées | Journal en console | Lot 1.11 |
| Serveur SMTP | Courriels réels | Mailpit, aucun envoi réel | Bêta privée, lot 1.17 |
| Apple Developer | Publication iOS et Sign in with Apple | — | V1.2 |
| Google Play | Publication Android | — | Lot 1.18 |
| Hébergeur | Production | Docker local | Lot 0.7 |
| Registrar + INPI | Nom et domaine définitifs | `localhost` | Lot 0.1 |

---

## 1. Google Cloud — connexion Google

**Utilité** : `EF-AUTH-06`. Réduit la friction d'inscription, ce qui compte pour un
produit dont l'acquisition repose sur le partage entre amis.

**Coût** : gratuit.

**Ce qu'il faut créer**

1. Se rendre sur https://console.cloud.google.com et créer un projet nommé `PartyPlan`.
2. *APIs & Services → OAuth consent screen* : type « Externe », nom de l'application,
   adresse de support, et le lien vers la politique de confidentialité — ce dernier est
   exigé pour la validation, il faudra donc que la page existe (lot 1.15).
3. *Credentials → Create credentials → OAuth client ID*, **trois fois** :

| Type de client | Pour | Champ à renseigner |
|---|---|---|
| Application Web | Flutter Web et l'API | Origines autorisées : `http://localhost:8080` en développement, `https://partyplan.maxencecoeur.fr` en production |
| Android | l'application Android | Nom du paquet `fr.maxencecoeur.partyplan` + empreinte SHA-1 du certificat de signature |
| iOS | l'application iOS | Identifiant de l'offre groupée `fr.maxencecoeur.partyplan` |

L'empreinte SHA-1 du certificat de débogage s'obtient ainsi :

```bash
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA1
```

**Où mettre les valeurs**

```bash
# .env  (développement)
GOOGLE_CLIENT_ID=xxxxx.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
```

**Point de vigilance** : dès que la connexion Google est proposée sur iOS, les règles
d'Apple imposent d'offrir également « Sign in with Apple » (`R-05`). Une soumission qui
ne le fait pas est refusée. C'est la raison pour laquelle `EF-AUTH-07` est marqué
prérequis au dépôt iOS.

---

## 2. Firebase — notifications poussées

**Utilité** : lot 1.11. Les six notifications du `§5.12`, dont celle qui porte le plus
de valeur : « tu dois 18,40 € à Maxence », envoyée le lendemain de l'événement. C'est
elle qui ramène l'utilisateur dans l'application, donc le principal levier de rétention
(`R-01`).

**Coût** : gratuit. Firebase Cloud Messaging n'est pas facturé.

**Ce qu'il faut créer**

1. https://console.firebase.google.com → nouveau projet. **Réutiliser le projet Google
   Cloud créé à l'étape 1** plutôt que d'en créer un second : les deux services
   partagent la même console, et deux projets séparés compliquent la gestion sans rien
   apporter.
2. *Ajouter une application Android* : paquet `fr.maxencecoeur.partyplan`. Télécharger
   `google-services.json` et le placer dans `app/android/app/`.
3. *Ajouter une application Web* : récupérer la configuration Firebase et la clé VAPID
   (*Cloud Messaging → Web Push certificates*).
4. *Paramètres du projet → Comptes de service → Générer une nouvelle clé privée* : un
   fichier JSON, destiné au **serveur** uniquement.

**Où mettre les valeurs**

```bash
# .env  — le chemin du fichier de clé de compte de service
FIREBASE_SERVICE_ACCOUNT_PATH=/chemin/vers/serviceAccountKey.json
```

**Attention** : `app/android/app/google-services.json` contient des identifiants de
projet. Il n'est pas secret au sens d'un mot de passe, mais il ne doit pas être versionné
dans un dépôt public. Le dépôt étant privé, c'est acceptable ; je l'ajouterai malgré tout
au `.gitignore` avec un `google-services.json.example`, par prudence.

**iOS** : les notifications exigent en plus une clé APNs, qui suppose le compte Apple
Developer (étape 4).

---

## 3. Serveur SMTP — courriels réels

**Utilité** : vérification d'adresse et réinitialisation de mot de passe. Tant que le
développement se fait en local, Mailpit capture tout et **aucun message ne part vers une
adresse réelle** (`NF-DEV-03`). Dès la bêta privée, il faut de vrais envois.

**Coût** : gratuit jusqu'à quelques centaines d'envois par jour chez la plupart des
fournisseurs.

**Fournisseurs européens à considérer** — la localisation compte, `RG-RGPD-03` impose
l'Union européenne :

| Fournisseur | Origine | Palier gratuit indicatif |
|---|---|---|
| Brevo | France | 300 courriels/jour |
| Scaleway Transactional Email | France | 300/jour |
| OVHcloud | France | selon l'offre d'hébergement |
| Mailjet | France | 200/jour |

**Ce qu'il faut faire**

1. Créer le compte, vérifier le domaine d'envoi.
2. **Configurer SPF, DKIM et DMARC** dans le DNS. Sans ces enregistrements, les
   courriels de vérification arrivent en indésirable — et un utilisateur qui ne reçoit
   pas son code croit que l'inscription est cassée.
3. Récupérer les identifiants SMTP.

```bash
# infra/compose/.env  (production)
SMTP_HOST=smtp-relay.brevo.com
SMTP_PORT=587
SMTP_USER=…
SMTP_PASSWORD=…
SMTP_FROM=PartyPlan <bonjour@partyplan.maxencecoeur.fr>
```

**Vérification** : après configuration, s'inscrire avec une adresse réelle et contrôler
que le message arrive en boîte de réception, pas en indésirable. Un test avec
https://www.mail-tester.com donne un score et liste ce qui manque.

---

## 4. Apple Developer Program

**Utilité** : publication sur l'App Store (V1.2), Sign in with Apple, notifications
poussées iOS.

**Coût** : environ 99 € par an — à vérifier, le tarif évolue. **C'est la seule dépense
récurrente significative du projet.**

**Ce qu'il faut créer**

1. https://developer.apple.com → adhésion au programme. Compter quelques jours de
   validation.
2. Identifiant d'application `fr.maxencecoeur.partyplan`, avec les capacités
   *Push Notifications* et *Sign in with Apple*.
3. Clé APNs (*Keys → Create a Key*), pour les notifications.
4. Clé Sign in with Apple : identifiant de service, identifiant d'équipe, identifiant de
   clé, et le fichier `.p8`.

**Nécessite un Mac** pour construire et soumettre, ou un service d'intégration continue
hébergé. Ce n'est pas contournable.

**Recommandation** : ne pas prendre cette adhésion avant que V1.1 soit publiée sur
Android et validée par de vrais utilisateurs. C'est une dépense annuelle qui ne rapporte
rien tant qu'il n'y a pas d'application à publier.

---

## 5. Google Play Console

**Utilité** : publication Android, lot 1.18.

**Coût** : environ 25 $ une seule fois — à vérifier.

**Ce qu'il faut créer**

1. https://play.google.com/console → compte développeur.
2. Générer un certificat de signature de publication :

```bash
keytool -genkey -v -keystore ~/partyplan-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

**Sauvegarder ce fichier et son mot de passe hors du poste.** Le perdre empêche
définitivement de publier une mise à jour de l'application. C'est la perte la plus
coûteuse et la plus irréversible du projet.

Le fichier est déjà exclu du dépôt (`app/android/key.properties` et
`app/android/app/upload-keystore.jks` figurent dans `.gitignore`).

3. Renseigner la fiche : description, captures, icône, classification de contenu, et la
   **fiche de confidentialité** — obligatoire, elle exige que la politique de
   confidentialité soit publiée (lot 1.15).

---

## 6. Hébergeur

**Utilité** : lot 0.7. Bloquant pour toute mise en production.

**Coût** : de l'ordre de 5 à 20 € par mois pour un serveur suffisant au démarrage.

**Contrainte** : localisation dans l'Union européenne (`RG-RGPD-03`).

**Dimensionnement** : 2 vCPU, 4 Go de mémoire, 40 Go de disque suffisent largement pour
la cible de `NF-SCAL-01` — 5 000 événements actifs et 50 000 membres. La base et l'API
tiennent sur la même machine à ce volume.

**Ce qu'il faut, une fois le serveur pris**

```bash
JWT_SIGNING_KEY=$(openssl rand -base64 48)
POSTGRES_PASSWORD=$(openssl rand -base64 32)
```

Ces deux valeurs se génèrent sur le serveur et ne se notent nulle part ailleurs que dans
un gestionnaire de mots de passe.

---

## 7. Nom et domaine

**Utilité** : lot 0.1. Bloquant pour l'identité visuelle et les fiches des magasins.

| Démarche | Coût indicatif | Où |
|---|---|---|
| Domaine `partyplan.fr` | 10 à 15 € par an | n'importe quel registrar |
| Marque à l'INPI, classes 9 et 42 | environ 190 € pour une classe, plus 40 € par classe supplémentaire — à vérifier | https://www.inpi.fr |

**Vérifier avant de payer** : la base des marques de l'INPI, l'EUIPO pour l'Union
européenne, et la disponibilité du nom sur les magasins d'applications. Un nom déjà
déposé dans la classe 9 rendrait la publication risquée.

---

## Ordre recommandé

1. **Maintenant** — rien. Le développement avance sans aucune clé.
2. **Avant l'identité visuelle** — vérifier le nom, réserver le domaine.
3. **Avant la première mise en production** — hébergeur, puis les trois clés générées
   sur place.
4. **Avant la bêta privée** — SMTP réel, avec SPF, DKIM et DMARC.
5. **Avec le lot 0.9** — Google Cloud, pour la connexion Google.
6. **Avec le lot 1.11** — Firebase, pour les notifications.
7. **Avant la publication Android** — Google Play, et le certificat de signature mis en
   sécurité.
8. **Seulement après validation sur Android** — Apple Developer.

Dépense engagée avant d'avoir un utilisateur : le domaine, et l'hébergeur. Le reste
attend d'être réellement nécessaire.

---

## Où placer les valeurs

| Environnement | Fichier | Versionné ? |
|---|---|---|
| Développement | `.env` à la racine | non, exclu |
| Production | `infra/compose/.env` sur le serveur | non, exclu |
| Référence | `.env.example` et `infra/compose/.env.example` | oui, **sans valeur** |

Règle `RG-DEV-02` : toute variable lue par le code figure dans les fichiers d'exemple,
sans valeur secrète. Une variable ajoutée au code sans y figurer se découvre au premier
démarrage en production, au plus mauvais moment.

## Vérifier qu'une clé est bien prise en compte

```bash
make api            # relance l'API avec le nouveau .env
make inotify        # au besoin, si le rechargement à chaud échoue
```

Le journal de démarrage énumère les modules chargés. Pour les courriels,
http://localhost:8025 montre ce qui serait parti ; en production, contrôler la boîte de
réception réelle et non le journal.
