import 'package:partyplan/core/models/activite.dart';
import 'package:partyplan/core/network/activite_api.dart';

/// Fil d'activité contrôlé, pour les écrans qui en dépendent sans l'éprouver.
///
/// Substituée au client d'API plutôt qu'au provider : `filActiviteProvider` est un
/// notifier paginé, et le remplacer par une valeur fixe priverait les tests du
/// comportement réel de chargement.
class ActiviteApiDouble implements ActiviteApi {
  ActiviteApiDouble({this.lignes = const [], this.encore = false});

  final List<Activite> lignes;
  final bool encore;

  @override
  Future<PageActivite> lire(
    String evenementId, {
    String? avant,
    int limite = 30,
  }) async => PageActivite(lignes: lignes, encore: encore);
}
