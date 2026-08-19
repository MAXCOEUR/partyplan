import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/models/profil.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';

/// Activation et désactivation du second facteur (EF-AUTH-12).
class SecondFacteurReglagePage extends ConsumerStatefulWidget {
  const SecondFacteurReglagePage({super.key});

  @override
  ConsumerState<SecondFacteurReglagePage> createState() =>
      _SecondFacteurReglagePageState();
}

class _SecondFacteurReglagePageState
    extends ConsumerState<SecondFacteurReglagePage> {
  final _code = TextEditingController();
  final _motDePasse = TextEditingController();

  EnrolementTotp? _enrolement;
  List<String>? _codesDeSecours;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _code.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _preparer() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final enrolement = await ref
          .read(comptesApiProvider)
          .preparerSecondFacteur();
      setState(() => _enrolement = enrolement);
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _activer() async {
    if (_code.text.trim().isEmpty) {
      setState(() => _erreur = 'Saisis le code affiché par ton application.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final codes = await ref
          .read(comptesApiProvider)
          .activerSecondFacteur(_code.text.trim());

      ref.invalidate(profilProvider);
      setState(() {
        _codesDeSecours = codes;
        _enrolement = null;
        _code.clear();
      });
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _desactiver() async {
    if (_motDePasse.text.isEmpty) {
      setState(() => _erreur = 'Indique ton mot de passe.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(comptesApiProvider)
          .desactiverSecondFacteur(_motDePasse.text);
      ref.invalidate(profilProvider);
      _motDePasse.clear();
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _regenerer() async {
    setState(() => _enCours = true);

    try {
      final codes = await ref
          .read(comptesApiProvider)
          .regenererCodesDeSecours();
      setState(() => _codesDeSecours = codes);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Double authentification')),
      body: profil.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: PpStrings.erreurReseau,
          onRetry: () => ref.invalidate(profilProvider),
        ),
        data: (donnees) => ListView(
          padding: const EdgeInsets.all(PpSpacing.lg),
          children: [
            if (_erreur != null) ...[
              PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.lg),
            ],
            if (_codesDeSecours != null) ...[
              _CodesDeSecours(codes: _codesDeSecours!),
              const SizedBox(height: PpSpacing.lg),
            ],
            if (donnees.doubleAuthentification)
              _Active(
                motDePasse: _motDePasse,
                enCours: _enCours,
                estPersonnel: donnees.estPersonnelPlateforme,
                onDesactiver: _desactiver,
                onRegenerer: _regenerer,
              )
            else if (_enrolement != null)
              _Enrolement(
                enrolement: _enrolement!,
                code: _code,
                enCours: _enCours,
                onActiver: _activer,
              )
            else
              _Inactive(enCours: _enCours, onPreparer: _preparer),
          ],
        ),
      ),
    );
  }
}

class _Inactive extends StatelessWidget {
  const _Inactive({required this.enCours, required this.onPreparer});

  final bool enCours;
  final VoidCallback onPreparer;

  @override
  Widget build(BuildContext context) => PpCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PpEyebrow('Inactive'),
        const SizedBox(height: PpSpacing.md),
        Text(
          'Un second facteur protège ton compte même si ton mot de passe est découvert. '
          'Il est obligatoire pour les rôles d’administration.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: PpSpacing.lg),
        PpPrimaryButton(
          label: 'Activer',
          icone: Icons.shield_outlined,
          enCours: enCours,
          onPressed: onPreparer,
        ),
      ],
    ),
  );
}

class _Enrolement extends StatelessWidget {
  const _Enrolement({
    required this.enrolement,
    required this.code,
    required this.enCours,
    required this.onActiver,
  });

  final EnrolementTotp enrolement;
  final TextEditingController code;
  final bool enCours;
  final VoidCallback onActiver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PpEyebrow('Étape 1 — enregistre le secret'),
          const SizedBox(height: PpSpacing.md),
          Text(
            'Ajoute ce secret dans ton application d’authentification, puis saisis le '
            'code qu’elle affiche.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: PpSpacing.lg),
          // Le secret est affiché en clair, découpé en groupes de quatre : le QR code
          // n'est pas toujours scannable, notamment lorsque l'application et
          // l'authentificateur sont sur le même téléphone.
          Container(
            padding: const EdgeInsets.all(PpSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(PpRadius.md),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: SelectableText(
                    enrolement.secretLisible,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontFamily: 'monospace',
                      fontFamilyFallback: const ['Courier'],
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Copier',
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: enrolement.secret),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Secret copié.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: PpSpacing.lg),
          const PpEyebrow('Étape 2 — confirme'),
          const SizedBox(height: PpSpacing.md),
          PpField(
            label: 'Code affiché',
            controller: code,
            enabled: !enCours,
            aide: 'Six chiffres. Le code change toutes les 30 secondes.',
          ),
          const SizedBox(height: PpSpacing.lg),
          PpPrimaryButton(
            label: 'Confirmer et activer',
            enCours: enCours,
            onPressed: onActiver,
          ),
        ],
      ),
    );
  }
}

class _Active extends StatelessWidget {
  const _Active({
    required this.motDePasse,
    required this.enCours,
    required this.estPersonnel,
    required this.onDesactiver,
    required this.onRegenerer,
  });

  final TextEditingController motDePasse;
  final bool enCours;
  final bool estPersonnel;
  final VoidCallback onDesactiver;
  final VoidCallback onRegenerer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vert = PpColors.texteSur(PpColors.vert, theme.brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PpCard(
          child: Row(
            children: [
              Icon(Icons.verified_user_rounded, color: vert),
              const SizedBox(width: PpSpacing.md),
              Expanded(
                child: Text(
                  'Double authentification active',
                  style: theme.textTheme.titleMedium?.copyWith(color: vert),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.lg),
        PpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PpEyebrow('Codes de secours'),
              const SizedBox(height: PpSpacing.md),
              Text(
                'Régénérer produit un nouveau lot et rend les précédents inutilisables.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: PpSpacing.lg),
              OutlinedButton.icon(
                onPressed: enCours ? null : onRegenerer,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Régénérer les codes'),
              ),
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.lg),
        PpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PpEyebrow('Désactiver'),
              const SizedBox(height: PpSpacing.md),
              if (estPersonnel)
                Text(
                  'Ton rôle d’administration exige un second facteur : il ne peut pas '
                  'être retiré tant que tu conserves ce rôle.',
                  style: theme.textTheme.bodyMedium,
                )
              else ...[
                PpField(
                  label: 'Mot de passe',
                  controller: motDePasse,
                  obscure: true,
                  enabled: !enCours,
                  aide:
                      'Exigé : sans lui, un jeton volé suffirait à retirer ta '
                      'protection.',
                ),
                const SizedBox(height: PpSpacing.lg),
                OutlinedButton(
                  onPressed: enCours ? null : onDesactiver,
                  child: const Text('Désactiver la double authentification'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Affichage unique des codes de secours.
class _CodesDeSecours extends StatelessWidget {
  const _CodesDeSecours({required this.codes});

  final List<String> codes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final orange = PpColors.texteSur(PpColors.orange, theme.brightness);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.lg),
      decoration: BoxDecoration(
        color: PpColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PpRadius.card),
        border: Border.all(color: orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.key_rounded, size: 18, color: orange),
              const SizedBox(width: PpSpacing.sm),
              Expanded(
                child: Text(
                  'Note ces codes maintenant',
                  style: theme.textTheme.titleMedium?.copyWith(color: orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.xs),
          Text(
            'Ils ne seront plus affichés. Chacun ne sert qu’une fois, et remplace le '
            'code de ton application si tu perds ton téléphone.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: PpSpacing.md),
          Wrap(
            spacing: PpSpacing.sm,
            runSpacing: PpSpacing.sm,
            children: [
              for (final code in codes)
                SelectableText(
                  code,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontFamilyFallback: const ['Courier'],
                  ),
                ),
            ],
          ),
          const SizedBox(height: PpSpacing.md),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: codes.join('\n')));
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Codes copiés.')));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier les codes'),
          ),
        ],
      ),
    );
  }
}
