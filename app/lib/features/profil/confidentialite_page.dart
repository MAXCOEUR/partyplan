import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';

/// Mes données et confidentialité : export et suppression (EF-USR-09, EF-USR-10).
class ConfidentialitePage extends ConsumerStatefulWidget {
  const ConfidentialitePage({super.key});

  @override
  ConsumerState<ConfidentialitePage> createState() =>
      _ConfidentialitePageState();
}

class _ConfidentialitePageState extends ConsumerState<ConfidentialitePage> {
  bool _enCours = false;
  String? _apercuExport;

  Future<void> _exporter() async {
    setState(() => _enCours = true);

    try {
      final donnees = await ref.read(comptesApiProvider).exporterDonnees();
      setState(() => _apercuExport = donnees);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(PpStrings.erreurReseau)));
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _supprimer() async {
    final profil = await ref.read(profilProvider.future);
    final adresse = profil.email;

    if (adresse == null || !mounted) {
      return;
    }

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => _DialogueSuppression(adresse: adresse),
    );

    if (confirme != true || !mounted) {
      return;
    }

    setState(() => _enCours = true);

    try {
      await ref.read(comptesApiProvider).supprimerCompte(adresse);
      await ref.read(sessionProvider.notifier).deconnecter();

      if (mounted) {
        context.go(PpRoutes.connexion);
      }
    } on ApiException catch (erreur) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
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
    final rouge = PpColors.texteSur(PpColors.rouge, theme.brightness);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes données')),
      body: ListView(
        padding: const EdgeInsets.all(PpSpacing.lg),
        children: [
          PpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PpEyebrow('Export'),
                const SizedBox(height: PpSpacing.md),
                Text(
                  'Récupère l’intégralité des données de ton compte au format JSON. '
                  'Aucune démarche, aucun délai.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: PpSpacing.lg),
                PpPrimaryButton(
                  label: 'Exporter mes données',
                  icone: Icons.download_rounded,
                  enCours: _enCours,
                  onPressed: _exporter,
                ),
                if (_apercuExport != null) ...[
                  const SizedBox(height: PpSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(PpSpacing.md),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(PpRadius.md),
                      border: Border.all(color: theme.colorScheme.outline),
                    ),
                    child: SizedBox(
                      height: 220,
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _apercuExport!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontFamilyFallback: const ['Courier'],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: PpSpacing.lg),
          PpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PpEyebrow('Suppression', couleur: rouge),
                const SizedBox(height: PpSpacing.md),
                Text(
                  'La suppression est définitive. Tes contributions financières aux '
                  'événements sont conservées sous « Ancien participant » : les '
                  'supprimer fausserait les comptes des autres participants.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: PpSpacing.lg),
                OutlinedButton.icon(
                  onPressed: _enCours ? null : _supprimer,
                  icon: Icon(
                    Icons.delete_forever_rounded,
                    size: 18,
                    color: rouge,
                  ),
                  label: Text(
                    'Supprimer mon compte',
                    style: TextStyle(color: rouge),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: rouge.withValues(alpha: 0.5)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: PpSpacing.xl),
        ],
      ),
    );
  }
}

/// Confirmation de suppression.
///
/// Exige la saisie de l'adresse : un simple bouton « confirmer » se clique par réflexe,
/// alors que recopier son adresse suppose d'avoir lu (RG-USR-05).
class _DialogueSuppression extends StatefulWidget {
  const _DialogueSuppression({required this.adresse});

  final String adresse;

  @override
  State<_DialogueSuppression> createState() => _DialogueSuppressionState();
}

class _DialogueSuppressionState extends State<_DialogueSuppression> {
  final _saisie = TextEditingController();

  @override
  void dispose() {
    _saisie.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final correspond =
        _saisie.text.trim().toLowerCase() == widget.adresse.toLowerCase();

    return AlertDialog(
      title: const Text('Supprimer ton compte ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cette action est irréversible. Pour confirmer, recopie ton adresse :',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: PpSpacing.sm),
          Text(widget.adresse, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: PpSpacing.md),
          TextField(
            controller: _saisie,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Ton adresse e-mail'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: correspond ? () => Navigator.of(context).pop(true) : null,
          style: FilledButton.styleFrom(backgroundColor: PpColors.rouge),
          child: const Text('Supprimer définitivement'),
        ),
      ],
    );
  }
}
