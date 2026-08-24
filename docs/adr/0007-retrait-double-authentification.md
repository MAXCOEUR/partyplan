# ADR 0007 — Retrait de la double authentification

- Date : 24/08/2026
- Statut : accepté
- Abroge : `EF-AUTH-12`, `EF-AUTH-13`, `RG-AUTH-09` à `RG-AUTH-13`, `RG-ADM-04`,
  `NF-SEC-07`, `NF-SEC-10`
- Révise : `ADR 0005` — le second facteur n'est plus la contre-mesure de la
  compromission d'un compte administrateur

## Contexte

La double authentification par code temporel a été livrée au lot 0.9 : RFC 6238
implémentée dans le dépôt et validée contre les vecteurs de l'annexe B, huit codes de
secours, secret chiffré en AES-GCM sous une clé distincte de celle de signature, et
connexion en deux temps sur une audience de jeton séparée. `RG-ADM-04` la rendait
obligatoire pour tout rôle plateforme.

Cette obligation a rendu l'administration inatteignable. Le compte administrateur
amorcé au démarrage n'a pas de second facteur ; l'activer suppose d'accéder à
l'application ; et la garde `RG-ADM-04`, portée par une revendication du jeton, faisait
répondre « accès refusé » au seul administrateur de l'instance. Le parcours d'enrôlement
existait pourtant, mais l'ordre des opérations était trop fragile pour un produit dont
l'administration doit rester joignable à une seule personne.

S'ajoute la mesure du rapport : PartyPlan organise des soirées entre proches. Le
back-office ne donne accès à aucun contenu d'événement — `RG-ADM-01` l'interdit, et un
`PlatformAdmin` non membre reçoit 404 comme n'importe qui. Ce qu'un compte plateforme
compromis permet, c'est de suspendre, de supprimer et de déclencher des
réinitialisations : sérieux, mais sans commune mesure avec l'accès aux données qu'une
2FA protège habituellement.

Un premier retrait partiel a été appliqué le 21/08/2026 : écrans supprimés et défi
retiré de la connexion, mais endpoints, colonnes et secrets conservés. Cet état est le
pire des trois — un compte ayant activé la 2FA se connectait avec son seul mot de passe
tandis que l'API continuait d'annoncer la protection. C'est ce constat qui motive la
présente décision : trancher dans un sens ou dans l'autre, mais entièrement.

## Décision

La double authentification est retirée du produit, sans demi-mesure.

1. **Aucune surface d'API.** `POST /v1/auth/mfa/verify`, `POST /v1/auth/totp/setup`,
   `POST /v1/auth/totp/activate`, `DELETE /v1/auth/totp` et
   `POST /v1/auth/totp/recovery-codes` sont supprimés. Ils répondent 404.
2. **Aucun état intermédiaire de connexion.** `POST /v1/auth/login` et
   `POST /v1/auth/google` remettent toujours une session complète. Le contrat
   `LoginResponse` — et avec lui `requiresSecondFactor`, `challengeToken` et
   `challengeExpiresAt` — disparaît au profit de `TokenResponse`. Le jeton intermédiaire
   et son audience `-mfa` n'existent plus.
3. **Aucune donnée conservée.** La table `totp_recovery_codes` et les colonnes
   `users.totp_secret_encrypted` et `users.totp_enabled_at` sont supprimées par
   migration. Les secrets ne sont pas gardés « au cas où » : plus aucun code ne les lit,
   ce qui en ferait des données personnelles conservées sans finalité.
4. **Aucune obligation de rôle.** Les politiques `PlatformAdmin` et `PlatformStaff`
   n'exigent plus la revendication `pp:totp`, qui n'est plus émise. La promotion d'un
   compte vers `Support` ou `PlatformAdmin` n'exige plus de second facteur : l'erreur
   `admin.totp_required` disparaît.
5. **Le chiffrement de secrets au repos disparaît avec son unique usage.**
   `ISecretProtector`, `AesGcmSecretProtector` et la clé `Security:EncryptionKey` ne
   protégeaient que les secrets TOTP. La garde de production ne réclame plus cette clé :
   la maintenir aurait fait générer, stocker et faire tourner par l'exploitant une clé
   qui ne protège rien — et `docs/exploitation.md` documentait une conséquence de perte
   devenue fausse.

## Ce que cette décision coûte, en clair

Le mot de passe devient l'unique protection d'un compte capable de suspendre, de
supprimer et de réinitialiser tous les autres. Cela reste vrai et doit être dit tel
quel. Ce qui le rend tenable :

- `RG-AUTH-01` : 12 caractères minimum, refus des mots de passe compromis sur une liste
  embarquée de 45 567 condensés.
- `RG-AUTH-02` : Argon2id, aucun mot de passe consultable ni journalisé.
- `RG-AUTH-05` : ralentissement croissant après dix échecs, limite par adresse et par IP.
- `RG-ADM-01` : un rôle plateforme ne lit jamais le contenu d'un événement.
- `RG-ADM-06` : le journal d'audit est en ajout seul, y compris pour un `PlatformAdmin`.
- `RG-ADM-03` : pas d'auto-suppression, pas d'auto-révocation, jamais zéro administrateur.

## Conséquences

- Le nombre de tables passe de 27 à 26.
- Un compte qui avait activé la double authentification perd son secret et ses codes de
  secours. Il n'a rien à faire : sa connexion par mot de passe fonctionne, et
  fonctionnait déjà depuis le retrait partiel du 21/08/2026.
- L'implémentation RFC 6238 et ses tests de conformité quittent le dépôt. Ils restent
  récupérables dans l'historique Git si la fonctionnalité revient.
- `Down()` de la migration rétablit la structure, jamais le contenu : un retour de la
  fonctionnalité imposera un réenrôlement complet.
- Le seuil de réouverture est nommé : la 2FA revient si l'instance dépasse le cercle des
  proches — offre payante, comptes d'organisateurs professionnels — ou si le back-office
  gagne un accès au contenu, ce que `RG-ADM-01` interdit aujourd'hui. Elle reviendra
  alors **facultative pour tous et obligatoire pour personne**, l'obligation étant ce
  qui a échoué ici.

## Alternatives écartées

| Alternative | Motif du rejet |
|---|---|
| Rendre la 2FA facultative et abroger la seule `RG-ADM-04` | Conserve un parcours de sécurité complet — enrôlement, QR code, codes de secours, connexion en deux temps — pour un produit où presque personne ne l'activera. Le coût de maintenance est permanent, le bénéfice marginal. |
| Geler le code serveur et purger les seules données | Laisse une implémentation morte que rien n'exerce. Un chemin de sécurité non exercé pourrit : au prochain retour, il faudrait tout revérifier de toute façon. |
| Conserver l'état du 21/08/2026 | Retrait partiel : l'API annonce une protection que la connexion n'applique plus. C'est le défaut que cette décision corrige. |

## Références

- `docs/adr/0005-identite-et-administration.md`
- `api/tests/PartyPlan.IntegrationTests/SansDoubleAuthentificationTests.cs` — le retrait
  vérifié dans ses quatre dimensions : route, contrat, schéma, autorisation
- `api/src/PartyPlan.Infrastructure/Persistence/Migrations/20260824165718_RetraitDoubleAuthentification.cs`
