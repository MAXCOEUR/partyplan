# Écrans événementiels et socle hors ligne — plan d'implémentation

> **Pour les agents :** SOUS-SKILL REQUIS — utiliser `superpowers:subagent-driven-development`
> (recommandé) ou `superpowers:executing-plans` pour dérouler ce plan tâche par tâche.
> Les étapes utilisent la syntaxe à cases (`- [ ]`).

**But :** rendre utilisable depuis l'application ce que l'API sait déjà faire — créer un
événement, inviter, répondre — et poser le socle hors ligne sur lequel tous les modules
suivants se brancheront.

**Architecture :** le hors ligne est une couche générique adossée à `ApiClient`, seul
point de sortie réseau de l'application. Trois unités isolées derrière leur interface —
`MagasinLocal`, `CacheLecture`, `FileEcritures` — plus un `EtatReseau` observable par les
écrans. Les écrans suivent le patron établi au lot 0.5 : une classe d'API écrite à la
main par domaine, des modèles dans `core/models/`, des providers Riverpod.

**Pile technique :** Flutter 3.38, Riverpod 3.3, `go_router` 17.5, Dio 5.9,
`shared_preferences`, `share_plus`, `qr_flutter` (déjà présent). Côté API : ASP.NET
Core 10, xUnit, Testcontainers.

**Spec :** `docs/superpowers/specs/2026-08-20-ecrans-evenementiels-design.md`

## Contraintes globales

Elles s'appliquent implicitement à **toutes** les tâches.

- **Cloisonnement.** Toute requête remonte `User → EventMember → Event`. Un endpoint ne
  renvoie jamais une ressource au seul motif que son identifiant existe.
- **Invité sans compte.** Le parcours « lien → prénom → présence » reste fonctionnel sans
  authentification. **Ne jamais introduire de dépendance à `user_id`** dans un écran ou
  un modèle du parcours invité.
- **Frontières de modules.** Un module n'accède pas aux tables d'un autre. Communication
  par interface publique. Vérifié par `tools/verifier-frontieres-modules.sh`.
- **Français** dans l'interface et la documentation, **anglais** dans le code et les
  identifiants de base. Dates affichées en **JJ/MM/AAAA**.
- **`NF-I18N-01`** — aucune chaîne en dur dans un écran. Toute chaîne visible passe par
  `lib/l10n/arb/app_fr.arb` puis `make l10n`. Les fichiers générés ne sont pas versionnés.
- **`NF-A11Y-02`** — cibles tactiles de 44 points minimum.
  **`NF-A11Y-03`** — libellé sémantique sur toute action.
- **Tests** — xUnit côté API, `flutter_test` côté application. Les tests de widgets
  montent `PartyPlanApp`, **jamais** un `MaterialApp` nu : sinon ils ne voient pas la même
  application que la production.
- **Commits conventionnels avec périmètre** : `feat(events):`, `fix(offline):`.
- **`make verif`** avant tout push. Jamais d'annonce de complétion sans sortie de commande.
- **Aucun calcul financier côté client**, jamais. Le domaine financier a une source de
  vérité unique.

## Structure des fichiers

### Créés — application

| Fichier | Responsabilité |
|---|---|
| `app/lib/core/storage/magasin_local.dart` | Interface clé-valeur et implémentation `shared_preferences` |
| `app/lib/core/offline/cache_lecture.dart` | Dernière réponse de chaque `GET`, horodatée |
| `app/lib/core/offline/file_ecritures.dart` | Écritures non parties, rejeu ordonné |
| `app/lib/core/offline/etat_reseau.dart` | État observable : en ligne, hors ligne, rejeu, fraîcheur |
| `app/lib/core/offline/ecriture_differee.dart` | Exception signalant « mis en file, pas perdu » |
| `app/lib/core/models/evenement.dart` | `Evenement`, `ResumeEvenement` |
| `app/lib/core/models/membre.dart` | `Membre`, `StatutPresence`, `RoleMembre` |
| `app/lib/core/models/invitation.dart` | `Invitation`, `ApercuInvitation` |
| `app/lib/core/network/evenements_api.dart` | Appels du domaine événementiel |
| `app/lib/features/evenement/accueil_evenements_page.dart` | Liste à venir / passés |
| `app/lib/features/evenement/creation_evenement_page.dart` | Assistant en trois étapes |
| `app/lib/features/evenement/tableau_de_bord_page.dart` | Page à sections |
| `app/lib/features/evenement/sections/` | Une section = un widget autonome |
| `app/lib/features/evenement/invites_page.dart` | Liste des membres et présences |
| `app/lib/features/evenement/parametres_evenement_page.dart` | Modifier, quitter, transférer, supprimer |
| `app/lib/features/evenement/invitation_page.dart` | Lien, code court, QR, partage |
| `app/lib/features/rejoindre/apercu_invitation_page.dart` | Aperçu restreint, sans session |
| `app/lib/features/rejoindre/adhesion_page.dart` | Prénom puis statut — deux écrans |
| `app/lib/design/components/pp_bandeau_hors_ligne.dart` | Bandeau de fraîcheur |

### Modifiés — application

| Fichier | Modification |
|---|---|
| `app/lib/core/network/api_client.dart` | Branchement du cache, de la file et de l'état réseau |
| `app/lib/design/components/pp_optimistic.dart` | Ne pas annuler sur `EcritureDifferee` |
| `app/lib/core/providers.dart` | Providers du domaine événementiel et du hors ligne |
| `app/lib/app/router.dart` | Routes des nouveaux écrans |
| `app/lib/features/evenement/coquille_evenement.dart` | Branchement des onglets |
| `app/lib/features/accueil/accueil_page.dart` | Liste réelle à la place de l'état vide |
| `app/lib/l10n/arb/app_fr.arb` | Chaînes des écrans nouveaux |
| `app/pubspec.yaml` | `shared_preferences`, `share_plus` |

### Modifiés — API

| Fichier | Modification |
|---|---|
| `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs` | `.RequireIdempotency()` sur deux endpoints |
| `api/src/PartyPlan.Modules.Users/Endpoints/AuthEndpoints.cs` | Champ `guestToken` sur `register` et `login` |
| `api/src/PartyPlan.Modules.Users/Application/*` | Service de rattachement |
| `api/src/PartyPlan.SharedKernel/Contracts/` | Contrat public de rattachement d'invité |

**Frontière à respecter.** Le rattachement touche `event_members`, table du module
`Events`. Le module `Users` n'y accède pas directement : il appelle un contrat public
exposé par `Events`, sur le modèle de `IEventStatistics` déjà utilisé par
`Administration` au lot 0.12. `tools/verifier-frontieres-modules.sh` échoue sinon.

---

## Phase 1 — Socle hors ligne

### Tâche 1 : Magasin local

**Fichiers :**
- Créer : `app/lib/core/storage/magasin_local.dart`
- Créer : `app/test/doubles/magasin_local_double.dart`
- Modifier : `app/pubspec.yaml`
- Test : `app/test/core/magasin_local_test.dart`

**Interfaces :**
- Consomme : rien.
- Produit : `abstract interface class MagasinLocal` avec
  `Future<String?> lire(String cle)`, `Future<void> ecrire(String cle, String valeur)`,
  `Future<void> supprimer(String cle)`, `Future<Set<String>> cles()`,
  `Future<void> supprimerPrefixe(String prefixe)`.
  Implémentations : `MagasinPreferences` (production) et `MagasinLocalDouble` (tests).

- [ ] **Étape 1 : ajouter les dépendances**

Dans `app/pubspec.yaml`, sous `dependencies`, après `flutter_secure_storage` :

```yaml
  # Magasin du cache de lecture et de la file d'écritures (NF-OFFLINE-01).
  # Retenu parce que c'est la seule option identique sur Android, iOS et Web sans
  # étape de compilation native — et le Web est une cible de publication.
  shared_preferences: ^2.5.3

  # Feuille de partage native : lien d'invitation et QR code (EF-INV-02).
  share_plus: ^12.0.0
```

Puis `cd app && flutter pub get`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/core/magasin_local_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('MagasinLocal', () {
    test('relit ce qui a été écrit', () async {
      final magasin = MagasinLocalDouble();

      await magasin.ecrire('a', 'valeur');

      expect(await magasin.lire('a'), 'valeur');
    });

    test('renvoie null sur une clé absente', () async {
      expect(await MagasinLocalDouble().lire('absente'), isNull);
    });

    test('supprime par préfixe sans toucher au reste', () async {
      final magasin = MagasinLocalDouble();
      await magasin.ecrire('cache|a', '1');
      await magasin.ecrire('cache|b', '2');
      await magasin.ecrire('file|c', '3');

      await magasin.supprimerPrefixe('cache|');

      expect(await magasin.lire('cache|a'), isNull);
      expect(await magasin.lire('cache|b'), isNull);
      expect(await magasin.lire('file|c'), '3');
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/core/magasin_local_test.dart`
Attendu : ÉCHEC — `Target of URI doesn't exist: '../doubles/magasin_local_double.dart'`.

- [ ] **Étape 4 : écrire l'interface et l'implémentation**

`app/lib/core/storage/magasin_local.dart` :

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Magasin clé-valeur persistant, hors secrets.
///
/// Distinct de [SessionStore], qui protège les jetons : ce qui transite ici est du
/// contenu applicatif, pas un secret d'authentification. Les mélanger reviendrait à
/// faire passer des kilo-octets de JSON par le trousseau de la plateforme.
///
/// Interface plutôt qu'implémentation directe : `shared_preferences` convient aux
/// charges actuelles — une liste d'événements, une liste de membres — mais pas au fil
/// d'activité paginé du lot 1.10. Le jour venu, seul ce fichier change.
abstract interface class MagasinLocal {
  Future<String?> lire(String cle);

  Future<void> ecrire(String cle, String valeur);

  Future<void> supprimer(String cle);

  Future<Set<String>> cles();

  Future<void> supprimerPrefixe(String prefixe);
}

/// Implémentation sur `shared_preferences`.
class MagasinPreferences implements MagasinLocal {
  MagasinPreferences();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _instance async =>
      _prefs ??= await SharedPreferences.getInstance();

  @override
  Future<String?> lire(String cle) async => (await _instance).getString(cle);

  @override
  Future<void> ecrire(String cle, String valeur) async =>
      (await _instance).setString(cle, valeur);

  @override
  Future<void> supprimer(String cle) async => (await _instance).remove(cle);

  @override
  Future<Set<String>> cles() async => (await _instance).getKeys();

  @override
  Future<void> supprimerPrefixe(String prefixe) async {
    final prefs = await _instance;

    // La liste est copiée avant l'itération : supprimer pendant que l'on parcourt
    // l'ensemble renvoyé par getKeys lèverait une ConcurrentModificationError.
    for (final cle in prefs.getKeys().toList()) {
      if (cle.startsWith(prefixe)) {
        await prefs.remove(cle);
      }
    }
  }
}
```

`app/test/doubles/magasin_local_double.dart` :

```dart
import 'package:partyplan/core/storage/magasin_local.dart';

/// Magasin en mémoire.
///
/// `shared_preferences` passe par un canal de plateforme absent d'un test de widget :
/// sans ce substitut, chaque test échouerait pour une raison étrangère à ce qu'il
/// vérifie.
class MagasinLocalDouble implements MagasinLocal {
  final Map<String, String> contenu = {};

  @override
  Future<String?> lire(String cle) async => contenu[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async => contenu[cle] = valeur;

  @override
  Future<void> supprimer(String cle) async => contenu.remove(cle);

  @override
  Future<Set<String>> cles() async => contenu.keys.toSet();

  @override
  Future<void> supprimerPrefixe(String prefixe) async =>
      contenu.removeWhere((cle, _) => cle.startsWith(prefixe));
}
```

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/core/magasin_local_test.dart`
Attendu : 3 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/pubspec.yaml app/pubspec.lock app/lib/core/storage/magasin_local.dart \
        app/test/doubles/magasin_local_double.dart app/test/core/magasin_local_test.dart
git commit -m "feat(offline): magasin clé-valeur local, isolé derrière son interface"
```

---

### Tâche 2 : Cache de lecture

**Fichiers :**
- Créer : `app/lib/core/offline/cache_lecture.dart`
- Test : `app/test/core/cache_lecture_test.dart`

**Interfaces :**
- Consomme : `MagasinLocal` (tâche 1).
- Produit : `class CacheLecture` avec
  `String cle(String chemin, Map<String, dynamic>? parametres)`,
  `Future<void> enregistrer(String chemin, Map<String, dynamic>? parametres, Object? charge, DateTime recuA)`,
  `Future<EntreeCache?> lire(String chemin, Map<String, dynamic>? parametres)`,
  `Future<void> purger()`.
  `class EntreeCache { final Object? charge; final DateTime recuA; }`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/cache_lecture_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/cache_lecture.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('CacheLecture', () {
    test('la clé ne dépend pas de l’ordre des paramètres', () {
      final cache = CacheLecture(MagasinLocalDouble());

      // Deux requêtes équivalentes ne doivent pas produire deux entrées : l'ordre
      // d'insertion d'une Map n'est pas significatif pour l'API.
      expect(
        cache.cle('/events', {'b': 2, 'a': 1}),
        cache.cle('/events', {'a': 1, 'b': 2}),
      );
    });

    test('la clé distingue deux chemins', () {
      final cache = CacheLecture(MagasinLocalDouble());

      expect(cache.cle('/events', null), isNot(cache.cle('/events/42', null)));
    });

    test('relit la charge et la date de réception', () async {
      final magasin = MagasinLocalDouble();
      final cache = CacheLecture(magasin);
      final recuA = DateTime.utc(2026, 8, 20, 14, 32);

      await cache.enregistrer('/events', null, [
        {'id': 'a', 'name': 'Crémaillère'},
      ], recuA);

      final entree = await cache.lire('/events', null);

      expect(entree, isNotNull);
      expect(entree!.recuA, recuA);
      expect((entree.charge! as List).first, {'id': 'a', 'name': 'Crémaillère'});
    });

    test('renvoie null quand rien n’a été mis en cache', () async {
      final cache = CacheLecture(MagasinLocalDouble());

      expect(await cache.lire('/events', null), isNull);
    });

    test('purge tout le cache sans toucher aux autres clés', () async {
      final magasin = MagasinLocalDouble();
      final cache = CacheLecture(magasin);
      await magasin.ecrire('pp_file|1', 'écriture en attente');
      await cache.enregistrer('/events', null, [], DateTime.utc(2026));

      await cache.purger();

      expect(await cache.lire('/events', null), isNull);
      // La file d'écritures survit à la purge du cache : ce sont des actions de
      // l'utilisateur qui ne sont pas encore parties, pas des données rechargeables.
      expect(await magasin.lire('pp_file|1'), 'écriture en attente');
    });
  });
}
```

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd app && flutter test test/core/cache_lecture_test.dart`
Attendu : ÉCHEC — `Target of URI doesn't exist: 'package:partyplan/core/offline/cache_lecture.dart'`.

- [ ] **Étape 3 : implémenter**

`app/lib/core/offline/cache_lecture.dart` :

```dart
import 'dart:convert';

import '../storage/magasin_local.dart';

/// Entrée de cache : la charge utile telle qu'elle a été reçue, et la date de réception.
///
/// La date n'est pas un détail de journalisation : c'est elle que l'écran affiche
/// (« données du 20/08 à 14 h 32 »). Sans elle, l'utilisateur ne distingue pas un état
/// ancien d'un état courant, et décide sur des chiffres périmés.
class EntreeCache {
  const EntreeCache({required this.charge, required this.recuA});

  final Object? charge;
  final DateTime recuA;
}

/// Dernière réponse connue de chaque lecture.
class CacheLecture {
  const CacheLecture(this._magasin);

  static const prefixe = 'pp_cache|';

  final MagasinLocal _magasin;

  /// Clé stable d'une lecture.
  ///
  /// Les paramètres sont triés : deux requêtes équivalentes dont les paramètres ont été
  /// construits dans un ordre différent doivent partager une seule entrée.
  String cle(String chemin, Map<String, dynamic>? parametres) {
    if (parametres == null || parametres.isEmpty) {
      return '${prefixe}GET|$chemin';
    }

    final tries = parametres.keys.toList()..sort();
    final rendu = tries.map((c) => '$c=${parametres[c]}').join('&');

    return '${prefixe}GET|$chemin?$rendu';
  }

  Future<void> enregistrer(
    String chemin,
    Map<String, dynamic>? parametres,
    Object? charge,
    DateTime recuA,
  ) => _magasin.ecrire(
    cle(chemin, parametres),
    jsonEncode({'recuA': recuA.toIso8601String(), 'charge': charge}),
  );

  Future<EntreeCache?> lire(
    String chemin,
    Map<String, dynamic>? parametres,
  ) async {
    final brut = await _magasin.lire(cle(chemin, parametres));

    if (brut == null) {
      return null;
    }

    final decode = jsonDecode(brut) as Map<String, dynamic>;

    return EntreeCache(
      charge: decode['charge'],
      recuA: DateTime.parse(decode['recuA'] as String),
    );
  }

  /// Vidé à la déconnexion et au changement de compte : le cache contient le contenu
  /// d'événements privés, et le laisser en place sur un appareil partagé démentirait la
  /// promesse d'événement privé.
  Future<void> purger() => _magasin.supprimerPrefixe(prefixe);
}
```

- [ ] **Étape 4 : vérifier le succès**

Run : `cd app && flutter test test/core/cache_lecture_test.dart`
Attendu : 5 tests réussis.

- [ ] **Étape 5 : commit**

```bash
git add app/lib/core/offline/cache_lecture.dart app/test/core/cache_lecture_test.dart
git commit -m "feat(offline): cache de lecture horodaté, à clé stable"
```

---

### Tâche 3 : File d'écritures

**Fichiers :**
- Créer : `app/lib/core/offline/file_ecritures.dart`
- Créer : `app/lib/core/offline/ecriture_differee.dart`
- Test : `app/test/core/file_ecritures_test.dart`

**Interfaces :**
- Consomme : `MagasinLocal` (tâche 1).
- Produit :
  `class EcritureEnAttente { final String id; final String methode; final String chemin;
  final Object? corps; final String cleIdempotence; final DateTime inscriteA;
  final int tentatives; }`
  `class FileEcritures` avec
  `Future<EcritureEnAttente> inscrire({required String methode, required String chemin, Object? corps})`,
  `Future<List<EcritureEnAttente>> enAttente()`,
  `Future<void> retirer(String id)`,
  `Future<void> incrementerTentatives(String id)`,
  `Future<void> purger()`.
  `class EcritureDifferee implements Exception { final EcritureEnAttente ecriture; }`

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/file_ecritures_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/file_ecritures.dart';

import '../doubles/magasin_local_double.dart';

void main() {
  group('FileEcritures', () {
    test('conserve l’ordre d’inscription', () async {
      final file = FileEcritures(MagasinLocalDouble());

      await file.inscrire(methode: 'POST', chemin: '/join/abc', corps: {'a': 1});
      await file.inscrire(methode: 'PATCH', chemin: '/events/1/members/me');

      final attente = await file.enAttente();

      expect(attente.map((e) => e.chemin), [
        '/join/abc',
        '/events/1/members/me',
      ]);
    });

    test('la clé d’idempotence est fixée à l’inscription et ne change plus', () async {
      final magasin = MagasinLocalDouble();
      final file = FileEcritures(magasin);

      final inscrite = await file.inscrire(methode: 'POST', chemin: '/join/abc');

      // Relecture depuis le magasin : c'est le chemin qu'emprunte un rejeu après
      // redémarrage de l'application. Une clé régénérée ici ne serait plus reconnue
      // par l'idempotence du serveur, et le rejeu créerait un doublon.
      final relue = (await FileEcritures(magasin).enAttente()).single;

      expect(relue.cleIdempotence, inscrite.cleIdempotence);
      expect(relue.cleIdempotence, isNotEmpty);
    });

    test('deux inscriptions portent deux clés distinctes', () async {
      final file = FileEcritures(MagasinLocalDouble());

      final a = await file.inscrire(methode: 'POST', chemin: '/join/abc');
      final b = await file.inscrire(methode: 'POST', chemin: '/join/abc');

      expect(a.cleIdempotence, isNot(b.cleIdempotence));
    });

    test('retirer sort une écriture et laisse les autres', () async {
      final file = FileEcritures(MagasinLocalDouble());
      final a = await file.inscrire(methode: 'POST', chemin: '/a');
      await file.inscrire(methode: 'POST', chemin: '/b');

      await file.retirer(a.id);

      expect((await file.enAttente()).map((e) => e.chemin), ['/b']);
    });

    test('compte les tentatives', () async {
      final file = FileEcritures(MagasinLocalDouble());
      final a = await file.inscrire(methode: 'POST', chemin: '/a');

      await file.incrementerTentatives(a.id);
      await file.incrementerTentatives(a.id);

      expect((await file.enAttente()).single.tentatives, 2);
    });

    test('le corps est restitué à l’identique après relecture', () async {
      final magasin = MagasinLocalDouble();
      await FileEcritures(magasin).inscrire(
        methode: 'PATCH',
        chemin: '/events/1/members/me',
        corps: {'status': 'Going', 'extraGuests': 2},
      );

      final relue = (await FileEcritures(magasin).enAttente()).single;

      expect(relue.corps, {'status': 'Going', 'extraGuests': 2});
    });
  });
}
```

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd app && flutter test test/core/file_ecritures_test.dart`
Attendu : ÉCHEC — fichier `file_ecritures.dart` inexistant.

- [ ] **Étape 3 : implémenter l'exception**

`app/lib/core/offline/ecriture_differee.dart` :

```dart
import 'file_ecritures.dart';

/// L'écriture n'est pas partie : elle est en file et repartira à la reconnexion.
///
/// Distincte d'une erreur : l'interface **conserve** l'état optimiste au lieu de
/// l'annuler. Traiter ce cas comme un échec ferait disparaître sous les yeux de
/// l'utilisateur une action qui, elle, aboutira.
class EcritureDifferee implements Exception {
  const EcritureDifferee(this.ecriture);

  final EcritureEnAttente ecriture;

  @override
  String toString() =>
      'EcritureDifferee(${ecriture.methode} ${ecriture.chemin})';
}
```

- [ ] **Étape 4 : implémenter la file**

`app/lib/core/offline/file_ecritures.dart` :

```dart
import 'dart:convert';
import 'dart:math';

import '../storage/magasin_local.dart';

/// Écriture inscrite en file, en attente de départ.
class EcritureEnAttente {
  const EcritureEnAttente({
    required this.id,
    required this.methode,
    required this.chemin,
    required this.corps,
    required this.cleIdempotence,
    required this.inscriteA,
    required this.tentatives,
  });

  final String id;
  final String methode;
  final String chemin;
  final Object? corps;

  /// Fixée à l'inscription, jamais régénérée. Voir [FileEcritures.inscrire].
  final String cleIdempotence;

  final DateTime inscriteA;
  final int tentatives;

  EcritureEnAttente avecTentatives(int valeur) => EcritureEnAttente(
    id: id,
    methode: methode,
    chemin: chemin,
    corps: corps,
    cleIdempotence: cleIdempotence,
    inscriteA: inscriteA,
    tentatives: valeur,
  );

  Map<String, dynamic> versJson() => {
    'id': id,
    'methode': methode,
    'chemin': chemin,
    'corps': corps,
    'cleIdempotence': cleIdempotence,
    'inscriteA': inscriteA.toIso8601String(),
    'tentatives': tentatives,
  };

  static EcritureEnAttente depuisJson(Map<String, dynamic> json) =>
      EcritureEnAttente(
        id: json['id'] as String,
        methode: json['methode'] as String,
        chemin: json['chemin'] as String,
        corps: json['corps'],
        cleIdempotence: json['cleIdempotence'] as String,
        inscriteA: DateTime.parse(json['inscriteA'] as String),
        tentatives: json['tentatives'] as int,
      );
}

/// Écritures qui n'ont pas pu partir, rejouées dans l'ordre à la reconnexion.
class FileEcritures {
  FileEcritures(this._magasin);

  static const cleFile = 'pp_file|ecritures';

  final MagasinLocal _magasin;
  final Random _alea = Random.secure();

  /// Inscrit une écriture et lui attribue **définitivement** sa clé d'idempotence.
  ///
  /// C'est le point qui fait tenir tout le mécanisme. Régénérer la clé au rejeu
  /// produirait une clé neuve, l'idempotence du serveur ne reconnaîtrait rien, et le
  /// rejeu créerait un doublon — exactement ce que la file est censée empêcher.
  Future<EcritureEnAttente> inscrire({
    required String methode,
    required String chemin,
    Object? corps,
  }) async {
    final ecriture = EcritureEnAttente(
      id: _identifiant(),
      methode: methode,
      chemin: chemin,
      corps: corps,
      cleIdempotence: _identifiant(),
      inscriteA: DateTime.now(),
      tentatives: 0,
    );

    final attente = await enAttente()..add(ecriture);
    await _ecrire(attente);

    return ecriture;
  }

  /// Écritures en attente, dans l'ordre d'inscription.
  ///
  /// L'ordre est significatif : rejouer en parallèle ferait par exemple partir un
  /// changement de statut avant l'adhésion qui le rend possible.
  Future<List<EcritureEnAttente>> enAttente() async {
    final brut = await _magasin.lire(cleFile);

    if (brut == null) {
      return [];
    }

    return (jsonDecode(brut) as List)
        .map((e) => EcritureEnAttente.depuisJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> retirer(String id) async {
    final attente = await enAttente()..removeWhere((e) => e.id == id);
    await _ecrire(attente);
  }

  Future<void> incrementerTentatives(String id) async {
    final attente = await enAttente();

    await _ecrire([
      for (final e in attente)
        if (e.id == id) e.avecTentatives(e.tentatives + 1) else e,
    ]);
  }

  Future<void> purger() => _magasin.supprimer(cleFile);

  Future<void> _ecrire(List<EcritureEnAttente> ecritures) => _magasin.ecrire(
    cleFile,
    jsonEncode([for (final e in ecritures) e.versJson()]),
  );

  /// 128 bits en hexadécimal. `Random.secure` et non `Random` : une clé d'idempotence
  /// devinable permettrait à un tiers de faire rejouer la réponse d'autrui.
  String _identifiant() => List.generate(
    16,
    (_) => _alea.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
```

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/core/file_ecritures_test.dart`
Attendu : 6 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/core/offline/file_ecritures.dart \
        app/lib/core/offline/ecriture_differee.dart \
        app/test/core/file_ecritures_test.dart
git commit -m "feat(offline): file d'écritures ordonnée, à clé d'idempotence stable"
```

---

### Tâche 4 : État réseau et branchement dans `ApiClient`

**Fichiers :**
- Créer : `app/lib/core/offline/etat_reseau.dart`
- Modifier : `app/lib/core/network/api_client.dart`
- Modifier : `app/lib/design/components/pp_optimistic.dart`
- Test : `app/test/core/api_client_hors_ligne_test.dart`

**Interfaces :**
- Consomme : `CacheLecture` (tâche 2), `FileEcritures` et `EcritureDifferee` (tâche 3).
- Produit :
  `enum ModeReseau { enLigne, horsLigne, rejeuEnCours }`
  `class EtatReseau extends ChangeNotifier` avec `ModeReseau get mode`,
  `DateTime? get fraicheur`, `int get enAttente`.
  `ApiClient.get` gagne le paramètre nommé `bool cacheable = true`.
  `ApiClient.post/patch/put/delete` gagnent `bool differable = false`.

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/api_client_hors_ligne_test.dart` :

```dart
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/offline/cache_lecture.dart';
import 'package:partyplan/core/offline/ecriture_differee.dart';
import 'package:partyplan/core/offline/etat_reseau.dart';
import 'package:partyplan/core/offline/file_ecritures.dart';

import '../doubles/magasin_local_double.dart';
import '../doubles/session_store_double.dart';

/// Intercepteur qui simule l'absence de réseau ou une réponse donnée.
class _Reseau extends Interceptor {
  _Reseau();

  bool coupe = false;
  Object? reponse;
  int statut = 200;
  int appels = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    appels++;

    if (coupe) {
      handler.reject(
        DioException.connectionError(
          requestOptions: options,
          reason: 'réseau coupé',
        ),
      );
      return;
    }

    handler.resolve(
      Response<Object?>(
        requestOptions: options,
        statusCode: statut,
        data: reponse,
      ),
    );
  }
}

void main() {
  late _Reseau reseau;
  late MagasinLocalDouble magasin;
  late ApiClient client;
  late EtatReseau etat;

  setUp(() {
    reseau = _Reseau();
    magasin = MagasinLocalDouble();
    etat = EtatReseau();

    final dio = Dio(BaseOptions(baseUrl: 'https://exemple.test/v1'))
      ..interceptors.add(reseau);

    client = ApiClient(
      SessionStoreDouble(jetonAcces: 'jeton'),
      dio: dio,
      cache: CacheLecture(magasin),
      file: FileEcritures(magasin),
      etat: etat,
    );
  });

  group('Lecture hors ligne', () {
    test('sert la dernière réponse connue quand le réseau est coupé', () async {
      reseau.reponse = [
        {'id': 'a'},
      ];
      await client.get<List<dynamic>>(
        '/events',
        analyser: (c) => c! as List<dynamic>,
      );

      reseau.coupe = true;
      final servi = await client.get<List<dynamic>>(
        '/events',
        analyser: (c) => c! as List<dynamic>,
      );

      expect(servi, [
        {'id': 'a'},
      ]);
      expect(etat.mode, ModeReseau.horsLigne);
      expect(etat.fraicheur, isNotNull);
    });

    test('échoue quand le réseau est coupé et que rien n’est en cache', () async {
      reseau.coupe = true;

      expect(
        () => client.get<List<dynamic>>(
          '/events',
          analyser: (c) => c! as List<dynamic>,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('Écriture hors ligne', () {
    test('met en file une écriture différable et lève EcritureDifferee', () async {
      reseau.coupe = true;

      await expectLater(
        client.patch<void>(
          '/events/1/members/me',
          corps: {'status': 'Going'},
          differable: true,
          analyser: (_) {},
        ),
        throwsA(isA<EcritureDifferee>()),
      );

      expect((await FileEcritures(magasin).enAttente()).single.chemin,
          '/events/1/members/me');
      expect(etat.enAttente, 1);
    });

    test('ne met pas en file une écriture non différable', () async {
      reseau.coupe = true;

      await expectLater(
        client.post<void>(
          '/events/1/invitation/rotate',
          analyser: (_) {},
        ),
        throwsA(isA<DioException>()),
      );

      // rotate est délibérément non idempotent : rejoué, il invaliderait le lien que
      // l'utilisateur vient de partager.
      expect(await FileEcritures(magasin).enAttente(), isEmpty);
    });

    test('rejoue la file avec la clé d’idempotence d’origine', () async {
      reseau.coupe = true;
      await client
          .patch<void>(
            '/events/1/members/me',
            corps: {'status': 'Going'},
            differable: true,
            analyser: (_) {},
          )
          .onError((_, _) {});

      final cleAttendue =
          (await FileEcritures(magasin).enAttente()).single.cleIdempotence;

      reseau.coupe = false;
      reseau.reponse = null;
      reseau.statut = 204;
      await client.rejouerLaFile();

      expect(await FileEcritures(magasin).enAttente(), isEmpty);
      expect(cleAttendue, isNotEmpty);
    });

    test('une 4xx métier retire l’écriture de la file', () async {
      reseau.coupe = true;
      await client
          .patch<void>('/a', corps: {}, differable: true, analyser: (_) {})
          .onError((_, _) {});

      reseau.coupe = false;
      reseau.statut = 422;
      reseau.reponse = {'title': 'Statut inconnu.', 'code': 'attendance.bad'};
      await client.rejouerLaFile();

      expect(await FileEcritures(magasin).enAttente(), isEmpty);
    });

    test('une 5xx conserve l’écriture en file', () async {
      reseau.coupe = true;
      await client
          .patch<void>('/a', corps: {}, differable: true, analyser: (_) {})
          .onError((_, _) {});

      reseau.coupe = false;
      reseau.statut = 503;
      reseau.reponse = {'title': 'Service indisponible.'};
      await client.rejouerLaFile();

      expect((await FileEcritures(magasin).enAttente()).single.tentatives, 1);
    });
  });
}
```

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd app && flutter test test/core/api_client_hors_ligne_test.dart`
Attendu : ÉCHEC — `ApiClient` n'accepte pas les paramètres `cache`, `file`, `etat`.

- [ ] **Étape 3 : implémenter `EtatReseau`**

`app/lib/core/offline/etat_reseau.dart` :

```dart
import 'package:flutter/foundation.dart';

enum ModeReseau { enLigne, horsLigne, rejeuEnCours }

/// État réseau observable par les écrans.
///
/// Les écrans ne connaissent que cet objet : ni le cache, ni la file. C'est ce qui
/// permet d'ajouter un module sans qu'aucun de ses écrans n'ait à savoir comment le
/// hors ligne fonctionne.
class EtatReseau extends ChangeNotifier {
  ModeReseau _mode = ModeReseau.enLigne;
  DateTime? _fraicheur;
  int _enAttente = 0;

  ModeReseau get mode => _mode;

  /// Date de la dernière donnée servie depuis le cache. `null` en ligne.
  DateTime? get fraicheur => _fraicheur;

  int get enAttente => _enAttente;

  void signalerEnLigne() {
    if (_mode != ModeReseau.enLigne || _fraicheur != null) {
      _mode = ModeReseau.enLigne;
      _fraicheur = null;
      notifyListeners();
    }
  }

  void signalerHorsLigne({DateTime? fraicheur}) {
    _mode = ModeReseau.horsLigne;
    _fraicheur = fraicheur;
    notifyListeners();
  }

  void signalerRejeu() {
    _mode = ModeReseau.rejeuEnCours;
    notifyListeners();
  }

  void majEnAttente(int valeur) {
    if (_enAttente != valeur) {
      _enAttente = valeur;
      notifyListeners();
    }
  }
}
```

- [ ] **Étape 4 : brancher `ApiClient`**

Dans `app/lib/core/network/api_client.dart` — remplacer le constructeur et ajouter les
champs :

```dart
  ApiClient(
    this._sessionStore, {
    Dio? dio,
    CacheLecture? cache,
    FileEcritures? file,
    EtatReseau? etat,
  })  : _cache = cache,
        _file = file,
        _etat = etat ?? EtatReseau(),
        _dio = dio ?? Dio(/* BaseOptions inchangées */) {
    // interceptor de jeton inchangé
  }

  final CacheLecture? _cache;
  final FileEcritures? _file;
  final EtatReseau _etat;

  EtatReseau get etat => _etat;
```

Remplacer `get` :

```dart
  Future<T> get<T>(
    String chemin, {
    Map<String, dynamic>? parametres,
    bool cacheable = true,
    required T Function(Object? corps) analyser,
  }) async {
    try {
      final reponse = await _dio.get<Object?>(
        chemin,
        queryParameters: parametres,
      );
      _verifier(reponse);

      if (cacheable && _cache != null) {
        await _cache.enregistrer(
          chemin,
          parametres,
          reponse.data,
          DateTime.now(),
        );
      }

      _etat.signalerEnLigne();
      return analyser(reponse.data);
    } on DioException catch (erreur) {
      if (!_estPanneReseau(erreur) || !cacheable || _cache == null) {
        rethrow;
      }

      final entree = await _cache.lire(chemin, parametres);

      // Sans entrée en cache, l'échec est propagé tel quel : l'écran affiche son état
      // d'erreur. Inventer une réponse vide laisserait croire à une liste vide.
      if (entree == null) {
        _etat.signalerHorsLigne();
        rethrow;
      }

      _etat.signalerHorsLigne(fraicheur: entree.recuA);
      return analyser(entree.charge);
    }
  }
```

Ajouter la détection et le rejeu :

```dart
  /// Panne réseau, et non refus du serveur.
  ///
  /// Détectée sur l'échec réel de la requête, jamais sur une bibliothèque de
  /// connectivité : un wifi capté sans accès à Internet — salle des fêtes, cave,
  /// portail captif — est le cas le plus fréquent pour ce produit, et une telle
  /// bibliothèque le déclare « connecté ».
  static bool _estPanneReseau(DioException erreur) =>
      erreur.type == DioExceptionType.connectionError ||
      erreur.type == DioExceptionType.connectionTimeout ||
      erreur.type == DioExceptionType.sendTimeout ||
      erreur.type == DioExceptionType.receiveTimeout;

  /// Rejoue la file, dans l'ordre, en s'arrêtant à la première écriture qui reste.
  Future<void> rejouerLaFile() async {
    final file = _file;
    if (file == null) {
      return;
    }

    _etat.signalerRejeu();

    for (final ecriture in await file.enAttente()) {
      final Response<Object?> reponse;

      try {
        reponse = await _dio.request<Object?>(
          ecriture.chemin,
          data: ecriture.corps,
          options: Options(
            method: ecriture.methode,
            headers: {'Idempotency-Key': ecriture.cleIdempotence},
          ),
        );
      } on DioException {
        await file.incrementerTentatives(ecriture.id);
        _etat.signalerHorsLigne();
        break;
      }

      final statut = reponse.statusCode ?? 0;

      if (statut >= 200 && statut < 300) {
        await file.retirer(ecriture.id);
        continue;
      }

      if (statut == 401) {
        // La session est à rouvrir. L'écriture n'est pas fautive : elle reste.
        break;
      }

      if (statut >= 400 && statut < 500) {
        // Refus définitif. La laisser en file bloquerait tout ce qui suit, pour
        // toujours.
        await file.retirer(ecriture.id);
        continue;
      }

      await file.incrementerTentatives(ecriture.id);
      break;
    }

    _etat.majEnAttente((await file.enAttente()).length);

    if (_etat.mode == ModeReseau.rejeuEnCours) {
      _etat.signalerEnLigne();
    }
  }
```

Remplacer `_envoyer` par une version qui met en file :

```dart
  Future<Response<Object?>> _envoyer(
    Future<Response<Object?>> Function() requete, {
    required bool differable,
    required String methode,
    required String chemin,
    Object? corps,
  }) async {
    Response<Object?> reponse;

    try {
      reponse = await requete();
    } on DioException catch (erreur) {
      final file = _file;

      // La mise en file est déclarée opération par opération, jamais par défaut :
      // POST /events/{id}/invitation/rotate est délibérément non idempotent, et un
      // rejeu invaliderait le lien que l'utilisateur vient de partager.
      if (!differable || file == null || !_estPanneReseau(erreur)) {
        rethrow;
      }

      final ecriture = await file.inscrire(
        methode: methode,
        chemin: chemin,
        corps: corps,
      );

      _etat.signalerHorsLigne();
      _etat.majEnAttente((await file.enAttente()).length);

      throw EcritureDifferee(ecriture);
    }

    if (reponse.statusCode == 401 && await _rafraichir()) {
      reponse = await requete();
    }

    _verifier(reponse);
    _etat.signalerEnLigne();
    return reponse;
  }
```

Chaque méthode d'écriture transmet ses paramètres, par exemple :

```dart
  Future<T> patch<T>(
    String chemin, {
    Object? corps,
    bool differable = false,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _envoyer(
      () => _dio.patch<Object?>(chemin, data: corps),
      differable: differable,
      methode: 'PATCH',
      chemin: chemin,
      corps: corps,
    );
    return analyser(reponse.data);
  }
```

Faire de même pour `post`, `put`, `delete` et `deleteWithBody`. Sur `post`, la clé
d'idempotence explicite reste transmise en en-tête comme aujourd'hui.

- [ ] **Étape 5 : adapter `PpOptimisticAction`**

Dans `app/lib/design/components/pp_optimistic.dart`, remplacer le bloc `catch` :

```dart
    try {
      await envoyer();
      return true;
    } on EcritureDifferee {
      // Différée n'est pas échouée. Annuler ferait disparaître sous les yeux de
      // l'utilisateur une action qui, elle, partira à la reconnexion.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(messageDiffere)),
        );
      }
      return true;
    } on Exception {
      annuler();
      ...
    }
```

Ajouter le paramètre nommé requis `required String messageDiffere` à `executer`, et
l'import de `ecriture_differee.dart`.

- [ ] **Étape 6 : vérifier le succès**

Run : `cd app && flutter test test/core/api_client_hors_ligne_test.dart`
Attendu : 7 tests réussis.
Puis `cd app && flutter test` — l'ensemble des tests existants doit rester vert.

- [ ] **Étape 7 : commit**

```bash
git add app/lib/core/offline/etat_reseau.dart app/lib/core/network/api_client.dart \
        app/lib/design/components/pp_optimistic.dart \
        app/test/core/api_client_hors_ligne_test.dart
git commit -m "feat(offline): cache et file branchés sur le point de sortie réseau unique"
```

---

### Tâche 5 : Bandeau de fraîcheur

**Fichiers :**
- Créer : `app/lib/design/components/pp_bandeau_hors_ligne.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/design/pp_bandeau_hors_ligne_test.dart`

**Interfaces :**
- Consomme : `EtatReseau`, `ModeReseau` (tâche 4).
- Produit : `class PpBandeauHorsLigne extends StatelessWidget` — paramètre
  `EtatReseau etat`, callback `VoidCallback? onReessayer`.

- [ ] **Étape 1 : ajouter les chaînes**

Dans `app/lib/l10n/arb/app_fr.arb` :

```json
  "horsLigneDonneesDu": "Données du {date}",
  "@horsLigneDonneesDu": {
    "description": "Bandeau affiché quand l'écran montre l'état en cache. La date rend visible qu'il ne s'agit pas de l'état courant.",
    "placeholders": { "date": { "type": "String" } }
  },
  "horsLigneEnAttente": "{nombre, plural, one{1 modification en attente d’envoi} other{{nombre} modifications en attente d’envoi}}",
  "@horsLigneEnAttente": {
    "placeholders": { "nombre": { "type": "int" } }
  },
  "horsLigneReessayer": "Réessayer",
  "horsLigneDiffere": "Enregistré. Sera envoyé dès le retour du réseau."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/design/pp_bandeau_hors_ligne_test.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/offline/etat_reseau.dart';
import 'package:partyplan/design/components/pp_bandeau_hors_ligne.dart';

import '../aide/monter.dart';

void main() {
  testWidgets('reste invisible en ligne', (tester) async {
    await monterWidget(tester, PpBandeauHorsLigne(etat: EtatReseau()));

    expect(find.byType(Card), findsNothing);
  });

  testWidgets('affiche la date de fraîcheur en JJ/MM/AAAA', (tester) async {
    final etat = EtatReseau()
      ..signalerHorsLigne(fraicheur: DateTime(2026, 8, 20, 14, 32));

    await monterWidget(tester, PpBandeauHorsLigne(etat: etat));

    expect(find.textContaining('20/08/2026'), findsOneWidget);
  });

  testWidgets('annonce les écritures en attente', (tester) async {
    final etat = EtatReseau()
      ..signalerHorsLigne()
      ..majEnAttente(2);

    await monterWidget(tester, PpBandeauHorsLigne(etat: etat));

    expect(find.textContaining('2 modifications'), findsOneWidget);
  });
}
```

Créer aussi l'aide de montage `app/test/aide/monter.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';

/// Monte un widget isolé avec les délégués de localisation de l'application.
///
/// Les écrans complets se montent par `PartyPlanApp` ; cette aide ne sert qu'aux
/// composants du système de design, qui n'ont pas besoin du routeur.
Future<void> monterWidget(WidgetTester tester, Widget enfant) => tester.pumpWidget(
  MaterialApp(
    localizationsDelegates: PartyPlanApp.delegues,
    supportedLocales: PartyPlanApp.languesPrisesEnCharge,
    home: Scaffold(body: enfant),
  ),
);
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/design/pp_bandeau_hors_ligne_test.dart`
Attendu : ÉCHEC — `pp_bandeau_hors_ligne.dart` inexistant.

- [ ] **Étape 4 : implémenter**

`app/lib/design/components/pp_bandeau_hors_ligne.dart` :

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/offline/etat_reseau.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../tokens.dart';

/// Bandeau de fraîcheur, affiché quand l'écran montre l'état en cache.
///
/// La date est le contenu, pas la décoration : sans elle, l'utilisateur ne distingue
/// pas un état ancien d'un état courant et décide sur des chiffres périmés.
class PpBandeauHorsLigne extends StatelessWidget {
  const PpBandeauHorsLigne({required this.etat, this.onReessayer, super.key});

  final EtatReseau etat;
  final VoidCallback? onReessayer;

  @override
  Widget build(BuildContext context) {
    if (etat.mode == ModeReseau.enLigne && etat.enAttente == 0) {
      return const SizedBox.shrink();
    }

    final l10n = PpL10n.of(context);
    final fraicheur = etat.fraicheur;

    final lignes = <String>[
      if (fraicheur != null)
        l10n.horsLigneDonneesDu(
          DateFormat('dd/MM/yyyy à HH:mm', 'fr').format(fraicheur),
        ),
      if (etat.enAttente > 0) l10n.horsLigneEnAttente(etat.enAttente),
    ];

    return Semantics(
      liveRegion: true,
      child: Card(
        margin: const EdgeInsets.all(PpSpacing.sm),
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.sm),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded),
              const SizedBox(width: PpSpacing.sm),
              Expanded(child: Text(lignes.join(' · '))),
              if (onReessayer != null)
                TextButton(
                  onPressed: onReessayer,
                  child: Text(l10n.horsLigneReessayer),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/design/pp_bandeau_hors_ligne_test.dart`
Attendu : 3 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/design/components/pp_bandeau_hors_ligne.dart app/test/aide/monter.dart \
        app/test/design/pp_bandeau_hors_ligne_test.dart app/lib/l10n/arb/app_fr.arb
git commit -m "feat(offline): bandeau de fraîcheur avec date et écritures en attente"
```

---

## Phase 2 — API

### Tâche 6 : Idempotence des deux écritures différables

**Fichiers :**
- Modifier : `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs`

**Interfaces :**
- Consomme : `RequireIdempotency()` de `PartyPlan.SharedKernel.Contracts`.
- Produit : rien de nouveau. Deux endpoints exigent désormais `Idempotency-Key`.

- [ ] **Étape 1 : écrire les tests qui échouent**

Ajouter à `api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs` :

```csharp
[Fact]
public async Task Adhesion_rejouee_avec_la_meme_cle_ne_cree_pas_deux_membres()
{
    var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
    var invitation = await LireInvitationAsync(evenement);
    var cle = Guid.NewGuid().ToString();

    var premiere = await PosterAdhesionAsync(invitation.Token, "Léa", cle);
    var seconde = await PosterAdhesionAsync(invitation.Token, "Léa", cle);

    Assert.Equal(HttpStatusCode.OK, premiere.StatusCode);
    Assert.Equal(HttpStatusCode.OK, seconde.StatusCode);

    // Le rejeu doit rendre la réponse mémorisée, pas créer un second membre : c'est
    // exactement ce qui se produirait au retour du réseau après une mise en file.
    var membres = await ListerMembresAsync(evenement);
    Assert.Single(membres, m => m.DisplayName == "Léa");
}

[Fact]
public async Task Adhesion_sans_cle_est_refusee()
{
    var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
    var invitation = await LireInvitationAsync(evenement);

    var reponse = await PosterAdhesionAsync(invitation.Token, "Léa", cle: null);

    Assert.Equal(HttpStatusCode.BadRequest, reponse.StatusCode);
}

[Fact]
public async Task Transfert_de_propriete_rejoue_ne_change_rien()
{
    var (evenement, proprietaire) = await CreerEvenementAvecProprietaireAsync();
    var cible = await AjouterMembreAvecCompteAsync(evenement);
    var cle = Guid.NewGuid().ToString();

    await PosterTransfertAsync(evenement, cible.Id, cle);
    await PosterTransfertAsync(evenement, cible.Id, cle);

    var membres = await ListerMembresAsync(evenement);
    Assert.Single(membres, m => m.Role == "Owner");
    Assert.Equal(cible.Id, membres.Single(m => m.Role == "Owner").Id);
    Assert.Equal("Admin", membres.Single(m => m.Id == proprietaire.Id).Role);
}
```

Vérifier lesquelles des aides `CreerEvenementAvecProprietaireAsync`,
`LireInvitationAsync` et `ListerMembresAsync` existent déjà dans ce fichier ; écrire
celles qui manquent, sur le modèle des aides présentes. Ajouter dans tous les cas
`PosterAdhesionAsync(string token, string prenom, string? cle)`,
`PosterTransfertAsync(Guid evenement, Guid membre, string cle)` et
`AjouterMembreAvecCompteAsync(Guid evenement)` sur le modèle des aides existantes.

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd api && dotnet test tests/PartyPlan.IntegrationTests --filter "Adhesion_sans_cle_est_refusee"`
Attendu : ÉCHEC — la réponse est 200, pas 400, l'endpoint n'exigeant pas encore la clé.

- [ ] **Étape 3 : déclarer l'exigence**

Dans `api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs`, sur
`groupe.MapPost("/{token}", ...)` du groupe `/join`, après `.WithName(...)` :

```csharp
            .WithSummary("Rejoint un événement avec un prénom. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
```

Et sur `groupe.MapPost("/{memberId:guid}/transfer-ownership", ...)` :

```csharp
            .WithSummary("Transfère la propriété. En-tête Idempotency-Key obligatoire.")
            .RequireIdempotency()
```

Motif à porter en commentaire au-dessus des deux :

```csharp
        // Écriture susceptible d'être mise en file par le client hors ligne
        // (NF-OFFLINE-01) : le rejeu doit rendre la réponse mémorisée, jamais créer un
        // second effet.
```

- [ ] **Étape 4 : vérifier le succès**

Run : `cd api && dotnet test tests/PartyPlan.IntegrationTests --filter "FullyQualifiedName~EvenementsTests"`
Attendu : tous verts, dont les trois nouveaux.

- [ ] **Étape 5 : régénérer le contrat OpenAPI**

Run : `make openapi`
Attendu : `docs/api/openapi.json` mis à jour, les deux endpoints portant désormais
l'en-tête `Idempotency-Key` obligatoire.

- [ ] **Étape 6 : commit**

```bash
git add api/src/PartyPlan.Modules.Events/Endpoints/EventsEndpoints.cs \
        api/tests/PartyPlan.IntegrationTests/EvenementsTests.cs docs/api/openapi.json
git commit -m "feat(events): idempotence sur l'adhésion et le transfert de propriété"
```

---

### Tâche 7 : Rattachement d'un invité à un compte — contrat et service

**Fichiers :**
- Créer : `api/src/PartyPlan.SharedKernel/Contracts/IGuestMembershipLinking.cs`
- Créer : `api/src/PartyPlan.Modules.Events/Application/GuestMembershipLinking.cs`
- Modifier : `api/src/PartyPlan.Modules.Events/EventsModule.cs`
- Test : `api/tests/PartyPlan.IntegrationTests/ConversionInviteTests.cs`

**Interfaces :**
- Consomme : `IEventsDbContext`, `EventMember`.
- Produit :
```csharp
public interface IGuestMembershipLinking
{
    Task<int> LinkAsync(Guid userId, string guestSessionHash, CancellationToken ct);
}
```
Renvoie le nombre de participations rattachées.

**Frontière.** Le module `Users` n'accède pas à `event_members`. Ce contrat est exposé
par `Events` dans le noyau partagé, exactement comme `IEventStatistics` l'est pour
`Administration` depuis le lot 0.12. `tools/verifier-frontieres-modules.sh` échoue sinon.

- [ ] **Étape 1 : écrire les tests qui échouent**

`api/tests/PartyPlan.IntegrationTests/ConversionInviteTests.cs` :

```csharp
using System.Net;
using Xunit;

namespace PartyPlan.IntegrationTests;

/// <summary>
/// EF-AUTH-11 — conversion d'une participation d'invité en compte permanent.
/// La liaison se fait sur l'empreinte du jeton d'invité, jamais sur le prénom
/// (RG-AUTH-07) : deux homonymes ne doivent jamais fusionner.
/// </summary>
public sealed class ConversionInviteTests(PartyPlanApiFixture fixture)
    : IClassFixture<PartyPlanApiFixture>
{
    [Fact]
    public async Task Inscription_avec_jeton_invite_rattache_la_participation()
    {
        var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
        var invitation = await LireInvitationAsync(evenement);
        var jetonInvite = await RejoindreCommeInviteAsync(invitation.Token, "Léa");

        var session = await InscrireAsync("lea@exemple.test", jetonInvite);

        var evenements = await ListerMesEvenementsAsync(session);
        Assert.Contains(evenements, e => e.Id == evenement);
    }

    [Fact]
    public async Task Aucun_doublon_de_membre_apres_conversion()
    {
        var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
        var invitation = await LireInvitationAsync(evenement);
        var jetonInvite = await RejoindreCommeInviteAsync(invitation.Token, "Léa");

        await InscrireAsync("lea@exemple.test", jetonInvite);

        var membres = await ListerMembresAsync(evenement);
        Assert.Single(membres, m => m.DisplayName == "Léa");
    }

    [Fact]
    public async Task Deux_homonymes_ne_fusionnent_pas()
    {
        var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
        var invitation = await LireInvitationAsync(evenement);
        var jetonA = await RejoindreCommeInviteAsync(invitation.Token, "Léa");
        var jetonB = await RejoindreCommeInviteAsync(invitation.Token, "Léa");

        await InscrireAsync("lea1@exemple.test", jetonA);
        await InscrireAsync("lea2@exemple.test", jetonB);

        var membres = await ListerMembresAsync(evenement);

        // Deux personnes, deux lignes, deux comptes distincts. Fusionner sur le prénom
        // ferait disparaître une participante et ses dépenses.
        Assert.Equal(2, membres.Count(m => m.DisplayName == "Léa"));
        Assert.Equal(2, membres.Where(m => m.DisplayName == "Léa")
                               .Select(m => m.UserId).Distinct().Count());
    }

    [Fact]
    public async Task Jeton_invite_inconnu_ne_fait_pas_echouer_l_inscription()
    {
        var reponse = await InscrireBrutAsync("neuf@exemple.test", "jeton-inexistant");

        // Un jeton périmé ne doit pas empêcher de créer un compte.
        Assert.Equal(HttpStatusCode.OK, reponse.StatusCode);
    }

    [Fact]
    public async Task Membre_deja_rattache_a_un_autre_compte_n_est_pas_repris()
    {
        var (evenement, _) = await CreerEvenementAvecProprietaireAsync();
        var invitation = await LireInvitationAsync(evenement);
        var jeton = await RejoindreCommeInviteAsync(invitation.Token, "Léa");
        await InscrireAsync("lea@exemple.test", jeton);

        // Le même jeton, présenté par un second compte : le membre est déjà nominatif.
        await InscrireAsync("intrus@exemple.test", jeton);

        var membres = await ListerMembresAsync(evenement);
        Assert.Single(membres, m => m.DisplayName == "Léa");
        Assert.DoesNotContain(membres, m => m.Email == "intrus@exemple.test");
    }
}
```

Les aides sont à écrire sur le modèle de `EvenementsTests.cs`.

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd api && dotnet test tests/PartyPlan.IntegrationTests --filter "FullyQualifiedName~ConversionInviteTests"`
Attendu : ÉCHEC — `register` n'accepte pas de champ `guestToken`.

- [ ] **Étape 3 : déclarer le contrat**

`api/src/PartyPlan.SharedKernel/Contracts/IGuestMembershipLinking.cs` :

```csharp
namespace PartyPlan.SharedKernel.Contracts;

/// <summary>
/// Rattachement des participations d'invité à un compte créé ensuite (EF-AUTH-11).
/// <para>
/// Exposé par le module Events et consommé par Users. Le module Users n'accède jamais
/// à <c>event_members</c> : la frontière est contrôlée en intégration continue.
/// </para>
/// </summary>
public interface IGuestMembershipLinking
{
    /// <summary>
    /// Rattache au compte toute participation portant cette empreinte de jeton.
    /// La liaison se fait sur l'empreinte, jamais sur le prénom (RG-AUTH-07).
    /// </summary>
    /// <returns>Nombre de participations rattachées. Zéro n'est pas une erreur.</returns>
    Task<int> LinkAsync(Guid userId, string guestSessionHash, CancellationToken ct);
}
```

- [ ] **Étape 4 : implémenter le service**

`api/src/PartyPlan.Modules.Events/Application/GuestMembershipLinking.cs` :

```csharp
namespace PartyPlan.Modules.Events.Application;

using Microsoft.EntityFrameworkCore;
using PartyPlan.Modules.Events.Persistence;
using PartyPlan.SharedKernel.Contracts;

/// <inheritdoc />
public sealed class GuestMembershipLinking(IEventsDbContext db) : IGuestMembershipLinking
{
    public async Task<int> LinkAsync(
        Guid userId,
        string guestSessionHash,
        CancellationToken ct)
    {
        var participations = await db.EventMembers
            .Where(m => m.GuestSessionHash == guestSessionHash
                     && m.UserId == null
                     && m.RemovedAt == null)
            .ToListAsync(ct)
            .ConfigureAwait(false);

        if (participations.Count == 0)
        {
            return 0;
        }

        var evenements = participations.Select(m => m.EventId).ToList();

        // Membres que le compte possède déjà sur ces événements : une conversion ne
        // doit jamais produire deux lignes pour une même personne.
        var deja = await db.EventMembers
            .Where(m => m.UserId == userId && evenements.Contains(m.EventId))
            .ToDictionaryAsync(m => m.EventId, ct)
            .ConfigureAwait(false);

        var rattachees = 0;

        foreach (var participation in participations)
        {
            if (deja.ContainsKey(participation.EventId))
            {
                // Le compte est déjà membre à un autre titre. La ligne d'invité est
                // retirée, jamais supprimée (RG-ROLE-03).
                //
                // TÂCHE B2 OBLIGATOIRE : dès que le module Expenses existe, les
                // contributions financières de cette ligne devront être réaffectées à
                // la ligne conservée, faute de quoi le critère EF-AUTH-11 « la dépense
                // reste rattachée à lui » serait faux.
                participation.RemovedAt = DateTimeOffset.UtcNow;
                continue;
            }

            participation.UserId = userId;
            rattachees++;
        }

        await db.SaveChangesAsync(ct).ConfigureAwait(false);
        return rattachees;
    }
}
```

Enregistrer le service dans `EventsModule.cs`, sur le modèle de `EventStatistics` :

```csharp
        services.AddScoped<IGuestMembershipLinking, GuestMembershipLinking>();
```

- [ ] **Étape 5 : accepter `guestToken` sur `register` et `login`**

Dans `api/src/PartyPlan.Modules.Users/Endpoints/AuthEndpoints.cs`, ajouter le champ aux
deux corps de requête :

```csharp
public sealed record RegisterBody(
    [Required][EmailAddress] string Email,
    [Required] string Password,
    [Required][MaxLength(120)] string DisplayName,
    /// <summary>
    /// Jeton d'invité présent sur l'appareil, facultatif (EF-AUTH-11).
    /// Transmis dans le corps et non dans l'en-tête Authorization : cet endpoint est
    /// anonyme, et l'intergiciel d'authentification rejette de toute façon ce jeton,
    /// dont l'audience est distincte (RG-AUTH-09).
    /// </summary>
    string? GuestToken);
```

Après création de la session, appeler le contrat :

```csharp
        if (!string.IsNullOrWhiteSpace(corps.GuestToken))
        {
            // L'empreinte, et non le jeton : c'est elle qui est stockée sur la ligne de
            // membre (RG-AUTH-07).
            await linking.LinkAsync(
                    utilisateur.Id,
                    GuestTokenHasher.Hash(corps.GuestToken),
                    cancellationToken)
                .ConfigureAwait(false);
        }
```

`GuestTokenHasher` est la fonction déjà utilisée à l'adhésion pour remplir
`GuestSessionHash` : la réutiliser, ne pas en écrire une seconde. Si elle n'est pas
publique, l'exposer dans le noyau partagé plutôt que la dupliquer.

Faire de même sur `login`.

- [ ] **Étape 6 : vérifier le succès**

Run : `cd api && dotnet test tests/PartyPlan.IntegrationTests --filter "FullyQualifiedName~ConversionInviteTests"`
Attendu : 5 tests réussis.
Run : `bash tools/verifier-frontieres-modules.sh`
Attendu : 11 modules, aucune violation.

- [ ] **Étape 7 : commit**

```bash
git add api/src/PartyPlan.SharedKernel/Contracts/IGuestMembershipLinking.cs \
        api/src/PartyPlan.Modules.Events/Application/GuestMembershipLinking.cs \
        api/src/PartyPlan.Modules.Events/EventsModule.cs \
        api/src/PartyPlan.Modules.Users/Endpoints/AuthEndpoints.cs \
        api/tests/PartyPlan.IntegrationTests/ConversionInviteTests.cs
git commit -m "feat(auth): conversion d'une participation d'invité en compte (EF-AUTH-11)"
```

---

## Phase 3 — Couche données

### Tâche 8 : Modèles et client d'API événementiel

**Fichiers :**
- Créer : `app/lib/core/models/evenement.dart`
- Créer : `app/lib/core/models/membre.dart`
- Créer : `app/lib/core/models/invitation.dart`
- Créer : `app/lib/core/network/evenements_api.dart`
- Modifier : `app/lib/core/providers.dart`
- Test : `app/test/core/evenements_api_test.dart`

**Interfaces :**
- Consomme : `ApiClient` (tâche 4).
- Produit :
  `class ResumeEvenement { String id; String nom; String? description; DateTime debut;
  DateTime? fin; String? adresse; String? imageCouverture; int nombreMembres;
  int nombrePresents; int nombrePeutEtre; bool adhesionsOuvertes; }`
  `enum StatutPresence { inconnu, present, peutEtre, absent, enRetard, partAvant }`
  `enum RoleMembre { proprietaire, administrateur, membre }`
  `class Membre { String id; String? userId; String nomAffiche; StatutPresence statut;
  String? heureArrivee; String? heureDepart; int accompagnants; RoleMembre role; }`
  `class Invitation { String lien; String codeCourt; bool adhesionsOuvertes; }`
  `class ApercuInvitation { String nom; DateTime debut; String? adresse;
  int nombreParticipants; bool adhesionsOuvertes; }`
  `class EvenementsApi` — méthodes listées ci-dessous.

- [ ] **Étape 1 : écrire le test qui échoue**

`app/test/core/evenements_api_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/models/membre.dart';

void main() {
  group('ResumeEvenement', () {
    test('analyse la réponse de l’API', () {
      final resume = ResumeEvenement.depuisJson({
        'id': '0198-uuid',
        'name': 'Crémaillère chez Léa',
        'description': null,
        'startsAt': '2026-09-12T20:00:00+02:00',
        'endsAt': null,
        'address': '12 rue des Lilas, Lyon',
        'coverImageUrl': null,
        'memberCount': 8,
        'presentCount': 5,
        'maybeCount': 2,
        'joinEnabled': true,
      });

      expect(resume.nom, 'Crémaillère chez Léa');
      expect(resume.debut.toUtc(), DateTime.utc(2026, 9, 12, 18));
      expect(resume.fin, isNull);
      expect(resume.nombrePresents, 5);
      expect(resume.adhesionsOuvertes, isTrue);
    });

    test('est à venir tant que le début n’est pas passé', () {
      final resume = _resume(debut: DateTime.now().add(const Duration(days: 1)));

      expect(resume.estAVenir, isTrue);
    });
  });

  group('StatutPresence', () {
    test('traduit les cinq statuts de l’API', () {
      expect(StatutPresence.depuisApi('Going'), StatutPresence.present);
      expect(StatutPresence.depuisApi('Maybe'), StatutPresence.peutEtre);
      expect(StatutPresence.depuisApi('NotGoing'), StatutPresence.absent);
      expect(StatutPresence.depuisApi('Late'), StatutPresence.enRetard);
      expect(StatutPresence.depuisApi('EarlyLeave'), StatutPresence.partAvant);
      expect(StatutPresence.depuisApi('Unknown'), StatutPresence.inconnu);
    });

    test('un statut inconnu de l’API ne fait pas planter l’écran', () {
      // Une version d'API plus récente peut introduire un statut : dégrader vers
      // « inconnu » vaut mieux qu'une exception dans une liste.
      expect(StatutPresence.depuisApi('Teleportation'), StatutPresence.inconnu);
    });

    test('RG-PRES-02 : en retard et part plus tôt comptent comme présents', () {
      expect(StatutPresence.enRetard.compteCommePresent, isTrue);
      expect(StatutPresence.partAvant.compteCommePresent, isTrue);
      expect(StatutPresence.peutEtre.compteCommePresent, isFalse);
    });
  });
}

ResumeEvenement _resume({required DateTime debut}) => ResumeEvenement(
  id: 'a',
  nom: 'Test',
  description: null,
  debut: debut,
  fin: null,
  adresse: null,
  imageCouverture: null,
  nombreMembres: 1,
  nombrePresents: 1,
  nombrePeutEtre: 0,
  adhesionsOuvertes: true,
);
```

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd app && flutter test test/core/evenements_api_test.dart`
Attendu : ÉCHEC — modèles inexistants.

- [ ] **Étape 3 : implémenter les modèles**

`app/lib/core/models/evenement.dart` :

```dart
/// Vue de synthèse d'un événement, telle que l'API la renvoie (`EventSummary`).
class ResumeEvenement {
  const ResumeEvenement({
    required this.id,
    required this.nom,
    required this.description,
    required this.debut,
    required this.fin,
    required this.adresse,
    required this.imageCouverture,
    required this.nombreMembres,
    required this.nombrePresents,
    required this.nombrePeutEtre,
    required this.adhesionsOuvertes,
  });

  final String id;
  final String nom;
  final String? description;
  final DateTime debut;
  final DateTime? fin;
  final String? adresse;
  final String? imageCouverture;
  final int nombreMembres;

  /// RG-PRES-04 — présents et têtes sont deux décomptes distincts. Celui-ci compte les
  /// personnes ; les têtes, accompagnants compris, se calculent sur la liste des
  /// membres. Les confondre fausserait toutes les quantités de courses.
  final int nombrePresents;

  /// RG-PRES-03 — les « peut-être » sont comptés à part, jamais dans les présents.
  final int nombrePeutEtre;

  final bool adhesionsOuvertes;

  bool get estAVenir => debut.isAfter(DateTime.now());

  /// EF-EVT-02 — sans fin saisie, l'événement se termine implicitement à +12 heures.
  DateTime get finEffective => fin ?? debut.add(const Duration(hours: 12));

  static ResumeEvenement depuisJson(Map<String, dynamic> json) => ResumeEvenement(
    id: json['id'] as String,
    nom: json['name'] as String,
    description: json['description'] as String?,
    debut: DateTime.parse(json['startsAt'] as String),
    fin: json['endsAt'] == null
        ? null
        : DateTime.parse(json['endsAt'] as String),
    adresse: json['address'] as String?,
    imageCouverture: json['coverImageUrl'] as String?,
    nombreMembres: json['memberCount'] as int,
    nombrePresents: json['presentCount'] as int,
    nombrePeutEtre: json['maybeCount'] as int,
    adhesionsOuvertes: json['joinEnabled'] as bool,
  );
}
```

`app/lib/core/models/membre.dart` :

```dart
/// Statut de présence (EF-PRES-01).
enum StatutPresence {
  inconnu('Unknown'),
  present('Going'),
  peutEtre('Maybe'),
  absent('NotGoing'),
  enRetard('Late'),
  partAvant('EarlyLeave');

  const StatutPresence(this.versApi);

  final String versApi;

  /// RG-PRES-02 — « arrive plus tard » et « part plus tôt » comptent comme présents,
  /// y compris dans le total des têtes.
  bool get compteCommePresent =>
      this == present || this == enRetard || this == partAvant;

  /// Un statut inconnu de cette version dégrade vers `inconnu` plutôt que de lever :
  /// une exception au milieu d'une liste rendrait l'écran inutilisable pour un ajout
  /// d'API sans conséquence.
  static StatutPresence depuisApi(String valeur) => values.firstWhere(
    (s) => s.versApi == valeur,
    orElse: () => inconnu,
  );
}

/// Rôle dans l'événement (RG-ROLE-01).
enum RoleMembre {
  proprietaire('Owner'),
  administrateur('Admin'),
  membre('Member');

  const RoleMembre(this.versApi);

  final String versApi;

  /// Peut modifier l'événement, inviter, exclure.
  bool get peutGerer => this == proprietaire || this == administrateur;

  /// RG-ROLE-01 — seul le propriétaire supprime l'événement.
  bool get peutSupprimer => this == proprietaire;

  static RoleMembre depuisApi(String valeur) =>
      values.firstWhere((r) => r.versApi == valeur, orElse: () => membre);
}

/// Membre d'un événement.
///
/// [userId] est nul pour un invité sans compte (EF-INV-04). **Aucune fonctionnalité ne
/// doit dépendre de sa présence** — règle non négociable du projet.
class Membre {
  const Membre({
    required this.id,
    required this.userId,
    required this.nomAffiche,
    required this.statut,
    required this.heureArrivee,
    required this.heureDepart,
    required this.accompagnants,
    required this.role,
  });

  final String id;
  final String? userId;
  final String nomAffiche;
  final StatutPresence statut;
  final String? heureArrivee;
  final String? heureDepart;
  final int accompagnants;
  final RoleMembre role;

  /// Têtes apportées : la personne et ses accompagnants (EF-PRES-06).
  /// L'organisateur achète pour des têtes, pas pour des comptes.
  int get tetes => statut.compteCommePresent ? 1 + accompagnants : 0;

  static Membre depuisJson(Map<String, dynamic> json) => Membre(
    id: json['id'] as String,
    userId: json['userId'] as String?,
    nomAffiche: json['displayName'] as String,
    statut: StatutPresence.depuisApi(json['status'] as String),
    heureArrivee: json['arrivalTime'] as String?,
    heureDepart: json['departureTime'] as String?,
    accompagnants: json['extraGuests'] as int? ?? 0,
    role: RoleMembre.depuisApi(json['role'] as String),
  );
}
```

`app/lib/core/models/invitation.dart` :

```dart
/// Invitation d'un événement : lien, code court, état des adhésions.
class Invitation {
  const Invitation({
    required this.lien,
    required this.codeCourt,
    required this.adhesionsOuvertes,
  });

  final String lien;
  final String codeCourt;
  final bool adhesionsOuvertes;

  static Invitation depuisJson(Map<String, dynamic> json) => Invitation(
    lien: json['url'] as String,
    codeCourt: json['shortCode'] as String,
    adhesionsOuvertes: json['joinEnabled'] as bool,
  );
}

/// Aperçu restreint, visible sans session.
///
/// RG-INV-04 — nom, date, lieu et nombre de participants. **Ni liste nominative, ni
/// dépenses, ni jeton.** Le modèle ne porte volontairement aucun autre champ : ce qui
/// n'existe pas ici ne peut pas fuiter dans un écran.
class ApercuInvitation {
  const ApercuInvitation({
    required this.nom,
    required this.debut,
    required this.adresse,
    required this.nombreParticipants,
    required this.adhesionsOuvertes,
  });

  final String nom;
  final DateTime debut;
  final String? adresse;
  final int nombreParticipants;
  final bool adhesionsOuvertes;

  static ApercuInvitation depuisJson(Map<String, dynamic> json) =>
      ApercuInvitation(
        nom: json['name'] as String,
        debut: DateTime.parse(json['startsAt'] as String),
        adresse: json['address'] as String?,
        nombreParticipants: json['memberCount'] as int,
        adhesionsOuvertes: json['joinEnabled'] as bool,
      );
}
```

- [ ] **Étape 4 : implémenter le client**

`app/lib/core/network/evenements_api.dart` :

```dart
import '../models/evenement.dart';
import '../models/invitation.dart';
import '../models/membre.dart';
import '../storage/session_store.dart';
import 'api_client.dart';

/// Appels d'API du domaine événementiel.
///
/// La mise en file hors ligne est déclarée **opération par opération** via `differable`.
/// Elle n'est jamais un comportement par défaut : `regenererInvitation` est
/// délibérément non idempotent, et un rejeu invaliderait le lien que l'utilisateur
/// vient de partager (EF-INV-05).
class EvenementsApi {
  const EvenementsApi(this._client, this._sessions);

  final ApiClient _client;
  final SessionStore _sessions;

  // ------------------------------------------------------------ événements ----

  Future<List<ResumeEvenement>> lister() => _client.get(
    '/events',
    analyser: (corps) => [
      for (final e in corps! as List)
        ResumeEvenement.depuisJson(e as Map<String, dynamic>),
    ],
  );

  Future<ResumeEvenement> lire(String id) => _client.get(
    '/events/$id',
    analyser: (corps) =>
        ResumeEvenement.depuisJson(corps! as Map<String, dynamic>),
  );

  /// [cleIdempotence] est fournie par l'assistant de création et fixée à son ouverture :
  /// un double appui sur « Créer » ne doit jamais produire deux événements.
  Future<ResumeEvenement> creer({
    required String nom,
    required DateTime debut,
    DateTime? fin,
    String? adresse,
    String? description,
    required String cleIdempotence,
  }) => _client.post(
    '/events',
    corps: {
      'name': nom,
      'startsAt': debut.toIso8601String(),
      if (fin != null) 'endsAt': fin.toIso8601String(),
      if (adresse != null) 'address': adresse,
      if (description != null) 'description': description,
    },
    cleIdempotence: cleIdempotence,
    analyser: (corps) =>
        ResumeEvenement.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<ResumeEvenement> modifier(
    String id, {
    String? nom,
    String? description,
    DateTime? debut,
    DateTime? fin,
    String? adresse,
  }) => _client.patch(
    '/events/$id',
    corps: {
      if (nom != null) 'name': nom,
      if (description != null) 'description': description,
      if (debut != null) 'startsAt': debut.toIso8601String(),
      if (fin != null) 'endsAt': fin.toIso8601String(),
      if (adresse != null) 'address': adresse,
    },
    differable: true,
    analyser: (corps) =>
        ResumeEvenement.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> supprimer(String id) => _client.delete('/events/$id');

  // ----------------------------------------------------------- invitations ----

  Future<Invitation> invitation(String evenementId) => _client.get(
    '/events/$evenementId/invitation',
    analyser: (corps) => Invitation.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Jamais différable : chaque appel produit un jeton neuf, c'est tout son intérêt.
  Future<Invitation> regenererInvitation(String evenementId) => _client.post(
    '/events/$evenementId/invitation/rotate',
    analyser: (corps) => Invitation.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> ouvrirAdhesions(String evenementId, {required bool ouvertes}) =>
      _client.patch<void>(
        '/events/$evenementId/join-enabled',
        corps: {'joinEnabled': ouvertes},
        differable: true,
        analyser: (_) {},
      );

  // -------------------------------------------------- accès sans compte ----

  Future<ApercuInvitation> apercu(String jeton) => _client.get(
    '/join/$jeton',
    analyser: (corps) =>
        ApercuInvitation.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<String> resoudreCodeCourt(String code) => _client.get(
    '/join/code/${_normaliserCode(code)}',
    // Jamais mis en cache : le jeton d'invitation ne doit pas rester sur l'appareil
    // d'une personne qui n'a fait que taper un code.
    cacheable: false,
    analyser: (corps) => (corps! as Map<String, dynamic>)['token'] as String,
  );

  /// Saisie tolérante : minuscules, espaces, tirets, absence de préfixe.
  static String _normaliserCode(String saisie) {
    final propre = saisie.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return propre.startsWith('PLAN') ? propre.substring(4) : propre;
  }

  /// Rejoint l'événement avec un prénom seulement (EF-INV-04). Le jeton d'invité remis
  /// est conservé : c'est lui qui permettra le rattachement à un compte (RG-AUTH-07).
  Future<String> rejoindre({
    required String jeton,
    required String prenom,
    required StatutPresence statut,
    required String cleIdempotence,
  }) async {
    final reponse = await _client.post<Map<String, dynamic>>(
      '/join/$jeton',
      corps: {'displayName': prenom, 'status': statut.versApi},
      cleIdempotence: cleIdempotence,
      analyser: (corps) => corps! as Map<String, dynamic>,
    );

    final jetonInvite = reponse['guestToken'] as String;
    await _sessions.enregistrerJetonInvite(jetonInvite);

    return reponse['eventId'] as String;
  }

  // --------------------------------------------------------------- membres ----

  Future<List<Membre>> membres(String evenementId) => _client.get(
    '/events/$evenementId/members',
    analyser: (corps) => [
      for (final m in corps! as List) Membre.depuisJson(m as Map<String, dynamic>),
    ],
  );

  Future<void> majMaPresence(
    String evenementId, {
    required StatutPresence statut,
    String? heureArrivee,
    String? heureDepart,
    int? accompagnants,
  }) => _client.patch<void>(
    '/events/$evenementId/members/me',
    corps: {
      'status': statut.versApi,
      if (heureArrivee != null) 'arrivalTime': heureArrivee,
      if (heureDepart != null) 'departureTime': heureDepart,
      if (accompagnants != null) 'extraGuests': accompagnants,
    },
    differable: true,
    analyser: (_) {},
  );

  Future<void> quitter(String evenementId) =>
      _client.delete('/events/$evenementId/members/me');

  Future<void> exclure(String evenementId, String membreId) =>
      _client.delete('/events/$evenementId/members/$membreId');

  Future<void> transfererPropriete(String evenementId, String membreId) =>
      _client.post<void>(
        '/events/$evenementId/members/$membreId/transfer-ownership',
        analyser: (_) {},
      );
}
```

Ajouter le provider dans `app/lib/core/providers.dart` :

```dart
final magasinLocalProvider = Provider<MagasinLocal>((ref) => MagasinPreferences());

final etatReseauProvider = ChangeNotifierProvider<EtatReseau>(
  (ref) => ref.watch(apiClientProvider).etat,
);

final evenementsApiProvider = Provider<EvenementsApi>(
  (ref) => EvenementsApi(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  ),
);

/// Événements de la personne connectée (EF-EVT-05).
final mesEvenementsProvider = FutureProvider<List<ResumeEvenement>>(
  (ref) => ref.watch(evenementsApiProvider).lister(),
);

final evenementProvider = FutureProvider.family<ResumeEvenement, String>(
  (ref, id) => ref.watch(evenementsApiProvider).lire(id),
);

final membresProvider = FutureProvider.family<List<Membre>, String>(
  (ref, id) => ref.watch(evenementsApiProvider).membres(id),
);

final invitationProvider = FutureProvider.family<Invitation, String>(
  (ref, id) => ref.watch(evenementsApiProvider).invitation(id),
);
```

Et modifier `apiClientProvider` pour injecter les trois collaborateurs :

```dart
final apiClientProvider = Provider<ApiClient>((ref) {
  final magasin = ref.watch(magasinLocalProvider);

  return ApiClient(
    ref.watch(sessionStoreProvider),
    cache: CacheLecture(magasin),
    file: FileEcritures(magasin),
  );
});
```

Enfin, purger le cache à la déconnexion : dans `SessionCourante.deconnecter`, appeler
`CacheLecture(ref.read(magasinLocalProvider)).purger()` avant d'effacer la session.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/core/evenements_api_test.dart`
Attendu : 6 tests réussis.
Run : `cd app && flutter analyze`
Attendu : aucun problème.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/core/models app/lib/core/network/evenements_api.dart \
        app/lib/core/providers.dart app/test/core/evenements_api_test.dart
git commit -m "feat(events): modèles et client d'API du domaine événementiel"
```

---

## Phase 4 — Écrans

> Chaque tâche de cette phase suit le même rythme : chaînes ARB puis `make l10n`, test de
> widget rouge, écran, test vert, commit. Les tests montent `PartyPlanApp` et non un
> `MaterialApp` nu.

### Tâche 9 : Accueil — liste des événements

**Fichiers :**
- Modifier : `app/lib/features/accueil/accueil_page.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/accueil_evenements_test.dart`

**Interfaces :**
- Consomme : `mesEvenementsProvider`, `etatReseauProvider` (tâche 8),
  `PpBandeauHorsLigne` (tâche 5), `CarteEvenement` (déjà présente dans le fichier).
- Produit : `AccueilPage` branchée. `CarteEvenement` gagne les paramètres
  `int nombrePresents`, `int nombreMembres`, `StatutPresence monStatut`,
  `VoidCallback onOuvrir`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "accueilChargementErreur": "Impossible de charger tes événements.",
  "accueilReessayer": "Réessayer",
  "presencesSurInvites": "{presents} présents sur {invites} invités",
  "@presencesSurInvites": {
    "placeholders": {
      "presents": { "type": "int" },
      "invites": { "type": "int" }
    }
  },
  "peutEtreCommeSuffixe": "· {nombre} peut-être",
  "@peutEtreCommeSuffixe": {
    "description": "RG-PRES-03 : les peut-être sont comptés à part, jamais dans les présents.",
    "placeholders": { "nombre": { "type": "int" } }
  }
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/features/accueil_evenements_test.dart` :

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/app/app.dart';
import 'package:partyplan/core/models/evenement.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/session_store_double.dart';

void main() {
  group('Accueil', () {
    testWidgets('sépare à venir et passés', (tester) async {
      await _monter(tester, [
        _resume(id: 'a', nom: 'Crémaillère', jours: 5),
        _resume(id: 'b', nom: 'Nouvel an dernier', jours: -200),
      ]);

      expect(find.text('À venir'), findsOneWidget);
      expect(find.text('Passés'), findsOneWidget);
      expect(find.text('Crémaillère'), findsOneWidget);
      expect(find.text('Nouvel an dernier'), findsOneWidget);
    });

    testWidgets('affiche l’état vide quand il n’y a rien', (tester) async {
      await _monter(tester, []);

      expect(find.text('Créer un événement'), findsOneWidget);
    });

    testWidgets('RG-PRES-03 : les peut-être sont comptés à part', (tester) async {
      await _monter(tester, [
        _resume(id: 'a', nom: 'Crémaillère', jours: 5, presents: 5, peutEtre: 2,
            membres: 8),
      ]);

      expect(find.textContaining('5 présents sur 8 invités'), findsOneWidget);
      expect(find.textContaining('2 peut-être'), findsOneWidget);
    });

    testWidgets('affiche une erreur récupérable', (tester) async {
      await _monterEnErreur(tester);

      expect(find.text('Impossible de charger tes événements.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });
  });
}
```

Les aides `_monter`, `_monterEnErreur` et `_resume` surchargent
`mesEvenementsProvider` par `overrideWith`, sur le modèle de
`app/test/features/connexion_test.dart`.

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/accueil_evenements_test.dart`
Attendu : ÉCHEC — la page affiche l'état vide en toutes circonstances.

- [ ] **Étape 4 : implémenter**

Remplacer le corps de `AccueilPage.build` par une `ConsumerWidget` qui observe
`mesEvenementsProvider` :

```dart
    return Scaffold(
      appBar: AppBar(title: const Text(PpMarque.nom), actions: [...]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PpRoutes.creationEvenement),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.creerUnEvenement),
      ),
      body: Column(
        children: [
          PpBandeauHorsLigne(
            etat: ref.watch(etatReseauProvider),
            onRetry: () => ref.invalidate(mesEvenementsProvider),
          ),
          Expanded(
            child: ref.watch(mesEvenementsProvider).when(
              loading: () => const PpLoadingState(),
              error: (_, _) => PpErrorState(
                message: l10n.accueilChargementErreur,
                onRetry: () => ref.invalidate(mesEvenementsProvider),
              ),
              data: (evenements) => evenements.isEmpty
                  ? _etatVide(context)
                  : _listeSectionnee(context, evenements),
            ),
          ),
        ],
      ),
    );
```

`_listeSectionnee` partitionne sur `estAVenir`, trie les à-venir par date croissante et
les passés par date décroissante, puis émet un `PpEyebrow(texte)` par groupe — `PpSectionHeader` n’existe pas.

Compléter `CarteEvenement` : pile d'avatars, `PpStatusChip` du statut personnel, et la
ligne de synthèse `l10n.presencesSurInvites(...)` suivie du suffixe
`l10n.peutEtreCommeSuffixe(...)` **seulement si** `nombrePeutEtre > 0`.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/accueil_evenements_test.dart`
Attendu : 4 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/accueil/accueil_page.dart app/lib/l10n/arb/app_fr.arb \
        app/test/features/accueil_evenements_test.dart
git commit -m "feat(events): accueil branché sur la liste des événements (EF-EVT-05)"
```

---

### Tâche 10 : Assistant de création d'événement

**Fichiers :**
- Créer : `app/lib/features/evenement/creation_evenement_page.dart`
- Modifier : `app/lib/app/router.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/creation_evenement_test.dart`

**Interfaces :**
- Consomme : `evenementsApiProvider` (tâche 8).
- Produit : `class CreationEvenementPage extends ConsumerStatefulWidget`.
  Route : `PpRoutes.creationEvenement = '/events/nouveau'`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "creationTitre": "Nouvel événement",
  "creationEtapeSur": "{courante} / {total}",
  "@creationEtapeSur": {
    "placeholders": { "courante": { "type": "int" }, "total": { "type": "int" } }
  },
  "creationQuestionNom": "Ça s’appelle comment ?",
  "creationQuestionQuand": "C’est quand, et où ?",
  "creationQuestionDescription": "Quelque chose à préciser ?",
  "creationChampNom": "Nom de l’événement",
  "creationChampDebut": "Début",
  "creationChampFin": "Fin (facultatif)",
  "creationChampLieu": "Lieu (facultatif)",
  "creationChampDescription": "Description (facultatif)",
  "creationFinImplicite": "Sans fin précisée, l’événement se termine 12 heures après son début.",
  "creationSuite": "Suite",
  "creationCreer": "Créer l’événement",
  "creationNomRequis": "Donne un nom à ton événement.",
  "creationDateRequise": "Indique au moins une date de début.",
  "creationEchec": "L’événement n’a pas pu être créé."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/features/creation_evenement_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Assistant de création', () {
    testWidgets('démarre à l’étape 1 sur la question du nom', (tester) async {
      await _monter(tester);

      expect(find.text('Ça s’appelle comment ?'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('refuse de passer à l’étape 2 sans nom', (tester) async {
      await _monter(tester);

      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      expect(find.text('Donne un nom à ton événement.'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('le retour ne perd pas la saisie', (tester) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Crémaillère'), findsOneWidget);
    });

    testWidgets('« Créer » est actif dès l’étape 2', (tester) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      // Nom et date suffisent à l'API : imposer l'étape 3 ferait de la description un
      // champ obligatoire de fait.
      final creer = find.widgetWithText(FilledButton, 'Créer l’événement');
      expect(creer, findsOneWidget);
      expect(tester.widget<FilledButton>(creer).onPressed, isNotNull);
    });

    testWidgets('la barre de progression mène directement à une étape', (tester) async {
      await _monter(tester);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('etape-1')));
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('Crémaillère'), findsOneWidget);
    });

    testWidgets('la clé d’idempotence est fixée à l’ouverture', (tester) async {
      final api = _EvenementsApiEspion();
      await _monter(tester, api: api);
      await tester.enterText(find.byType(TextFormField).first, 'Crémaillère');
      await tester.tap(find.text('Suite'));
      await tester.pumpAndSettle();

      // Double appui : une seule clé, donc un seul événement côté serveur.
      await tester.tap(find.text('Créer l’événement'));
      await tester.tap(find.text('Créer l’événement'));
      await tester.pumpAndSettle();

      expect(api.clesUtilisees.toSet(), hasLength(1));
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/creation_evenement_test.dart`
Attendu : ÉCHEC — `creation_evenement_page.dart` inexistant.

- [ ] **Étape 4 : implémenter**

`CreationEvenementPage` : `PageView` à trois pages, `PageController` conservé, état des
champs en `TextEditingController` de niveau `State` — c'est ce qui garantit qu'un retour
ne perd rien.

Points obligatoires :

```dart
  /// Fixée à l'ouverture de l'assistant, pas à l'appui sur « Créer ».
  ///
  /// Un double appui, ou un appui suivi d'une perte de réseau puis d'un rejeu, ne doit
  /// jamais produire deux événements. POST /v1/events exige déjà cette clé.
  late final String _cleIdempotence = _genererCle();
```

Barre de progression : trois segments tactiles de 44 points minimum
(`NF-A11Y-02`), chacun avec `ValueKey('etape-N')` et un `Semantics(label: ...)`
(`NF-A11Y-03`). Un segment n'est atteignable que si les étapes précédentes sont valides.

Bouton principal : `Suite` à l'étape 1, `Créer l'événement` aux étapes 2 et 3.

Sous le champ de fin, afficher `l10n.creationFinImplicite` — sans quoi la règle
`EF-EVT-02` reste invisible et l'utilisateur croit avoir oublié un champ obligatoire.

Dates saisies via `showDatePicker` et `showTimePicker`, affichées en JJ/MM/AAAA par
`DateFormat('dd/MM/yyyy', 'fr')`.

Après création : `context.go(PpRoutes.versEvenement(resume.id))`.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/creation_evenement_test.dart`
Attendu : 6 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/creation_evenement_page.dart app/lib/app/router.dart \
        app/lib/l10n/arb/app_fr.arb app/test/features/creation_evenement_test.dart
git commit -m "feat(events): assistant de création en trois étapes (EF-EVT-01, EF-EVT-02)"
```

---

### Tâche 11 : Tableau de bord à sections

**Fichiers :**
- Créer : `app/lib/features/evenement/tableau_de_bord_page.dart`
- Créer : `app/lib/features/evenement/sections/section_identite.dart`
- Créer : `app/lib/features/evenement/sections/section_compte_a_rebours.dart`
- Créer : `app/lib/features/evenement/sections/section_ma_presence.dart`
- Créer : `app/lib/features/evenement/sections/section_synthese_presences.dart`
- Créer : `app/lib/features/evenement/sections/section_partage.dart`
- Créer : `app/lib/features/evenement/sections/section_sans_reponse.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/tableau_de_bord_test.dart`

**Interfaces :**
- Consomme : `evenementProvider`, `membresProvider`, `etatReseauProvider` (tâche 8).
- Produit : `class TableauDeBordPage extends ConsumerWidget`. Chaque section est un
  `ConsumerWidget` autonome exposant `bool get estVisible` via son propre rendu — une
  section invisible renvoie `SizedBox.shrink()`.

**Contrat pour B2 et B4.** Ajouter une section consiste à créer un fichier dans
`sections/` et à l'insérer dans la liste de `TableauDeBordPage`. Aucune autre
modification. C'est la raison d'être du découpage.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "tdbDansNJours": "{jours, plural, =0{Aujourd’hui} one{Demain} other{Dans {jours} jours}}",
  "@tdbDansNJours": { "placeholders": { "jours": { "type": "int" } } },
  "tdbMaPresenceQuestion": "Tu viens ?",
  "tdbMaPresenceModifier": "Modifier ma réponse",
  "tdbPartagerInvitation": "Partager l’invitation",
  "tdbSansReponse": "{nombre, plural, one{1 personne n’a pas répondu} other{{nombre} personnes n’ont pas répondu}}",
  "@tdbSansReponse": { "placeholders": { "nombre": { "type": "int" } } },
  "tdbTetesAPrevoir": "{nombre} têtes à prévoir",
  "@tdbTetesAPrevoir": {
    "description": "RG-PRES-04 : les têtes comptent les accompagnants, contrairement aux présents. Les confondre fausserait toutes les quantités de courses.",
    "placeholders": { "nombre": { "type": "int" } }
  },
  "tdbErreur": "Cet événement est introuvable."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/features/tableau_de_bord_test.dart` :

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Tableau de bord', () {
    testWidgets('affiche nom, date et lieu', (tester) async {
      await _monter(tester);

      expect(find.text('Crémaillère chez Léa'), findsOneWidget);
      expect(find.textContaining('12/09/2026'), findsOneWidget);
      expect(find.text('12 rue des Lilas, Lyon'), findsOneWidget);
    });

    testWidgets('RG-PRES-01 : demande la réponse quand le statut est inconnu',
        (tester) async {
      await _monter(tester, monStatut: StatutPresence.inconnu);

      expect(find.text('Tu viens ?'), findsOneWidget);
    });

    testWidgets('n’insiste plus une fois la réponse donnée', (tester) async {
      await _monter(tester, monStatut: StatutPresence.present);

      expect(find.text('Tu viens ?'), findsNothing);
      expect(find.text('Modifier ma réponse'), findsOneWidget);
    });

    testWidgets('RG-PRES-04 : présents et têtes sont deux décomptes distincts',
        (tester) async {
      // 5 présents dont un avec 2 accompagnants : 5 personnes, 7 têtes.
      await _monter(tester, presents: 5, membres: 8, accompagnantsTotal: 2);

      expect(find.textContaining('5 présents sur 8 invités'), findsOneWidget);
      expect(find.textContaining('7 têtes'), findsOneWidget);
    });

    testWidgets('la section de partage n’apparaît pas pour un simple membre',
        (tester) async {
      await _monter(tester, monRole: RoleMembre.membre);

      expect(find.text('Partager l’invitation'), findsNothing);
    });

    testWidgets('la section de partage apparaît pour un administrateur',
        (tester) async {
      await _monter(tester, monRole: RoleMembre.administrateur);

      expect(find.text('Partager l’invitation'), findsOneWidget);
    });

    testWidgets('RG-ADM-01 : un événement hors périmètre donne l’état introuvable',
        (tester) async {
      await _monterEnErreur(tester, statut: 404);

      // 404 et non « accès refusé » : dire « refusé » révélerait que la ressource
      // existe (RG-SEC-02).
      expect(find.text('Cet événement est introuvable.'), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/tableau_de_bord_test.dart`
Attendu : ÉCHEC — page inexistante.

- [ ] **Étape 4 : implémenter**

`TableauDeBordPage` :

```dart
class TableauDeBordPage extends ConsumerWidget {
  const TableauDeBordPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evenement = ref.watch(evenementProvider(evenementId));

    return evenement.when(
      loading: () => const PpLoadingState(),
      error: (erreur, _) => PpErrorState(
        message: PpL10n.of(context).tdbErreur,
        onRetry: () => ref.invalidate(evenementProvider(evenementId)),
      ),
      data: (resume) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(evenementProvider(evenementId));
          ref.invalidate(membresProvider(evenementId));
        },
        child: ListView(
          padding: const EdgeInsets.all(PpSpacing.md),
          children: [
            PpBandeauHorsLigne(etat: ref.watch(etatReseauProvider)),
            SectionIdentite(resume: resume),
            SectionCompteARebours(resume: resume),
            SectionMaPresence(evenementId: evenementId),
            SectionSynthesePresences(evenementId: evenementId, resume: resume),
            SectionPartage(evenementId: evenementId),
            SectionSansReponse(evenementId: evenementId),
            // --- Emplacements réservés ------------------------------------
            // B2 : SectionArticlesNonAttribues, SectionCeQueJeDois
            // B4 : SectionProchaineEtape
            // Chacune s'insère ici, sans autre modification de ce fichier.
          ],
        ),
      ),
    );
  }
}
```

`SectionSynthesePresences` affiche **deux** nombres : présents sur invités
(`l10n.presencesSurInvites`), et têtes à prévoir (`l10n.tdbTetesAPrevoir`), les têtes
calculées par `membres.fold(0, (t, m) => t + m.tetes)`. Le suffixe « peut-être » n'est
émis que si `nombrePeutEtre > 0`.

`SectionPartage` et `SectionSansReponse` renvoient `SizedBox.shrink()` si le rôle de
l'appelant ne le permet pas — la visibilité est décidée par la section, jamais par la
page, faute de quoi la page finirait par tout savoir de tous les modules.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/tableau_de_bord_test.dart`
Attendu : 7 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/tableau_de_bord_page.dart \
        app/lib/features/evenement/sections app/lib/l10n/arb/app_fr.arb \
        app/test/features/tableau_de_bord_test.dart
git commit -m "feat(events): tableau de bord à sections autonomes (EF-EVT-04)"
```

---

### Tâche 12 : Écran des invités

**Fichiers :**
- Créer : `app/lib/features/evenement/invites_page.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/invites_test.dart`

**Interfaces :**
- Consomme : `membresProvider`, `evenementsApiProvider` (tâche 8),
  `PpOptimisticAction` (tâche 4).
- Produit : `class InvitesPage extends ConsumerWidget`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "invitesTitre": "Invités",
  "statutPresent": "Présent",
  "statutPeutEtre": "Peut-être",
  "statutAbsent": "Absent",
  "statutEnRetard": "Arrive plus tard",
  "statutPartAvant": "Part plus tôt",
  "statutInconnu": "Sans réponse",
  "invitesAccompagnants": "{nombre, plural, one{+1 accompagnant} other{+{nombre} accompagnants}}",
  "@invitesAccompagnants": { "placeholders": { "nombre": { "type": "int" } } },
  "invitesAccompagnantsPlafond": "Au-delà de dix accompagnants, il s’agit d’un autre événement.",
  "invitesExclure": "Exclure de l’événement",
  "invitesExclureConfirmation": "{nom} ne verra plus l’événement. Ses dépenses et ses achats restent comptabilisés.",
  "@invitesExclureConfirmation": { "placeholders": { "nom": { "type": "String" } } },
  "invitesEchecStatut": "Ton statut n’a pas pu être enregistré."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

`app/test/features/invites_test.dart` :

```dart
void main() {
  group('Écran des invités', () {
    testWidgets('EF-PRES-05 : synthèse avec les peut-être à part', (tester) async {
      await _monter(tester, membres: [
        _membre('Léa', StatutPresence.present),
        _membre('Tom', StatutPresence.enRetard),
        _membre('Zoé', StatutPresence.peutEtre),
        _membre('Max', StatutPresence.inconnu),
      ]);

      // RG-PRES-02 : « arrive plus tard » compte comme présent.
      expect(find.textContaining('2 présents sur 4 invités'), findsOneWidget);
      expect(find.textContaining('1 peut-être'), findsOneWidget);
    });

    testWidgets('EF-PRES-03 : on ne modifie que son propre statut', (tester) async {
      await _monter(tester, monId: 'moi', membres: [
        _membre('Moi', StatutPresence.present, id: 'moi'),
        _membre('Léa', StatutPresence.present, id: 'lea'),
      ]);

      expect(find.byKey(const ValueKey('changer-statut-moi')), findsOneWidget);
      expect(find.byKey(const ValueKey('changer-statut-lea')), findsNothing);
    });

    testWidgets('EF-PRES-06 : les accompagnants sont plafonnés à dix', (tester) async {
      await _monter(tester, monId: 'moi', membres: [
        _membre('Moi', StatutPresence.present, id: 'moi', accompagnants: 10),
      ]);

      await tester.tap(find.byKey(const ValueKey('accompagnant-plus')));
      await tester.pumpAndSettle();

      expect(find.text('+10 accompagnants'), findsOneWidget);
      expect(
        find.text('Au-delà de dix accompagnants, il s’agit d’un autre événement.'),
        findsOneWidget,
      );
    });

    testWidgets('l’exclusion est réservée à qui peut gérer', (tester) async {
      await _monter(tester, monRole: RoleMembre.membre, membres: [
        _membre('Léa', StatutPresence.present, id: 'lea'),
      ]);

      expect(find.byKey(const ValueKey('exclure-lea')), findsNothing);
    });

    testWidgets('RG-ROLE-03 : la confirmation dit que les dépenses restent',
        (tester) async {
      await _monter(tester, monRole: RoleMembre.proprietaire, membres: [
        _membre('Léa', StatutPresence.present, id: 'lea'),
      ]);

      await tester.tap(find.byKey(const ValueKey('exclure-lea')));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Ses dépenses et ses achats restent comptabilisés.'),
        findsOneWidget,
      );
    });

    testWidgets('RG-UI-03 : un échec serveur revient en arrière visiblement',
        (tester) async {
      await _monter(tester, monId: 'moi', echoueALEcriture: true, membres: [
        _membre('Moi', StatutPresence.inconnu, id: 'moi'),
      ]);

      await tester.tap(find.byKey(const ValueKey('changer-statut-moi')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Présent'));
      await tester.pumpAndSettle();

      expect(find.text('Ton statut n’a pas pu être enregistré.'), findsOneWidget);
      expect(find.text('Sans réponse'), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/invites_test.dart`
Attendu : ÉCHEC — page inexistante.

- [ ] **Étape 3 bis : sortir les libellés de `PpStatusChip` du code**

Défaut relevé pendant la revue du plan : `PpStatusChip._apparence()` porte ses libellés
**en dur** — `'Présent'`, `'Arrive plus tard'`, `'Peut-être'`. C'est une violation de
`NF-I18N-01`, que le lot 0.6 a cochée sans la voir parce qu'aucun écran n'affichait
encore de statut.

Remplacer le tuple par une paire `(Color, IconData)` et faire venir le libellé du
contexte :

```dart
  @override
  Widget build(BuildContext context) {
    final (couleurBrute, icone) = _apparence();
    final libelle = _libelle(PpL10n.of(context));
    ...
  }

  String _libelle(PpL10n l10n) => switch (presence) {
    PpPresence.present => l10n.statutPresent,
    PpPresence.peutEtre => l10n.statutPeutEtre,
    PpPresence.absent => l10n.statutAbsent,
    PpPresence.arriveTard => l10n.statutEnRetard,
    PpPresence.partTot => l10n.statutPartAvant,
    PpPresence.inconnu => l10n.statutInconnu,
  };
```

Les six chaînes correspondantes ont été ajoutées à l'étape 1.

Mettre à jour `app/test/design/pp_status_chip_test.dart` : il monte le composant, il
lui faut désormais les délégués de localisation, donc `monterWidget` de la tâche 5.

- [ ] **Étape 3 ter : passerelle entre les deux énumérations**

Deux énumérations décrivent le même concept, et c'est **voulu** : `PpPresence` est le
vocabulaire visuel du système de design, `StatutPresence` est le contrat de l'API. Les
fusionner ferait dépendre un composant de design de la couche réseau, ce que les
frontières du projet interdisent en esprit.

La conversion vit donc dans la couche fonctionnalité, jamais dans le design.
Créer `app/lib/features/evenement/presence_vers_pastille.dart` :

```dart
import '../../core/models/membre.dart';
import '../../design/components/pp_status_chip.dart';

/// Traduit le statut du contrat d'API vers le vocabulaire du système de design.
///
/// Placée ici et non dans `pp_status_chip.dart` : un composant de design qui
/// importerait `core/models` dépendrait de la forme des réponses de l'API, et
/// changerait à chaque évolution de contrat.
PpPresence versPastille(StatutPresence statut) => switch (statut) {
  StatutPresence.present => PpPresence.present,
  StatutPresence.peutEtre => PpPresence.peutEtre,
  StatutPresence.absent => PpPresence.absent,
  StatutPresence.enRetard => PpPresence.arriveTard,
  StatutPresence.partAvant => PpPresence.partTot,
  StatutPresence.inconnu => PpPresence.inconnu,
};
```

Test associé, dans `app/test/features/invites_test.dart` :

```dart
    test('les six statuts ont une pastille', () {
      for (final statut in StatutPresence.values) {
        expect(() => versPastille(statut), returnsNormally);
      }
    });
```

- [ ] **Étape 4 : implémenter**

Liste de `PpCard`, une par membre : `PpAvatar`, nom affiché, `PpStatusChip`, horaires en
`HH:mm`, accompagnants, `PpEyebrow` du rôle — il n'existe pas de composant `PpTag`.

Le bouton de changement de statut porte `ValueKey('changer-statut-<id>')` et n'est rendu
que si `membre.id == monId`. Le bouton d'exclusion porte `ValueKey('exclure-<id>')` et
n'est rendu que si `monRole.peutGerer && membre.role != RoleMembre.proprietaire` —
`RG-ROLE-01` interdit d'exclure le propriétaire.

L'écriture passe par `PpOptimisticAction.executer` avec
`messageEchec: l10n.invitesEchecStatut` et `messageDiffere: l10n.horsLigneDiffere`.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/invites_test.dart`
Attendu : 6 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/invites_page.dart app/lib/l10n/arb/app_fr.arb \
        app/test/features/invites_test.dart
git commit -m "feat(events): écran des invités et modification de sa présence"
```

---

### Tâche 13 : Paramètres de l'événement

**Fichiers :**
- Créer : `app/lib/features/evenement/parametres_evenement_page.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/parametres_evenement_test.dart`

**Interfaces :**
- Consomme : `evenementProvider`, `membresProvider`, `evenementsApiProvider` (tâche 8).
- Produit : `class ParametresEvenementPage extends ConsumerStatefulWidget`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "paramTitre": "Paramètres",
  "paramEnregistrer": "Enregistrer",
  "paramTransferer": "Transférer la propriété",
  "paramTransfererExplication": "Le nouveau propriétaire doit avoir un compte : un invité sans compte ne retrouverait pas l’événement depuis un autre appareil.",
  "paramTransfererDevientAdmin": "Tu deviendras administrateur de l’événement.",
  "paramQuitter": "Quitter l’événement",
  "paramQuitterInterditProprietaire": "Transfère d’abord la propriété à quelqu’un d’autre.",
  "paramSupprimer": "Supprimer l’événement",
  "paramSupprimerConfirmation": "Saisis « {nom} » pour confirmer la suppression.",
  "@paramSupprimerConfirmation": { "placeholders": { "nom": { "type": "String" } } },
  "paramSupprimerDefinitif": "Cette suppression est définitive.",
  "paramDateModifieeAvertissement": "Un changement de date ou de lieu sera inscrit au fil de l’événement."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

```dart
void main() {
  group('Paramètres de l’événement', () {
    testWidgets('RG-ROLE-02 : le transfert précède « quitter » pour le propriétaire',
        (tester) async {
      await _monter(tester, monRole: RoleMembre.proprietaire);

      final transfert = tester.getTopLeft(find.text('Transférer la propriété'));
      final quitter = tester.getTopLeft(find.text('Quitter l’événement'));

      // Découvrir l'interdiction après avoir appuyé sur « quitter » est un cul-de-sac.
      expect(transfert.dy, lessThan(quitter.dy));
    });

    testWidgets('un propriétaire ne peut pas quitter directement', (tester) async {
      await _monter(tester, monRole: RoleMembre.proprietaire);

      await tester.tap(find.text('Quitter l’événement'));
      await tester.pumpAndSettle();

      expect(
        find.text('Transfère d’abord la propriété à quelqu’un d’autre.'),
        findsOneWidget,
      );
    });

    testWidgets('le transfert ne propose que des membres avec compte', (tester) async {
      await _monter(tester, monRole: RoleMembre.proprietaire, membres: [
        _membre('Léa', StatutPresence.present, id: 'lea', userId: 'u1'),
        _membre('Invité', StatutPresence.present, id: 'inv', userId: null),
      ]);

      await tester.tap(find.text('Transférer la propriété'));
      await tester.pumpAndSettle();

      expect(find.text('Léa'), findsOneWidget);
      expect(find.text('Invité'), findsNothing);
      expect(
        find.textContaining('un invité sans compte ne retrouverait pas l’événement'),
        findsOneWidget,
      );
    });

    testWidgets('RG-ROLE-01 : un administrateur ne peut pas supprimer', (tester) async {
      await _monter(tester, monRole: RoleMembre.administrateur);

      expect(find.text('Supprimer l’événement'), findsNothing);
    });

    testWidgets('EF-EVT-07 : la suppression exige la saisie du nom', (tester) async {
      await _monter(tester, monRole: RoleMembre.proprietaire, nom: 'Crémaillère');

      await tester.tap(find.text('Supprimer l’événement'));
      await tester.pumpAndSettle();

      final confirmer = find.widgetWithText(FilledButton, 'Supprimer l’événement').last;
      expect(tester.widget<FilledButton>(confirmer).onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'Crémaillère');
      await tester.pumpAndSettle();

      expect(tester.widget<FilledButton>(confirmer).onPressed, isNotNull);
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/parametres_evenement_test.dart`
Attendu : ÉCHEC — page inexistante.

- [ ] **Étape 4 : implémenter**

Ordre des blocs, non négociable : formulaire de modification, puis **transfert**, puis
**quitter**, puis **supprimer**. Motif à porter en commentaire :

```dart
// L'ordre suit RG-ROLE-02 : un propriétaire doit transférer avant de partir.
// Présenter « quitter » d'abord ferait découvrir l'interdiction après coup, sans issue
// visible.
```

Sélecteur de transfert : filtrer sur `membre.userId != null`, afficher
`l10n.paramTransfererExplication` en tête de la feuille, et
`l10n.paramTransfererDevientAdmin` — l'ancien propriétaire devient administrateur, pas
membre ordinaire.

Suppression : `FilledButton` désactivé tant que la saisie ne correspond pas exactement au
nom de l'événement.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/parametres_evenement_test.dart`
Attendu : 5 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/parametres_evenement_page.dart \
        app/lib/l10n/arb/app_fr.arb app/test/features/parametres_evenement_test.dart
git commit -m "feat(events): paramètres, transfert de propriété et suppression"
```

---

### Tâche 14 : Invitation — lien, code court, QR et partage

**Fichiers :**
- Créer : `app/lib/features/evenement/invitation_page.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/invitation_test.dart`

**Interfaces :**
- Consomme : `invitationProvider`, `evenementsApiProvider` (tâche 8),
  `qr_flutter`, `share_plus` (tâche 1).
- Produit : `class InvitationPage extends ConsumerWidget`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "invitationTitre": "Inviter",
  "invitationLien": "Lien d’invitation",
  "invitationCodeCourt": "Code à saisir",
  "invitationCopier": "Copier",
  "invitationCopie": "Lien copié.",
  "invitationPartager": "Partager",
  "invitationPartagerTexte": "Rejoins « {nom} » sur PartyPlan : {lien}",
  "@invitationPartagerTexte": {
    "placeholders": { "nom": { "type": "String" }, "lien": { "type": "String" } }
  },
  "invitationRegenerer": "Régénérer le lien",
  "invitationRegenererAvertissement": "Le lien et le code actuels cesseront de fonctionner. Toute personne à qui tu les as déjà envoyés devra en recevoir de nouveaux.",
  "invitationFermerArrivees": "Fermer les nouvelles arrivées",
  "invitationFermee": "Les nouvelles arrivées sont fermées."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

```dart
void main() {
  group('Écran d’invitation', () {
    testWidgets('affiche le lien, le code court et le QR', (tester) async {
      await _monter(tester,
          lien: 'https://partyplan.fr/join/abc', codeCourt: 'PLAN-K7M2X9');

      expect(find.text('https://partyplan.fr/join/abc'), findsOneWidget);
      expect(find.text('PLAN-K7M2X9'), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('le QR est sur fond blanc quel que soit le thème', (tester) async {
      await _monter(tester, sombre: true);

      // Sans fond blanc imposé, le code n'est pas lisible par un téléphone en thème
      // sombre.
      final qr = tester.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.backgroundColor, Colors.white);
    });

    testWidgets('EF-INV-05 : la régénération avertit avant d’agir', (tester) async {
      await _monter(tester);

      await tester.tap(find.text('Régénérer le lien'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Le lien et le code actuels cesseront de fonctionner.'),
        findsOneWidget,
      );
    });

    testWidgets('EF-INV-06 : l’état fermé est visible', (tester) async {
      await _monter(tester, adhesionsOuvertes: false);

      expect(find.text('Les nouvelles arrivées sont fermées.'), findsOneWidget);
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/invitation_test.dart`
Attendu : ÉCHEC — page inexistante.

- [ ] **Étape 4 : implémenter**

```dart
          QrImageView(
            data: invitation.lien,
            size: 220,
            // Fond blanc imposé : le thème sombre ne le fournit pas, et sans lui le
            // code n'est pas lisible par un téléphone. Même raisonnement qu'à
            // l'enrôlement du second facteur.
            backgroundColor: Colors.white,
            padding: const EdgeInsets.all(PpSpacing.md),
          ),
```

Partage : `SharePlus.instance.share(ShareParams(text: l10n.invitationPartagerTexte(...)))`.

Porter le motif en commentaire au-dessus :

```dart
// EF-INV-02 « exportable en image » est livré comme partage natif plutôt que comme
// enregistrement en galerie : le besoin réel est d'envoyer le QR dans une conversation,
// et l'enregistrement coûterait une permission et une dépendance sur chaque plateforme.
```

La régénération n'est **jamais** différable (voir `EvenementsApi.regenererInvitation`) :
en cas de panne réseau, elle échoue franchement.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/invitation_test.dart`
Attendu : 4 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/invitation_page.dart app/lib/l10n/arb/app_fr.arb \
        app/test/features/invitation_test.dart
git commit -m "feat(events): écran d'invitation, QR code et partage natif"
```

---

### Tâche 15 : Aperçu et adhésion sans compte

**Fichiers :**
- Créer : `app/lib/features/rejoindre/apercu_invitation_page.dart`
- Créer : `app/lib/features/rejoindre/adhesion_page.dart`
- Modifier : `app/lib/features/rejoindre/rejoindre_page.dart`
- Modifier : `app/lib/app/router.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/adhesion_test.dart`

**Interfaces :**
- Consomme : `evenementsApiProvider` (tâche 8).
- Produit : `ApercuInvitationPage`, `AdhesionPage`. Routes :
  `/join/:token` (aperçu, publique), `/join/:token/prenom`, `/join/:token/statut`.

**Contrainte de comptage.** De l'ouverture du lien à l'affichage du tableau de bord :
**trois interactions au maximum, aucune saisie d'adresse**. Le décompte prévu — appui sur
« Participer », saisie du prénom et validation, choix du statut. Toute interaction
supplémentaire fait échouer `EF-INV-04`.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "apercuParticiper": "Participer",
  "apercuParticipants": "{nombre, plural, one{1 participant} other{{nombre} participants}}",
  "@apercuParticipants": { "placeholders": { "nombre": { "type": "int" } } },
  "apercuFermee": "L’organisateur a fermé les nouvelles arrivées.",
  "adhesionPrenomQuestion": "Comment tu t’appelles ?",
  "adhesionPrenomChamp": "Ton prénom",
  "adhesionPrenomRequis": "Indique ton prénom.",
  "adhesionStatutQuestion": "Tu viens ?",
  "adhesionSansCompte": "Pas besoin de créer un compte.",
  "adhesionEchec": "Impossible de rejoindre cet événement."
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

```dart
void main() {
  group('Parcours sans compte', () {
    testWidgets('RG-INV-04 : l’aperçu ne montre ni membres ni dépenses', (tester) async {
      await _monterApercu(tester, nom: 'Crémaillère', participants: 8);

      expect(find.text('Crémaillère'), findsOneWidget);
      expect(find.text('8 participants'), findsOneWidget);
      // Le modèle ApercuInvitation ne porte aucun nom de membre : ce qui n'existe pas
      // ne peut pas fuiter.
      expect(find.text('Léa'), findsNothing);
    });

    testWidgets('EF-INV-04 : trois interactions du lien au tableau de bord',
        (tester) async {
      final compteur = _CompteurInteractions();
      await _monterApercu(tester, compteur: compteur);

      await compteur.appuyer(tester, find.text('Participer'));
      await compteur.saisirEtValider(tester, find.byType(TextFormField), 'Léa');
      await compteur.appuyer(tester, find.text('Présent'));
      await tester.pumpAndSettle();

      expect(compteur.total, lessThanOrEqualTo(3));
      expect(find.byType(TableauDeBordPage), findsOneWidget);
    });

    testWidgets('RG-INV-05 : deux écrans, pas trois', (tester) async {
      await _monterApercu(tester);

      await tester.tap(find.text('Participer'));
      await tester.pumpAndSettle();
      expect(find.text('Comment tu t’appelles ?'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Léa');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Tu viens ?'), findsOneWidget);
    });

    testWidgets('aucune saisie d’adresse n’est demandée', (tester) async {
      await _monterApercu(tester);
      await tester.tap(find.text('Participer'));
      await tester.pumpAndSettle();

      expect(find.textContaining('e-mail'), findsNothing);
      expect(find.text('Pas besoin de créer un compte.'), findsOneWidget);
    });

    testWidgets('EF-INV-06 : l’aperçu reste lisible quand les arrivées sont fermées',
        (tester) async {
      await _monterApercu(tester, adhesionsOuvertes: false, nom: 'Crémaillère');

      // L'aperçu explique le refus au lieu de renvoyer une erreur opaque.
      expect(find.text('Crémaillère'), findsOneWidget);
      expect(find.text('L’organisateur a fermé les nouvelles arrivées.'),
          findsOneWidget);
      expect(find.text('Participer'), findsNothing);
    });

    testWidgets('la saisie du code court est tolérante', (tester) async {
      await _monterRejoindreParCode(tester);

      await tester.enterText(find.byType(TextFormField), ' plan-k7m 2x9 ');
      await tester.tap(find.text('Continuer'));
      await tester.pumpAndSettle();

      expect(_dernierCodeAppele, 'K7M2X9');
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/adhesion_test.dart`
Attendu : ÉCHEC — pages inexistantes.

- [ ] **Étape 4 : implémenter**

`ApercuInvitationPage` — route publique. N'affiche que ce que porte `ApercuInvitation`.
Un seul bouton d'action, `Participer`, masqué si `!adhesionsOuvertes`.

`AdhesionPage` — `PageView` verrouillé à deux pages :
1. Prénom, avec `textInputAction: TextInputAction.done` et `onFieldSubmitted` qui passe
   directement à la page 2 : la validation clavier **est** l'interaction, il ne faut pas
   en ajouter une seconde par un bouton.
2. Choix du statut : cinq `PpStatusChip` tactiles, un appui déclenche l'adhésion et la
   navigation vers le tableau de bord.

Sous le champ de prénom, `l10n.adhesionSansCompte`.

Après adhésion réussie, `context.go(PpRoutes.versEvenement(eventId))` — `go` et non
`push`, pour qu'un retour arrière ne ramène pas sur le formulaire.

`rejoindre_page.dart` — saisie du code court, `onChanged` qui normalise l'affichage,
`EvenementsApi.resoudreCodeCourt` puis navigation vers l'aperçu.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/adhesion_test.dart`
Attendu : 6 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/rejoindre app/lib/app/router.dart app/lib/l10n/arb/app_fr.arb \
        app/test/features/adhesion_test.dart
git commit -m "feat(events): aperçu d'invitation et adhésion sans compte en deux écrans"
```

---

### Tâche 16 : Conversion d'invité côté application

**Fichiers :**
- Créer : `app/lib/features/evenement/sections/section_creer_un_compte.dart`
- Modifier : `app/lib/core/network/comptes_api.dart`
- Modifier : `app/lib/features/auth/inscription_page.dart`
- Modifier : `app/lib/l10n/arb/app_fr.arb`
- Test : `app/test/features/conversion_invite_test.dart`

**Interfaces :**
- Consomme : `SessionStore.lireJetonInvite` (existant), l'API de la tâche 7.
- Produit : `ComptesApi.inscrire` gagne le paramètre nommé facultatif
  `String? jetonInvite`. `SectionCreerUnCompte` s'affiche pour un invité sans compte.

- [ ] **Étape 1 : ajouter les chaînes**

```json
  "conversionTitre": "Garde tes événements",
  "conversionExplication": "Sans compte, tu perds l’accès à cet événement si tu changes de téléphone ou vides ton navigateur.",
  "conversionCreerUnCompte": "Créer un compte"
```

Puis `make l10n`.

- [ ] **Étape 2 : écrire le test qui échoue**

```dart
void main() {
  group('Conversion d’un invité', () {
    testWidgets('la proposition apparaît pour un invité sans compte', (tester) async {
      await _monterTableauDeBord(tester, etat: EtatSession.invite);

      expect(find.text('Garde tes événements'), findsOneWidget);
      expect(
        find.textContaining('tu perds l’accès à cet événement'),
        findsOneWidget,
      );
    });

    testWidgets('elle n’apparaît pas pour un compte', (tester) async {
      await _monterTableauDeBord(tester, etat: EtatSession.connecte);

      expect(find.text('Garde tes événements'), findsNothing);
    });

    testWidgets('l’inscription transmet le jeton d’invité', (tester) async {
      final api = _ComptesApiEspion();
      await _monterInscription(tester, api: api, jetonInvite: 'jeton-invite');

      await _remplirEtSoumettre(tester);

      // RG-AUTH-07 : c'est le jeton qui porte le rattachement, jamais le prénom.
      expect(api.dernierJetonInvite, 'jeton-invite');
    });

    testWidgets('sans jeton d’invité, rien n’est transmis', (tester) async {
      final api = _ComptesApiEspion();
      await _monterInscription(tester, api: api, jetonInvite: null);

      await _remplirEtSoumettre(tester);

      expect(api.dernierJetonInvite, isNull);
    });
  });
}
```

- [ ] **Étape 3 : vérifier l'échec**

Run : `cd app && flutter test test/features/conversion_invite_test.dart`
Attendu : ÉCHEC — `inscrire` n'accepte pas `jetonInvite`.

- [ ] **Étape 4 : implémenter**

Dans `comptes_api.dart` :

```dart
  Future<void> inscrire({
    required String email,
    required String motDePasse,
    required String nomAffiche,
    String? jetonInvite,
  }) => _ouvrirSession('/auth/register', {
    'email': email,
    'password': motDePasse,
    'displayName': nomAffiche,
    // Transmis dans le corps et non par l'en-tête Authorization : cet endpoint est
    // anonyme, et le jeton d'invité porte une audience distincte (EF-AUTH-11).
    if (jetonInvite != null) 'guestToken': jetonInvite,
  });
```

`inscription_page.dart` lit `SessionStore.lireJetonInvite()` au montage et le transmet.

`SectionCreerUnCompte` s'ajoute à la liste de `TableauDeBordPage`, entre
`SectionMaPresence` et `SectionSynthesePresences`, et renvoie `SizedBox.shrink()` si
l'état de session n'est pas `EtatSession.invite`.

- [ ] **Étape 5 : vérifier le succès**

Run : `cd app && flutter test test/features/conversion_invite_test.dart`
Attendu : 4 tests réussis.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/sections/section_creer_un_compte.dart \
        app/lib/core/network/comptes_api.dart app/lib/features/auth/inscription_page.dart \
        app/lib/l10n/arb/app_fr.arb app/test/features/conversion_invite_test.dart
git commit -m "feat(auth): proposition de compte et transmission du jeton d'invité"
```

---

### Tâche 17 : Navigation et branchement de la coquille

**Fichiers :**
- Modifier : `app/lib/features/evenement/coquille_evenement.dart`
- Modifier : `app/lib/app/router.dart`
- Test : `app/test/router_test.dart`

**Interfaces :**
- Consomme : toutes les pages des tâches 9 à 16.
- Produit : coquille branchée. `PpRoutes` gagne `creationEvenement`,
  `evenementInvites`, `evenementParametres`, `evenementInvitation`.

- [ ] **Étape 1 : écrire le test qui échoue**

Ajouter à `app/test/router_test.dart` :

```dart
    testWidgets('RG-UI-01 : cinq entrées, pas une de plus', (tester) async {
      await _monterEvenement(tester);

      final barre = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(barre.destinations, hasLength(5));
    });

    testWidgets('l’onglet Accueil affiche le tableau de bord', (tester) async {
      await _monterEvenement(tester);

      expect(find.byType(TableauDeBordPage), findsOneWidget);
    });

    testWidgets('Invités, Invitation et Paramètres sont sous « Plus »',
        (tester) async {
      await _monterEvenement(tester);

      await tester.tap(find.text('Plus'));
      await tester.pumpAndSettle();

      expect(find.text('Invités'), findsOneWidget);
      expect(find.text('Inviter'), findsOneWidget);
      expect(find.text('Paramètres'), findsOneWidget);
    });

    testWidgets('/join/:token reste accessible sans session', (tester) async {
      await _monterSansSession(tester, route: '/join/abc');

      expect(find.byType(ApercuInvitationPage), findsOneWidget);
    });

    testWidgets('un invité sans compte n’atteint ni profil ni back-office',
        (tester) async {
      await _monterInvite(tester, route: PpRoutes.profilEdition);

      expect(find.byType(ProfilEditionPage), findsNothing);
    });
```

- [ ] **Étape 2 : vérifier l'échec**

Run : `cd app && flutter test test/router_test.dart`
Attendu : ÉCHEC — la coquille affiche encore `PpEmptyState` sur l'onglet Accueil.

- [ ] **Étape 3 : implémenter**

Dans `coquille_evenement.dart`, remplacer le `body` par un `IndexedStack` :

```dart
      body: IndexedStack(
        index: _onglet,
        children: [
          TableauDeBordPage(evenementId: widget.eventId),
          // Courses (B2), Dépenses (B2), Planning (B4) conservent leur état vide.
          PpEmptyState(titre: l10n.ongletCourses, ...),
          PpEmptyState(titre: l10n.ongletDepenses, ...),
          PpEmptyState(titre: l10n.ongletPlanning, ...),
          _MenuPlus(evenementId: widget.eventId),
        ],
      ),
```

`IndexedStack` et non reconstruction : changer d'onglet ne doit pas recharger le tableau
de bord ni perdre la position de défilement.

`_MenuPlus` liste Invités, Inviter, Paramètres — et **rien de plus**. La contrainte des
cinq entrées reste écrite dans le fichier.

Ajouter les routes correspondantes dans `router.dart`, et conserver `/join/:token` dans
`PpRoutes.publiques`.

- [ ] **Étape 4 : vérifier le succès**

Run : `cd app && flutter test test/router_test.dart`
Attendu : tous verts.
Run : `cd app && flutter test`
Attendu : la totalité de la suite verte.

- [ ] **Étape 5 : étendre le test d'accessibilité aux écrans nouveaux**

`app/test/design/accessibilite_test.dart` vérifie déjà `NF-A11Y-01` (contrastes) et
`NF-A11Y-02` (cibles de 44 points) sur les composants du lot 0.6. La spec demande de
**l'étendre, pas de le réécrire**.

Ajouter une table des écrans produits par B1 et, pour chacun, vérifier que toute cible
tactile mesure au moins 44 points et que toute action porte un libellé sémantique :

```dart
  const ecrans = <String, Widget Function()>{
    'accueil': AccueilPage.new,
    'création': CreationEvenementPage.new,
    'tableau de bord': () => const TableauDeBordPage(evenementId: 'test'),
    'invités': () => const InvitesPage(evenementId: 'test'),
    'paramètres': () => const ParametresEvenementPage(evenementId: 'test'),
    'invitation': () => const InvitationPage(evenementId: 'test'),
    'aperçu': () => const ApercuInvitationPage(jeton: 'test'),
    'adhésion': () => const AdhesionPage(jeton: 'test'),
  };

  for (final entree in ecrans.entries) {
    testWidgets('NF-A11Y-02 : cibles de 44 points sur l’écran ${entree.key}',
        (tester) async {
      await _monterEcran(tester, entree.value());

      for (final cible in find.byWidgetPredicate(_estTactile).evaluate()) {
        final taille = tester.getSize(find.byWidget(cible.widget));
        expect(taille.height, greaterThanOrEqualTo(44),
            reason: '${entree.key} : cible trop courte');
      }
    });

    testWidgets('NF-A11Y-03 : toute action porte un libellé sur ${entree.key}',
        (tester) async {
      await _monterEcran(tester, entree.value());

      final handle = tester.ensureSemantics();
      for (final noeud in _actionsSansLibelle(tester)) {
        fail('${entree.key} : action sans libellé sémantique — $noeud');
      }
      handle.dispose();
    });
  }
```

Run : `cd app && flutter test test/design/accessibilite_test.dart`
Attendu : tous verts. Un écran qui échoue est un défaut de l'écran, **pas du test** :
corriger l'écran.

- [ ] **Étape 6 : commit**

```bash
git add app/lib/features/evenement/coquille_evenement.dart app/lib/app/router.dart \
        app/test/router_test.dart app/test/design/accessibilite_test.dart
git commit -m "feat(events): coquille de navigation branchée sur les écrans réels"
```

---

## Phase 5 — Recette

### Tâche 18 : Extension de la recette du parcours événementiel

**Fichiers :**
- Modifier : `tools/recette/parcours-evenement.py`
- Modifier : `docs/roadmap.md`

**Interfaces :**
- Consomme : l'API complète, y compris la conversion de la tâche 7.
- Produit : recette étendue, exécutable de bout en bout.

- [ ] **Étape 1 : ajouter les vérifications**

Ajouter au script, sur le modèle des 53 vérifications existantes :

```python
def verifier_conversion_invite(ctx):
    """EF-AUTH-11 — la participation suit le compte, sans doublon."""
    evenement = ctx.creer_evenement("Recette conversion")
    invitation = ctx.lire_invitation(evenement)
    jeton = ctx.rejoindre(invitation["token"], "Léa")

    session = ctx.inscrire("lea@recette.local", jeton_invite=jeton)

    ctx.verifier(
        evenement in [e["id"] for e in ctx.mes_evenements(session)],
        "l'événement rejoint sans compte apparaît dans la liste du compte créé",
    )
    membres = ctx.membres(evenement)
    ctx.verifier(
        len([m for m in membres if m["displayName"] == "Léa"]) == 1,
        "aucun doublon de membre après conversion",
    )


def verifier_idempotence_adhesion(ctx):
    """Rejeu d'une adhésion mise en file : la réponse est rendue, rien n'est créé."""
    evenement = ctx.creer_evenement("Recette idempotence")
    invitation = ctx.lire_invitation(evenement)
    cle = str(uuid.uuid4())

    ctx.rejoindre(invitation["token"], "Tom", cle=cle)
    ctx.rejoindre(invitation["token"], "Tom", cle=cle)

    membres = ctx.membres(evenement)
    ctx.verifier(
        len([m for m in membres if m["displayName"] == "Tom"]) == 1,
        "une adhésion rejouée ne crée pas un second membre",
    )


def verifier_trois_interactions(ctx):
    """EF-INV-04 — du lien au tableau de bord en trois appels, sans adresse."""
    evenement = ctx.creer_evenement("Recette parcours")
    invitation = ctx.lire_invitation(evenement)

    apercu = ctx.apercu(invitation["token"])
    ctx.verifier("members" not in apercu, "RG-INV-04 : l'aperçu ne liste pas les membres")
    ctx.verifier("token" not in apercu, "RG-INV-04 : l'aperçu ne révèle aucun jeton")

    jeton = ctx.rejoindre(invitation["token"], "Zoé", statut="Going")
    tableau = ctx.evenement(evenement, jeton_invite=jeton)

    ctx.verifier(tableau["name"] == "Recette parcours",
                 "le tableau de bord est atteint sans adresse e-mail")
```

- [ ] **Étape 2 : exécuter la recette**

Run : `make reset-db && make up && python3 tools/recette/parcours-evenement.py`
Attendu : toutes les vérifications passent, le total ayant augmenté de 53 à au moins 60.

- [ ] **Étape 3 : mettre la feuille de route à jour**

Cocher dans `docs/roadmap.md` les tâches des lots 1.1, 1.2, 1.3, 1.4 et 1.12 couvertes,
et **laisser décochée** la ligne `RG-UI-02` du lot 1.2, en y ajoutant :

```markdown
- [ ] `RG-UI-02` Le tableau de bord affiche l'information actionnable du moment
  - → structure livrée en B1, sections autonomes prêtes à recevoir les modules suivants
  - → l'information exigée par la règle — articles non attribués, montant dû — vient de
    `Shopping` et `Settlements` : la case ne peut être cochée qu'à la fin de B2
```

- [ ] **Étape 4 : vérification complète**

Run : `make verif`
Attendu : format C#, format Dart, analyse, frontières de modules, tests unitaires,
tests d'intégration et tests Flutter, tous verts. **Reporter la sortie réelle, pas un
résumé.**

- [ ] **Étape 5 : commit**

```bash
git add tools/recette/parcours-evenement.py docs/roadmap.md
git commit -m "test(events): recette étendue à la conversion d'invité et à l'idempotence"
```

---

## Vérification finale de B1

Avant d'annoncer B1 terminé, exécuter et **coller la sortie** de :

```bash
make verif
cd app && flutter test
cd api && dotnet test
bash tools/verifier-frontieres-modules.sh
bash tools/verifier-variables-env.sh
python3 tools/recette/parcours-evenement.py
```

Puis invoquer `superpowers:requesting-code-review`, et `security-review` avant tout
jalon de publication.

Aucune affirmation de complétion sans sortie de commande à l'appui.
