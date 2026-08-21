import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/features/courses/nombre_saisi.dart';

void main() {
  group('Saisie de nombres', () {
    test('la virgule décimale est acceptée', () {
      // C'est ce que produit un clavier français, et double.tryParse la refuse.
      expect(nombreDepuisTexte('30,50'), 30.5);
      expect(nombreDepuisTexte('30.50'), 30.5);
    });

    test('les espaces de saisie sont ignorés', () {
      expect(nombreDepuisTexte(' 24 '), 24);
      expect(nombreDepuisTexte('1 200'), 1200);
    });

    test('un champ vide ou illisible ne vaut rien', () {
      expect(nombreDepuisTexte(''), isNull);
      expect(nombreDepuisTexte('  '), isNull);
      expect(nombreDepuisTexte('abc'), isNull);
      expect(nombreDepuisTexte(null), isNull);
    });

    test('une quantité entière s’affiche sans décimale', () {
      expect(nombreVersTexte(24), '24');
      expect(nombreVersTexte(1.5), '1,5');
    });

    test('un montant garde ses deux décimales', () {
      // « 28,4 » pour un prix paraît amputé, et laisse douter du chiffre.
      expect(montantVersTexte(28.4), '28,40');
      expect(montantVersTexte(180), '180,00');
      expect(montantVersTexte(0.5), '0,50');
    });
  });
}
