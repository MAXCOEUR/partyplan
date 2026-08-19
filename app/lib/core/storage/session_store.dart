import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Conservation du jeton de session.
///
/// Deux natures de jeton coexistent : celui d'un compte, et celui d'un invité sans
/// compte restreint à un seul événement (EF-INV-04). Le second est conservé aussi
/// durablement que le premier : c'est lui qui permet de rattacher la participation à un
/// compte créé plus tard (RG-AUTH-07). Le perdre, c'est perdre les dépenses saisies.
class SessionStore {
  const SessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _cleAcces = 'pp_access_token';
  static const _cleRafraichissement = 'pp_refresh_token';
  static const _cleInvite = 'pp_guest_token';

  Future<String?> lireJetonAcces() => _storage.read(key: _cleAcces);

  Future<String?> lireJetonRafraichissement() =>
      _storage.read(key: _cleRafraichissement);

  Future<String?> lireJetonInvite() => _storage.read(key: _cleInvite);

  Future<void> enregistrerSession({
    required String jetonAcces,
    required String jetonRafraichissement,
  }) async {
    await _storage.write(key: _cleAcces, value: jetonAcces);
    await _storage.write(
      key: _cleRafraichissement,
      value: jetonRafraichissement,
    );
  }

  Future<void> enregistrerJetonInvite(String jeton) =>
      _storage.write(key: _cleInvite, value: jeton);

  /// Efface la session de compte. Le jeton d'invité est délibérément conservé : se
  /// déconnecter d'un compte ne doit pas faire perdre l'accès à un événement rejoint
  /// sans compte.
  Future<void> effacerSession() async {
    await _storage.delete(key: _cleAcces);
    await _storage.delete(key: _cleRafraichissement);
  }

  Future<void> toutEffacer() => _storage.deleteAll();
}
