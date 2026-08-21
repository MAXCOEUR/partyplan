import '../models/evenement.dart';
import '../models/invitation.dart';
import '../models/membre.dart';
import '../storage/session_store.dart';
import 'api_client.dart';
import 'cle_idempotence.dart';

/// Appels d'API du domaine événementiel.
///
/// Écrit à la main, comme `ComptesApi` : le générateur produit un paquet séparé et une
/// chaîne de compilation supplémentaire, disproportionnés pour cette surface.
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

  Future<List<EvenementDeLaListe>> lister() => _client.get(
    '/events',
    analyser: (corps) => [
      for (final e in corps! as List)
        EvenementDeLaListe.depuisJson(e as Map<String, dynamic>),
    ],
  );

  Future<ResumeEvenement> lire(String id) => _client.get(
    '/events/$id',
    analyser: (corps) =>
        ResumeEvenement.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Crée un événement.
  ///
  /// [cleIdempotence] est fournie par l'assistant de création et fixée à son
  /// ouverture : un double appui sur « Créer » ne doit jamais produire deux événements.
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
      'startsAt': debut.toUtc().toIso8601String(),
      if (fin != null) 'endsAt': fin.toUtc().toIso8601String(),
      if (adresse != null && adresse.isNotEmpty) 'address': adresse,
      if (description != null && description.isNotEmpty)
        'description': description,
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
      'name': ?nom,
      'description': ?description,
      if (debut != null) 'startsAt': debut.toUtc().toIso8601String(),
      if (fin != null) 'endsAt': fin.toUtc().toIso8601String(),
      'address': ?adresse,
    },
    differable: true,
    analyser: (corps) =>
        ResumeEvenement.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Supprime l'événement. Jamais différée : une suppression se confirme en
  /// connaissance de cause, et son résultat doit être connu tout de suite.
  Future<void> supprimer(String id) => _client.delete('/events/$id');

  // ----------------------------------------------------------- invitations ----

  Future<Invitation> invitation(String evenementId) => _client.get(
    '/events/$evenementId/invitation',
    analyser: (corps) => Invitation.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Régénère le lien et le code court.
  ///
  /// **Jamais différable** : chaque appel produit un jeton neuf, c'est tout son intérêt
  /// (EF-INV-05). Rejouée, elle invaliderait le lien que l'utilisateur vient de
  /// partager.
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

  // ---------------------------------------------------- accès sans compte ----

  Future<ApercuInvitation> apercuParJeton(String jeton) => _client.get(
    '/join/$jeton',
    analyser: (corps) =>
        ApercuInvitation.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<ApercuInvitation> apercuParCode(String code) => _client.get(
    '/join/code/${normaliserCode(code)}',
    // Jamais mis en cache : une personne qui n'a fait que taper un code ne doit pas
    // laisser l'aperçu d'un événement privé sur son appareil.
    cacheable: false,
    analyser: (corps) =>
        ApercuInvitation.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Rejoint par le lien d'invitation (EF-INV-04).
  ///
  /// Le jeton d'invité remis est conservé : c'est lui, et jamais le prénom, qui
  /// permettra le rattachement à un compte créé plus tard (RG-AUTH-07). Le perdre,
  /// c'est perdre les dépenses saisies.
  Future<String> rejoindreParJeton({
    required String jeton,
    required String prenom,
    required StatutPresence statut,
  }) => _rejoindre('/join/$jeton', prenom, statut);

  /// Rejoint par le code court (EF-INV-03).
  Future<String> rejoindreParCode({
    required String code,
    required String prenom,
    required StatutPresence statut,
  }) => _rejoindre('/join/code/${normaliserCode(code)}', prenom, statut);

  Future<String> _rejoindre(
    String chemin,
    String prenom,
    StatutPresence statut,
  ) async {
    final reponse = await _client.post<Map<String, dynamic>>(
      chemin,
      corps: {'displayName': prenom, 'status': statut.versApi},
      cleIdempotence: nouvelleCleIdempotence(),
      analyser: (corps) => corps! as Map<String, dynamic>,
    );

    final jetonInvite = reponse['guestToken'] as String?;

    if (jetonInvite != null) {
      await _sessions.enregistrerJetonInvite(jetonInvite);
    }

    return reponse['eventId'] as String;
  }

  /// Saisie tolérante : minuscules, espaces, tirets, absence de préfixe.
  ///
  /// Publique parce qu'elle est testée seule : la tolérance de saisie est une règle
  /// d'interface, pas un détail d'appel réseau.
  static String normaliserCode(String saisie) {
    final propre = saisie.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

    return propre.startsWith('PLAN') ? propre.substring(4) : propre;
  }

  // --------------------------------------------------------------- membres ----

  Future<List<Membre>> membres(String evenementId) => _client.get(
    '/events/$evenementId/members',
    analyser: (corps) => [
      for (final m in corps! as List)
        Membre.depuisJson(m as Map<String, dynamic>),
    ],
  );

  Future<Membre> majMaPresence(
    String evenementId, {
    required StatutPresence statut,
    String? heureArrivee,
    String? heureDepart,
    int? accompagnants,
  }) => _client.patch(
    '/events/$evenementId/members/me',
    corps: {
      'status': statut.versApi,
      'arrivalTime': ?heureArrivee,
      'departureTime': ?heureDepart,
      'extraGuests': ?accompagnants,
    },
    differable: true,
    analyser: (corps) => Membre.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> quitter(String evenementId) =>
      _client.delete('/events/$evenementId/members/me');

  /// RG-ROLE-03 — l'exclusion horodate la ligne sans la supprimer : les données
  /// financières du membre subsistent.
  Future<void> exclure(String evenementId, String membreId) =>
      _client.delete('/events/$evenementId/members/$membreId');

  Future<void> transfererPropriete(String evenementId, String membreId) =>
      _client.post<void>(
        '/events/$evenementId/members/$membreId/transfer-ownership',
        cleIdempotence: nouvelleCleIdempotence(),
        differable: true,
        analyser: (_) {},
      );

  /// Rattache au compte les participations rejointes sans compte (EF-AUTH-11).
  ///
  /// Appelée après toute ouverture de session, si un jeton d'invité subsiste sur
  /// l'appareil. Zéro rattachement n'est pas une erreur.
  Future<int> reclamerParticipations() async {
    final jeton = await _sessions.lireJetonInvite();

    if (jeton == null) {
      return 0;
    }

    return _client.post<int>(
      '/auth/guest-claim',
      corps: {'guestToken': jeton},
      analyser: (corps) =>
          ((corps! as Map<String, dynamic>)['linked'] as num).toInt(),
    );
  }

}
