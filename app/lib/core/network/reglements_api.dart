import '../models/reglement.dart';
import 'api_client.dart';
import 'cle_idempotence.dart';

/// Appels d'API des remboursements (§8.2).
///
/// Aucun solde n'est calculé ni conservé ici : tout vient du serveur, recalculé à la
/// demande (`RG-RMB-02`). L'ordre d'affichage est celui de l'émission (`RG-CALC-01`) :
/// les listes ne sont jamais retriées côté application, faute de quoi deux personnes
/// verraient les mêmes règlements dans deux ordres différents.
class ReglementsApi {
  const ReglementsApi(this._client);

  final ApiClient _client;

  String _base(String evenementId) => '/events/$evenementId/settlements';

  Future<PageReglements> lire(String evenementId) => _client.get(
    _base(evenementId),
    analyser: (corps) =>
        PageReglements.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Marque un remboursement comme effectué (`EF-RMB-03`).
  Future<void> marquerEffectue(
    String evenementId, {
    required String deMembreId,
    required String versMembreId,
    required double montant,
  }) => _client.post<void>(
    _base(evenementId),
    corps: {
      'fromMemberId': deMembreId,
      'toMemberId': versMembreId,
      'amount': montant,
    },
    cleIdempotence: nouvelleCleIdempotence(),
    analyser: (_) {},
  );

  /// Annule un marquage (`EF-RMB-04`).
  Future<void> annuler(String evenementId, String reglementId) =>
      _client.delete('${_base(evenementId)}/$reglementId');
}
