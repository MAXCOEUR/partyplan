import 'file_ecritures.dart';

/// L'écriture n'est pas partie : elle est en file et repartira à la reconnexion.
///
/// Distincte d'une erreur : l'interface **conserve** l'état optimiste au lieu de
/// l'annuler. Traiter ce cas comme un échec ferait disparaître sous les yeux de
/// l'utilisateur une action qui, elle, aboutira.
class EcritureDifferee implements Exception {
  const EcritureDifferee(this.ecriture);

  final EcritureEnAttente ecriture;

  @override
  String toString() =>
      'EcritureDifferee(${ecriture.methode} ${ecriture.chemin})';
}
