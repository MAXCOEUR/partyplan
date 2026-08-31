import 'package:partyplan/core/models/avis.dart';
import 'package:partyplan/core/network/avis_api.dart';

/// Client d'API des avis contrôlé, pour les écrans qui en dépendent sans réseau.
///
/// Ne couvre que ce que les écrans de test exercent réellement : la seule méthode
/// éprouvée par l'écran de réglage par soirée est `definirPreferenceDeSoiree`, dont
/// chaque appel est consigné dans [ecrits]. Les autres retombent sur une valeur vide
/// plutôt que de lever, pour ne pas casser un écran qui les appellerait en marge du
/// scénario testé.
class AvisApiDouble implements AvisApi {
  /// Chaque écriture posée pour une soirée : catégorie, valeur envoyée. `null` signale
  /// un retrait d'écart (« Comme mes réglages habituels »).
  final ecrits = <(String, bool?)>[];

  /// Catégories dont l'écriture échoue systématiquement, pour simuler une coupure
  /// réseau sur une seule des deux préférences de la discussion.
  final categoriesEnEchec = <String>{};

  @override
  Future<void> definirPreferenceDeSoiree(
    String evenementId,
    String categorie,
    bool? actif,
  ) async {
    if (categoriesEnEchec.contains(categorie)) {
      throw Exception('échec simulé pour $categorie');
    }

    ecrits.add((categorie, actif));
  }

  @override
  Future<List<PreferenceDeSoiree>> preferencesDeSoiree(
    String evenementId,
  ) async => const [];

  @override
  Future<void> definirPreference(PreferenceAvis preference) async {}

  @override
  Future<void> definirSourdine(
    String evenementId, {
    required bool enSourdine,
  }) async {}

  @override
  Future<PageAvis> lire({String? avant, int limite = 30}) async =>
      PageAvis.vide;

  @override
  Future<void> marquerLu(String id) async {}

  @override
  Future<List<PreferenceAvis>> preferences() async => const [];

  @override
  Future<bool> sourdine(String evenementId) async => false;

  @override
  Future<void> toutMarquerLu() async {}
}
