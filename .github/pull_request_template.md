## Objet

<!-- Une phrase. Quel lot de docs/roadmap.md avance, et jusqu'où. -->

## Exigences couvertes

<!-- Références du cahier des charges : EF-…, RG-…, NF-…, et les cases cochées dans
     docs/roadmap.md. Une modification sans référence signifie qu'il faut d'abord
     compléter le cahier des charges. -->

-

## Vérifications

- [ ] `make verif` passe (format, analyse, tests)
- [ ] Testé en local avant la poussée (`§13.4` — une fonctionnalité qui ne peut être
      essayée qu'en production n'est pas livrable)
- [ ] Aucun secret ajouté au dépôt ; toute nouvelle variable figure dans `.env.example`
      et `infra/compose/.env.example` sans valeur (`RG-DEV-02`, `NF-OPS-09`)

## Règles non négociables — à confirmer si le sujet est touché

- [ ] **Cloisonnement** : toute requête sur une ressource d'événement remonte
      `User → EventMember → Event`. Réponse 404, jamais 403 (`RG-SEC-01`, `RG-SEC-02`)
- [ ] **Rôles plateforme** : aucun accès au contenu d'un événement, sans exception
      « pour le support » (`RG-ADM-01`)
- [ ] **Mots de passe** : jamais journalisés, jamais renvoyés, jamais consultables
      (`RG-AUTH-02`, `RG-ADM-02`)
- [ ] **Ajout seul** : aucune modification ni suppression sur le journal d'audit, le fil
      d'activité et l'historique des dépenses (`RG-ADM-06`, `RG-FIL-02`)
- [ ] **Montants** : `decimal` en C#, `numeric(10,2)` en base, calcul en centiemes.
      Jamais de flottant (`§6.1`)
- [ ] **Domaine financier** : le jeu de référence du `§6.5` passe, couverture des
      branches à 100 % (`RG-TEST-01`, `NF-QUAL-01`)
- [ ] **Invité sans compte** : le parcours « lien → prénom → présence » reste
      fonctionnel sans authentification (`EF-INV-04`)
- [ ] **Frontières de modules** : `./tools/verifier-frontieres-modules.sh` passe
      (`ADR 0002`)

## Captures

<!-- Pour toute modification d'interface : avant / après, thème clair et thème sombre. -->
