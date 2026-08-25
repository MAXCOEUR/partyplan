# PartyPlan — Cahier des charges

| | |
|---|---|
| Produit | PartyPlan — organisation d'événements entre amis |
| Version du document | 1.0 |
| Date | 19/08/2026 |
| Auteur | Maxence Cœur |
| Statut | À valider |

## Sommaire

1. [Contexte et objectifs](#1-contexte-et-objectifs)
2. [Périmètre](#2-périmètre)
3. [Acteurs et rôles](#3-acteurs-et-rôles)
4. [Glossaire](#4-glossaire)
5. [Exigences fonctionnelles](#5-exigences-fonctionnelles)
6. [Règles de calcul financier](#6-règles-de-calcul-financier)
7. [Modèle de données](#7-modèle-de-données)
8. [Interface de programmation (API)](#8-interface-de-programmation-api)
9. [Temps réel](#9-temps-réel)
10. [Écrans et navigation](#10-écrans-et-navigation)
11. [Exigences non fonctionnelles](#11-exigences-non-fonctionnelles)
12. [Conformité RGPD et mentions légales](#12-conformité-rgpd-et-mentions-légales)
13. [Infrastructure, déploiement et environnement local](#13-infrastructure-et-déploiement)
14. [Supervision, sauvegardes, reprise](#14-supervision-sauvegardes-reprise)
15. [Stratégie de test](#15-stratégie-de-test)
16. [Jalons et livrables](#16-jalons-et-livrables)
17. [Risques](#17-risques)
18. [Critères d'acceptation du MVP](#18-critères-dacceptation-du-mvp)
19. [Hypothèses retenues et questions ouvertes](#19-hypothèses-retenues-et-questions-ouvertes)

---

## 1. Contexte et objectifs

### 1.1 Problème

L'organisation d'une soirée entre amis se fait aujourd'hui dans un groupe de messagerie
(WhatsApp, Snapchat, Messenger). Les informations structurantes — qui vient, qui apporte
quoi, qui a payé combien — se noient dans le flux conversationnel. Conséquences observées :

- le nombre réel de présents reste inconnu jusqu'au dernier moment ;
- des achats sont dupliqués ou oubliés ;
- les avances de trésorerie ne sont jamais réglées, ou le sont approximativement ;
- l'organisateur porte seul la charge de synthèse.

### 1.2 Proposition

Un espace unique par événement, où chaque information est structurée plutôt que
conversationnelle : présences, liste de courses attribuée, dépenses, remboursements
calculés, planning.

### 1.3 Objectifs mesurables

| Réf | Objectif | Indicateur | Cible à 6 mois |
|---|---|---|---|
| OBJ-01 | L'invité répond sans friction | Taux de réponse à l'invitation | > 70 % des invités ouvrant le lien |
| OBJ-02 | Le produit est réutilisé | Part d'organisateurs créant un 2ᵉ événement | > 40 % |
| OBJ-03 | Viralité | Nombre moyen d'invités par événement devenant organisateurs | > 0,15 |
| OBJ-04 | Les remboursements aboutissent | Part des dettes marquées remboursées sous 7 jours | > 50 % |
| OBJ-05 | La liste de courses est complète | Part d'articles attribués avant la date de l'événement | > 80 % |

### 1.4 Facteur de différenciation

L'acquisition est portée par l'usage : un organisateur amène mécaniquement 5 à 15
personnes dans le produit en envoyant un lien. L'aperçu doit rester immédiatement
accessible et le retour après connexion ou inscription doit conserver ce lien ; toute
nouvelle adhésion exige néanmoins un compte, conformément à l'ADR 0006.

---

## 2. Périmètre

### 2.1 Inclus au MVP

**Socle identité (V0.5, développé en premier)** : création de compte avec mot de passe,
connexion Google, vérification d'adresse, réinitialisation de mot de passe, gestion du
profil et de la photo, gestion des sessions, export et suppression de ses données,
compte administrateur amorcé par variables d'environnement, back-office de gestion des
comptes avec journal d'audit.

**Socle événementiel (V1.0)** : création d'événement · invitation par lien, QR code et
code court · aperçu public restreint puis adhésion avec compte · statuts de présence détaillés · liste de courses
collaborative avec attribution · saisie des montants payés · calcul et simplification des
remboursements · planning de l'événement · notifications · synchronisation temps réel ·
application Web (PWA) et Android.

### 2.2 Reporté en V1.1

Tâches · sondages · discussion · photos · rappels configurables · groupes permanents ·
application iOS.

### 2.3 Reporté en V2

Modèles d'événements · suggestions de quantités par IA · statistiques · widgets système ·
synchronisation Google/Apple Calendar · liens de paiement · événements récurrents ·
offre Premium · gamification.

### 2.4 Explicitement hors périmètre (toutes versions)

| Réf | Exclusion | Motif |
|---|---|---|
| HP-01 | Encaissement ou transfert de fonds par PartyPlan | Statut d'établissement de paiement, agrément ACPR. Le produit se limite à générer des liens vers des services tiers. |
| HP-02 | Messagerie généraliste hors événement | Non concurrentiel face aux messageries installées. |
| HP-03 | Découverte d'événements publics, réseau social | Événement privé par défaut, non indexable. |
| HP-04 | Billetterie, contrôle d'accès, événements commerciaux | Autre marché, autres contraintes réglementaires. |
| HP-05 | Multi-devise | Un seul groupe d'amis, une seule devise. Reporté sans date. |

---

## 3. Acteurs et rôles

### 3.1 Rôles plateforme

Portée : l'instance entière. Colonne `users.platform_role`.

| Rôle | Obtention | Droits |
|---|---|---|
| **Utilisateur** (`User`) | par défaut | Aucun droit d'administration. |
| **Support** (`Support`) | promu par un `PlatformAdmin` | Consultation des comptes, déclenchement d'une réinitialisation de mot de passe, révocation de sessions. Ni suppression, ni suspension, ni gestion des rôles — `RG-ADM-05`. |
| **Administrateur** (`PlatformAdmin`) | amorcé par variables d'environnement, puis promotion | Toutes les actions d'administration du `§5.1.3`. |

**Un rôle plateforme ne donne aucun accès au contenu d'un événement** — `RG-ADM-01`.
C'est la règle qui rend crédible la promesse d'événement privé du `RG-EVT-01`.

### 3.2 Rôles événement

Portée : un seul événement. Colonne `event_members.role`. Sans rapport avec le rôle
plateforme.

| Rôle | Obtention | Droits |
|---|---|---|
| **Propriétaire** (`Owner`) | Créateur de l'événement | Tous droits, y compris suppression de l'événement et transfert de propriété. Un seul par événement. |
| **Administrateur** (`Admin`) | Promu par le propriétaire | Modifier l'événement, inviter, exclure un membre, modifier toute dépense, régénérer le lien d'invitation. |
| **Membre** (`Member`) | Compte ayant rejoint via une invitation | Modifier son propre statut, ajouter/prendre des articles, créer des dépenses, marquer ses remboursements. |
| **Membre historique sans compte** | Ligne créée avant l'ADR 0006 | Conservé et listable avec ses références financières, sans session ni possibilité de nouvelle adhésion. |
| **Visiteur** | Détient un lien d'invitation non encore utilisé | Lecture du nom, de la date et du lieu de l'événement uniquement, afin de décider s'il rejoint. |

**RG-ROLE-01** — Un administrateur ne peut ni exclure le propriétaire, ni se promouvoir
propriétaire, ni supprimer l'événement.

**RG-ROLE-02** — Le propriétaire ne peut pas quitter l'événement sans avoir transféré la
propriété à un autre membre. Le transfert est donc une opération de premier plan et non
un raffinement : sans elle, la règle enfermerait l'organisateur dans son propre événement.

Le repreneur doit posséder un compte. Les membres historiques sans compte ne sont pas
éligibles au transfert de propriété.
L'ancien propriétaire devient administrateur, et non membre ordinaire — il vient
d'organiser l'événement, lui retirer tout droit dans le même geste serait absurde.

**RG-ROLE-03** — L'exclusion d'un membre ne supprime ni ses dépenses, ni les articles
qu'il a achetés, ni ses dettes. Il apparaît comme membre inactif dans les calculs
financiers jusqu'à règlement complet.

---

## 4. Glossaire

| Terme | Définition |
|---|---|
| Événement | Unité d'organisation : une soirée, un week-end, un festival, un voyage. |
| Membre | Compte utilisateur rattaché à un événement. Les lignes historiques sans compte sont conservées uniquement pour leur historique financier. |
| Article | Ligne de la liste de courses (produit, quantité, unité, catégorie). |
| Attribution | Engagement d'un membre à se charger d'un article. |
| Dépense | Montant réellement payé par un membre, à répartir entre plusieurs membres. |
| Part | Poids attribué à un membre dans la répartition d'une dépense. |
| Solde | Différence entre ce qu'un membre a avancé et ce qu'il doit. |
| Règlement | Transfert d'argent proposé par l'application pour ramener les soldes à zéro. |
| Code court | Identifiant lisible d'un événement, saisi manuellement (format `PLAN-XXXXXX`). |
| Rôle plateforme | Droit portant sur l'instance entière : `User`, `Support`, `PlatformAdmin`. |
| Rôle événement | Droit portant sur un seul événement : `Member`, `Admin`, `Owner`. |
| Amorçage | Création du premier compte administrateur au démarrage, depuis les variables d'environnement. |
| Journal d'audit | Trace immuable, en ajout seul, de toute action d'administration. |

---

## 5. Exigences fonctionnelles

Chaque exigence porte une référence, une priorité et des critères d'acceptation.

Priorités : **P0** livraison MVP obligatoire · **P1** V1.1 · **P2** V2.

### 5.1 Comptes, authentification et administration

Cette section couvre l'identité : elle est développée avant toute fonctionnalité
événementielle, en version V0.5 de la feuille de route.

#### 5.1.1 Authentification

| Réf | P | Exigence |
|---|---|---|
| EF-AUTH-01 | P0 | Créer un compte avec adresse e-mail et mot de passe. |
| EF-AUTH-02 | P0 | Se connecter avec adresse e-mail et mot de passe. |
| EF-AUTH-03 | P0 | Vérifier l'adresse e-mail par lien envoyé à l'inscription. |
| EF-AUTH-04 | P0 | Réinitialiser son mot de passe par lien envoyé à l'adresse déclarée. |
| EF-AUTH-05 | P0 | Changer son mot de passe en fournissant l'ancien. |
| EF-AUTH-06 | P0 | Se connecter avec Google. |
| EF-AUTH-07 | P1 | Se connecter avec Apple. Obligatoire dès la publication iOS si une autre connexion tierce est proposée. |
| EF-AUTH-08 | P0 | Rattacher ou détacher une connexion tierce d'un compte existant. |
| EF-AUTH-09 | P0 | Session conservée 90 jours sans reconnexion, prolongée à chaque usage. |
| EF-AUTH-10 | P0 | Lister ses sessions actives et en révoquer une, ou toutes. |
| EF-AUTH-11 | P0 | Après connexion ou inscription depuis un aperçu d'invitation, conserver le chemin d'invitation afin que le compte rejoigne l'événement. |
| ~~EF-AUTH-12~~ | — | ~~Activer une double authentification par code temporel (TOTP).~~ **Abrogé le 24/08/2026 — ADR 0007.** |
| ~~EF-AUTH-13~~ | — | ~~Recevoir huit codes de secours à l'activation.~~ **Abrogé le 24/08/2026 — ADR 0007.** |

**RG-AUTH-01** — Le mot de passe comporte de 8 à 30 caractères, dont au moins une
majuscule, une minuscule, un chiffre et un caractère spécial, et est refusé s'il figure
dans une liste de mots de passe compromis. Aucune expiration périodique n'est imposée.

Règle modifiée le 25/08/2026 sur décision du produit. La précédente — 12 caractères sans
exigence de composition — suivait les recommandations de l'ANSSI et de la CNIL. Ce que le
changement coûte, pour mémoire : huit caractères complexes offrent moins de résistance que
douze quelconques, et le plafond à 30 interdit les phrases de passe. Le refus des mots de
passe divulgués reste donc la protection la plus efficace de cette règle, et il est
contrôlé **avant** la composition : dire « ajoute un caractère spécial » à quelqu'un dont
le mot de passe figure dans une fuite le pousse vers une variante de ce même mot de passe.

**RG-AUTH-02** — Le mot de passe est haché avec Argon2id. Aucun mot de passe n'est
journalisé, transmis par courriel, ni consultable par qui que ce soit, administrateur
inclus.

**RG-AUTH-03** — Le lien de vérification d'adresse et le lien de réinitialisation sont
valables 15 minutes, à usage unique, et invalidés dès qu'un nouveau est demandé pour la
même adresse. Seul le condensé du jeton est stocké.

**RG-AUTH-04** — La réponse à une demande de réinitialisation est identique que l'adresse
existe ou non, afin de ne pas révéler l'existence d'un compte.

**RG-AUTH-05** — Cinq demandes de réinitialisation par adresse et par heure au maximum.
Après dix échecs de connexion consécutifs sur un compte, les tentatives sont ralenties
de façon croissante ; le compte n'est jamais verrouillé définitivement, afin d'éviter un
déni de service par un tiers.

Deux limites concourantes sont nécessaires, et non une seule : le décompte **par adresse**
est tenu par le service, celui **par adresse IP** par le limiteur de débit HTTP. La
première arrête le harcèlement d'un compte précis depuis plusieurs sources, la seconde un
balayage d'adresses depuis une source unique. Le dépassement de la limite par adresse est
silencieux, la réponse de l'endpoint étant de toute façon invariable (`RG-AUTH-04`).

**RG-AUTH-06** — La réinitialisation d'un mot de passe et le changement d'adresse e-mail
révoquent toutes les sessions actives, sauf celle en cours.

**RG-AUTH-07** — Aucun nouveau jeton invité n'est créé et aucune ligne historique sans
`user_id` n'est rattachée automatiquement à un compte. Ces lignes restent conservées et
listables avec leurs références financières ; elles ne permettent ni session ni nouvelle
adhésion.

**RG-AUTH-08** — Un compte créé par connexion tierce sans mot de passe peut en définir un
à tout moment, par le parcours de réinitialisation.

**RG-AUTH-09 à RG-AUTH-13** — *Abrogées le 24/08/2026 — `ADR 0007`.* Elles décrivaient
la connexion en deux temps, le chiffrement AES-GCM du secret, l'activation après
validation d'un premier code, les huit codes de secours et la désactivation par mot de
passe. La double authentification est retirée du produit : la connexion n'a plus qu'une
étape, et le mot de passe est l'unique facteur, y compris pour un rôle plateforme.
L'ADR nomme ce que cette décision coûte et à quelles conditions elle serait revue.

*Critères d'acceptation EF-AUTH-11* : depuis un aperçu d'invitation, après connexion ou
inscription, le retour conserve le chemin ; le compte rejoint l'événement une fois avec
son nom de profil et le statut `Unknown`, puis ouvre son tableau de bord.

#### 5.1.2 Compte et profil

| Réf | P | Exigence |
|---|---|---|
| EF-USR-01 | P0 | Consulter son profil. |
| EF-USR-02 | P0 | Modifier son nom affiché. |
| EF-USR-03 | P0 | Modifier son adresse e-mail, avec vérification de la nouvelle adresse avant prise d'effet. |
| EF-USR-04 | P0 | Téléverser une photo de profil. |
| EF-USR-05 | P0 | Recadrer la photo avant envoi. |
| EF-USR-06 | P0 | Supprimer sa photo de profil et revenir à l'avatar par défaut. |
| EF-USR-07 | P0 | Choisir sa langue et son fuseau horaire. |
| EF-USR-08 | P0 | Consulter et modifier ses préférences de notification. |
| EF-USR-09 | P0 | Exporter l'intégralité de ses données au format JSON. |
| EF-USR-10 | P0 | Supprimer son compte depuis l'application, sans passer par le support. |

**RG-USR-01** — La photo de profil est acceptée en JPEG, PNG, WebP ou HEIC, dans la
limite de 5 Mo. Elle est redimensionnée côté serveur en trois tailles (512, 128, 48
pixels), convertie en WebP, et les métadonnées EXIF — dont la géolocalisation — sont
supprimées.

**RG-USR-02** — L'avatar par défaut est généré à partir des initiales et d'une couleur
dérivée de l'identifiant, sans appel à un service externe de type Gravatar.

**RG-USR-03** — Les photos sont servies par le domaine de fichiers statiques, sous une
adresse contenant une empreinte du contenu, afin d'être mises en cache durablement sans
risque d'afficher une version obsolète.

**RG-USR-04** — Le nom affiché est modifiable librement, mais son historique est conservé
sur les événements en cours : un membre ne peut pas changer de nom pour se dissocier
d'une dette. Le fil d'activité conserve le nom utilisé au moment de l'action.

**RG-USR-05** — La suppression de compte suit `RG-RGPD-01` : les contributions
financières sont anonymisées, non supprimées. L'utilisateur en est informé par un texte
explicite avant confirmation, et doit saisir son adresse e-mail pour confirmer.

**RG-USR-06** — Un compte supprimé libère son adresse e-mail : une réinscription
ultérieure avec la même adresse crée un compte neuf, sans lien avec l'ancien.

#### 5.1.3 Administration de la plateforme

Deux axes de rôle indépendants coexistent, et ne doivent jamais être confondus :

| Axe | Valeurs | Portée |
|---|---|---|
| Rôle **plateforme** (`users.platform_role`) | `User` · `Support` · `PlatformAdmin` | l'instance entière |
| Rôle **événement** (`event_members.role`) | `Member` · `Admin` · `Owner` | un seul événement |

Être `PlatformAdmin` ne confère aucun droit dans un événement dont on n'est pas membre.

| Réf | P | Exigence |
|---|---|---|
| EF-ADM-01 | P0 | Un compte administrateur est créé au premier démarrage à partir des variables d'environnement, si aucun n'existe. |
| EF-ADM-02 | P0 | Lister les comptes utilisateurs, avec recherche par nom ou adresse, tri et pagination. |
| EF-ADM-03 | P0 | Consulter la fiche technique d'un compte : date de création, dernière connexion, adresse vérifiée, connexions tierces rattachées, nombre d'événements, état de suspension. |
| EF-ADM-04 | P0 | Déclencher l'envoi d'un lien de réinitialisation de mot de passe à un utilisateur. |
| EF-ADM-05 | P0 | Révoquer toutes les sessions d'un utilisateur. |
| EF-ADM-06 | P0 | Suspendre un compte, avec motif, et le réactiver. |
| EF-ADM-07 | P0 | Supprimer un compte, avec la même anonymisation que l'auto-suppression. |
| EF-ADM-08 | P0 | Promouvoir un compte en `Support` ou `PlatformAdmin`, et révoquer ce rôle. |
| EF-ADM-09 | P0 | Consulter le journal d'audit des actions d'administration. |
| EF-ADM-10 | P0 | Consulter les indicateurs d'instance : comptes, événements actifs, lignes historiques sans compte, volume de stockage. |
| EF-ADM-11 | P1 | Forcer la vérification d'une adresse e-mail, en cas de courriel non délivré. |
| EF-ADM-12 | P1 | Exporter les données d'un utilisateur à sa demande, lorsqu'il ne peut plus se connecter. |
| EF-ADM-13 | P1 | Supprimer une photo de profil signalée comme inappropriée. |
| EF-ADM-14 | P2 | Consulter les indicateurs des objectifs `OBJ-01` à `OBJ-05`. |

**RG-ADM-01** — **Un rôle plateforme ne donne aucun accès au contenu d'un événement.**
Ni la liste nominative des membres, ni les dépenses, ni la liste de courses, ni la
discussion, ni le planning ne sont consultables par un administrateur qui n'est pas
membre de l'événement. Le filtre du `RG-SEC-01` s'applique sans exception ni
contournement. Sans cette règle, la promesse d'événement privé du `RG-EVT-01` serait
fausse.

**RG-ADM-02** — Un administrateur ne définit, ne consulte, ni ne transmet jamais un mot
de passe. Il ne peut que déclencher l'envoi d'un lien de réinitialisation à l'adresse
enregistrée.

**RG-ADM-03** — Un administrateur ne peut ni se supprimer, ni se révoquer lui-même, ni
supprimer le dernier `PlatformAdmin` existant.

**RG-ADM-04** — *Abrogée le 24/08/2026 — `ADR 0007`.* Elle exigeait la double
authentification de tout compte `Support` ou `PlatformAdmin`. C'est cette exigence qui
rendait l'administration inatteignable : le compte amorcé n'a pas de second facteur,
l'activer supposait d'accéder à l'application, et le back-office refusait l'accès à son
seul administrateur. Le rôle seul ouvre désormais l'administration. Les contreparties
qui rendent ce choix tenable sont énumérées dans l'ADR, `RG-ADM-01` en tête : un rôle
plateforme ne lit jamais le contenu d'un événement.

**RG-ADM-05** — Le rôle `Support` dispose des seules actions `EF-ADM-02`, `EF-ADM-03`,
`EF-ADM-04`, `EF-ADM-05` et `EF-ADM-11`. La suppression, la suspension et la gestion des
rôles sont réservées à `PlatformAdmin`.

**RG-ADM-06** — Toute action d'administration produit une entrée d'audit immuable :
auteur, cible, nature de l'action, motif saisi, horodatage, adresse IP. Le journal
n'est ni modifiable ni supprimable, y compris par un `PlatformAdmin`.

**RG-ADM-07** — Un compte suspendu ne peut plus se connecter ; ses sessions sont
révoquées immédiatement. Ses données restent intactes et ses dettes restent dues.

**RG-ADM-08** — Les écrans d'administration ne sont pas embarqués dans les applications
mobiles. Ils n'existent que dans la version Web, sous les routes `/admin/*`, et ne
répondent qu'aux rôles plateforme.

**Amorçage du compte administrateur**

**RG-ADM-09** — Au démarrage, si aucun compte `PlatformAdmin` n'existe, un compte est
créé à partir de `ADMIN_EMAIL` et `ADMIN_PASSWORD`. L'opération est idempotente :
si un `PlatformAdmin` existe déjà, rien n'est fait, et le mot de passe d'amorçage n'est
jamais réappliqué.

**RG-ADM-10** — Le compte amorcé porte l'obligation de changer son mot de passe à la
première connexion, avant toute autre action.
L'obligation est portée par une revendication du jeton : tant qu'elle est présente, seules
la lecture de son profil, le changement de mot de passe et la déconnexion sont permis.
Le mot de passe d'amorçage figure dans un fichier de configuration, donc lisible par
quiconque accède au serveur : laisser agir ce compte avant changement reviendrait à ne pas
avoir posé la contrainte.

**RG-ADM-11** — En environnement de production, l'API refuse de démarrer si
`ADMIN_EMAIL` est absent, si `ADMIN_PASSWORD` est absent alors qu'aucun administrateur
n'existe, ou si ce mot de passe ne satisfait pas `RG-AUTH-01`. Un démarrage silencieux
avec un identifiant par défaut connu serait la faille la plus évidente du produit.

**RG-ADM-12** — `ADMIN_PASSWORD` peut être retiré de l'environnement dès que le mot de
passe a été changé. Sa présence continue est signalée comme un avertissement dans les
journaux de démarrage.

*Critères d'acceptation EF-ADM-01* : sur une base vierge, le démarrage crée le compte et
le journalise sans afficher le mot de passe ; un second démarrage ne crée aucun doublon
et ne réinitialise pas le mot de passe changé entre-temps.

*Critères d'acceptation RG-ADM-01* : un `PlatformAdmin` appelant les endpoints d'un
événement dont il n'est pas membre reçoit 404 sur l'ensemble d'entre eux. Un test
d'intégration le vérifie pour chaque endpoint d'événement.

### 5.2 Événements

| Réf | P | Exigence |
|---|---|---|
| EF-EVT-01 | P0 | Créer un événement avec nom, date et heure de début, lieu (texte libre), description. |
| EF-EVT-02 | P0 | Renseigner une date et heure de fin facultatives. En leur absence, l'événement est considéré comme terminé 12 heures après son début. |
| EF-EVT-03 | P0 | Modifier tout champ de l'événement (propriétaire et administrateurs). Toute modification de date ou de lieu génère une notification aux membres ayant répondu. |
| EF-EVT-04 | P0 | Consulter le tableau de bord de l'événement : présents, avancement des courses, total dépensé, prochaine étape du planning. |
| EF-EVT-05 | P0 | Lister ses événements séparés en « à venir » et « passés », triés par date. |
| EF-EVT-06 | P0 | Quitter un événement. |
| EF-EVT-07 | P0 | Supprimer un événement (propriétaire uniquement), avec confirmation explicite mentionnant la perte des données financières. |
| EF-EVT-08 | P1 | Ajouter une image de couverture. |
| EF-EVT-09 | P1 | Archiver un événement passé pour le sortir de la liste principale. |
| EF-EVT-10 | P1 | Dupliquer un événement (structure, courses, membres — sans les dépenses). |
| EF-EVT-11 | P2 | Créer un événement depuis un modèle. |
| EF-EVT-12 | P2 | Créer un événement récurrent. |

**RG-EVT-01** — Un événement est privé par défaut et sans exception au MVP : aucune page
publique, aucun référencement, en-tête `X-Robots-Tag: noindex` sur toute page d'événement.

**RG-EVT-02** — La suppression d'un événement est bloquée s'il subsiste des règlements
non marqués comme effectués, sauf confirmation renforcée du propriétaire.

**RG-EVT-03** — Le lieu est un champ texte au MVP. Latitude et longitude sont stockées
mais non alimentées ; la géolocalisation est reportée.

*Critères d'acceptation EF-EVT-04* : le tableau de bord affiche des valeurs cohérentes
avec les autres écrans à la seconde près après une action d'un autre membre, sans
rafraîchissement manuel.

### 5.3 Invitations et accès

| Réf | P | Exigence |
|---|---|---|
| EF-INV-01 | P0 | Générer un lien d'invitation partageable de la forme `https://web.partyplan.maxencecoeur.fr/join/{token}`. |
| EF-INV-02 | P0 | Afficher un QR code correspondant au lien, exportable en image. |
| EF-INV-03 | P0 | Afficher un code court saisissable manuellement, au format `PLAN-XXXXXX`. |
| EF-INV-04 | P0 | Après l'aperçu public restreint, se connecter ou créer un compte avant de rejoindre ; le serveur prend le nom du profil et crée le statut `Unknown`. |
| EF-INV-05 | P0 | Régénérer le lien d'invitation, ce qui invalide le précédent. |
| EF-INV-06 | P0 | Désactiver les nouvelles arrivées (événement fermé). |
| EF-INV-07 | P1 | Inviter par e-mail depuis l'application. |
| EF-INV-08 | P1 | Réinviter les membres d'un groupe permanent en une action. |

**RG-INV-01** — Le jeton du lien comporte au minimum 128 bits d'entropie, encodé en
base64url, non déductible de l'identifiant de l'événement.

**RG-INV-02** — Le code court utilise un alphabet de 32 caractères excluant les
ambiguïtés (`I`, `O`, `0`, `1`), sur 6 positions. Il est unique parmi les événements
non archivés. En cas de collision à la génération, une nouvelle valeur est tirée.

**RG-INV-03** — La résolution d'un code court est limitée à 10 tentatives par minute et
par adresse IP, et 100 par jour. Au-delà, réponse 429 pendant 15 minutes. Cette
limitation est la contre-mesure au caractère devinable d'un code à 6 caractères.

**RG-INV-04** — Avant d'avoir rejoint, un visiteur ne voit que le nom, les dates, le
lieu, la description et le nombre de participants. Ni la liste nominative, ni les
dépenses, ni la discussion.

**RG-INV-05** — Les POST d'adhésion exigent un compte authentifié, sont idempotents et
ne reçoivent ni prénom ni statut. Le lien d'invitation est conservé pendant
l'authentification, puis le compte rejoint automatiquement avec le statut `Unknown`.

**RG-INV-06** — Après décodage, le paramètre `retour` n'accepte que l'un des deux
formats exacts `/join/{token}` ou `/rejoindre/{code}`. Toute autre valeur — URL absolue,
schéma, autorité ou préfixe `//`, fragment, paramètres, segment supplémentaire ou route
hors invitation — est remplacée par `/`. Cette liste positive interdit toute redirection
ouverte après connexion ou inscription.

*Critères d'acceptation EF-INV-04* : depuis un navigateur sans session, l'aperçu affiche
« Se connecter » et « Créer un compte ». Après authentification, l'application revient
à l'invitation, rejoint une seule fois avec le nom du profil et ouvre le tableau de bord ;
aucun formulaire de prénom ou de statut ne précède l'entrée dans la soirée.

*Recette du retour* : `/join/{token}` et `/rejoindre/{code}` sont conservés après
authentification. `https://host/...`, `//host/...`, `/admin`, un fragment, des paramètres
ou tout autre chemin sont remplacés par `/`.

### 5.4 Présences

| Réf | P | Exigence |
|---|---|---|
| EF-PRES-01 | P0 | Déclarer son statut parmi : présent, peut-être, absent, arrive plus tard, part plus tôt. |
| EF-PRES-02 | P0 | Renseigner une heure d'arrivée prévue et/ou une heure de départ prévue. |
| EF-PRES-03 | P0 | Modifier son statut à tout moment, y compris pendant l'événement. |
| EF-PRES-04 | P0 | Consulter la liste des membres avec statut et horaires. |
| EF-PRES-05 | P0 | Afficher la synthèse « n confirmés sur m invités ». |
| EF-PRES-06 | P1 | Indiquer un nombre d'accompagnants (« +1 »), plafonné à dix. |
| EF-PRES-07 | P1 | Relancer les membres n'ayant pas répondu (action de l'organisateur). |

**RG-PRES-01** — Le statut initial d'un membre est `Unknown`. Il n'est jamais présumé
présent.

**RG-PRES-02** — Les statuts `Late` et `EarlyLeave` comptent comme présents dans tous
les décomptes et dans l'assiette de répartition par défaut des dépenses.

**RG-PRES-03** — Le statut `Maybe` ne compte pas dans les présents affichés, mais est
signalé séparément. Il n'entre pas dans la répartition par défaut des dépenses.

**RG-PRES-04** — Le décompte des présents et le décompte des têtes sont deux valeurs
distinctes : la seconde ajoute les accompagnants. L'organisateur achète pour des têtes,
pas pour des comptes ; les confondre fausse toutes les quantités de la liste de courses.

### 5.5 Liste de courses

| Réf | P | Exigence |
|---|---|---|
| EF-CRS-01 | P0 | Ajouter un article : libellé, quantité, unité, catégorie. Seul le libellé est obligatoire. |
| EF-CRS-02 | P0 | Catégories prédéfinies : boissons, nourriture, matériel, autres. |
| EF-CRS-03 | P0 | S'attribuer un article (« je m'en occupe »), visible immédiatement par tous. |
| EF-CRS-04 | P0 | Retirer son attribution. |
| EF-CRS-05 | P0 | Marquer un article comme acheté, avec quantité réellement obtenue. |
| EF-CRS-06 | P0 | Saisir un prix estimé et un prix réellement payé. |
| EF-CRS-07 | P0 | Créer automatiquement une dépense lors de la saisie d'un prix payé, avec l'acheteur comme payeur. |
| EF-CRS-08 | P0 | Modifier ou supprimer un article. La suppression est refusée si une dépense y est rattachée. |
| EF-CRS-09 | P0 | Afficher l'avancement « n / m articles pris » et « n / m achetés ». |
| EF-CRS-10 | P0 | Commenter un article (texte court, par exemple « je n'ai trouvé que 2 paquets »). |
| EF-CRS-11 | P1 | Réordonner les articles et regrouper par catégorie ou par personne. |
| EF-CRS-12 | P1 | Ajouter plusieurs articles en une saisie (une ligne par article). |
| EF-CRS-13 | P2 | Générer une liste depuis un modèle d'événement. |
| EF-CRS-14 | P2 | Proposer des quantités selon le nombre de présents. |

**RG-CRS-01** — Un article n'a qu'un seul attributaire. Une seconde tentative
d'attribution est refusée avec un message indiquant qui s'en occupe déjà. Le contrôle
est effectué côté serveur en transaction, pas côté client.

**RG-CRS-02** — Si la quantité achetée est inférieure à la quantité demandée, l'article
reste visible comme partiellement satisfait ; le reliquat est affiché.

**RG-CRS-03** — Un article marqué acheté sans prix payé n'engendre aucune dépense.
Le prix estimé n'entre jamais dans les calculs financiers.

*Critères d'acceptation EF-CRS-03* : deux membres appuyant simultanément sur le même
article aboutissent à une seule attribution ; le second reçoit un refus explicite dans
la même seconde.

### 5.6 Dépenses

| Réf | P | Exigence |
|---|---|---|
| EF-DEP-01 | P0 | Créer une dépense : libellé, montant, payeur, date. |
| EF-DEP-02 | P0 | Choisir l'assiette de répartition : tous les présents, une sélection de membres, ou parts personnalisées. |
| EF-DEP-03 | P0 | Modifier ou supprimer une dépense (auteur, payeur, administrateurs). |
| EF-DEP-04 | P0 | Lister les dépenses de l'événement avec total et total par personne. |
| EF-DEP-05 | P0 | Consulter le détail d'une dépense : qui a payé, qui participe, part de chacun. |
| EF-DEP-06 | P1 | Joindre une photo de ticket. |
| EF-DEP-07 | P1 | Rattacher une dépense à un article de la liste de courses. |
| EF-DEP-08 | P2 | Définir plusieurs groupes de partage au sein d'un même événement. |
| EF-DEP-09 | P2 | Exporter les dépenses en PDF ou tableur. |

**RG-DEP-01** — Le montant est strictement positif, au maximum 99 999,99 €, exprimé en
euros avec deux décimales.

**RG-DEP-02** — L'assiette par défaut est constituée des membres de statut `Going`,
`Late` ou `EarlyLeave` au moment de la création de la dépense. Cette assiette est figée :
un membre confirmant sa présence après la saisie n'y est pas ajouté rétroactivement.

**RG-DEP-03** — Le payeur peut être exclu de l'assiette (cas du cadeau collectif).

**RG-DEP-04** — Une dépense conserve l'historique de ses modifications (auteur, date,
valeur précédente du montant et de l'assiette) pendant toute la vie de l'événement.

**RG-DEP-05** — La suppression d'une dépense est un effacement logique. Les soldes sont
recalculés, l'entrée reste consultable dans le fil d'activité.

### 5.7 Remboursements

| Réf | P | Exigence |
|---|---|---|
| EF-RMB-01 | P0 | Afficher le solde de chaque membre (avancé, dû, net). |
| EF-RMB-02 | P0 | Proposer une liste de règlements minimisant le nombre de transactions. |
| EF-RMB-03 | P0 | Marquer un règlement comme effectué, avec date et auteur du marquage. |
| EF-RMB-04 | P0 | Annuler un marquage erroné. |
| EF-RMB-05 | P0 | Afficher à chaque membre, sur le tableau de bord, ce qu'il doit et à qui. |
| EF-RMB-06 | P1 | Notifier le créditeur lorsqu'un débiteur déclare avoir remboursé. |
| EF-RMB-07 | P1 | Confirmation du remboursement par le créditeur (double validation). |
| EF-RMB-08 | P2 | Générer un lien de paiement Lydia/Sumeria, Revolut, PayPal, ou afficher un IBAN. |

**RG-RMB-01** — Le calcul est déterministe : deux exécutions sur le même jeu de données
produisent exactement la même liste de règlements, dans le même ordre.

**RG-RMB-02** — Aucun solde n'est persisté. Les soldes sont recalculés à la demande
depuis les dépenses et leurs participants. La table des règlements n'enregistre que les
remboursements déclarés effectués.

**RG-RMB-03** — Les règlements déjà marqués effectués sont intégrés comme mouvements
dans le calcul suivant, afin que la liste proposée ne les répète pas.

**RG-RMB-04** — Le tableau des règlements affiche un avertissement lorsque la somme des
soldes ne revient pas exactement à zéro, situation qui ne doit jamais survenir et
constitue une anomalie à journaliser.

### 5.8 Planning

| Réf | P | Exigence |
|---|---|---|
| EF-PLN-01 | P0 | Créer une étape : heure, libellé, lieu facultatif, commentaire facultatif. |
| EF-PLN-02 | P0 | Lister les étapes par ordre chronologique. |
| EF-PLN-03 | P0 | Modifier et supprimer une étape. |
| EF-PLN-04 | P0 | Mettre en évidence la prochaine étape sur le tableau de bord. |
| EF-PLN-05 | P1 | Affecter des participants à une étape. |
| EF-PLN-06 | P1 | Définir un rappel sur une étape (30 min, 1 h, 2 h avant). |
| EF-PLN-07 | P2 | Exporter le planning au format iCalendar. |

### 5.9 Tâches

| Réf | P | Exigence |
|---|---|---|
| EF-TSK-01 | P1 | Créer une tâche : libellé, responsable facultatif, échéance facultative. |
| EF-TSK-02 | P1 | S'attribuer une tâche, la marquer faite, l'annuler. |
| EF-TSK-03 | P1 | Afficher l'avancement des tâches sur le tableau de bord. |

### 5.10 Sondages

| Réf | P | Exigence |
|---|---|---|
| EF-SDG-01 | P1 | Créer un sondage à choix unique avec 2 à 10 options. |
| EF-SDG-02 | P1 | Voter et changer son vote tant que le sondage est ouvert. |
| EF-SDG-03 | P1 | Afficher les résultats avec le décompte par option. |
| EF-SDG-04 | P1 | Clôturer un sondage. |
| EF-SDG-05 | P2 | Choix multiple, vote anonyme, date limite automatique. |

### 5.11 Discussion et fil d'activité

| Réf | P | Exigence |
|---|---|---|
| EF-FIL-01 | P0 | Afficher un fil d'activité horodaté des actions structurantes de l'événement. |
| EF-MSG-01 | P1 | Envoyer un message texte dans l'événement. |
| EF-MSG-02 | P1 | Joindre une image à un message. |
| EF-MSG-03 | P1 | Réagir à un message par emoji. |
| EF-MSG-04 | P1 | Répondre à un message et mentionner un membre. |
| EF-MSG-05 | P1 | Supprimer son propre message. |

**RG-FIL-01** — Le fil d'activité enregistre au minimum : arrivée d'un membre,
changement de statut, ajout ou suppression d'article, attribution, achat, création et
modification de dépense, marquage de remboursement, modification de la date ou du lieu.

**RG-FIL-02** — Le fil est en lecture seule et ne peut pas être modifié, y compris par
le propriétaire. Il constitue la trace de référence en cas de litige entre membres sur
les montants.

**RG-MSG-01** — La discussion est une fonctionnalité secondaire. Aucun développement
visant à concurrencer une messagerie généraliste (appels, statuts, chiffrement bout en
bout, groupes hors événement) n'entre dans le périmètre.

### 5.12 Notifications

| Réf | P | Exigence |
|---|---|---|
| EF-NOT-01 | P0 | Notifier l'organisateur des réponses aux invitations. |
| EF-NOT-02 | P0 | Notifier les membres des modifications de date ou de lieu. |
| EF-NOT-03 | P0 | Rappeler à un membre qu'il n'a pas répondu à l'invitation (J-3 et J-1). |
| EF-NOT-04 | P0 | Signaler à l'organisateur les articles non attribués (J-1). |
| EF-NOT-05 | P0 | Rappeler l'événement 2 heures avant le début. |
| EF-NOT-06 | P0 | Notifier chaque débiteur du montant qu'il doit, le lendemain de l'événement. |
| EF-NOT-07 | P0 | Permettre la désactivation individuelle de chaque catégorie de notification. |
| EF-NOT-08 | P0 | Permettre la mise en sourdine d'un événement. |
| EF-NOT-09 | P1 | Notifications par courriel en repli lorsque les notifications poussées sont indisponibles. |

**RG-NOT-01** — Aucune notification n'est envoyée entre 22 h et 8 h heure locale du
destinataire, sauf le rappel de début d'événement.

**RG-NOT-02** — Les notifications d'activité (article pris, message) sont regroupées :
au maximum une notification par événement et par tranche de 15 minutes.

**RG-NOT-03** — Le consentement aux notifications poussées est demandé au moment où
il devient utile, jamais au premier lancement.

### 5.13 Groupes permanents

| Réf | P | Exigence |
|---|---|---|
| EF-GRP-01 | P1 | Créer un groupe nommé et y ajouter des membres. |
| EF-GRP-02 | P1 | Créer un événement en invitant l'ensemble d'un groupe. |
| EF-GRP-03 | P1 | Retirer un membre d'un groupe sans effet sur les événements passés. |

### 5.14 Offre Premium

| Réf | P | Exigence |
|---|---|---|
| EF-PRM-01 | P2 | Abonnement individuel 2,99 €/mois ou 19,99 €/an. |
| EF-PRM-02 | P2 | Fonctions incluses : au-delà de 20 participants, archives illimitées, modèles d'événements, thèmes et images de couverture, sondages avancés, export PDF/tableur, groupes de partage multiples, rappels avancés, statistiques. |
| EF-PRM-03 | P2 | Les fonctions Premium bénéficient à tous les membres d'un événement créé par un abonné. |

**RG-PRM-01** — Limites de l'offre gratuite : 20 participants par événement, nombre
d'événements actifs illimité, consultation des événements passés limitée à 3 mois après
leur date de fin.

**RG-PRM-02** — L'atteinte d'une limite ne bloque jamais un événement en cours : elle
empêche l'ajout du 21ᵉ participant, sans dégrader l'existant.

**RG-PRM-03** — Aucune fonction du MVP ne devient payante rétroactivement.

---

## 6. Règles de calcul financier

Cette section est normative. Toute divergence d'implémentation constitue une anomalie
bloquante.

### 6.1 Représentation des montants

- Stockage : `numeric(10,2)` en PostgreSQL, `decimal` en C#, `Decimal` en Dart.
- Aucun usage de `double`, `float` ou `real` sur un montant, à aucune étape.
- Unité de calcul interne : le centime, en entier, pour toute répartition.
- Devise unique : euro.

### 6.2 Répartition d'une dépense

Soit une dépense de montant `M` (en centimes) et `n` participants de parts
`p₁ … pₙ` (entiers positifs, valant 1 par défaut). Soit `P = Σpᵢ`.

1. Part théorique du participant `i` : `tᵢ = M × pᵢ / P`.
2. Part attribuée initiale : `aᵢ = ⌊tᵢ⌋`.
3. Reliquat : `R = M − Σaᵢ`, avec `0 ≤ R < n`.
4. Les `R` centimes restants sont attribués un par un aux participants ayant le plus
   grand reste fractionnaire `tᵢ − ⌊tᵢ⌋`. À reste égal, l'ordre est celui de
   l'identifiant de membre croissant, afin de garantir le déterminisme.

**Invariant IV-01** : `Σaᵢ = M` exactement, pour toute dépense.

### 6.3 Soldes

Pour chaque membre `i` :

- `avancé(i)` = somme des montants des dépenses non supprimées dont il est le payeur ;
- `dû(i)` = somme de ses parts attribuées sur l'ensemble des dépenses non supprimées ;
- `règlements_émis(i)` = somme des remboursements marqués effectués dont il est l'émetteur ;
- `règlements_reçus(i)` = somme des remboursements marqués effectués dont il est le destinataire ;
- `solde(i) = avancé(i) − dû(i) + règlements_émis(i) − règlements_reçus(i)`.

Un solde positif signifie que le membre doit recevoir de l'argent ; négatif, qu'il en doit.

**Invariant IV-02** : `Σ solde(i) = 0` sur l'ensemble des membres de l'événement.
Cet invariant est vérifié à chaque calcul ; toute violation est journalisée en erreur
et signalée dans l'interface.

### 6.4 Simplification des règlements

Algorithme retenu, dit d'appariement glouton :

1. Construire la liste `C` des créditeurs (solde > 0) et `D` des débiteurs (solde < 0).
2. Trier `C` par solde décroissant, puis par identifiant de membre croissant.
   Trier `D` par solde croissant (dette la plus forte d'abord), puis par identifiant croissant.
3. Tant que `C` et `D` ne sont pas vides :
   - soient `c` le premier créditeur et `d` le premier débiteur ;
   - montant du transfert : `m = min(solde(c), |solde(d)|)` ;
   - émettre le règlement `d → c` de montant `m` ;
   - retrancher `m` des deux soldes ; retirer de la liste tout solde devenu nul.
4. Les règlements dont le montant est inférieur à 1 centime ne sont pas émis.

**Propriétés**

- Le nombre de transferts produites est au plus `n − 1` pour `n` membres non soldés.
- L'algorithme ne garantit pas le minimum absolu de transactions — le problème est
  NP-difficile — mais s'en approche et reste explicable à l'utilisateur, ce qui est le
  critère retenu.
- Le tri explicite des égalités rend le résultat reproductible, condition nécessaire
  aux tests automatisés.

**RG-CALC-01** — L'ordre d'affichage des règlements suit l'ordre d'émission de
l'algorithme, jamais un tri ultérieur de l'interface.

### 6.5 Jeu de test de référence

Ce jeu doit être couvert par un test automatisé avant toute modification du calcul.

Événement à 3 membres — Maxence, Lucas, Emma — dépenses partagées entre tous à parts égales :

| Dépense | Montant | Payeur |
|---|---|---|
| Courses | 100,00 € | Maxence |
| Bières | 50,00 € | Lucas |
| Viande | 34,00 € | Emma |

La répartition se fait **dépense par dépense**, jamais sur le total : chaque dépense a
son propre payeur, et les fusionner perdrait cette information. Identifiants croissants
Maxence < Lucas < Emma.

| Dépense | Montant | Maxence | Lucas | Emma |
|---|---|---|---|---|
| Courses | 10 000 | 3 334 | 3 333 | 3 333 |
| Bières | 5 000 | 1 667 | 1 667 | 1 666 |
| Viande | 3 400 | 1 134 | 1 133 | 1 133 |
| **Dû total** | **18 400** | **6 135** | **6 133** | **6 132** |
| Avancé | | 10 000 | 5 000 | 3 400 |
| **Solde** | | **+3 865** | **−1 133** | **−2 732** |

Soldes : Maxence +38,65 € · Lucas −11,33 € · Emma −27,32 €. Somme nulle (IV-02).

Règlements attendus, dans cet ordre : Emma → Maxence 27,32 € puis Lucas → Maxence 11,33 €.

Somme des règlements : 38,65 €, égale au solde du créditeur unique. Deux transactions
au lieu des six d'un règlement bilatéral naïf.

> **Correction du 20/08/2026.** Cette section annonçait auparavant +38,66 / −11,33 /
> −27,33 et un premier règlement de 27,33 €. Ces chiffres provenaient d'une répartition
> du **total** 18 400 en une seule fois, ce qui donne bien un dû de 6 134 / 6 133 / 6 133
> — mais contredit le `§6.2` et le modèle de données, où chaque dépense porte son propre
> payeur et sa propre assiette (`expense_participants.amount_cents`). L'écart est d'un
> centime sur deux membres. Les valeurs ci-dessus sont celles que produit le `§6.2`
> appliqué à la lettre, vérifiées par `JeuDeReferenceTests`.

---

## 7. Modèle de données

### 7.1 Conventions

- Clés primaires : `uuid` v7 (ordonnées dans le temps, sans divulgation de séquence).
- Horodatages : `timestamptz`, stockés en UTC, affichés en `Europe/Paris`.
- Effacement logique : colonne `deleted_at timestamptz null` sur `expenses`,
  `shopping_items`, `messages`, `events`.
- Toutes les tables rattachées à un événement portent `event_id`, y compris lorsque la
  jointure serait déductible : condition du filtrage global de sécurité.

### 7.2 Tables

**users**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| email | citext | unique, null autorisé |
| email_verified_at | timestamptz | null |
| password_hash | text | null (compte créé par connexion tierce) |
| password_changed_at | timestamptz | null |
| must_change_password | boolean | défaut faux |
| platform_role | text | `User`\|`Support`\|`PlatformAdmin`, défaut `User` |
| display_name | text | non null |
| avatar_url | text | null |
| locale | text | défaut `fr-FR` |
| timezone | text | défaut `Europe/Paris` |
| google_subject | text | unique, null |
| apple_subject | text | unique, null |
| premium_until | timestamptz | null |
| last_login_at | timestamptz | null |
| failed_login_count | smallint | défaut 0 |
| suspended_at | timestamptz | null |
| suspension_reason | text | null |
| created_at, updated_at | timestamptz | non null |
| deleted_at | timestamptz | null |

Index : `(email) where deleted_at is null`, `(platform_role) where platform_role <> 'User'`.

**admin_audit_entries**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| actor_user_id | uuid | FK users, non null |
| actor_email | citext | non null, copié à l'écriture |
| target_user_id | uuid | FK users, null |
| action | text | non null, par exemple `user.suspended` |
| reason | text | null |
| ip_address | inet | null |
| metadata | jsonb | null |
| created_at | timestamptz | non null |

Aucune colonne de modification ni de suppression : la table est en ajout seul
(`RG-ADM-06`). Les droits de la base n'accordent ni `UPDATE` ni `DELETE` sur cette table
au rôle applicatif. `actor_email` est recopié afin que le journal reste lisible après
suppression du compte auteur.

**password_reset_tokens** et **email_verification_tokens**

Propriété du module Users, et non d'un module Auth distinct : voir l'amendement de
l'`ADR 0002`.

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| user_id | uuid | FK users, non null |
| token_hash | text | non null, condensé uniquement |
| new_email | citext | null, pour un changement d'adresse |
| expires_at | timestamptz | non null |
| consumed_at | timestamptz | null |
| requested_ip | inet | null |
| created_at | timestamptz | non null |

**events**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| name | text | non null, 1 à 120 caractères |
| description | text | null, 4 000 caractères max |
| starts_at | timestamptz | non null |
| ends_at | timestamptz | null |
| address | text | null |
| latitude, longitude | numeric(9,6) | null |
| cover_image_url | text | null |
| invite_token | text | unique, non null |
| short_code | text | unique parmi les non archivés, non null |
| join_enabled | boolean | défaut vrai |
| created_by | uuid | FK users |
| archived_at | timestamptz | null |
| created_at, updated_at, deleted_at | timestamptz | |

Index : `(starts_at)`, `(invite_token)`, `(short_code) where archived_at is null`.

**event_members**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| event_id | uuid | FK events, non null |
| user_id | uuid | FK users, null uniquement pour une ligne historique sans compte, conservée avec ses références financières |
| display_name | text | non null |
| status | text | `Unknown`\|`Going`\|`Maybe`\|`NotGoing`\|`Late`\|`EarlyLeave` |
| arrival_time | time | null |
| departure_time | time | null |
| extra_guests | smallint | défaut 0 |
| role | text | `Owner`\|`Admin`\|`Member` |
| guest_session_hash | text | null, donnée historique d'un ancien jeton invité |
| joined_at | timestamptz | non null |
| removed_at | timestamptz | null |

Contraintes : unique `(event_id, user_id)` lorsque `user_id` non null ;
un seul `role = 'Owner'` par événement.

**shopping_items**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| event_id | uuid | FK, non null |
| name | text | non null |
| quantity | numeric(8,2) | défaut 1 |
| unit | text | null |
| category | text | `Drinks`\|`Food`\|`Supplies`\|`Other` |
| assigned_member_id | uuid | FK event_members, null |
| purchased_quantity | numeric(8,2) | null |
| estimated_price | numeric(10,2) | null |
| actual_price | numeric(10,2) | null |
| is_purchased | boolean | défaut faux |
| note | text | null |
| position | integer | non null |
| created_by_member_id | uuid | FK event_members |
| created_at, updated_at, deleted_at | timestamptz | |

**expenses**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| event_id | uuid | FK, non null |
| label | text | non null |
| amount | numeric(10,2) | > 0 |
| paid_by_member_id | uuid | FK event_members, non null |
| shopping_item_id | uuid | FK shopping_items, null |
| receipt_url | text | null |
| spent_at | timestamptz | non null |
| created_by_member_id | uuid | FK event_members |
| created_at, updated_at, deleted_at | timestamptz | |

**expense_participants**

| Colonne | Type | Contraintes |
|---|---|---|
| expense_id | uuid | FK, PK composite |
| member_id | uuid | FK, PK composite |
| share | integer | > 0, défaut 1 |
| amount_cents | integer | part attribuée, figée au calcul |

`amount_cents` est stocké afin que la répartition reste stable même si l'algorithme
évolue, et pour rendre l'invariant IV-01 vérifiable par requête.

**settlements**

| Colonne | Type | Contraintes |
|---|---|---|
| id | uuid | PK |
| event_id | uuid | FK, non null |
| from_member_id | uuid | FK event_members |
| to_member_id | uuid | FK event_members |
| amount | numeric(10,2) | > 0 |
| settled_at | timestamptz | non null |
| marked_by_member_id | uuid | FK event_members |
| confirmed_at | timestamptz | null |
| cancelled_at | timestamptz | null |

**Autres tables métier** : `event_schedule_items`, `tasks`, `polls`, `poll_options`,
`poll_votes`, `messages`, `message_reactions`, `activity_entries`, `notifications`,
`notification_preferences`, `event_mute_settings`, `push_devices`, `groups`,
`group_members`, `sessions`, `expense_revisions`.

**Tables techniques** : `idempotency_keys` (support de l'en-tête `Idempotency-Key` du
`§8.1` : sans elle, un double appui sur « enregistrer la dépense » créerait deux
dépenses et fausserait tous les soldes).

**Total : 28 tables**, plus l'historique des migrations.

**Tables en ajout seul** : `admin_audit_entries`, `activity_entries` et
`expense_revisions`. Protégées par deux barrières — un garde applicatif dans le contexte,
et un déclencheur PostgreSQL couvrant `UPDATE`, `DELETE` et `TRUNCATE`. Le déclencheur
est retenu plutôt qu'un simple retrait de droits, car le propriétaire d'une table
contourne les `GRANT` : une révocation seule ne protégerait pas d'une écriture faite avec
le compte de migration.

### 7.3 Règle d'accès

**RG-SEC-01** — Un filtre global au niveau du `DbContext` restreint toute entité portant
`event_id` aux événements dont l'appelant est membre non exclu. Aucune requête ne
s'appuie sur la seule connaissance d'un identifiant.

**RG-SEC-02** — Le filtre est appliqué par intercepteur, non par du code répété dans
chaque requête. Un test d'intégration vérifie, pour chaque endpoint, qu'un membre d'un
autre événement reçoit 404 et non 403 — afin de ne pas confirmer l'existence de la ressource.

---

## 8. Interface de programmation (API)

### 8.1 Principes

- REST, JSON, versionnée par préfixe `/v1`.
- Authentification par jeton porteur (`Authorization: Bearer`) pour toute écriture
  d'adhésion. Aucun nouveau jeton invité n'est émis.
- Erreurs au format RFC 9457 (`application/problem+json`).
- Idempotence : les créations acceptent un en-tête `Idempotency-Key`, obligatoire pour
  les dépenses, les règlements et les adhésions.
- Pagination par curseur pour les listes susceptibles de croître (messages, activité).
- Contrat OpenAPI publié, source de la génération du client Dart.

### 8.2 Endpoints du MVP

```
POST   /v1/auth/register                   inscription e-mail + mot de passe
POST   /v1/auth/login
POST   /v1/auth/logout
POST   /v1/auth/refresh
POST   /v1/auth/email/verify/request
POST   /v1/auth/email/verify               consommation du jeton
POST   /v1/auth/password/forgot            réponse identique si l'adresse est inconnue
POST   /v1/auth/password/reset             consommation du jeton
POST   /v1/auth/password/change            avec l'ancien mot de passe
POST   /v1/auth/google
POST   /v1/auth/apple
POST   /v1/auth/providers/{provider}/link
DELETE /v1/auth/providers/{provider}
GET    /v1/auth/sessions
DELETE /v1/auth/sessions/{id}
DELETE /v1/auth/sessions                   révocation de toutes les autres sessions

GET    /v1/me
PATCH  /v1/me                              nom, langue, fuseau
POST   /v1/me/email                        demande de changement d'adresse
PUT    /v1/me/avatar                       téléversement (multipart)
DELETE /v1/me/avatar
DELETE /v1/me                              suppression du compte
GET    /v1/me/export                       export RGPD

GET    /v1/admin/users                     recherche, tri, pagination
GET    /v1/admin/users/{id}                fiche technique, jamais le contenu d'événement
POST   /v1/admin/users/{id}/password-reset déclenche l'envoi du lien
DELETE /v1/admin/users/{id}/sessions
POST   /v1/admin/users/{id}/suspend        motif obligatoire
POST   /v1/admin/users/{id}/unsuspend
DELETE /v1/admin/users/{id}
PATCH  /v1/admin/users/{id}/role
POST   /v1/admin/users/{id}/verify-email
GET    /v1/admin/users/{id}/export
DELETE /v1/admin/users/{id}/avatar
GET    /v1/admin/audit                     journal, curseur
GET    /v1/admin/metrics                   indicateurs d'instance

GET    /v1/events                          à venir / passés
POST   /v1/events
GET    /v1/events/{id}
PATCH  /v1/events/{id}
DELETE /v1/events/{id}
GET    /v1/events/{id}/dashboard
POST   /v1/events/{id}/invite/rotate
PATCH  /v1/events/{id}/join-enabled

GET    /v1/join/{token}                    aperçu public restreint
POST   /v1/join/{token}                    rejoindre avec un compte ; sans corps métier
GET    /v1/join/code/{shortCode}           résolution du code court
POST   /v1/join/code/{shortCode}           rejoindre avec un compte ; sans corps métier

GET    /v1/events/{id}/members
PATCH  /v1/events/{id}/members/me          statut, horaires
PATCH  /v1/events/{id}/members/{memberId}  rôle (admin)
DELETE /v1/events/{id}/members/{memberId}  exclusion

GET    /v1/events/{id}/shopping-items
POST   /v1/events/{id}/shopping-items
PATCH  /v1/events/{id}/shopping-items/{itemId}
DELETE /v1/events/{id}/shopping-items/{itemId}
POST   /v1/events/{id}/shopping-items/{itemId}/claim
DELETE /v1/events/{id}/shopping-items/{itemId}/claim
POST   /v1/events/{id}/shopping-items/{itemId}/purchase

GET    /v1/events/{id}/expenses
POST   /v1/events/{id}/expenses
GET    /v1/events/{id}/expenses/{expenseId}
PATCH  /v1/events/{id}/expenses/{expenseId}
DELETE /v1/events/{id}/expenses/{expenseId}

GET    /v1/events/{id}/balances            soldes par membre
GET    /v1/events/{id}/settlements          règlements proposés + effectués
POST   /v1/events/{id}/settlements          marquer effectué
DELETE /v1/events/{id}/settlements/{sid}    annuler un marquage

GET    /v1/events/{id}/schedule
POST   /v1/events/{id}/schedule
PATCH  /v1/events/{id}/schedule/{itemId}
DELETE /v1/events/{id}/schedule/{itemId}

GET    /v1/events/{id}/activity             fil d'activité, curseur

GET    /v1/notifications/preferences
PATCH  /v1/notifications/preferences
POST   /v1/notifications/devices            enregistrement d'un jeton poussé
```

### 8.3 Codes de retour

| Code | Usage |
|---|---|
| 200 / 201 / 204 | Succès |
| 400 | Corps invalide |
| 401 | Session absente ou expirée |
| 403 | Droit insuffisant sur une ressource dont l'appartenance est établie |
| 404 | Ressource inexistante **ou** hors du périmètre de l'appelant |
| 409 | Conflit métier : article déjà attribué, code court en collision |
| 422 | Règle de gestion violée : montant négatif, assiette vide |
| 429 | Limitation de débit atteinte |

---

## 9. Temps réel

**RG-RT-01** — SignalR est exposé sur `api.partyplan.maxencecoeur.fr/hubs/event`.
Un client s'abonne à un groupe par événement, après contrôle d'appartenance à la connexion.

**Messages diffusés** :

```
member.joined            member.statusChanged      member.removed
item.created             item.updated              item.claimed
item.unclaimed           item.purchased            item.deleted
expense.created          expense.updated           expense.deleted
balances.changed         settlement.marked         settlement.cancelled
event.updated            activity.appended
message.created          message.updated           message.deleted
poll.created             poll.voted
```

`schedule.changed` a disparu avec le planning, abandonné. Les cinq messages
`message.*` et `poll.*` ont été ajoutés le 25/08/2026 : la discussion et les sondages
sont livrés depuis la V1.0, et `activity.appended` ne les couvrait pas — une ligne de fil
d'activité n'est pas un message de discussion. C'est cette omission qui rendait la
discussion muette jusqu'à un rechargement manuel.

**RG-RT-02** — Chaque message contient l'état résultant de la ressource concernée, pas
seulement son identifiant, afin d'éviter une requête de relecture par le client.

Le client de la V1 relit néanmoins par REST à la réception d'un message, plutôt que de
rapiécer son état local : rapiécer vingt et un messages dans autant de listes paginées,
triées et filtrées crée autant d'occasions d'afficher autre chose que la base, sans
qu'aucune erreur ne le signale. L'état est tout de même envoyé, ce qui laisse le
rapiéçage possible plus tard sans toucher au serveur.

**RG-RT-03** — Le temps réel est une optimisation, jamais la source de vérité :
l'interface doit rester exacte après une simple relecture REST. Une reconnexion
déclenche un rechargement complet de l'écran actif.

**RG-RT-04** — Une seule instance d'API au démarrage, donc pas de backplane. L'ajout
d'une seconde instance impose Redis et fait l'objet d'un ADR préalable.

---

## 10. Écrans et navigation

### 10.1 Inventaire

```
Démarrage · Découverte (3 écrans)
Connexion · Création de compte
Accueil (à venir / passés)
Création d'événement · Rejoindre un événement
Tableau de bord de l'événement
Invités · Courses · Dépenses · Règlements · Planning
Tâches · Sondages · Discussion            (V1.1)
Notifications · Profil · Paramètres · Premium
Mentions légales · Confidentialité · CGU
```

### 10.2 Navigation dans un événement

Barre inférieure à cinq entrées : **Accueil · Courses · € · Planning · Plus**.

« Plus » regroupe : invités, tâches, sondages, discussion, paramètres de l'événement.

**RG-UI-01** — La barre inférieure ne dépassera jamais cinq entrées. Toute fonction
supplémentaire passe par « Plus ».

**RG-UI-02** — Le tableau de bord affiche en premier l'information actionnable du moment :
avant l'événement, les articles non attribués ; après, le montant que l'utilisateur doit.

**RG-UI-03** — Toute action d'écriture est optimiste côté interface, avec retour arrière
visible et explicite en cas d'échec serveur.

### 10.3 Identité visuelle

Référence : `docs/brand/charte.md`. Primaire `#6C5CE7`, accent `#A855F7`,
accent chaud `#FF4D8D`, succès `#00C896`, attention `#FFB020`, danger `#EF4444`,
fond clair `#F8FAFC`, fond sombre `#0F172A`. Typographie Poppins.
Cartes arrondies, avatars empilés, chiffres clés proéminents. Registre convivial,
en aucun cas applicatif d'entreprise.

---

## 11. Exigences non fonctionnelles

| Réf | Exigence | Seuil |
|---|---|---|
| NF-PERF-01 | Temps de réponse API en lecture, 95ᵉ centile | < 300 ms |
| NF-PERF-02 | Temps de réponse API en écriture, 95ᵉ centile | < 500 ms |
| NF-PERF-03 | Calcul complet des soldes et règlements, événement de 20 membres et 100 dépenses | < 50 ms |
| NF-PERF-04 | Premier affichage utile de l'application Web, connexion 4G | < 2,5 s |
| NF-PERF-05 | Propagation d'une modification aux autres clients connectés | < 1 s |
| NF-DISPO-01 | Disponibilité mensuelle | 99,0 % |
| NF-SCAL-01 | Capacité cible sans changement d'architecture | 5 000 événements actifs, 50 000 membres |
| NF-COMPAT-01 | Android | 8.0 et supérieur |
| NF-COMPAT-02 | iOS | 15 et supérieur |
| NF-COMPAT-03 | Navigateurs | deux dernières versions majeures de Chrome, Safari, Firefox, Edge |
| NF-A11Y-01 | Contraste des textes | WCAG 2.1 AA |
| NF-A11Y-02 | Cibles tactiles | 44 × 44 points minimum |
| NF-A11Y-03 | Lecteurs d'écran | libellés sémantiques sur toute action |
| NF-I18N-01 | Langue | français au lancement, aucune chaîne codée en dur dans l'interface |
| NF-OFFLINE-01 | Mode dégradé | consultation en lecture du dernier état chargé, file d'attente des écritures |
| NF-SEC-01 | Transport | TLS 1.2 minimum, HSTS activé |
| NF-SEC-02 | Secrets | aucun secret dans le dépôt, variables d'environnement uniquement |
| NF-SEC-03 | Journalisation | aucun montant, aucune adresse, aucun jeton en clair dans les journaux |
| NF-SEC-04 | Limitation de débit | par IP et par session sur les endpoints d'authentification et de résolution de code |
| NF-SEC-05 | Dépendances | analyse de vulnérabilités en intégration continue, blocage sur criticité haute |
| NF-SEC-06 | Mots de passe | Argon2id, 8 à 30 caractères avec les quatre classes exigées, refus des mots de passe compromis — `RG-AUTH-01`, `RG-AUTH-02` |
| ~~NF-SEC-07~~ | ~~Rôles plateforme~~ | ~~double authentification obligatoire~~ — **sans objet depuis l'`ADR 0007`** |
| NF-SEC-08 | Journal d'audit | ajout seul, sans droit `UPDATE` ni `DELETE` pour le rôle applicatif — `RG-ADM-06` |
| NF-SEC-09 | Téléversements | type MIME vérifié par le contenu, métadonnées EXIF supprimées, taille plafonnée — `RG-USR-01` |
| ~~NF-SEC-10~~ | ~~Secrets stockés~~ | ~~AES-GCM, clé distincte de la signature des jetons~~ — **sans objet depuis l'`ADR 0007`** : plus aucun secret réversible n'est stocké |
| NF-SEC-11 | Limitation de débit | limites paramétrables, désactivables en test uniquement — la valeur juste dépend du trafic réel |
| NF-QUAL-01 | Couverture de tests du domaine financier | 100 % des branches |
| NF-QUAL-02 | Couverture globale du domaine | > 70 % |

---

## 12. Conformité RGPD et mentions légales

### 12.1 Traitements

| Finalité | Données | Base légale | Conservation |
|---|---|---|---|
| Fourniture du service | identité déclarée, participations, dépenses | exécution du contrat | 3 ans après le dernier accès |
| Notifications poussées | jeton d'appareil | consentement | jusqu'au retrait |
| Notifications par courriel | adresse | exécution du contrat | durée du compte |
| Sécurité et prévention d'abus | adresse IP, horodatage | intérêt légitime | 12 mois |
| Administration des comptes et support | identité, état du compte, actions d'administration | intérêt légitime | journal d'audit conservé 3 ans |
| Mesure d'usage | événements anonymisés | intérêt légitime | 25 mois |

### 12.2 Droits des personnes

| Réf | Exigence |
|---|---|
| EF-RGPD-01 | Export de l'intégralité de ses données au format JSON, depuis l'application, sans intervention humaine (`EF-USR-09`). |
| EF-RGPD-02 | Suppression du compte depuis l'application, effective sous 30 jours. |
| EF-RGPD-03 | Rectification des données d'identité à tout moment. |
| EF-RGPD-04 | Retrait du consentement aux notifications, par catégorie. |

**RG-RGPD-01** — La suppression d'un compte anonymise les contributions financières
(le membre devient « Ancien participant ») plutôt que de les supprimer, afin de ne pas
détruire la comptabilité d'événements auxquels d'autres personnes participent. Ce point
est explicité dans la politique de confidentialité.

**RG-RGPD-02** — Les lignes historiques sans compte restent conservées avec leurs
références financières ; elles ne constituent pas un nouveau parcours d'accès sans
compte. Les droits relatifs à un compte s'exercent depuis ce compte.

**RG-RGPD-03** — Le sous-traitant d'hébergement doit être situé dans l'Union européenne.

**RG-RGPD-04** — L'accès d'un administrateur à une fiche de compte est limité aux données
techniques nécessaires au support, journalisé (`RG-ADM-06`), et n'inclut jamais le contenu
d'un événement (`RG-ADM-01`). Ce périmètre est décrit dans la politique de confidentialité.

### 12.3 Documents à produire

Conditions générales d'utilisation · politique de confidentialité · politique de cookies
(aucun cookie non essentiel au lancement) · mentions légales · registre des traitements
· fiches de confidentialité App Store et Google Play.

**RG-LEG-01** — La documentation précise que PartyPlan ne détient, ne transfère et ne
garantit aucun fonds, et que les règlements entre membres relèvent exclusivement de leur
relation privée.

---

## 13. Infrastructure, déploiement et environnement local

### 13.1 Composants

```
Reverse proxy (TLS, en-têtes de sécurité)
  ├── web.partyplan.maxencecoeur.fr    Flutter Web (fichiers statiques)
  │     ├── /admin/*                   back-office, rôles plateforme uniquement
  │     ├── /join/*                    liens d'invitation (EF-INV-01)
  │     └── /.well-known/assetlinks.json   association Android
  ├── partyplan.maxencecoeur.fr        Site vitrine statique, indexable
  │                                    n'appelle jamais l'API
  ├── api.partyplan.maxencecoeur.fr    API ASP.NET Core 10
  │     └── /hubs/event                SignalR
  └── cdn.partyplan.maxencecoeur.fr    photos de profil, images et pièces jointes
PostgreSQL 16
```

Le back-office n'est pas une application distincte : ce sont des routes de l'application
Web, protégées par le rôle plateforme et absentes des versions mobiles (`RG-ADM-08`,
`HY-11`). Un sous-domaine `admin.partyplan.maxencecoeur.fr` pointant vers la même
application reste possible sans changement de code.

Redis absent au démarrage, introduit uniquement sur besoin mesuré.

### 13.2 Certificats

Sous-domaines de deuxième niveau : un joker `*.maxencecoeur.fr` ne couvre pas
`api.partyplan.maxencecoeur.fr`. Certificats individuels en challenge HTTP-01 au
démarrage ; bascule vers un joker `*.partyplan.maxencecoeur.fr` en DNS-01 si le nombre
de sous-domaines croît. Détail dans `docs/adr/0003-domaines.md`.

### 13.3 Chaîne de livraison

Détail et justification : `docs/adr/0004-chaine-de-livraison.md`.

- Intégration continue par composant, sélection par répertoire modifié.
- Images OCI construites exclusivement par l'intégration continue, publiées sur
  GitHub Container Registry : `partyplan-api`, `partyplan-web`, `partyplan-landing`.
- Étiquetage : `latest` sur la branche par défaut, `sha-<empreinte>` sur chaque commit,
  version issue du tag (`api-v1.2.0` → `1.2.0`).
- Sur une pull request, l'image est construite sans publication et déposée comme
  artefact du run, afin de ne pas exposer de jeton d'écriture à du code non revu.
- Migrations de base appliquées au démarrage de l'API, en avant seulement, jamais
  destructives sans script de reprise explicite.
- Déploiement : modification d'une étiquette dans `infra/compose/.env`, puis
  `docker compose pull && up -d`. Retour arrière par l'étiquette précédente.
- Plateforme unique `linux/amd64`.

**NF-OPS-08** — Aucune image n'est construite sur le serveur de production.

**NF-OPS-09** — Tout secret ajouté au déploiement doit figurer, sans valeur, dans
`infra/compose/.env.example`.

### 13.4 Environnement de développement local

Contrainte permanente : **toute fonctionnalité doit être exécutable et vérifiable en
local avant d'être poussée.** Une fonctionnalité qui ne peut être essayée qu'en
production n'est pas livrable.

| Réf | Exigence |
|---|---|
| NF-DEV-01 | La pile complète démarre en une seule commande, sur une machine sans configuration préalable autre que Docker. |
| NF-DEV-02 | Aucun service externe payant ou nécessitant un compte n'est requis pour développer : le courriel, les notifications poussées et les connexions tierces disposent tous d'un substitut local. |
| NF-DEV-03 | Les courriels sortants sont capturés par un serveur local doté d'une interface de consultation. Aucun courriel ne part vers une adresse réelle depuis un poste de développement. |
| NF-DEV-04 | Les notifications poussées sont journalisées en console lorsque aucune clé n'est configurée, sans faire échouer l'action métier. |
| NF-DEV-05 | Les connexions Google et Apple sont désactivables par configuration ; leur absence n'empêche ni l'inscription, ni la connexion par mot de passe. |
| NF-DEV-06 | Un compte administrateur de développement est amorcé avec des identifiants connus, documentés, et refusés en production par `RG-ADM-11`. |
| NF-DEV-07 | Un jeu de données de démonstration est installable et réinitialisable en une commande : plusieurs comptes, un événement passé soldé, un événement à venir en cours de préparation. |
| NF-DEV-08 | Les migrations exécutées en local sont exactement celles exécutées en production. Aucun schéma créé à la main. |
| NF-DEV-09 | Le rechargement à chaud fonctionne côté API et côté Flutter, sans reconstruction d'image. |
| NF-DEV-10 | La suite de tests s'exécute en local par une seule commande, sans accès réseau sortant. |

**RG-DEV-01** — Les valeurs par défaut du développement local ne doivent jamais pouvoir
s'appliquer en production. Toute valeur de commodité (mot de passe d'amorçage connu,
signature de jeton fixe, désactivation de la vérification d'adresse) est refusée au
démarrage lorsque l'environnement est `Production`.

**RG-DEV-02** — Le fichier `.env.example` est la documentation de référence des variables.
Toute variable ajoutée au code y figure immédiatement, sans valeur secrète.

**RG-DEV-03** — Aucun poste de développement ne se connecte à la base de production, à
aucun moment, y compris en lecture.

---

## 14. Supervision, sauvegardes, reprise

| Réf | Exigence |
|---|---|
| NF-OPS-01 | Endpoint `/health` distinguant vivacité et disponibilité (base joignable). |
| NF-OPS-02 | Journalisation structurée avec identifiant de corrélation par requête. |
| NF-OPS-03 | Remontée des exceptions non gérées vers un outil de suivi d'erreurs. |
| NF-OPS-04 | Sauvegarde quotidienne complète de PostgreSQL, conservation 30 jours, dépôt hors du serveur applicatif. |
| NF-OPS-05 | Restauration testée au moins une fois avant l'ouverture de la bêta, puis chaque trimestre. |
| NF-OPS-06 | RPO 24 h, RTO 4 h. |
| NF-OPS-07 | Alerte sur : indisponibilité, taux d'erreur 5xx supérieur à 1 % sur 5 minutes, saturation disque, échec de sauvegarde. |

---

## 15. Stratégie de test

| Niveau | Portée | Exigence |
|---|---|---|
| Unitaire | Répartition, soldes, simplification des règlements, génération des codes | 100 % des branches, jeu de référence du §6.5 inclus |
| Intégration | Chaque endpoint, avec base réelle | Cloisonnement vérifié : tout accès hors périmètre renvoie 404 |
| Intégration | Chaque endpoint d'événement, appelé par un `PlatformAdmin` non membre | Réponse 404 sans exception — `RG-ADM-01` |
| Intégration | Chaque endpoint `/v1/admin/*`, appelé par un `User` puis par un `Support` | Droits respectés — `RG-ADM-05` |
| Intégration | Amorçage du compte administrateur | Idempotent, aucun doublon, mot de passe changé non réappliqué |
| Concurrence | Attribution simultanée d'un article, marquage simultané d'un règlement | Une seule opération aboutit |
| Bout en bout | Parcours « lien → authentification → adhésion automatique → présence → article → prix → règlement » | Exécuté à chaque livraison |
| Manuel | Android, iOS, Safari iOS, Chrome Android | Grille de recette par version |

**RG-TEST-01** — Aucune modification du domaine financier n'est livrée sans que le jeu
de référence du §6.5 ne passe.

**RG-TEST-02** — Un test vérifie l'invariant IV-02 sur des jeux de données générés
aléatoirement (dépenses, parts et suppressions tirées au hasard).

---

## 16. Jalons et livrables

| Jalon | Contenu | Sortie attendue |
|---|---|---|
| J1 | Squelette technique : dépôt, API, Flutter, PostgreSQL, migrations, CI | Application vide déployée sur les trois domaines |
| J2 | **Comptes** : inscription, connexion, vérification d'adresse, réinitialisation, profil, photo, sessions, export, suppression | Un utilisateur gère intégralement son compte sans intervention |
| J2b | **Administration** : amorçage du compte administrateur, back-office, journal d'audit | Un administrateur gère les comptes sans jamais accéder au contenu d'un événement |
| J3 | Événements et invitations | Création, lien, QR, code court, aperçu public et adhésion avec compte |
| J4 | Présences | Statuts, horaires, synthèse |
| J5 | Liste de courses et temps réel | Attribution concurrente sûre, propagation en moins d'une seconde |
| J6 | Dépenses et règlements | Jeu de référence du §6.5 validé |
| J7 | Planning et notifications | Rappels effectifs |
| J8 | Durcissement : sécurité, RGPD, supervision, sauvegardes | Restauration testée, documents légaux publiés |
| J9 | Bêta privée | 3 groupes réels, 3 événements complets menés jusqu'aux remboursements |
| J10 | Publication | PWA et Google Play |

Livrables documentaires : ce cahier des charges, les ADR, le contrat OpenAPI, le
schéma de base, la grille de recette, les documents légaux, la procédure d'exploitation.

---

## 17. Risques

| Réf | Risque | Impact | Traitement |
|---|---|---|---|
| R-01 | L'invité ne revient pas après la soirée | Rétention nulle, viralité rompue | La notification de dette au J+1 est le point de rappel principal ; elle est prioritaire au MVP |
| R-02 | Contestation d'un montant entre membres | Perte de confiance | Fil d'activité inaltérable, historique des modifications de dépenses |
| R-03 | Erreur de calcul financier | Perte de crédibilité irréversible | Couverture de branches intégrale, invariants vérifiés à l'exécution, jeu de référence figé |
| R-04 | Code court devinable | Accès non autorisé à un événement | 32⁶ combinaisons, limitation de débit stricte, aucune donnée nominative avant participation |
| R-05 | Refus Apple faute de « Sign in with Apple » | Publication iOS bloquée | Prévoir la connexion Apple avant la soumission iOS |
| R-06 | Notifications poussées indisponibles sur PWA iOS | Rappels non reçus | Repli courriel, incitation à l'ajout à l'écran d'accueil |
| R-07 | Dérive du périmètre vers une messagerie | Retard de livraison | RG-MSG-01, discussion reportée en V1.1 |
| R-08 | Développeur unique | Arrêt du projet en cas d'indisponibilité | Documentation à jour, aucune connaissance uniquement orale, sauvegardes externes |
| R-09 | Saisonnalité de l'usage | Rétention difficile à mesurer | Mesurer par cohorte d'événement, non par mois calendaire |

---

## 18. Critères d'acceptation du MVP

Le MVP est réputé livré lorsque l'ensemble des points suivants est vérifié sur
l'environnement de production.

### Comptes et administration (V0.5)

1. Un utilisateur s'inscrit, vérifie son adresse, ajoute une photo de profil, change son
   mot de passe, révoque une session et supprime son compte, sans aucune intervention.
2. Un mot de passe de moins de 12 caractères, ou figurant dans une liste de mots de passe
   compromis, est refusé.
3. La demande de réinitialisation renvoie la même réponse pour une adresse existante et
   pour une adresse inconnue.
4. Sur une base vierge, le démarrage crée le compte administrateur depuis l'environnement,
   sans journaliser le mot de passe ; un second démarrage ne crée aucun doublon et ne
   réapplique pas un mot de passe changé entre-temps.
5. L'API refuse de démarrer en production si `ADMIN_PASSWORD` est absent alors qu'aucun
   administrateur n'existe, ou s'il ne satisfait pas `RG-AUTH-01`.
6. Le compte amorcé doit changer son mot de passe avant toute autre action. *(Révisé le
   24/08/2026 — `ADR 0007` : l'activation d'une double authentification n'est plus
   exigée.)*
7. Un administrateur liste les comptes, déclenche une réinitialisation, révoque des
   sessions, suspend puis supprime un compte ; chaque action figure au journal d'audit
   avec son auteur, sa cible et son motif.
8. Le journal d'audit n'est modifiable ni supprimable, y compris par un `PlatformAdmin`.
9. Un `PlatformAdmin` reçoit 404 sur tous les endpoints d'un événement dont il n'est pas
   membre.
10. Un `Support` reçoit 403 sur la suppression d'un compte et sur la gestion des rôles.
11. Un administrateur ne peut ni se supprimer, ni se révoquer, ni supprimer le dernier
    `PlatformAdmin`.
12. Un compte suspendu ne peut plus se connecter et ses sessions sont révoquées
    immédiatement.

### Socle événementiel (V1.0)

13. Un organisateur crée un événement en moins de 60 secondes, sans documentation.
14. Le lien d'invitation ouvre un aperçu public restreint ; après connexion ou création
    de compte, il revient à l'invitation, rejoint automatiquement avec le nom de profil
    et le statut `Unknown`, puis ouvre la soirée. Les App Links Android et Universal
    Links iOS ouvrent directement ce lien ; SignalR assure le temps réel et FCM est
    limité aux notifications.
15. Dix membres déclarent leur présence ; les décomptes affichés sont exacts.
16. Deux membres tentant simultanément de prendre le même article aboutissent à une
    seule attribution, avec message explicite pour le second.
17. Un article acheté avec prix saisi crée une dépense correctement répartie.
18. Le jeu de référence du §6.5 produit exactement les deux règlements attendus,
    dans l'ordre attendu.
19. La somme des soldes est nulle sur tout jeu de données testé.
20. Une action d'un membre est visible par les autres clients connectés en moins d'une
    seconde, sans rafraîchissement.
21. Un membre d'un autre événement reçoit 404 sur toutes les ressources de l'événement.
22. Les six catégories de notifications du §5.12 sont émises et désactivables.
23. La suppression de compte et l'export des données fonctionnent depuis l'application.
24. Une restauration de sauvegarde a été réalisée avec succès.
25. Conditions générales, politique de confidentialité et mentions légales sont publiées.
26. Trois groupes réels ont mené un événement complet jusqu'aux remboursements marqués.

---

## 19. Hypothèses retenues et questions ouvertes

Points tranchés en l'absence d'arbitrage explicite. Chacun est modifiable, mais l'est
d'autant plus facilement qu'il est décidé maintenant.

| Réf | Hypothèse retenue | Motif | À confirmer |
|---|---|---|---|
| HY-01 | ~~Pas de mot de passe~~ **Révisé le 19/08/2026** : mot de passe + Google, réinitialisation par lien | Décision du commanditaire. Un back-office capable de déclencher une réinitialisation suppose un mot de passe. Contrepartie assumée : hachage Argon2id, refus des mots de passe compromis, limitation des tentatives. La double authentification obligatoire pour les rôles plateforme, d'abord retenue, a été retirée le 24/08/2026 (`ADR 0007`) | Tranché |
| HY-02 | Code court sur 6 caractères et non 4 | 4 caractères, soit environ un million de combinaisons, exposent à l'énumération | Oui |
| HY-03 | SignalR sur le domaine de l'API, pas de sous-domaine `ws` | Une origine, un certificat, un mécanisme d'authentification ; repli SSE possible | Oui |
| HY-04 | Assiette de répartition figée à la création de la dépense | Une assiette rétroactive modifierait des soldes déjà réglés | Oui |
| HY-05 | Statut « peut-être » exclu de la répartition par défaut | Facturer un absent probable génère des litiges | Oui |
| HY-06 | Android avant iOS | Coût et délai de publication moindres, itération plus rapide | Oui |
| HY-07 | Suppression de compte par anonymisation des données financières | Une suppression réelle détruirait la comptabilité de tiers | Oui |
| HY-08 | Offre gratuite limitée à 20 participants, archives 3 mois | Cohérent avec l'usage cible de 3 à 20 personnes | Oui |
| HY-09 | Devise unique, l'euro | Le multi-devise complexifie tous les calculs pour un cas marginal | Oui |
| HY-10 | Pas de Redis au démarrage | Aucun besoin mesuré en instance unique | Non, technique |
| HY-11 | Le back-office n'est accessible qu'en version Web, sous `/admin/*` | Embarquer des écrans d'administration dans l'application mobile publiée sur les stores augmente la surface d'attaque sans usage réel | Oui |
| HY-12 | Rôle `Support` distinct de `PlatformAdmin` | Permet de traiter une demande d'utilisateur sans détenir le droit de supprimer un compte | Oui |
| HY-13 | ~~Double authentification obligatoire pour les rôles plateforme~~ **Infirmée le 24/08/2026 — `ADR 0007`** : l'obligation rendait l'administration inatteignable à son seul administrateur, et un compte plateforme ne donne accès à aucun contenu d'événement (`RG-ADM-01`). Le mot de passe est l'unique facteur, contreparties énumérées dans l'ADR | Infirmée |

**Questions restant ouvertes**

1. Nom définitif et dépôt de marque : PartyPlan est-il disponible à l'INPI en classes 9
   et 42, et le domaine `partyplan.fr` est-il libre ?
2. Hébergeur retenu, et son emplacement dans l'Union européenne.
3. Le rattachement d'un « +1 » à une part de dépense doit-il être possible dès le MVP ?
4. La double validation des remboursements (EF-RMB-07) doit-elle remonter en P0 ?
   Elle prévient un litige fréquent, pour un coût faible.
