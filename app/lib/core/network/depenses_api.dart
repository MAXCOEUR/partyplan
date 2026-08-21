import '../models/depense.dart';
import 'api_client.dart';
import 'cle_idempotence.dart';

/// Appels d'API des dépenses (§8.2).
///
/// Aucun calcul de répartition n'est fait ici : le serveur est seul juge, y compris
/// pour les centimes (`§6.2`). Répartir aussi côté application créerait une seconde
/// source de vérité, et la moindre divergence resterait invisible jusqu'au litige.
class DepensesApi {
  const DepensesApi(this._client);

  final ApiClient _client;

  String _base(String evenementId) => '/events/$evenementId/expenses';

  Future<PageDepenses> lister(String evenementId) => _client.get(
    _base(evenementId),
    analyser: (corps) =>
        PageDepenses.depuisJson(corps! as Map<String, dynamic>),
  );

  Future<DetailDepense> detail(String evenementId, String depenseId) =>
      _client.get(
        '${_base(evenementId)}/$depenseId',
        analyser: (corps) =>
            DetailDepense.depuisJson(corps! as Map<String, dynamic>),
      );

  /// Crée une dépense (`EF-DEP-01`).
  ///
  /// [payeurMembreId] laissé nul désigne l'appelant. On saisit souvent la dépense d'un
  /// autre — « c'est Lucas qui a payé le taxi » — et sans ce champ le solde serait
  /// faux pour deux personnes.
  ///
  /// [parts] n'est transmis qu'en mode sélection ou parts personnalisées : envoyer une
  /// liste vide avec « tous les présents » ferait refuser la dépense pour assiette
  /// vide.
  Future<DetailDepense> creer(
    String evenementId, {
    required String libelle,
    required double montant,
    required ModeAssiette mode,
    String? payeurMembreId,
    DateTime? date,
    List<PartDemandee>? parts,
  }) => _client.post(
    _base(evenementId),
    corps: _corps(
      libelle: libelle,
      montant: montant,
      mode: mode,
      payeurMembreId: payeurMembreId,
      date: date,
      parts: parts,
    ),
    cleIdempotence: nouvelleCleIdempotence(),
    analyser: (corps) =>
        DetailDepense.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Modifie une dépense (`EF-DEP-03`). L'état précédent est conservé côté serveur
  /// (`RG-DEP-04`).
  Future<DetailDepense> modifier(
    String evenementId,
    String depenseId, {
    required String libelle,
    required double montant,
    required ModeAssiette mode,
    String? payeurMembreId,
    DateTime? date,
    List<PartDemandee>? parts,
  }) => _client.patch(
    '${_base(evenementId)}/$depenseId',
    corps: _corps(
      libelle: libelle,
      montant: montant,
      mode: mode,
      payeurMembreId: payeurMembreId,
      date: date,
      parts: parts,
    ),
    analyser: (corps) =>
        DetailDepense.depuisJson(corps! as Map<String, dynamic>),
  );

  /// Supprime une dépense. La trace subsiste côté serveur et les soldes sont recalculés
  /// (`RG-DEP-05`).
  Future<void> supprimer(String evenementId, String depenseId) =>
      _client.delete('${_base(evenementId)}/$depenseId');

  static Map<String, dynamic> _corps({
    required String libelle,
    required double montant,
    required ModeAssiette mode,
    required String? payeurMembreId,
    required DateTime? date,
    required List<PartDemandee>? parts,
  }) => {
    'label': libelle,
    'amount': montant,
    'mode': mode.versApi,
    'paidByMemberId': ?payeurMembreId,
    if (date != null) 'spentAt': date.toUtc().toIso8601String(),
    if (mode != ModeAssiette.tousLesPresents && parts != null)
      'shares': [for (final part in parts) part.versJson()],
  };
}
