# Publier PartyPlan sur Google Play

*Rédigé le 31/08/2026, pour un compte développeur personnel.*

Ce guide part de l'état réel du dépôt et va jusqu'à l'application visible sur le Play
Store. Il est écrit pour être suivi dans l'ordre : chaque étape dépend de la précédente,
et deux d'entre elles sont irréversibles — le choix « gratuite » et l'identifiant du
paquet.

---

## 0. Le parcours imposé : test fermé, puis production

Ton compte est un compte **personnel**, et Google impose à ces comptes une phase de test
fermé avant d'autoriser la production. Ce n'est pas une option à décocher : c'est la seule
voie, et chercher à la contourner est le plus sûr moyen de faire suspendre le compte.

Concrètement, le parcours est celui-ci :

```
créer l'application → test fermé → attendre le délai imposé
                                        ↓
                        demander l'accès à la production → publier
```

L'ordre de gravité des choses à savoir :

- il faut **des testeurs réels et distincts**, qui acceptent l'invitation depuis leur
  propre compte Google — de l'ordre d'une douzaine ;
- ils doivent le rester pendant une **période continue** de l'ordre de deux semaines : le
  compteur repart si le nombre passe sous le seuil ;
- ces deux valeurs ont déjà changé plusieurs fois. **La Play Console affiche la règle qui
  s'applique à ton compte**, avec un compteur de progression. C'est elle qui fait foi, pas
  ce document.

Ce n'est pas du temps perdu : c'est exactement la recette sur appareil réel qui manque
encore au lot 1.11, et douze personnes qui organisent une vraie soirée trouveront ce
qu'aucun test automatisé ne trouve.

**Coût** : 25 USD, une seule fois, à la création du compte.

**À commencer dès aujourd'hui** : réunir douze personnes prêtes à installer et à rester
inscrites deux semaines est plus long que tout le reste de ce guide. Le délai court à
partir du moment où elles ont accepté, pas du dépôt du bundle.

---

## 1. La clé d'upload

Il y a **deux clés**, et les confondre est la source d'à peu près toutes les frayeurs
qu'on lit sur le sujet :

| | Qui la détient | À quoi elle sert | Si tu la perds |
|---|---|---|---|
| Clé de **signature** | Google, via Play App Signing | Signer l'application livrée aux téléphones | Rien à craindre : tu ne l'as jamais eue |
| Clé d'**upload** | Toi | Prouver que c'est bien toi qui déposes | Google la révoque et t'en fait générer une autre |

C'est bien Google qui gère la clé qui compte — la recommandation qu'on t'a donnée est la
bonne, et l'étape 4 l'active. Mais un `.aab` non signé est rejeté avant même d'arriver
jusqu'à lui : il te faut donc ta propre clé d'upload.

L'application est aujourd'hui signée avec la clé de débogage, que Google Play refuse.

```bash
keytool -genkey -v \
  -keystore ~/cles/partyplan-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload
```

Réponds aux questions (nom, organisation, pays : `FR`). Retiens les deux mots de passe.

> Sauvegarde le `.jks` ailleurs que sur ton poste. La perdre n'est pas dramatique — Google
> sait révoquer une clé d'upload et en accepter une nouvelle — mais c'est un échange de
> courriels avec l'assistance, et quelques jours sans pouvoir publier de correctif. Le
> fichier est déjà exclu du dépôt par `.gitignore`.

Déclare-la ensuite dans `app/android/key.properties` — fichier hors dépôt :

```properties
storePassword=<mot de passe du magasin>
keyPassword=<mot de passe de la clé>
keyAlias=upload
storeFile=/home/maxence/cles/partyplan-upload.jks
```

Rien d'autre à modifier : `app/android/app/build.gradle.kts` lit ce fichier s'il existe et
signe le release avec cette clé. Absent, il retombe sur la clé de débogage en le disant —
un clone frais reste ainsi compilable sans détenir la clé.

---

## 2. Le numéro de version

Google Play refuse un `versionCode` déjà publié. Il vient de `version:` dans
`app/pubspec.yaml`, aujourd'hui `0.1.0`.

Pour une première publication, passe à `1.0.0+1` :

```yaml
version: 1.0.0+1
```

Ce qui suit le `+` est le `versionCode` : un entier à incrémenter **à chaque dépôt**, y
compris pour une correction déposée le même jour. Ce qui précède est le `versionName`,
celui que les gens lisent.

---

## 3. Construire le bundle

Google Play n'accepte pas d'APK pour une nouvelle application : il exige un *App Bundle*,
dont il dérive lui-même un APK adapté à chaque appareil.

```bash
make aab
```

Le fichier arrive dans `app/build/app/outputs/bundle/release/app-release.aab`. La cible
refuse de produire quoi que ce soit si `key.properties` est absent, plutôt que de te
laisser déposer un bundle signé en débogage que Google rejetterait sans explication utile.

**Vérifie le niveau d'API cible.** Google relève chaque année le `targetSdk` minimum exigé
pour une nouvelle application. Le projet suit la valeur par défaut de Flutter, en général
suffisante, mais la console te le dira au dépôt. Si elle refuse, la valeur se force dans
`app/android/app/build.gradle.kts`.

---

## 4. Créer l'application dans la Play Console

Sur [play.google.com/console](https://play.google.com/console) : *Créer une application*.

- **Nom** : PartyPlan
- **Langue par défaut** : français (France)
- **Type** : application, gratuite

Le choix gratuit/payant est **définitif** : une application publiée gratuite ne peut jamais
devenir payante. Le modèle prévu au cahier des charges — gratuit avec une formule Premium
en achat intégré (`EF-PRM-01`) — impose donc bien « gratuite » ici.

**Play App Signing** est actif par défaut pour toute nouvelle application, et c'est ce que
tu veux : Google conserve la clé de signature finale, celle qu'il serait catastrophique de
perdre, et resigne ton bundle après réception. La clé de l'étape 1 n'est que ta clé
d'upload.

> ⚠️ **Conséquence directe, et c'est le piège de cette étape** : l'empreinte de
> l'application publiée n'est plus celle de ta clé. Deux choses de PartyPlan en dépendent
> et casseront si tu l'ignores — la connexion Google et les liens d'invitation. C'est
> l'objet de l'étape 7, à faire impérativement.

---

## 5. La fiche du magasin

*Présence sur Google Play → Fiche Play Store principale.*

| Champ | Valeur pour PartyPlan |
|---|---|
| Nom | PartyPlan |
| Description courte (80 car.) | Organisez vos soirées à plusieurs : présences, courses, dépenses, remboursements. |
| Description complète | À rédiger — parle des soirées entre amis, pas de « gestion d'événements » : le registre est convivial (`§10.3`). |
| Icône | 512 × 512 PNG, depuis `app/assets/brand/logo.png` |
| Image de bannière | 1024 × 500 PNG, à produire |
| Captures d'écran | 2 minimum, 8 recommandées, téléphone. `docs/captures/` en contient déjà. |
| Catégorie | Style de vie, ou Social |
| Courriel de contact | Le tien |
| Politique de confidentialité | `https://partyplan.maxencecoeur.fr/confidentialite.html` |

Les quatre documents légaux sont déjà en ligne sur la vitrine : `confidentialite.html`,
`conditions.html`, `mentions-legales.html`, `support.html`. C'est l'URL de confidentialité
que Google exige, et il vérifie qu'elle répond.

---

## 6. Les questionnaires obligatoires

Quatre formulaires bloquent la publication tant qu'ils ne sont pas remplis. Le plus long
est le deuxième.

**Accès à l'application.** PartyPlan exige un compte pour tout voir. Google doit donc
recevoir des identifiants de test, sans quoi le relecteur ne voit qu'un écran de connexion
et **refuse l'application**. Crée un compte dédié à la relecture, membre d'une soirée
d'exemple bien remplie, et donne ses identifiants ici. N'utilise pas ton compte
d'administration.

**Sécurité des données.** Déclare ce que PartyPlan collecte réellement :

| Donnée | Collectée | Pourquoi |
|---|---|---|
| Adresse e-mail, nom | Oui | Compte et identification dans une soirée |
| Photos | Oui | Photo de profil, images de soirée et de discussion |
| Messages | Oui | Discussion de soirée |
| Informations financières | Oui | Dépenses et remboursements entre amis |
| Position | Non | |
| Identifiants publicitaires | Non | Aucune publicité, aucun pistage |

Déclare aussi le chiffrement en transit (TLS partout) et la possibilité de supprimer son
compte — PartyPlan la propose, c'est un point sur lequel Google insiste.

**Classification du contenu.** Questionnaire sur la violence, le sexe, les jeux d'argent :
réponds non partout. PartyPlan comporte une discussion entre utilisateurs, il faut le
déclarer — cela suffit souvent à obtenir PEGI 3 ou 7.

**Public cible.** Choisis 18 ans et plus. L'application parle de soirées et de partage de
dépenses ; viser les mineurs déclencherait les obligations bien plus lourdes de la
politique « Familles ».

---

## 7. Rebrancher ce qui dépend de la signature

**À faire après le premier dépôt, et sans l'oublier.** Play App Signing a changé
l'empreinte de l'application publiée. Deux fonctions de PartyPlan s'y adossent.

Récupère la nouvelle empreinte dans la console : *Configuration → Intégrité de
l'application → Signature de l'application*. Note le **SHA-1** et le **SHA-256** du
« certificat de signature de l'application » — pas ceux du certificat d'upload.

**a. La connexion Google.** Dans la [console Google Cloud](https://console.cloud.google.com/apis/credentials),
projet `partyplan-99106`, crée un second identifiant OAuth **Android** avec le paquet
`fr.maxencecoeur.partyplan` et le **SHA-1** de Play. Garde celui de ta clé de debug : les
deux coexistent, ce qui te permet de continuer à tester en local.

**b. Les liens d'invitation.** `app/web/.well-known/assetlinks.json` porte aujourd'hui le
SHA-256 de la clé de débogage :

```
99:AB:98:70:F1:32:06:6A:2D:48:66:05:4F:F3:F1:C6:46:3C:3E:5E:67:CB:82:77:54:CF:AB:E8:48:0D:20:B4
```

Ajoute celui de Play **à côté** — le tableau accepte plusieurs empreintes, et conserver les
deux garde les liens fonctionnels sur tes builds locaux. Sans cette mise à jour, ouvrir un
lien `/join/...` sur un téléphone lance le navigateur au lieu de l'application, alors même
que tout le reste marche. Reconstruis ensuite l'image web pour publier le fichier.

---

## 8. Déposer et publier

### 8.1 Le test fermé

*Test → Test fermé → Créer une release.*

1. Crée la liste de testeurs et invite tes douze personnes (adresse Google de chacune).
2. Téléverse le `.aab`.
3. Écris les notes de version.
4. *Envoyer pour examen.*

Même une release de test fermé passe la revue de Google. Compte de quelques heures à
plusieurs jours pour ce premier examen ; les suivants sont plus rapides.

Une fois approuvée, **transmets à chaque testeur le lien d'inscription** affiché sur la
page de la liste. Tant qu'une personne n'a pas cliqué et accepté, elle ne compte pas — et
c'est là que le calendrier dérape le plus souvent.

Pendant ces deux semaines, tu peux déposer autant de versions que tu veux : incrémente le
`versionCode` à chaque fois. C'est le moment d'utiliser tes testeurs pour ce qu'ils valent
— les notifications sur de vrais téléphones, des marques et des versions d'Android
différentes.

### 8.2 Le passage en production

Quand la console indique le seuil atteint, un bouton apparaît pour **demander l'accès à la
production**. Un formulaire s'y ajoute : comment tu as recruté tes testeurs, ce que leurs
retours ont changé. Réponds honnêtement et concrètement, c'est relu par un humain.

Une fois l'accès accordé : *Production → Créer une release*, même bundle, même procédure.

Un refus est courant sur un premier dépôt. Le motif est toujours explicite, et se corrige
presque toujours dans les questionnaires de l'étape 6, rarement dans le code.

---

## 9. Après la publication, ce qui reste vrai

- **Le versionCode ne recule jamais.** Incrémente-le à chaque dépôt.
- **La clé de publication ne se remplace pas** hors procédure Play App Signing. Sauvegarde-la.
- **Les notifications ne dépendent pas du Play Store.** Elles passent par Firebase, déjà
  configuré, et continueront de fonctionner à l'identique.
- **Le domaine de l'API est inscrit dans le binaire** à la compilation (`API_BASE_URL`).
  En changer impose une nouvelle version, pas un réglage serveur.

---

## Ce que ce guide ne couvre pas

- **iOS** : autre magasin, autres règles, prévu en V1.2 (`docs/comptes-externes.md`).
- **Les achats intégrés Premium** (`EF-PRM-01`) : ils exigent la facturation Play, un lot
  à part entière.
- **La publication automatisée** depuis la CI : possible via l'API Play Developer, sans
  intérêt tant que les dépôts sont rares.
