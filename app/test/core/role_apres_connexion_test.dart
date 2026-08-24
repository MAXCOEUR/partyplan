import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/providers.dart';

import '../doubles/session_store_double.dart';

String _jetonAvecRole(String role) {
  String segment(Map<String, Object?> contenu) =>
      base64Url.encode(utf8.encode(jsonEncode(contenu))).replaceAll('=', '');

  return '${segment({'alg': 'RS256'})}'
      '.${segment({'pp:platform_role': role})}.signature';
}

void main() {
  test('le rôle suit la session, il ne reste pas celui d’avant la connexion', () async {
    // Au lancement, personne n'est connecté : le rôle lu est celui d'un compte
    // ordinaire. Si le provider s'arrête là, l'administrateur qui se connecte ensuite
    // ne voit jamais son entrée du back-office — c'était le cas.
    final magasin = SessionStoreDouble();
    final conteneur = ProviderContainer(
      overrides: [sessionStoreProvider.overrideWithValue(magasin)],
    );
    addTearDown(conteneur.dispose);

    // La session est déterminée avant ses consommateurs, comme au démarrage réel.
    // L'ancien second accès au stockage invité masquait cette synchronisation dans
    // le test en laissant au provider de rôle le temps de terminer le premier.
    expect(await conteneur.read(sessionProvider.future), EtatSession.anonyme);
    expect(await conteneur.read(rolePlateformeProvider.future), 'User');

    magasin.jetonAcces = _jetonAvecRole('PlatformAdmin');
    conteneur.read(sessionProvider.notifier).state = const AsyncData(
      EtatSession.connecte,
    );

    expect(
      await conteneur.read(rolePlateformeProvider.future),
      'PlatformAdmin',
    );
  });
}
