import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/notifications/notification_recue.dart';
import 'package:partyplan/core/notifications/regle_affichage_premier_plan.dart';
import 'package:partyplan/core/notifications/zone_visible.dart';

/// La table de suppression, ligne à ligne.
///
/// Une table se teste ligne à ligne : la ligne oubliée est précisément celle qui se
/// trompera, et une notification indûment masquée ne laisse aucune trace visible.
void main() {
  group('Affichage au premier plan', () {
    group('dans une soirée, l’écran qui montre déjà la chose la masque', () {
      test('la discussion masque un message', () {
        expect(
          _doitAfficher(
            categorie: 'discussion.message',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isFalse,
        );
      });

      test('la discussion masque une mention', () {
        expect(
          _doitAfficher(
            categorie: 'discussion.mention',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isFalse,
        );
      });

      test('la discussion masque un sondage, qui y paraît aussi', () {
        // Un sondage créé s'annonce dans le fil de discussion autant que dans l'écran
        // des sondages : il est déjà sous les yeux dans les deux cas.
        expect(
          _doitAfficher(
            categorie: 'poll.new',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isFalse,
        );
      });

      test('les dépenses masquent une dépense', () {
        expect(
          _doitAfficher(
            categorie: 'expense.new',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.depenses),
          ),
          isFalse,
        );
      });

      test('les courses masquent un article non attribué', () {
        expect(
          _doitAfficher(
            categorie: 'shopping.unclaimed',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.courses),
          ),
          isFalse,
        );
      });

      test('l’écran des sondages masque un sondage', () {
        expect(
          _doitAfficher(
            categorie: 'poll.new',
            soiree: '42',
            zone: const ZoneVisible(chemin: '/events/42/sondages'),
          ),
          isFalse,
        );
      });

      test('le fil d’activité masque une activité', () {
        expect(
          _doitAfficher(
            categorie: 'activity',
            soiree: '42',
            zone: const ZoneVisible(chemin: '/events/42/activite'),
          ),
          isFalse,
        );
      });

      test('l’écran des notifications les masque toutes', () {
        for (final categorie in const [
          'discussion.message',
          'expense.new',
          'balance.due',
          'event.changed',
        ]) {
          expect(
            _doitAfficher(
              categorie: categorie,
              soiree: '42',
              zone: const ZoneVisible(chemin: '/notifications'),
            ),
            isFalse,
            reason: '$categorie est déjà dans la liste qu’on regarde',
          );
        }
      });
    });

    group('ce qui s’affiche toujours', () {
      test('une notification d’une autre soirée', () {
        // Être dans la discussion de la crémaillère ne doit rien masquer du week-end à
        // la montagne. C'est la clause qui distingue « par écran » de « par soirée ».
        expect(
          _doitAfficher(
            categorie: 'discussion.message',
            soiree: '77',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isTrue,
        );
      });

      test('une catégorie sans écran qui la rende redondante', () {
        for (final categorie in const [
          'balance.due',
          'invitation.answer',
          'invitation.pending',
          'event.changed',
          'event.starting_soon',
        ]) {
          expect(
            _doitAfficher(
              categorie: categorie,
              soiree: '42',
              zone: _soiree('42', ZoneEvenement.discussion),
            ),
            isTrue,
            reason: 'aucun écran ne montre déjà $categorie',
          );
        }
      });

      test('une catégorie inconnue de la table', () {
        // Le défaut d'une table de suppression doit être de ne rien supprimer : sinon
        // toute catégorie ajoutée demain naît muette, et personne ne s'en aperçoit.
        expect(
          _doitAfficher(
            categorie: 'course.aux.tresors',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isTrue,
        );
      });

      test('une notification sans catégorie', () {
        expect(
          _doitAfficher(
            categorie: null,
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isTrue,
        );
      });

      test('un message reçu depuis un autre onglet de la même soirée', () {
        expect(
          _doitAfficher(
            categorie: 'discussion.message',
            soiree: '42',
            zone: _soiree('42', ZoneEvenement.depenses),
          ),
          isTrue,
        );
      });

      test('un message reçu depuis l’accueil', () {
        expect(
          _doitAfficher(
            categorie: 'discussion.message',
            soiree: '42',
            zone: const ZoneVisible(chemin: '/'),
          ),
          isTrue,
        );
      });

      test('une notification de soirée reçue sur un écran de profil', () {
        expect(
          _doitAfficher(
            categorie: 'expense.new',
            soiree: '42',
            zone: const ZoneVisible(chemin: '/profil/notifications'),
          ),
          isTrue,
        );
      });

      test('une notification sans soirée, sur l’écran d’une soirée', () {
        // Sans identifiant, rien ne permet d'affirmer qu'elle concerne ce qui est à
        // l'écran. On affiche : le doute profite à l'affichage.
        expect(
          _doitAfficher(
            categorie: 'activity',
            soiree: null,
            zone: _soiree('42', ZoneEvenement.discussion),
          ),
          isTrue,
        );
      });
    });
  });

  _zoneComposee();
}

void _zoneComposee() {
  group('Composition de la zone', () {
    test('retient l’onglet publié pour la soirée affichée', () {
      final zone = ZoneVisible.composer(
        chemin: '/events/42',
        publie: (evenementId: '42', onglet: ZoneEvenement.discussion),
      );

      expect(zone.onglet, ZoneEvenement.discussion);
      expect(zone.evenementId, '42');
    });

    test('ignore l’onglet publié pour une autre soirée', () {
      // En passant d'une soirée à l'autre, l'onglet de la précédente reste inscrit le
      // temps que la nouvelle coquille publie le sien. Sans cette vérification, il
      // masquerait à tort les notifications de la nouvelle.
      final zone = ZoneVisible.composer(
        chemin: '/events/77',
        publie: (evenementId: '42', onglet: ZoneEvenement.discussion),
      );

      expect(zone.onglet, isNull);
    });

    test('ignore l’onglet publié hors de toute soirée', () {
      final zone = ZoneVisible.composer(
        chemin: '/',
        publie: (evenementId: '42', onglet: ZoneEvenement.discussion),
      );

      expect(zone.onglet, isNull);
      expect(zone.evenementId, isNull);
    });

    test('lit la soirée d’un écran poussé', () {
      expect(
        const ZoneVisible(chemin: '/events/42/sondages').evenementId,
        '42',
      );
    });
  });
}

ZoneVisible _soiree(String id, ZoneEvenement onglet) =>
    ZoneVisible(chemin: '/events/$id', onglet: onglet);

bool _doitAfficher({
  required String? categorie,
  required String? soiree,
  required ZoneVisible zone,
}) => RegleAffichagePremierPlan.doitAfficher(
  NotificationRecue(
    titre: 'Titre',
    corps: 'Corps',
    categorie: categorie,
    evenementId: soiree,
    destination: null,
  ),
  zone,
);
