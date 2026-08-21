import 'package:partyplan/core/storage/session_store.dart';

/// Stockage de session en mémoire.
///
/// Le stockage sécurisé de la plateforme n'existe pas dans un test de widget : sans ce
/// substitut, chaque test échouerait sur un canal de plateforme absent, pour une raison
/// étrangère à ce qu'il vérifie.
class SessionStoreDouble implements SessionStore {
  SessionStoreDouble({this.jetonAcces, this.jetonRafraichissement});

  String? jetonAcces;
  String? jetonRafraichissement;

  @override
  Future<String?> lireJetonAcces() async => jetonAcces;

  @override
  Future<String?> lireJetonRafraichissement() async => jetonRafraichissement;

  @override
  Future<void> enregistrerSession({
    required String jetonAcces,
    required String jetonRafraichissement,
  }) async {
    this.jetonAcces = jetonAcces;
    this.jetonRafraichissement = jetonRafraichissement;
  }

  @override
  Future<void> effacerSession() async {
    jetonAcces = null;
    jetonRafraichissement = null;
  }

  @override
  Future<void> toutEffacer() async {
    await effacerSession();
  }
}
