import 'package:flutter/material.dart';

import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/marque.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Écran d'accueil : les événements de la personne, à venir puis passés (EF-EVT-05).
///
/// Vide au lot 0.5 : la liste arrive avec le module Events en V1.0. L'état vide est en
/// revanche déjà écrit, car c'est le premier écran que verra tout nouvel utilisateur.
class AccueilPage extends StatelessWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(PpMarque.nom),
      actions: [
        IconButton(
          onPressed: null,
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
        const SizedBox(width: PpSpacing.sm),
      ],
    ),
    body: PpEmptyState(
      titre: PpL10n.of(context).accueilVideTitre,
      explication: PpL10n.of(context).accueilVideExplication,
      action: Column(
        children: [
          FilledButton.icon(
            onPressed: null,
            icon: const Icon(Icons.add_rounded),
            label: Text(PpL10n.of(context).creerUnEvenement),
          ),
          const SizedBox(height: PpSpacing.sm),
          TextButton(
            onPressed: null,
            child: Text(PpL10n.of(context).rejoindreUnEvenement),
          ),
        ],
      ),
    ),
  );
}

/// Vitrine des composants du système de design.
///
/// Conservée dans l'application, et non dans un projet séparé : un système de design
/// que l'on ne peut pas voir tourner dérive silencieusement du produit.
class GalerieDesignPage extends StatelessWidget {
  const GalerieDesignPage({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('Galerie des composants')));
}

/// Carte d'événement de l'accueil. Utilisée par la liste dès que l'API la fournit.
class CarteEvenement extends StatelessWidget {
  const CarteEvenement({
    required this.titre,
    required this.dateLisible,
    required this.lieu,
    required this.enfant,
    super.key,
  });

  final String titre;
  final String dateLisible;
  final String lieu;
  final Widget enfant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titre, style: theme.textTheme.titleLarge),
          const SizedBox(height: PpSpacing.xs),
          Text('$dateLisible · $lieu', style: theme.textTheme.bodySmall),
          const SizedBox(height: PpSpacing.lg),
          enfant,
        ],
      ),
    );
  }
}
