import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'network/api_client.dart';
import 'storage/session_store.dart';

/// Dépendances partagées de l'application.
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => SessionStore(ref.watch(secureStorageProvider)),
);

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(sessionStoreProvider)),
);

/// État d'authentification. Trois cas distincts, et non un simple booléen : un invité
/// sans compte est authentifié pour un événement, et pour un seul (EF-INV-04).
enum EtatSession { inconnu, anonyme, invite, connecte }

final etatSessionProvider = FutureProvider<EtatSession>((ref) async {
  final store = ref.watch(sessionStoreProvider);

  if (await store.lireJetonAcces() != null) {
    return EtatSession.connecte;
  }

  if (await store.lireJetonInvite() != null) {
    return EtatSession.invite;
  }

  return EtatSession.anonyme;
});
