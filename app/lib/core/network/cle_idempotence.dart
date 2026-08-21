import 'dart:math';

/// Engendre une clé d'idempotence.
///
/// 128 bits en hexadécimal, tirés de `Random.secure` : une clé devinable permettrait à
/// un tiers de faire rejouer la réponse d'autrui.
///
/// Partagée entre les clients d'API plutôt que recopiée dans chacun : trois domaines en
/// ont besoin — événements, courses, dépenses — et une copie affaiblie passerait
/// inaperçue.
String nouvelleCleIdempotence() {
  final alea = Random.secure();

  return List.generate(
    16,
    (_) => alea.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}
