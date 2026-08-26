import '../models/activite.dart';
import 'api_client.dart';

/// Appels d'API du fil d'activité (`§8.2`).
///
/// Lecture seule : le fil est alimenté par les actions métier, jamais par l'application
/// (`RG-FIL-02`).
class ActiviteApi {
  const ActiviteApi(this._client);

  final ApiClient _client;

  /// Une page du fil : les dernières lignes, ou celles qui précèdent [avant].
  ///
  /// Seule la première page est mise en cache. Le fil est un journal en lecture seule :
  /// hors ligne, montrer les dernières lignes connues suffit, et la suite exige le
  /// réseau. Mettre en cache les pages suivantes obligerait à remplacer
  /// `shared_preferences`, ce qui est un lot en soi — limite consignée au lot 1.12.
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) => _client.get(
    '/events/$evenementId/activity?limit=$limite'
    '${avant == null ? '' : '&before=$avant'}',
    cacheable: avant == null,
    analyser: (corps) =>
        PageActivite.depuisJson(corps! as Map<String, dynamic>),
  );
}
