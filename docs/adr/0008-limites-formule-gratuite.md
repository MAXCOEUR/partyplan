# ADR 0008 — Limites de la formule gratuite

- Date : 28/08/2026
- Statut : accepté
- Révise : `RG-PRM-01`, `RG-PRM-02`, `RG-PRM-03` — réécrites au `§5.14`
- Ajoute : `EF-PRM-04`, `EF-PRM-05`
- Remplace : la conception du 25/08/2026, `docs/superpowers/specs/2026-08-25-socle-premium-design.md`

## Contexte

Le cahier des charges annonçait une offre gratuite « à nombre d'événements actifs
illimité », plafonnée aux seuls 20 participants et à 3 mois d'archives. Aucune de ces
limites n'était implémentée : `users.premium_until` existe depuis le schéma initial et
`User.IsPremium()` était écrite, mais aucun appelant ne les lisait. Tout compte disposait
donc de tout, sans borne.

Une première conception a été écrite le 25/08/2026 et commitée par `56dedf3`. Elle
retenait un module `Subscriptions` dédié et un quota de 3 événements créés dont **seule
la suppression** libérait une place. Elle n'a jamais été exécutée : ni module, ni
migration, ni plan d'implémentation, et le cahier des charges n'en a jamais porté la
trace. Elle est restée orpheline trois jours.

Son point faible était assumé dans son propre texte : *« supprimer un événement détruit
ses dépenses et ses remboursements »*. Elle demandait à un utilisateur au quota
d'effacer l'historique financier d'une soirée pour en organiser une autre — dans un
produit dont la promesse centrale est justement de tenir les comptes d'un groupe.

## Décision

**Trois limites pour la formule gratuite**, dont deux implémentées maintenant : 3
événements possédés simultanément, 20 membres par événement, et 3 mois de consultation
des archives reportés au lot 4.1.

**Le quota d'événements porte sur les événements actifs, pas sur l'historique.** Un
événement terminé libère sa place de lui-même ; quitter ou supprimer libère par
anticipation. Aucune place ne se paie d'un historique détruit. C'est le point sur lequel
la conception du 25/08 est renversée.

**Le quota pèse sur la propriété, jamais sur l'adhésion.** Rejoindre reste illimité en
formule gratuite. La limite frappe l'organisateur — celui qui tire la valeur du produit,
donc le candidat naturel à l'abonnement — et jamais l'invité, dont le premier contact
avec le produit ne doit pas être un refus. Corollaire : le plafond de 20 membres est
celui du propriétaire de l'événement, ce qui est `EF-PRM-03` appliqué à l'adhésion.

**Un dépassement par transfert de propriété est toléré.** `RG-ROLE-02` oblige un
propriétaire à transférer avant de quitter. Refuser un transfert à un repreneur au quota
enfermerait le cédant dans un événement dont il ne pourrait plus sortir dès lors que tous
les membres seraient pleins. Le quota n'est donc vérifié qu'à la création. Le
contournement créer-transférer-recréer existe ; il coûte un complice à chaque tour et
n'est pas automatisable.

**La formule reste portée par `users.premium_until`.** Le module `Subscriptions` de la
conception du 25/08 est écarté : la colonne existe déjà, aucune migration n'est requise,
et `MyProfile` la remonte au client depuis le 19/08. Un contrat `IFormuleCompte` dans
`SharedKernel` la rend lisible par le module `Events` sans franchir la frontière de la
règle 6.

**L'attribution est manuelle et administrée.** Un `PlatformAdmin` fixe une échéance avec
un motif obligatoire, journalisé en ajout seul. Ni `Support` — `RG-ADM-05` le borne à la
consultation et au dépannage, et offrir un abonnement n'est ni l'un ni l'autre — ni
paiement, ni écran d'abonnement. Un bouton d'achat sans encaissement serait un bouton
condamné, ce que le produit s'interdit déjà pour la connexion Google.

## Conséquences

Le quota se vérifie à deux endroits seulement, `EventService.CreateAsync` et
`JoinService.RejoindreAsync`, dans la transaction de l'écriture — comme `RG-CRS-01` le
fait pour l'attribution d'un article, faute de quoi deux adhésions simultanées passeraient
toutes les deux le plafond.

L'aperçu public d'invitation annonce « complet » quand le plafond est atteint. Sans cela,
un invité créerait un compte pour découvrir ensuite qu'il ne peut pas entrer. Le nombre de
participants figure déjà dans l'aperçu autorisé par `RG-INV-04` : aucune donnée nouvelle
n'est exposée.

**Dette acceptée** : le lot 4.1 apportera Google Play, App Store, renouvellements,
expirations, remboursements et rétablissements d'achat — des cycles de vie datés qu'une
colonne unique ne portera pas. Une table devra alors être introduite, par migration, sur
des données de production puisque V1.0 et V1.1 auront été publiées. C'est le prix
sciemment consenti pour ne pas construire aujourd'hui un module que rien n'exerce. La
conception du 25/08 avait raison sur ce point ; elle avait tort de facturer cette raison
aujourd'hui.

`RG-PRM-03` change de sens et non de portée. Elle garantissait qu'aucune fonction du MVP
ne deviendrait payante rétroactivement ; la création d'événement, fonction du MVP, est
désormais plafonnée. La garantie devient : ce qui est déjà exercé ne se ferme jamais. La
laisser écrite dans sa forme initiale aurait fait croire à une promesse abandonnée.

## Alternatives écartées

**Le quota compte l'historique.** Position de la conception du 25/08. Écartée : elle
oppose l'organisation d'une nouvelle soirée à la conservation des comptes de la
précédente, dans un produit dont c'est la raison d'être.

**Créations et adhésions confondues dans le quota.** Écartée : une invitation pourrait
échouer pour un motif qui ne concerne ni l'événement ni son organisateur, et elle
contredirait `EF-PRM-03`.

**Les 20 membres comptés en têtes, accompagnants inclus.** Écartée : `EF-PRES-06` autorise
dix accompagnants par membre, et déclarer les siens ferait franchir le plafond après coup
— ce que `RG-PRM-02` interdit. Le décompte porte sur les membres, ce qui laisse un seul
point de contrôle.

**Refus en 402 Payment Required.** Écarté : aucun encaissement n'existe. Le refus est un
403 de code `plan.event_quota_reached` ou `plan.member_limit_reached`.
