import '../models/sondage.dart';
import 'api_client.dart';

/// Appels d'API des sondages (§8.2).
class SondagesApi {
  const SondagesApi(this._client);

  final ApiClient _client;

  String _base(String evenementId) => '/events/$evenementId/polls';

  Future<PageSondages> lister(String evenementId) => _client.get(
    _base(evenementId),
    // Jamais en cache : un décompte servi depuis le disque afficherait un résultat
    // périmé comme s'il était à jour, ce qui est pire que rien sur un vote.
    cacheable: false,
    analyser: (corps) =>
        PageSondages.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<Sondage> creer(
    String evenementId, {
    required String question,
    required List<String> options,
    bool choixMultiple = false,
  }) => _client.post(
    _base(evenementId),
    corps: {
      'question': question,
      'options': options,
      'allowMultiple': choixMultiple,
    },
    analyser: (corps) => Sondage.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Enregistre ses choix, en remplaçant les précédents.
  ///
  /// Une liste vide annule son vote : c'est le geste de qui s'est trompé, et il ne
  /// mérite pas un appel de plus.
  Future<Sondage> voter(
    String evenementId,
    String sondageId, {
    required List<String> optionIds,
  }) => _client.put(
    '${_base(evenementId)}/$sondageId/votes',
    corps: {'optionIds': optionIds},
    analyser: (corps) => Sondage.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<Sondage> clore(String evenementId, String sondageId) => _client.post(
    '${_base(evenementId)}/$sondageId/close',
    analyser: (corps) => Sondage.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<void> supprimer(String evenementId, String sondageId) =>
      _client.delete('${_base(evenementId)}/$sondageId');
}
