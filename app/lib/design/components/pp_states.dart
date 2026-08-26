import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pp_skeleton.dart';

/// Écran vide. Une invitation à agir, jamais un simple constat de vide.
class PpEmptyState extends StatelessWidget {
  const PpEmptyState({
    required this.titre,
    required this.explication,
    this.icone = Icons.celebration_outlined,
    this.action,
    super.key,
  });

  final String titre;
  final String explication;
  final IconData icone;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: PpColors.degradeMarque,
                  borderRadius: BorderRadius.circular(PpRadius.card),
                ),
                child: Icon(
                  icone,
                  color: Theme.of(context).colorScheme.onPrimary,
                  size: 32,
                ),
              ),
              const SizedBox(height: PpSpacing.lg),
              Text(
                titre,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: PpSpacing.sm),
              Text(
                explication,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (action != null) ...[
                const SizedBox(height: PpSpacing.xl),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Erreur affichée dans le corps d'un écran.
///
/// Dit ce qui s'est passé et ce que l'on peut faire. Ni excuse, ni formulation vague :
/// l'interface n'a pas de sentiments, l'utilisateur a un problème à résoudre.
class PpErrorState extends StatelessWidget {
  const PpErrorState({required this.message, this.onRetry, super.key});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 40,
                color: PpColors.rouge,
              ),
              const SizedBox(height: PpSpacing.lg),
              Text(
                message,
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: PpSpacing.lg),
                OutlinedButton(
                  onPressed: onRetry,
                  child: const Text('Réessayer'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Chargement d'un écran dont on connaît la forme : un squelette occupant la place du
/// contenu à venir, de sorte que rien ne saute quand la donnée arrive.
///
/// Le commentaire d'origine de ce fichier refusait les squelettes « tant que les écrans
/// réels n'existent pas », au motif qu'un faux contenu ne ressemblant à rien est pire
/// qu'un indicateur honnête. C'était juste, et cette condition est levée : les écrans
/// existent, et leur forme dominante est une liste de cartes.
///
/// Pour un chargement dont la forme est inconnue — l'attente d'un geste, une action en
/// cours —, utiliser [PpLoadingIndicateur] : un squelette n'aurait alors rien à imiter.
class PpLoadingState extends StatelessWidget {
  const PpLoadingState({this.cartes = 3, super.key});

  /// Nombre de cartes esquissées. Trois occupent un écran de téléphone ; en remplir la
  /// page ne rendrait pas l'attente plus courte.
  final int cartes;

  @override
  Widget build(BuildContext context) => PpSkeletonListe(cartes: cartes);
}

/// Indicateur circulaire, pour une attente sans forme connue.
///
/// Réservé aux gestes : envoi d'un formulaire, action en cours. Sur un écran de contenu,
/// c'est [PpLoadingState] qu'il faut.
class PpLoadingIndicateur extends StatelessWidget {
  const PpLoadingIndicateur({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 3,
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}
