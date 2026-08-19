import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';

import '../../core/models/profil.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';
import '../../l10n/validateurs.dart';

/// Sécurité du compte : mot de passe et sessions (EF-AUTH-05, EF-AUTH-10).
class SecuritePage extends ConsumerStatefulWidget {
  const SecuritePage({super.key});

  @override
  ConsumerState<SecuritePage> createState() => _SecuritePageState();
}

class _SecuritePageState extends ConsumerState<SecuritePage> {
  final _actuel = TextEditingController();
  final _nouveau = TextEditingController();
  bool _enCours = false;
  String? _erreur;

  static final _horodatage = DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR');

  @override
  void dispose() {
    _actuel.dispose();
    _nouveau.dispose();
    super.dispose();
  }

  Future<void> _changerMotDePasse() async {
    if (Validateurs.motDePasseExistant(_actuel.text) != null) {
      setState(() => _erreur = 'Indique ton mot de passe actuel.');
      return;
    }

    final probleme = Validateurs.motDePasse(_nouveau.text);
    if (probleme != null) {
      setState(() => _erreur = probleme);
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(comptesApiProvider)
          .changerMotDePasse(actuel: _actuel.text, nouveau: _nouveau.text);

      _actuel.clear();
      _nouveau.clear();
      ref.invalidate(sessionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Mot de passe changé. Tes autres sessions sont déconnectées.',
            ),
          ),
        );
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurEnregistrement);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _revoquer(String id) async {
    try {
      await ref.read(comptesApiProvider).revoquerSession(id);
      ref.invalidate(sessionsProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(PpStrings.erreurEnregistrement)),
        );
      }
    }
  }

  Future<void> _revoquerLesAutres() async {
    try {
      await ref.read(comptesApiProvider).revoquerAutresSessions();
      ref.invalidate(sessionsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Les autres sessions sont déconnectées.'),
          ),
        );
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(PpStrings.erreurEnregistrement)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessions = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité')),
      body: ListView(
        padding: const EdgeInsets.all(PpSpacing.lg),
        children: [
          if (_erreur != null) ...[
            PpFormError(_erreur!),
            const SizedBox(height: PpSpacing.lg),
          ],
          PpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PpEyebrow('Mot de passe'),
                const SizedBox(height: PpSpacing.md),
                PpField(
                  label: 'Mot de passe actuel',
                  controller: _actuel,
                  obscure: true,
                  enabled: !_enCours,
                ),
                const SizedBox(height: PpSpacing.lg),
                PpField(
                  label: 'Nouveau mot de passe',
                  controller: _nouveau,
                  obscure: true,
                  enabled: !_enCours,
                  aide:
                      '${Validateurs.longueurMotDePasse} caractères minimum. '
                      'Les mots de passe déjà divulgués sont refusés.',
                ),
                const SizedBox(height: PpSpacing.lg),
                PpPrimaryButton(
                  label: 'Changer le mot de passe',
                  enCours: _enCours,
                  onPressed: _changerMotDePasse,
                ),
              ],
            ),
          ),
          const SizedBox(height: PpSpacing.lg),
          const _EntreeSecondFacteur(),
          const SizedBox(height: PpSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: PpSpacing.xs),
                child: PpEyebrow('Sessions actives'),
              ),
              TextButton(
                onPressed: _revoquerLesAutres,
                child: const Text('Déconnecter les autres'),
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.sm),
          sessions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(PpSpacing.xl),
              child: PpLoadingState(),
            ),
            error: (_, _) => PpErrorState(
              message: PpStrings.erreurReseau,
              onRetry: () => ref.invalidate(sessionsProvider),
            ),
            data: (liste) => PpCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < liste.length; i++) ...[
                    _LigneSession(
                      session: liste[i],
                      horodatage: _horodatage,
                      onRevoquer: () => _revoquer(liste[i].id),
                    ),
                    if (i < liste.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: PpSpacing.xl),
        ],
      ),
    );
  }
}

class _LigneSession extends StatelessWidget {
  const _LigneSession({
    required this.session,
    required this.horodatage,
    required this.onRevoquer,
  });

  final SessionActive session;
  final DateFormat horodatage;
  final VoidCallback onRevoquer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      minVerticalPadding: PpSpacing.md,
      leading: Icon(
        session.estCourante
            ? Icons.smartphone_rounded
            : Icons.devices_other_rounded,
        color: session.estCourante
            ? PpColors.vertTexte
            : theme.colorScheme.onSurfaceVariant,
      ),
      title: Row(
        children: [
          Text(session.appareilLisible, style: theme.textTheme.titleMedium),
          if (session.estCourante) ...[
            const SizedBox(width: PpSpacing.sm),
            Text(
              '· cet appareil',
              style: theme.textTheme.bodySmall?.copyWith(
                color: PpColors.vertTexte,
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        'Vue le ${horodatage.format(session.vueLe.toLocal())}'
        '${session.adresse == null ? '' : ' · ${session.adresse}'}',
        style: theme.textTheme.bodySmall,
      ),
      trailing: IconButton(
        tooltip: session.estCourante
            ? 'Se déconnecter'
            : 'Déconnecter cet appareil',
        icon: const Icon(Icons.logout_rounded, size: 18),
        onPressed: onRevoquer,
      ),
    );
  }
}

/// Entrée vers le réglage du second facteur, avec son état courant.
class _EntreeSecondFacteur extends ConsumerWidget {
  const _EntreeSecondFacteur();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).value;
    final theme = Theme.of(context);
    final active = profil?.doubleAuthentification ?? false;
    final couleur = active
        ? PpColors.texteSur(PpColors.vert, theme.brightness)
        : PpColors.texteSur(PpColors.orange, theme.brightness);

    return PpCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push(PpRoutes.secondFacteurReglage),
      child: ListTile(
        onTap: () => context.push(PpRoutes.secondFacteurReglage),
        minVerticalPadding: PpSpacing.md,
        leading: Icon(
          active ? Icons.verified_user_rounded : Icons.shield_outlined,
          color: couleur,
        ),
        title: Text(
          'Double authentification',
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Text(
          active
              ? 'Active — un code est demandé à chaque connexion'
              : 'Inactive — ton mot de passe est ta seule protection',
          style: theme.textTheme.bodySmall?.copyWith(color: couleur),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}
