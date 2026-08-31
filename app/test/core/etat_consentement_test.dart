import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/etat_consentement.dart';
import 'package:partyplan/core/notifications/service_notifications.dart';
import 'package:partyplan/core/storage/magasin_local.dart';

/// Où en est le consentement, vu de l'application.
///
/// Le plugin Firebase ne sait pas répondre à cette question sur Android : sa méthode
/// `getPermissions` renvoie 1 si la permission est accordée et 0 dans tous les autres
/// cas, ce que la couche Dart traduit en `denied`. « Jamais demandé » et « refusé »
/// arrivent donc indistinguables — et c'est précisément la distinction dont dépend
/// l'affichage de la proposition. L'application s'en souvient donc elle-même.
void main() {
  group('Résolution de l’état', () {
    test('jamais demandé et non autorisé : il reste à demander', () {
      // Le cas qui rendait la carte invisible sur Android, donc la permission
      // impossible à accorder : le seul bouton capable d'ouvrir la boîte système était
      // caché par l'absence de la permission qu'il sert à obtenir.
      expect(
        EtatConsentement.resoudre(
          firebaseDisponible: true,
          autorise: false,
          dejaDemande: false,
        ),
        EtatNotifications.aDemander,
      );
    });

    test('déjà demandé et toujours pas autorisé : c’est un refus', () {
      // Redemander serait un bouton sans effet : Android ne représente jamais la boîte.
      expect(
        EtatConsentement.resoudre(
          firebaseDisponible: true,
          autorise: false,
          dejaDemande: true,
        ),
        EtatNotifications.refuse,
      );
    });

    test('autorisé : accordé, que la demande soit mémorisée ou non', () {
      // Une installation restaurée peut avoir la permission sans le souvenir de la
      // demande. C'est le système qui fait foi.
      for (final memoire in [true, false]) {
        expect(
          EtatConsentement.resoudre(
            firebaseDisponible: true,
            autorise: true,
            dejaDemande: memoire,
          ),
          EtatNotifications.accorde,
        );
      }
    });

    test('sans Firebase, rien n’est possible et rien n’est proposé', () {
      // Règle 5 : un clone sans compte Firebase reste utilisable.
      expect(
        EtatConsentement.resoudre(
          firebaseDisponible: false,
          autorise: false,
          dejaDemande: false,
        ),
        EtatNotifications.indisponible,
      );
    });
  });

  group('Mémoire de la demande', () {
    test('rien n’est mémorisé au premier lancement', () async {
      final memoire = MemoireConsentement(_MagasinDouble());

      expect(await memoire.dejaDemande(), isFalse);
    });

    test('la demande une fois posée est retenue', () async {
      final magasin = _MagasinDouble();
      final memoire = MemoireConsentement(magasin);

      await memoire.marquerDemande();

      expect(await memoire.dejaDemande(), isTrue);
      // Le souvenir survit à un redémarrage : c'est tout son intérêt.
      expect(await MemoireConsentement(magasin).dejaDemande(), isTrue);
    });

    test('un magasin en panne ne bloque pas la proposition', () async {
      // Perdre le souvenir doit conduire à reproposer, jamais à taire : une carte de
      // trop se referme, une carte manquante ne se découvre pas.
      final memoire = MemoireConsentement(_MagasinEnPanne());

      expect(await memoire.dejaDemande(), isFalse);
      await memoire.marquerDemande();
    });
  });
}

class _MagasinDouble implements MagasinLocal {
  final _valeurs = <String, String>{};

  @override
  Future<String?> lire(String cle) async => _valeurs[cle];

  @override
  Future<void> ecrire(String cle, String valeur) async =>
      _valeurs[cle] = valeur;

  @override
  Future<void> supprimer(String cle) async => _valeurs.remove(cle);

  @override
  Future<Set<String>> cles() async => _valeurs.keys.toSet();

  @override
  Future<void> supprimerPrefixe(String prefixe) async =>
      _valeurs.removeWhere((cle, _) => cle.startsWith(prefixe));
}

class _MagasinEnPanne implements MagasinLocal {
  @override
  Future<String?> lire(String cle) async => throw Exception('disque plein');

  @override
  Future<void> ecrire(String cle, String valeur) async =>
      throw Exception('disque plein');

  @override
  Future<void> supprimer(String cle) async => throw Exception('disque plein');

  @override
  Future<Set<String>> cles() async => throw Exception('disque plein');

  @override
  Future<void> supprimerPrefixe(String prefixe) async =>
      throw Exception('disque plein');
}
