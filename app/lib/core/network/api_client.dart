import 'dart:async';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../offline/cache_lecture.dart';
import '../offline/ecriture_differee.dart';
import '../offline/etat_reseau.dart';
import '../offline/file_ecritures.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

/// Client HTTP de l'API.
///
/// Un seul point de sortie réseau : jeton, corrélation, idempotence, traduction des
/// erreurs et mode dégradé y sont traités une fois pour toutes. Dispersés dans les
/// écrans, ces traitements finiraient par différer d'un appel à l'autre.
///
/// Le hors ligne (`NF-OFFLINE-01`) se place ici pour la même raison : un cache par
/// écran et une file par module divergeraient, et chaque module suivant paierait à
/// nouveau le prix de sa mise en place.
class ApiClient {
  ApiClient(
    this._sessionStore, {
    Dio? dio,
    CacheLecture? cache,
    FileEcritures? file,
    EtatReseau? etat,
  }) : _cache = cache,
       _file = file,
       _etat = etat ?? EtatReseau(),
       _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: AppConfig.apiRoot.toString(),
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               contentType: 'application/json',
               // Les statuts d'erreur sont traduits en ApiException plus bas :
               // sans cela, Dio lèverait avant que le corps ne soit exploité.
               validateStatus: (_) => true,
             ),
           ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final jeton =
              await _sessionStore.lireJetonAcces() ??
              await _sessionStore.lireJetonInvite();

          if (jeton != null) {
            options.headers['Authorization'] = 'Bearer $jeton';
          }

          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final SessionStore _sessionStore;
  final CacheLecture? _cache;
  final FileEcritures? _file;
  final EtatReseau _etat;

  EtatReseau get etat => _etat;

  /// Lecture.
  ///
  /// [cacheable] à faux pour ce qui ne doit pas rester sur l'appareil — la résolution
  /// d'un code court remet un jeton d'invitation, qui n'a rien à faire dans un cache.
  Future<T> get<T>(
    String chemin, {
    Map<String, dynamic>? parametres,
    bool cacheable = true,
    required T Function(Object? corps) analyser,
  }) async {
    try {
      var reponse = await _dio.get<Object?>(
        chemin,
        queryParameters: parametres,
      );

      // Le jeton d'accès ne vit que quinze minutes. Sans ce rejeu, toute lecture
      // échouerait passé ce délai — définitivement, puisque rien ne relancerait le
      // rafraîchissement : l'écran d'accueil resterait en erreur pour un compte
      // pourtant connecté. Les écritures l'avaient, les lectures non.
      if (reponse.statusCode == 401 && await _rafraichir()) {
        reponse = await _dio.get<Object?>(chemin, queryParameters: parametres);
      }

      _verifier(reponse);

      final cache = _cache;
      if (cacheable && cache != null) {
        // Écriture non attendue, et dont l'échec est avalé. Le cache est une
        // commodité : le faire précéder la réponse rend l'écran tributaire du magasin
        // local, et une écriture lente — ou qui n'aboutit jamais — laisse l'utilisateur
        // devant un indicateur de chargement alors que le serveur a déjà répondu.
        unawaited(
          cache
              .enregistrer(chemin, parametres, reponse.data, DateTime.now())
              .catchError((Object _) {}),
        );
      }

      _etat.signalerEnLigne();
      return analyser(reponse.data);
    } on DioException catch (erreur) {
      final cache = _cache;

      if (!estPanneReseau(erreur) || !cacheable || cache == null) {
        rethrow;
      }

      final entree = await cache.lire(chemin, parametres);

      // Sans entrée en cache, l'échec est propagé tel quel : l'écran affiche son état
      // d'erreur. Inventer une réponse vide laisserait croire à une liste vide, ce qui
      // est un mensonge sur une liste de courses partagée.
      if (entree == null) {
        _etat.signalerHorsLigne();
        rethrow;
      }

      _etat.signalerHorsLigne(fraicheur: entree.recuA);
      return analyser(entree.charge);
    }
  }

  Future<T> post<T>(
    String chemin, {
    Object? corps,
    String? cleIdempotence,
    bool differable = false,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _envoyer(
      () => _dio.post<Object?>(
        chemin,
        data: corps,
        options: Options(
          headers: cleIdempotence == null
              ? null
              // Obligatoire sur les dépenses et les règlements (§8.1) : un double appui
              // ne doit jamais créer deux dépenses.
              : {'Idempotency-Key': cleIdempotence},
        ),
      ),
      differable: differable,
      methode: 'POST',
      chemin: chemin,
      corps: corps,
    );
    return analyser(reponse.data);
  }

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

  Future<T> put<T>(
    String chemin, {
    Object? corps,
    bool differable = false,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _envoyer(
      () => _dio.put<Object?>(chemin, data: corps),
      differable: differable,
      methode: 'PUT',
      chemin: chemin,
      corps: corps,
    );
    return analyser(reponse.data);
  }

  Future<void> delete(String chemin, {bool differable = false}) async {
    await _envoyer(
      () => _dio.delete<Object?>(chemin),
      differable: differable,
      methode: 'DELETE',
      chemin: chemin,
    );
  }

  /// Suppression avec corps. `DELETE /me` exige une confirmation (RG-USR-05).
  Future<void> deleteWithBody(String chemin, {Object? corps}) async {
    await _envoyer(
      () => _dio.delete<Object?>(chemin, data: corps),
      // Jamais différée : une suppression de compte se confirme en connaissance de
      // cause, pas en différé sur un appareil qui n'a plus de réseau.
      differable: false,
      methode: 'DELETE',
      chemin: chemin,
      corps: corps,
    );
  }

  /// Panne réseau, et non refus du serveur.
  ///
  /// Détectée sur l'échec réel de la requête, jamais par une bibliothèque de
  /// connectivité : un wifi capté sans accès à Internet — salle des fêtes, cave,
  /// portail captif — est le cas le plus fréquent pour ce produit, et une telle
  /// bibliothèque le déclare « connecté ».
  static bool estPanneReseau(DioException erreur) =>
      erreur.type == DioExceptionType.connectionError ||
      erreur.type == DioExceptionType.connectionTimeout ||
      erreur.type == DioExceptionType.sendTimeout ||
      erreur.type == DioExceptionType.receiveTimeout;

  /// Rejoue la file, dans l'ordre, en s'arrêtant à la première écriture qui reste.
  ///
  /// L'ordre est significatif : rejouer en parallèle ferait partir un changement de
  /// statut avant l'adhésion qui le rend possible.
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

      // 5xx : panne serveur, pas erreur d'écriture.
      await file.incrementerTentatives(ecriture.id);
      break;
    }

    _etat.majEnAttente((await file.enAttente()).length);

    if (_etat.mode == ModeReseau.rejeuEnCours) {
      _etat.signalerEnLigne();
    }
  }

  /// Envoie une requête, retente une fois après rafraîchissement de la session, et met
  /// en file si le réseau manque et que l'opération le permet.
  ///
  /// Le jeton d'accès ne vit que quinze minutes : sans ce rejeu, l'utilisateur serait
  /// déconnecté au quart d'heure. La tentative de rafraîchissement n'a lieu qu'une
  /// fois, pour ne pas boucler quand la session est réellement expirée.
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

      if (reponse.statusCode == 401 && await _rafraichir()) {
        reponse = await requete();
      }
    } on DioException catch (erreur) {
      final file = _file;

      // La mise en file est déclarée opération par opération, jamais par défaut :
      // POST /events/{id}/invitation/rotate est délibérément non idempotent, et un
      // rejeu invaliderait le lien que l'utilisateur vient de partager.
      if (!differable || file == null || !estPanneReseau(erreur)) {
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

    _verifier(reponse);
    _etat.signalerEnLigne();
    return reponse;
  }

  Future<bool> _rafraichir() async {
    final jeton = await _sessionStore.lireJetonRafraichissement();
    if (jeton == null) {
      return false;
    }

    final reponse = await _dio.post<Object?>(
      '/auth/refresh',
      data: {'refreshToken': jeton},
    );

    if (reponse.statusCode != 200 || reponse.data is! Map<String, dynamic>) {
      // La session est définitivement perdue : l'effacer évite de retenter à chaque
      // appel avec un jeton mort.
      await _sessionStore.effacerSession();
      return false;
    }

    final corps = reponse.data! as Map<String, dynamic>;
    await _sessionStore.enregistrerSession(
      jetonAcces: corps['accessToken'] as String,
      jetonRafraichissement: corps['refreshToken'] as String,
    );

    return true;
  }

  void _verifier(Response<Object?> reponse) {
    final statut = reponse.statusCode ?? 0;

    if (statut >= 200 && statut < 300) {
      return;
    }

    final corps = reponse.data;

    throw corps is Map<String, dynamic>
        ? ApiException.depuisProblemDetails(statut, corps)
        : ApiException(statusCode: statut, title: 'Une erreur est survenue.');
  }
}
