import 'api_client.dart';

/// Appels d'API des appareils recevant les notifications.
///
/// Écrit à la main comme les autres clients du dépôt : deux endpoints ne justifient pas
/// une chaîne de génération.
class AppareilsApi {
  const AppareilsApi(this._client);

  final ApiClient _client;

  /// Inscrit l'appareil courant. Idempotent côté serveur : appelable à chaque lancement
  /// et à chaque rafraîchissement de jeton, sans précaution.
  Future<void> enregistrer(String jeton, {required String plateforme}) =>
      _client.post<void>(
        '/me/devices',
        corps: {'token': jeton, 'platform': plateforme},
        analyser: (_) {},
      );

  /// Retire l'appareil. Le jeton est échappé : un jeton FCM contient « : », qui
  /// découperait le chemin.
  Future<void> retirer(String jeton) =>
      _client.delete('/me/devices/${Uri.encodeComponent(jeton)}');
}
