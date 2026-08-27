import '../models/avis.dart';
import 'api_client.dart';

/// Appels d'API des notifications reçues et des préférences (`§8.2`).
class AvisApi {
  const AvisApi(this._client);

  final ApiClient _client;

  /// Une page d'avis : les plus récents, ou ceux qui précèdent [avant].
  ///
  /// La première page est mise en cache : hors ligne, revoir les derniers avis reçus a
  /// du sens, et c'est souvent ce qu'on cherche quand le réseau manque.
  Future<PageAvis> lire({String? avant, int limite = 30}) => _client.get(
    '/notifications?limit=$limite${avant == null ? '' : '&before=$avant'}',
    cacheable: avant == null,
    analyser: (corps) => PageAvis.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Marque un avis comme lu.
  ///
  /// Différable : l'endpoint est idempotent, donc rejouable sans conséquence, et une
  /// notification lue dans le métro doit le rester au retour du réseau
  /// (`NF-OFFLINE-01`).
  Future<void> marquerLu(String id) => _client.post<void>(
    '/notifications/$id/read',
    differable: true,
    analyser: (_) {},
  );

  Future<void> toutMarquerLu() => _client.post<void>(
    '/notifications/read-all',
    differable: true,
    analyser: (_) {},
  );

  Future<List<PreferenceAvis>> preferences() => _client.get(
    '/notifications/preferences',
    analyser: (corps) => (corps! as List<dynamic>)
        .map((e) => PreferenceAvis.depuisJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Différable : le réglage est une valeur, pas un incrément. Le rejeu réécrit la
  /// même chose.
  Future<void> definirPreference(PreferenceAvis preference) =>
      _client.patch<void>(
        '/notifications/preferences',
        differable: true,
        corps: {
          'category': preference.categorie,
          'pushEnabled': preference.poussee,
          'emailEnabled': preference.courriel,
        },
        analyser: (_) {},
      );

  Future<bool> sourdine(String evenementId) => _client.get(
    '/events/$evenementId/mute',
    analyser: (corps) => corps as bool? ?? false,
  );

  Future<void> definirSourdine(
    String evenementId, {
    required bool enSourdine,
  }) => _client.put<void>(
    '/events/$evenementId/mute',
    corps: {'muted': enSourdine},
    differable: true,
    analyser: (_) {},
  );
}
