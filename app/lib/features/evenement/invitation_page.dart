import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/evenement.dart';
import '../../core/models/invitation.dart';
import '../../app/router.dart';
import '../../core/providers.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_retour.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Écran d'invitation : lien, code court, QR code, partage (EF-INV-01 à EF-INV-06).
class InvitationPage extends ConsumerWidget {
  const InvitationPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final invitation = ref.watch(invitationProvider(evenementId));
    final evenement = ref.watch(evenementProvider(evenementId)).value;

    return Scaffold(
      appBar: PpBarreApp(
        bouton: PpRetour(versParent: PpRoutes.versEvenement(evenementId)),
        titre: Text(l10n.invitationTitre),
      ),
      body: PpRail(
        child: invitation.when(
          loading: () => const PpLoadingState(),
          error: (_, _) => PpErrorState(
            message: l10n.invitationErreur,
            onRetry: () => ref.invalidate(invitationProvider(evenementId)),
          ),
          data: (donnees) => _Contenu(
            evenementId: evenementId,
            invitation: donnees,
            evenement: evenement,
          ),
        ),
      ),
    );
  }
}

class _Contenu extends ConsumerWidget {
  const _Contenu({
    required this.evenementId,
    required this.invitation,
    required this.evenement,
  });

  final String evenementId;
  final Invitation invitation;
  final ResumeEvenement? evenement;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      children: [
        if (!invitation.adhesionsOuvertes)
          Padding(
            padding: const EdgeInsets.only(bottom: PpSpacing.md),
            child: PpCard(
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_outline_rounded,
                    color: PpColors.orange,
                  ),
                  const SizedBox(width: PpSpacing.md),
                  Expanded(child: Text(l10n.invitationFermee)),
                ],
              ),
            ),
          ),
        PpCard(
          child: Column(
            children: [
              // Fond blanc imposé : le thème sombre ne le fournit pas, et sans lui le
              // code n'est pas lisible par un téléphone.
              QrImageView(
                data: invitation.lien,
                size: 220,
                backgroundColor: Colors.white,
                padding: const EdgeInsets.all(PpSpacing.md),
              ),
              const SizedBox(height: PpSpacing.lg),
              PpEyebrow(l10n.invitationCodeCourt),
              const SizedBox(height: PpSpacing.xs),
              SelectableText(
                invitation.codeCourt,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.md),
        PpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PpEyebrow(l10n.invitationLien),
              const SizedBox(height: PpSpacing.xs),
              SelectableText(invitation.lien, style: theme.textTheme.bodySmall),
              const SizedBox(height: PpSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _copier(context, invitation.lien),
                      icon: const Icon(Icons.copy_rounded),
                      label: Text(l10n.invitationCopier),
                    ),
                  ),
                  const SizedBox(width: PpSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _partager(context),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: Text(l10n.invitationPartager),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.md),
        SwitchListTile(
          key: const ValueKey('adhesions-ouvertes'),
          title: Text(l10n.invitationFermerArrivees),
          value: invitation.adhesionsOuvertes,
          onChanged: (valeur) => _basculerAdhesions(ref, ouvertes: valeur),
        ),
        ListTile(
          key: const ValueKey('regenerer'),
          leading: const Icon(Icons.autorenew_rounded),
          title: Text(l10n.invitationRegenerer),
          onTap: () => _confirmerRegeneration(context, ref),
        ),
      ],
    );
  }

  Future<void> _copier(BuildContext context, String lien) async {
    final l10n = PpL10n.of(context);
    final messager = ScaffoldMessenger.of(context);

    await Clipboard.setData(ClipboardData(text: lien));

    messager.showSnackBar(SnackBar(content: Text(l10n.invitationCopie)));
  }

  /// EF-INV-02 « exportable en image » est livré comme **partage natif** plutôt que
  /// comme enregistrement en galerie : le besoin réel est d'envoyer l'invitation dans
  /// une conversation, et l'enregistrement coûterait une permission et une dépendance
  /// sur chaque plateforme.
  Future<void> _partager(BuildContext context) async {
    final l10n = PpL10n.of(context);

    await SharePlus.instance.share(
      ShareParams(
        text: l10n.invitationPartagerTexte(
          evenement?.nom ?? '',
          invitation.lien,
        ),
      ),
    );
  }

  Future<void> _basculerAdhesions(
    WidgetRef ref, {
    required bool ouvertes,
  }) async {
    await ref
        .read(evenementsApiProvider)
        .ouvrirAdhesions(evenementId, ouvertes: ouvertes);

    ref
      ..invalidate(invitationProvider(evenementId))
      ..invalidate(evenementProvider(evenementId));
  }

  Future<void> _confirmerRegeneration(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = PpL10n.of(context);

    final confirme = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.invitationRegenerer),
        // EF-INV-05 : régénérer ferme une porte restée ouverte, mais ferme aussi celle
        // que l'utilisateur vient d'envoyer. Le dire avant, pas après.
        content: Text(l10n.invitationRegenererAvertissement),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.paramAnnuler),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.invitationRegenerer),
          ),
        ],
      ),
    );

    if (confirme != true) {
      return;
    }

    await ref.read(evenementsApiProvider).regenererInvitation(evenementId);
    ref.invalidate(invitationProvider(evenementId));
  }
}
