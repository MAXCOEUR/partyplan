import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/session_store.dart';
import 'api_exception.dart';

/// Client HTTP de l'API.
///
/// Un seul point de sortie réseau : jeton, corrélation, idempotence et traduction des
/// erreurs y sont traités une fois pour toutes. Dispersés dans les écrans, ces
/// traitements finiraient par différer d'un appel à l'autre.
class ApiClient {
  ApiClient(this._sessionStore, {Dio? dio})
    : _dio =
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

  Future<T> get<T>(
    String chemin, {
    Map<String, dynamic>? parametres,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _dio.get<Object?>(
      chemin,
      queryParameters: parametres,
    );
    _verifier(reponse);
    return analyser(reponse.data);
  }

  Future<T> post<T>(
    String chemin, {
    Object? corps,
    String? cleIdempotence,
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
    );
    return analyser(reponse.data);
  }

  Future<T> patch<T>(
    String chemin, {
    Object? corps,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _envoyer(
      () => _dio.patch<Object?>(chemin, data: corps),
    );
    return analyser(reponse.data);
  }

  Future<T> put<T>(
    String chemin, {
    Object? corps,
    required T Function(Object? corps) analyser,
  }) async {
    final reponse = await _envoyer(
      () => _dio.put<Object?>(chemin, data: corps),
    );
    return analyser(reponse.data);
  }

  Future<void> delete(String chemin) async {
    await _envoyer(() => _dio.delete<Object?>(chemin));
  }

  /// Suppression avec corps. `DELETE /me` exige une confirmation (RG-USR-05).
  Future<void> deleteWithBody(String chemin, {Object? corps}) async {
    await _envoyer(() => _dio.delete<Object?>(chemin, data: corps));
  }

  /// Envoie une requête et retente une fois après rafraîchissement de la session.
  ///
  /// Le jeton d'accès ne vit que quinze minutes : sans ce rejeu, l'utilisateur serait
  /// déconnecté au quart d'heure. La tentative de rafraîchissement n'a lieu qu'une
  /// fois, pour ne pas boucler quand la session est réellement expirée.
  Future<Response<Object?>> _envoyer(
    Future<Response<Object?>> Function() requete,
  ) async {
    var reponse = await requete();

    if (reponse.statusCode == 401 && await _rafraichir()) {
      reponse = await requete();
    }

    _verifier(reponse);
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
