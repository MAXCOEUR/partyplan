# ADR 0006 — Compte obligatoire pour rejoindre un événement

- Date : 21/08/2026
- Statut : accepté
- Révise : règle 7 de `CLAUDE.md`, `EF-INV-04`, `RG-INV-05`, `EF-AUTH-11`

## Contexte

Le parcours historique permettait de rejoindre une soirée avec un prénom, un statut et
un jeton invité. Cette exception d'identité rendait le retour sur un autre appareil et
la gestion cohérente du profil plus difficiles. La décision produit approuvée est de
conserver une découverte légère, tout en rendant le compte obligatoire avant toute
nouvelle adhésion.

## Décision

1. Les aperçus `GET /v1/join/{token}` et `GET /v1/join/code/{shortCode}` restent
   publics et restreints au nom, aux dates, au lieu, à la description et au nombre de
   participants. Ils ne révèlent ni membres nominatifs, ni dépenses, ni jeton long.
2. Toute nouvelle adhésion est un `POST` authentifié. Après connexion ou inscription,
   le chemin d'invitation est conservé et l'adhésion est réalisée avec le compte.
3. Le serveur copie le nom affiché depuis le profil du compte ; le client ne fournit ni
   nom ni statut. Le statut initial est toujours `EventMemberStatus.Unknown`.
4. Les App Links Android et Universal Links iOS ouvrent directement les chemins
   d'invitation. Sans application installée, le même lien ouvre l'application Web.
5. SignalR porte le temps réel. Firebase Cloud Messaging (FCM) est réservé aux
   notifications : il ne gère ni les liens, ni l'authentification, ni les données, ni
   le temps réel.

## Conséquences

- Les nouveaux jetons invités et les routes de conversion (`guest-claim` / `guest-upgrade`)
  disparaissent ; les POST d'adhésion ne reçoivent pas de corps métier.
- Une adhésion rejouée pour le même compte est idempotente et ne modifie pas sa présence.
- Les lignes `event_members` historiques dont `user_id` est nul ne sont pas supprimées :
  elles restent listables et conservent leurs références financières. Elles ne peuvent
  pas ouvrir une session ni servir à une nouvelle adhésion.
- Le module Events obtient le nom par un contrat public avec Users, sans accéder à la
  table `users`.

## Références

- `docs/superpowers/specs/2026-08-21-invitations-comptes-liens-profonds-design.md`
- `docs/adr/0002-modular-monolith.md`
- `docs/adr/0003-domaines.md`
