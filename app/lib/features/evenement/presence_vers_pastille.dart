import '../../core/models/membre.dart';
import '../../design/components/pp_status_chip.dart';

/// Traduit le statut du contrat d'API vers le vocabulaire du système de design.
///
/// Deux énumérations décrivent le même concept, et c'est voulu : [PpPresence] est le
/// vocabulaire visuel, [StatutPresence] le contrat de l'API. La conversion vit ici, dans
/// la couche fonctionnalité — un composant de design qui importerait `core/models`
/// dépendrait de la forme des réponses de l'API et changerait à chaque évolution de
/// contrat.
PpPresence versPastille(StatutPresence statut) => switch (statut) {
  StatutPresence.present => PpPresence.present,
  StatutPresence.peutEtre => PpPresence.peutEtre,
  StatutPresence.absent => PpPresence.absent,
  StatutPresence.enRetard => PpPresence.arriveTard,
  StatutPresence.partAvant => PpPresence.partTot,
  StatutPresence.inconnu => PpPresence.inconnu,
};
