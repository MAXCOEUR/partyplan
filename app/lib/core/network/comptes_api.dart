import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/profil.dart';
import '../storage/session_store.dart';
import 'api_client.dart';
import 'api_exception.dart';

/// Appels d'API du domaine « comptes ».
///
/// Écrit à la main plutôt que généré depuis l'OpenAPI : le générateur produit un
/// paquet séparé et une chaîne de compilation supplémentaire, disproportionnés pour
/// une vingtaine d'endpoints. `tools/generate-api-client.sh` reste disponible le jour
/// où la surface le justifiera.
class ComptesApi {
  const ComptesApi(this._client, this._sessions);

  final ApiClient _client;
  final SessionStore _sessions;

  // ------------------------------------------------------ authentification ----

  Future<void> inscrire({
    required String email,
    required String motDePasse,
    required String nomAffiche,
  }) => _ouvrirSession('/auth/register', {
    'email': email,
    'password': motDePasse,
    'displayName': nomAffiche,
  });

  /// Connexion. Renvoie le résultat : session ouverte, ou second facteur exigé.
  Future<ResultatConnexion> connecter({
    required String email,
    required String motDePasse,
  }) async {
    final reponse = await _client.post<Map<String, dynamic>>(
      '/auth/login',
      corps: {'email': email, 'password': motDePasse},
      analyser: (corps) => corps! as Map<String, dynamic>,
    );

    final resultat = ResultatConnexion.depuisJson(reponse);

    if (!resultat.secondFacteurRequis) {
      await _enregistrer(reponse);
    }

    return resultat;
  }

  /// Achève la connexion avec un code temporel ou un code de secours.
  Future<void> verifierSecondFacteur({
    required String jetonDefi,
    required String code,
  }) async {
    final reponse = await _client.post<Map<String, dynamic>>(
      '/auth/mfa/verify',
      corps: {'challengeToken': jetonDefi, 'code': code},
      analyser: (corps) => corps! as Map<String, dynamic>,
    );

    await _enregistrer(reponse);
  }

  // --------------------------------------------------- double authentification ----

  Future<EnrolementTotp> preparerSecondFacteur() =>
      _client.post<EnrolementTotp>(
        '/auth/totp/setup',
        analyser: (corps) =>
            EnrolementTotp.depuisJson(corps! as Map<String, dynamic>),
      );

  Future<List<String>> activerSecondFacteur(String code) =>
      _client.post<List<String>>(
        '/auth/totp/activate',
        corps: {'code': code},
        analyser: (corps) => [
          for (final c
              in (corps! as Map<String, dynamic>)['recoveryCodes']
                  as List<dynamic>)
            c as String,
        ],
      );

  Future<void> desactiverSecondFacteur(String motDePasse) =>
      _client.deleteWithBody('/auth/totp', corps: {'password': motDePasse});

  Future<List<String>> regenererCodesDeSecours() => _client.post<List<String>>(
    '/auth/totp/recovery-codes',
    analyser: (corps) => [
      for (final c
          in (corps! as Map<String, dynamic>)['recoveryCodes'] as List<dynamic>)
        c as String,
    ],
  );

  Future<void> deconnecter() async {
    try {
      await _client.post<void>('/auth/logout', analyser: (_) {});
    } on ApiException {
      // La session locale est effacée quoi qu'il arrive : rester connecté côté
      // interface après un échec réseau serait pire que la révocation manquée.
    } finally {
      await _sessions.effacerSession();
    }
  }

  Future<void> demanderReinitialisation(String email) => _client.post<void>(
    '/auth/password/forgot',
    corps: {'email': email},
    analyser: (_) {},
  );

  Future<void> reinitialiser({
    required String code,
    required String nouveauMotDePasse,
  }) => _client.post<void>(
    '/auth/password/reset',
    corps: {'token': code, 'newPassword': nouveauMotDePasse},
    analyser: (_) {},
  );

  Future<void> changerMotDePasse({
    required String actuel,
    required String nouveau,
  }) => _client.post<void>(
    '/auth/password/change',
    corps: {'currentPassword': actuel, 'newPassword': nouveau},
    analyser: (_) {},
  );

  Future<void> verifierAdresse(String code) => _client.post<void>(
    '/auth/email/verify',
    corps: {'token': code},
    analyser: (_) {},
  );

  // ---------------------------------------------------------------- profil ----

  Future<Profil> profil() => _client.get<Profil>(
    '/me',
    analyser: (corps) => Profil.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<Profil> modifierProfil({
    String? nomAffiche,
    String? fuseau,
  }) => _client.patch<Profil>(
    '/me',
    // Marqueur `?` : un champ nul est absent du corps, et PATCH interprète l'absence
    // comme « inchangé ». Envoyer null signifierait «effacer ».
    corps: {'displayName': ?nomAffiche, 'timezone': ?fuseau},
    analyser: (corps) => Profil.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> demanderChangementAdresse(String nouvelleAdresse) =>
      _client.post<void>(
        '/me/email',
        corps: {'newEmail': nouvelleAdresse},
        analyser: (_) {},
      );

  Future<List<SessionActive>> sessions() => _client.get<List<SessionActive>>(
    '/me/sessions',
    analyser: (corps) => [
      for (final s in corps! as List<dynamic>)
        SessionActive.depuisJson(s as Map<String, dynamic>),
    ],
  );

  Future<void> revoquerSession(String id) => _client.delete('/me/sessions/$id');

  Future<void> revoquerAutresSessions() => _client.delete('/me/sessions');

  Future<String> televerserPhoto({
    required List<int> octets,
    required String nomFichier,
  }) async {
    final donnees = FormData.fromMap({
      'file': MultipartFile.fromBytes(octets, filename: nomFichier),
    });

    return _client.put<String>(
      '/me/avatar',
      corps: donnees,
      analyser: (corps) => corps! as String,
    );
  }

  Future<void> supprimerPhoto() => _client.delete('/me/avatar');

  Future<String> exporterDonnees() => _client.get<String>(
    '/me/export',
    analyser: (corps) => corps is String ? corps : jsonEncode(corps),
  );

  Future<void> supprimerCompte(String confirmationAdresse) => _client
      .deleteWithBody('/me', corps: {'emailConfirmation': confirmationAdresse});

  // -------------------------------------------------------- administration ----

  Future<PageComptes> listerComptes({
    String? recherche,
    int page = 1,
    int taille = 25,
  }) => _client.get<PageComptes>(
    '/admin/users',
    parametres: {
      if (recherche != null && recherche.isNotEmpty) 'search': recherche,
      'page': page,
      'pageSize': taille,
    },
    analyser: (corps) => PageComptes.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<FicheCompte> fiche(String id) => _client.get<FicheCompte>(
    '/admin/users/$id',
    analyser: (corps) => FicheCompte.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> declencherReinitialisation(String id) =>
      _client.post<void>('/admin/users/$id/password-reset', analyser: (_) {});

  Future<void> revoquerToutesSessions(String id) =>
      _client.delete('/admin/users/$id/sessions');

  Future<void> suspendre(String id, String motif) => _client.post<void>(
    '/admin/users/$id/suspend',
    corps: {'reason': motif},
    analyser: (_) {},
  );

  Future<void> reactiver(String id) =>
      _client.post<void>('/admin/users/$id/unsuspend', analyser: (_) {});

  Future<void> supprimerCompteAdmin(String id) =>
      _client.delete('/admin/users/$id');

  Future<void> changerRole(String id, String role) => _client.patch<void>(
    '/admin/users/$id/role',
    corps: {'role': role},
    analyser: (_) {},
  );

  Future<List<EntreeAudit>> journalAudit({int page = 1, int taille = 50}) =>
      _client.get<List<EntreeAudit>>(
        '/admin/audit',
        parametres: {'page': page, 'pageSize': taille},
        analyser: (corps) => [
          for (final e in corps! as List<dynamic>)
            EntreeAudit.depuisJson(e as Map<String, dynamic>),
        ],
      );

  Future<void> _ouvrirSession(String chemin, Map<String, dynamic> corps) async {
    final jetons = await _client.post<Map<String, dynamic>>(
      chemin,
      corps: corps,
      analyser: (reponse) => reponse! as Map<String, dynamic>,
    );

    await _enregistrer(jetons);
  }

  Future<void> _enregistrer(Map<String, dynamic> jetons) =>
      _sessions.enregistrerSession(
        jetonAcces: jetons['accessToken'] as String,
        jetonRafraichissement: jetons['refreshToken'] as String,
      );
}
