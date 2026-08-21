import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/comptes_api.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/magasin_local_double.dart';
import '../doubles/session_store_double.dart';

/// API de comptes qui ne fait rien, sinon retenir ce qu'on lui demande.
class ComptesApiDouble implements ComptesApi {
  final appels = <String>[];

  @override
  Future<void> deconnecter() async => appels.add('deconnecter');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} hors du périmètre');
}

void main() {
  test('se déconnecter rend la session anonyme', () async {
    // Sans cela l'application se croit encore connectée alors que le serveur a révoqué
    // la session : l'écran de connexion ne s'affiche pas, et il faut recharger la page
    // à la main pour pouvoir se reconnecter.
    final magasin = SessionStoreDouble(
      jetonAcces: 'jeton',
      jetonRafraichissement: 'renouvellement',
    );
    final conteneur = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(magasin),
        magasinLocalProvider.overrideWithValue(MagasinLocalDouble()),
        comptesApiProvider.overrideWithValue(ComptesApiDouble()),
      ],
    );
    addTearDown(conteneur.dispose);

    // Le profil est observé comme le fait n'importe quel écran : c'est cette
    // dépendance-là que la déconnexion doit savoir traverser.
    conteneur.listen(profilProvider, (_, _) {});

    expect(await conteneur.read(sessionProvider.future), EtatSession.connecte);

    await conteneur.read(sessionProvider.notifier).deconnecter();

    expect(conteneur.read(sessionProvider).value, EtatSession.anonyme);
  });
}
