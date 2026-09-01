@Tags(['reel'])
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/network/api_client.dart';
import 'package:partyplan/core/network/api_exception.dart';

import '../test/doubles/session_store_double.dart';

/// Vérification contre l'API réellement démarrée en local (`make up`).
///
/// Hors de `test/`, donc hors de `make verif` : elle exige un serveur, ce qu'aucune
/// suite automatique ne doit supposer. C'est la contrepartie des tests à faux serveur —
/// eux décrivent ce que le client doit faire, celle-ci constate ce qui se passe face à
/// la rotation telle que l'API la pratique réellement.
const _racine = 'http://localhost:5080/v1';

/// Nombre de cycles. Une seule exécution ne prouve rien : sur boucle locale l'ordre
/// d'arrivée des deux réponses est souvent stable, et la course ne se manifeste qu'à
/// l'occasion.
const _cycles = 15;

/// Renouvelle en écartant la limite de débit.
///
/// Un 429 n'est pas une session perdue. Les confondre fausserait toute la mesure : on
/// conclurait à la course là où le serveur a simplement dit « trop vite ».
Future<Response<Map<String, dynamic>>> _refraichirHorsLimite(
  Dio brut,
  String jeton,
) async {
  for (var essai = 0; essai < 5; essai++) {
    final reponse = await brut.post<Map<String, dynamic>>(
      '$_racine/auth/refresh',
      data: {'refreshToken': jeton},
    );

    if (reponse.statusCode != 429) {
      return reponse;
    }

    await Future<void>.delayed(const Duration(seconds: 12));
  }

  throw StateError('limite de débit persistante : mesure non concluante');
}

void main() {
  test('des lectures parallèles répétées ne tuent jamais la session', () async {
    final brut = Dio(BaseOptions(validateStatus: (_) => true));

    // Une seule inscription : `/auth/register` est plafonné à vingt par minute, et une
    // inscription par cycle ferait échouer la boucle sur la limite de débit — un échec
    // qu'on prendrait à tort pour la course qu'on cherche.
    final ouverture = await brut.post<Map<String, dynamic>>(
      '$_racine/auth/register',
      data: {
        'email': 'reel-${DateTime.now().microsecondsSinceEpoch}@partyplan.test',
        'password': 'MotDePasseDeVerification1!',
        'displayName': 'Vérification',
      },
    );

    if (ouverture.statusCode == 429) {
      markTestSkipped('inscription limitée en débit : non concluant');
      return;
    }

    expect(ouverture.statusCode, 200, reason: 'inscription impossible');

    final sessions = SessionStoreDouble(
      jetonRafraichissement: ouverture.data!['refreshToken'] as String,
    );

    final client = ApiClient(
      sessions,
      dio: Dio(BaseOptions(baseUrl: _racine, validateStatus: (_) => true)),
    );

    final pertes = <String>[];

    for (var cycle = 0; cycle < _cycles; cycle++) {
      // Un jeton d'accès invalide vaut jeton expiré du point de vue du serveur : c'est
      // la situation du lancement du lendemain matin.
      sessions.jetonAcces = 'jeton-perime';

      // Ce que fait l'application au lancement : la liste des soirées et le centre de
      // notifications partent ensemble.
      try {
        await Future.wait([
          client.get<Object?>('/events', cacheable: false, analyser: (c) => c),
          client.get<Object?>(
            '/notifications',
            cacheable: false,
            analyser: (c) => c,
          ),
        ]);
      } on ApiException catch (erreur) {
        // Un 429 n'est pas une session perdue : la mesure s'arrête sans conclure,
        // plutôt que d'imputer à la course ce que le serveur a refusé pour cadence.
        if (erreur.statusCode == 429) {
          markTestSkipped('limite de débit au cycle $cycle : non concluant');
          return;
        }

        pertes.add('cycle $cycle, lecture : $erreur');
        break;
      } on Object catch (erreur) {
        pertes.add('cycle $cycle, lecture : $erreur');
        break;
      }

      // Le point décisif : le jeton conservé après la course doit encore valoir quelque
      // chose. C'est là que la session mourait en silence, pour n'échouer qu'au
      // lancement suivant. La réponse sert de jeton au cycle suivant.
      final controle = await _refraichirHorsLimite(
        brut,
        sessions.jetonRafraichissement!,
      );

      if (controle.statusCode == 429) {
        markTestSkipped('limite de débit au contrôle $cycle : non concluant');
        return;
      }

      if (controle.statusCode != 200) {
        pertes.add('cycle $cycle, contrôle : ${controle.statusCode}');
        break;
      }

      sessions.jetonRafraichissement = controle.data!['refreshToken'] as String;
    }

    expect(pertes, isEmpty);
  });

  test(
    'un jeton de rafraîchissement révoqué conduit à la perte de session',
    () async {
      var perdue = false;

      final client = ApiClient(
        SessionStoreDouble(
          jetonAcces: 'jeton-perime',
          jetonRafraichissement: 'jeton-qui-n-a-jamais-existe',
        ),
        dio: Dio(BaseOptions(baseUrl: _racine, validateStatus: (_) => true)),
        auSessionPerdue: () => perdue = true,
      );

      await expectLater(
        client.get<Object?>(
          '/events',
          cacheable: false,
          analyser: (corps) => corps,
        ),
        throwsA(isA<Object>()),
      );

      expect(perdue, isTrue);
    },
  );
}
