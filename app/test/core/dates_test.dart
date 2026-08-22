import 'package:flutter_test/flutter_test.dart';
import 'package:partyplan/core/dates.dart';

void main() {
  test('compte les jours civils au passage à l’heure d’été à Paris', () {
    final maintenant = DateTime(2027, 3, 20, 12);
    final cible = DateTime(2027, 3, 31, 12);

    expect(joursCalendairesJusqua(cible, depuis: maintenant), 11);
  });
}
