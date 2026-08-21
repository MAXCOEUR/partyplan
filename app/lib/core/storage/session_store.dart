import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Conservation des jetons de session du compte.
class SessionStore {
  const SessionStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _cleAcces = 'pp_access_token';
  static const _cleRafraichissement = 'pp_refresh_token';

  Future<String?> lireJetonAcces() => _storage.read(key: _cleAcces);

  Future<String?> lireJetonRafraichissement() =>
      _storage.read(key: _cleRafraichissement);

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

  /// Efface la session de compte.
  Future<void> effacerSession() async {
    await _storage.delete(key: _cleAcces);
    await _storage.delete(key: _cleRafraichissement);
  }

  Future<void> toutEffacer() => _storage.deleteAll();
}
