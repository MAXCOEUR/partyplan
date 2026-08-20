import 'package:partyplan/core/storage/magasin_local.dart';

/// Magasin en mémoire.
///
/// `shared_preferences` passe par un canal de plateforme absent d'un test de widget :
/// sans ce substitut, chaque test échouerait pour une raison étrangère à ce qu'il
/// vérifie.
class MagasinLocalDouble implements MagasinLocal {
  final Map<String, String> contenu = {};

  @override
  Future<String?> lire(String cle) async => contenu[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async => contenu[cle] = valeur;

  @override
  Future<void> supprimer(String cle) async => contenu.remove(cle);

  @override
  Future<Set<String>> cles() async => contenu.keys.toSet();

  @override
  Future<void> supprimerPrefixe(String prefixe) async =>
      contenu.removeWhere((cle, _) => cle.startsWith(prefixe));
}
