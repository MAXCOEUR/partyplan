import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/moyens_connexion.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Moyens de connexion du compte : mot de passe et services tiers (EF-AUTH-08).
///
/// Trois états sont distingués pour un service, et ils ne se confondent pas :
/// l'instance n'a pas les clés, l'application ne sait pas encore obtenir un jeton, ou
/// le service est rattaché. Afficher un bouton dans les deux premiers cas reviendrait à
/// promettre une action qui échouera.
class ConnexionsPage extends ConsumerStatefulWidget {
  const ConnexionsPage({super.key});

  @override
  ConsumerState<ConnexionsPage> createState() => _ConnexionsPageState();
}

class _ConnexionsPageState extends ConsumerState<ConnexionsPage> {
  bool _enCours = false;

  Future<void> _detacher(MoyenTiers fournisseur) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détacher ${fournisseur.libelle} ?'),
        content: Text(
          'Tu ne pourras plus te connecter avec ${fournisseur.libelle}. '
          'Tes autres moyens de connexion restent valables.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Détacher'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) {
      return;
    }

    setState(() => _enCours = true);

    try {
      await ref
          .read(comptesApiProvider)
          .detacherFournisseur(fournisseur.identifiant);

      ref.invalidate(moyensConnexionProvider);
      // Le profil porte `hasPassword` et sert d'autres écrans : le laisser périmé
      // afficherait un état incohérent d'un écran à l'autre.
      ref.invalidate(profilProvider);
    } on ApiException catch (erreur) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PpL10n.of(context).erreurReseau)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  /// Rattache un service tiers au compte courant.
  ///
  /// Une annulation ne produit rien : c'est un geste ordinaire, et l'écran resterait
  /// dans le même état de toute façon.
  Future<void> _rattacher(MoyenTiers fournisseur) async {
    setState(() => _enCours = true);

    try {
      final jeton = await ref
          .read(serviceGoogleProvider)
          .obtenirJetonIdentite();

      if (jeton == null) {
        return;
      }

      await ref
          .read(comptesApiProvider)
          .rattacherFournisseur(
            identifiant: fournisseur.identifiant,
            jetonIdentite: jeton,
          );

      ref.invalidate(moyensConnexionProvider);
      ref.invalidate(profilProvider);
    } on ApiException catch (erreur) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PpL10n.of(context).erreurReseau)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final moyens = ref.watch(moyensConnexionProvider);
    // Décidé à l'exécution : l'identifiant client est injecté à la compilation de
    // l'image, une constante du code ne pourrait pas le savoir.
    final clientEmbarque = ref.watch(serviceGoogleProvider).disponible;

    return Scaffold(
      appBar: AppBar(title: const Text('Connexions')),
      body: switch (moyens) {
        AsyncError(:final error) => PpErrorState(
          message: error is ApiException
              ? error.title
              : PpL10n.of(context).erreurReseau,
          onRetry: () => ref.invalidate(moyensConnexionProvider),
        ),
        AsyncData(:final value) => ListView(
          padding: const EdgeInsets.all(PpSpacing.lg),
          children: [
            PpCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PpEyebrow('Mot de passe'),
                  const SizedBox(height: PpSpacing.md),
                  Row(
                    children: [
                      Icon(
                        value.aUnMotDePasse
                            ? Icons.check_circle_outline_rounded
                            : Icons.info_outline_rounded,
                        size: 20,
                        color: value.aUnMotDePasse
                            ? PpColors.texteSur(PpColors.vert, theme.brightness)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: PpSpacing.sm),
                      Expanded(
                        child: Text(
                          value.aUnMotDePasse
                              ? 'Mot de passe'
                              : 'Aucun mot de passe défini. Passe par « mot de passe '
                                    'oublié » pour en créer un.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: PpSpacing.lg),
            for (final fournisseur in value.fournisseurs) ...[
              _CarteFournisseur(
                fournisseur: fournisseur,
                detachable: value.peutDetacher(fournisseur),
                dernierMoyen:
                    fournisseur.rattache && !value.peutDetacher(fournisseur),
                clientEmbarque: clientEmbarque,
                enCours: _enCours,
                onDetacher: () => _detacher(fournisseur),
                onRattacher: () => _rattacher(fournisseur),
              ),
              const SizedBox(height: PpSpacing.md),
            ],
          ],
        ),
        _ => const PpLoadingState(),
      },
    );
  }
}

class _CarteFournisseur extends StatelessWidget {
  const _CarteFournisseur({
    required this.fournisseur,
    required this.detachable,
    required this.dernierMoyen,
    required this.clientEmbarque,
    required this.enCours,
    required this.onDetacher,
    required this.onRattacher,
  });

  final MoyenTiers fournisseur;
  final bool detachable;
  final bool dernierMoyen;
  final bool clientEmbarque;
  final bool enCours;
  final VoidCallback onDetacher;
  final VoidCallback onRattacher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(fournisseur.libelle, style: theme.textTheme.titleMedium),
          const SizedBox(height: PpSpacing.sm),
          if (fournisseur.rattache) ...[
            Text(
              dernierMoyen
                  ? 'C’est ton seul moyen de connexion : définis un mot de passe '
                        'avant de le détacher.'
                  : 'Rattaché à ton compte.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.md),
            OutlinedButton.icon(
              onPressed: detachable && !enCours ? onDetacher : null,
              icon: const Icon(Icons.link_off_rounded, size: 18),
              label: const Text('Détacher'),
            ),
          ] else if (!fournisseur.disponible)
            Text(
              '${fournisseur.libelle} n’est pas disponible sur cette instance.',
              style: theme.textTheme.bodySmall,
            )
          else if (clientEmbarque) ...[
            Text(
              'Ajoute ${fournisseur.libelle} pour te connecter d’un geste.',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.md),
            OutlinedButton.icon(
              key: Key('rattacher-${fournisseur.identifiant}'),
              onPressed: enCours ? null : onRattacher,
              icon: const Icon(Icons.link_rounded, size: 18),
              label: const Text('Rattacher'),
            ),
          ] else
            Text(
              'Le serveur accepte ${fournisseur.libelle}, mais cette version de '
              'l’application ne sait pas obtenir de jeton.',
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}
