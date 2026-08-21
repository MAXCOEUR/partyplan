import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/session/role_plateforme.dart';

/// Fabrique un jeton d'accès de la forme émise par l'API : trois segments séparés par
/// des points, la charge utile en base64url sans remplissage.
String _jeton(Map<String, Object?> charge) {
  String segment(Map<String, Object?> contenu) =>
      base64Url.encode(utf8.encode(jsonEncode(contenu))).replaceAll('=', '');

  return '${segment({'alg': 'RS256'})}.${segment(charge)}.signature';
}

void main() {
  group('rolePlateformeDuJeton', () {
    test('lit le rôle porté par le jeton', () {
      expect(
        rolePlateformeDuJeton(_jeton({'pp:platform_role': 'PlatformAdmin'})),
        'PlatformAdmin',
      );
    });

    test('sans revendication de rôle, le compte est ordinaire', () {
      expect(rolePlateformeDuJeton(_jeton({'sub': 'u1'})), 'User');
    });

    test('sans jeton, le compte est ordinaire', () {
      expect(rolePlateformeDuJeton(null), 'User');
      expect(rolePlateformeDuJeton(''), 'User');
    });

    test('un jeton illisible ne fait pas tomber l’écran', () {
      // Un jeton tronqué par un stockage local corrompu ne doit pas empêcher
      // l'application de démarrer : au pire, l'entrée du back-office manque.
      expect(rolePlateformeDuJeton('nimportequoi'), 'User');
      expect(rolePlateformeDuJeton('a.b.c'), 'User');
    });

    test('le personnel plateforme se distingue du compte ordinaire', () {
      expect(estPersonnelPlateforme('PlatformAdmin'), isTrue);
      expect(estPersonnelPlateforme('Support'), isTrue);
      expect(estPersonnelPlateforme('User'), isFalse);
    });
  });
}
