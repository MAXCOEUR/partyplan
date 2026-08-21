import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/models/profil.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_retour.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Écran de profil : ce que l'utilisateur voit de son propre compte.
///
/// Sert d'accueil tant que l'événementiel n'existe pas (V1.0). Il regroupe les actions
/// réellement disponibles plutôt que d'afficher un écran vide.
class ProfilPage extends ConsumerWidget {
  const ProfilPage({super.key});

  static final _dateFr = DateFormat('dd/MM/yyyy', 'fr_FR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider);

    return Scaffold(
      // La déconnexion n'est plus une icône de barre : elle est nommée en bas de
      // l'écran, avec la suppression du compte.
      appBar: const PpBarreApp(
        bouton: PpRetour(versParent: PpRoutes.accueil),
        titre: Text('Mon compte'),
      ),
      body: profil.when(
        loading: () => const PpLoadingState(),
        error: (erreur, _) => PpErrorState(
          message: PpL10n.of(context).erreurReseau,
          onRetry: () => ref.invalidate(profilProvider),
        ),
        data: (donnees) => PpRail(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(profilProvider),
            child: ListView(
              padding: const EdgeInsets.all(PpSpacing.lg),
              children: [
                _EnTeteProfil(profil: donnees),
                const SizedBox(height: PpSpacing.lg),
                if (!donnees.emailVerifie) ...[
                  const _RappelVerification(),
                  const SizedBox(height: PpSpacing.lg),
                ],
                _Section(
                  titre: 'Mon compte',
                  entrees: [
                    _Entree(
                      icone: Icons.person_outline_rounded,
                      libelle: 'Modifier mon profil',
                      detail: donnees.nomAffiche,
                      onTap: () => context.push(PpRoutes.profilEdition),
                    ),
                    _Entree(
                      icone: Icons.shield_outlined,
                      libelle: 'Sécurité et sessions',
                      detail: donnees.aUnMotDePasse
                          ? 'Mot de passe défini'
                          : 'Aucun mot de passe défini',
                      onTap: () => context.push(PpRoutes.securite),
                    ),
                    _Entree(
                      icone: Icons.privacy_tip_outlined,
                      libelle: 'Mes données et confidentialité',
                      detail: 'Export, suppression du compte',
                      onTap: () => context.push(PpRoutes.confidentialite),
                    ),
                  ],
                ),
                if (donnees.estPersonnelPlateforme) ...[
                  const SizedBox(height: PpSpacing.lg),
                  _Section(
                    titre: 'Administration',
                    entrees: [
                      _Entree(
                        icone: Icons.groups_outlined,
                        libelle: 'Gestion des comptes',
                        detail: donnees.estAdministrateur
                            ? 'Tous les droits'
                            : 'Consultation et dépannage',
                        onTap: () => context.push(PpRoutes.adminComptes),
                      ),
                      _Entree(
                        icone: Icons.history_rounded,
                        libelle: 'Journal d’audit',
                        detail: 'Trace de toutes les actions',
                        onTap: () => context.push(PpRoutes.adminAudit),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: PpSpacing.lg),
                _FinDeSession(profil: donnees),
                const SizedBox(height: PpSpacing.xl),
                Center(
                  child: Text(
                    'Compte créé le ${_dateFr.format(donnees.creeLe.toLocal())}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: PpSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnTeteProfil extends StatelessWidget {
  const _EnTeteProfil({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PpCard(
      child: Row(
        children: [
          PpAvatar(
            nom: profil.nomAffiche,
            urlPhoto: profil.urlPhoto,
            taille: 64,
          ),
          const SizedBox(width: PpSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profil.nomAffiche, style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  profil.email ?? 'Aucune adresse',
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profil.estPersonnelPlateforme) ...[
                  const SizedBox(height: PpSpacing.sm),
                  _EtiquetteRole(role: profil.rolePlateforme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EtiquetteRole extends StatelessWidget {
  const _EtiquetteRole({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final couleur = role == 'PlatformAdmin' ? PpColors.violet : PpColors.bleu;
    final libelle = role == 'PlatformAdmin' ? 'Administrateur' : 'Support';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PpSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(PpRadius.pill),
      ),
      child: Text(
        libelle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: couleur,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Rappel de vérification d'adresse. Informatif : rien n'est bloqué tant qu'elle n'est
/// pas confirmée, mais la réinitialisation du mot de passe en dépend.
class _RappelVerification extends ConsumerStatefulWidget {
  const _RappelVerification();

  @override
  ConsumerState<_RappelVerification> createState() =>
      _RappelVerificationState();
}

class _RappelVerificationState extends ConsumerState<_RappelVerification> {
  final _code = TextEditingController();
  bool _enCours = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verifier() async {
    setState(() => _enCours = true);

    try {
      await ref.read(comptesApiProvider).verifierAdresse(_code.text.trim());
      ref.invalidate(profilProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Adresse confirmée.')));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce code est invalide ou a expiré.')),
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
    final couleur = PpColors.texteSur(PpColors.orange, theme.brightness);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.lg),
      decoration: BoxDecoration(
        color: PpColors.orange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PpRadius.card),
        border: Border.all(color: couleur.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mark_email_unread_outlined, size: 18, color: couleur),
              const SizedBox(width: PpSpacing.sm),
              Text(
                'Adresse non confirmée',
                style: theme.textTheme.titleMedium?.copyWith(color: couleur),
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.xs),
          Text(
            'Colle le code reçu par courriel pour confirmer ton adresse.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: PpSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _code,
                  enabled: !_enCours,
                  decoration: const InputDecoration(hintText: 'Code reçu'),
                ),
              ),
              const SizedBox(width: PpSpacing.sm),
              FilledButton(
                onPressed: _enCours ? null : _verifier,
                child: const Text('Confirmer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.titre, required this.entrees});

  final String titre;
  final List<_Entree> entrees;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          left: PpSpacing.xs,
          bottom: PpSpacing.sm,
        ),
        child: PpEyebrow(titre),
      ),
      PpCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            for (var i = 0; i < entrees.length; i++) ...[
              entrees[i],
              if (i < entrees.length - 1)
                const Divider(height: 1, indent: PpSpacing.xxl),
            ],
          ],
        ),
      ),
    ],
  );
}

class _Entree extends StatelessWidget {
  const _Entree({
    required this.icone,
    required this.libelle,
    required this.detail,
    required this.onTap,
  });

  final IconData icone;
  final String libelle;
  final String detail;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actif = onTap != null;

    return ListTile(
      onTap: onTap,
      enabled: actif,
      minVerticalPadding: PpSpacing.md,
      leading: Icon(
        icone,
        color: actif ? PpColors.violet : theme.disabledColor,
      ),
      title: Text(libelle, style: theme.textTheme.titleMedium),
      subtitle: Text(detail, style: theme.textTheme.bodySmall),
      trailing: actif ? const Icon(Icons.chevron_right_rounded) : null,
    );
  }
}

/// Quitter la session, ou le produit.
///
/// Deux gestes nommés, en bas de l'écran : une icône dans la barre ne se trouve pas, et
/// fermer son compte n'a pas à se chercher dans « Mes données et confidentialité ».
class _FinDeSession extends ConsumerWidget {
  const _FinDeSession({required this.profil});

  final Profil profil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PpCard(
          onTap: () => _deconnecter(context, ref),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: PpColors.violet),
              const SizedBox(width: PpSpacing.md),
              Expanded(
                child: Text(
                  'Se déconnecter',
                  style: theme.textTheme.titleSmall,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
        const SizedBox(height: PpSpacing.sm),
        // Un administrateur de plateforme ne peut pas se supprimer tant qu'il n'a pas
        // transféré son rôle : le serveur le refuse (RG-ADM-05), et proposer le geste
        // pour le voir échouer vaudrait moins que l'expliquer.
        if (profil.estAdministrateur)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PpSpacing.lg),
            child: Text(
              'Ton compte est administrateur de la plateforme : transfère ce rôle '
              'avant de pouvoir le supprimer.',
              style: theme.textTheme.bodySmall,
            ),
          )
        else
          PpCard(
            onTap: () => context.push(PpRoutes.confidentialite),
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded, color: PpColors.rouge),
                const SizedBox(width: PpSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Supprimer mon compte',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: PpColors.rougeTexte,
                        ),
                      ),
                      Text(
                        'Définitif. Tes données sont exportables avant.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _deconnecter(BuildContext context, WidgetRef ref) async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text(
          'Les événements rejoints sans compte sur cet appareil resteront '
          'accessibles par leur lien.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Rester connecté'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );

    if (confirme != true) {
      return;
    }

    await ref.read(sessionProvider.notifier).deconnecter();

    if (context.mounted) {
      context.go(PpRoutes.connexion);
    }
  }
}
