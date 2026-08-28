import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/profil.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/comptes_api.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Recherche courante du back-office.
///
/// `Notifier` et non `StateProvider` : ce dernier a été retiré de Riverpod 3.
class RechercheComptes extends Notifier<String> {
  @override
  String build() => '';

  void definir(String valeur) => state = valeur.trim();
}

final rechercheComptesProvider = NotifierProvider<RechercheComptes, String>(
  RechercheComptes.new,
);

final comptesProvider = FutureProvider<PageComptes>(
  (ref) => ref
      .watch(comptesApiProvider)
      .listerComptes(
        recherche: ref.watch(rechercheComptesProvider),
        taille: 50,
      ),
);

/// Back-office de gestion des comptes (EF-ADM-02 à EF-ADM-08).
///
/// Aucun écran d'ici ne donne accès au contenu d'un événement : l'administration agit
/// sur des comptes (RG-ADM-01).
class AdminComptesPage extends ConsumerStatefulWidget {
  const AdminComptesPage({super.key});

  @override
  ConsumerState<AdminComptesPage> createState() => _AdminComptesPageState();
}

class _AdminComptesPageState extends ConsumerState<AdminComptesPage> {
  final _recherche = TextEditingController();

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final comptes = ref.watch(comptesProvider);
    final profil = ref.watch(profilProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des comptes'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              PpSpacing.lg,
              0,
              PpSpacing.lg,
              PpSpacing.md,
            ),
            child: TextField(
              controller: _recherche,
              onSubmitted: (valeur) =>
                  ref.read(rechercheComptesProvider.notifier).definir(valeur),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou adresse',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _recherche.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _recherche.clear();
                          ref
                              .read(rechercheComptesProvider.notifier)
                              .definir('');
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: comptes.when(
        loading: () => const PpLoadingState(),
        // Un refus d'autorisation n'est pas une panne : l'annoncer comme telle envoie
        // vérifier un wifi qui marche, et le bouton « Réessayer » ne peut pas aboutir.
        //
        // Le jeton porte déjà le rôle, sans quoi l'entrée serait cachée. Depuis
        // l'ADR 0007, il ne reste donc que RG-ADM-10 — le mot de passe imposé au compte
        // amorcé — et le rôle Support sur une action qui lui est fermée.
        error: (erreur, _) => erreur is ApiException && erreur.statusCode == 403
            ? const PpErrorState(
                message:
                    'Action refusée. Si c’est la première connexion du compte '
                    'administrateur, change son mot de passe : rien d’autre n’est '
                    'permis avant.',
              )
            : PpErrorState(
                message: PpL10n.of(context).erreurReseau,
                onRetry: () => ref.invalidate(comptesProvider),
              ),
        data: (page) => page.elements.isEmpty
            ? const PpEmptyState(
                titre: 'Aucun compte trouvé',
                explication:
                    'Modifie ta recherche, ou efface-la pour tout afficher.',
                icone: Icons.search_off_rounded,
              )
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(comptesProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(PpSpacing.lg),
                  itemCount: page.elements.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: PpSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: PpSpacing.sm),
                        child: Text(
                          '${page.total} compte(s)',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      );
                    }

                    final compte = page.elements[index - 1];

                    return _CarteCompte(
                      compte: compte,
                      estMoi: compte.id == profil?.id,
                      peutAdministrer: profil?.estAdministrateur ?? false,
                    );
                  },
                ),
              ),
      ),
    );
  }
}

class _CarteCompte extends ConsumerWidget {
  const _CarteCompte({
    required this.compte,
    required this.estMoi,
    required this.peutAdministrer,
  });

  final FicheCompte compte;
  final bool estMoi;
  final bool peutAdministrer;

  static final _dateFr = DateFormat('dd/MM/yyyy', 'fr_FR');

  Future<void> _agir(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
    String succes,
  ) async {
    try {
      await action();
      ref.invalidate(comptesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(succes)));
      }
    } on ApiException catch (erreur) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(PpL10n.of(context).erreurReseau)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final api = ref.read(comptesApiProvider);

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PpAvatar(
                nom: compte.nomAffiche,
                urlPhoto: compte.urlPhoto,
                taille: 44,
              ),
              const SizedBox(width: PpSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            compte.nomAffiche,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (estMoi) ...[
                          const SizedBox(width: PpSpacing.sm),
                          Text('· toi', style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                    Text(
                      compte.email ?? 'Adresse libérée',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.md),
          Wrap(
            spacing: PpSpacing.sm,
            runSpacing: PpSpacing.xs,
            children: [
              if (compte.rolePlateforme != 'User')
                _Puce(
                  compte.rolePlateforme == 'PlatformAdmin'
                      ? 'Administrateur'
                      : 'Support',
                  PpColors.violet,
                ),
              if (compte.suspendu) _Puce('Suspendu', PpColors.rouge),
              if (compte.estSupprime)
                _Puce('Supprimé', PpColors.texteSecondaireClair),
              if (!compte.emailVerifie && !compte.estSupprime)
                _Puce('Adresse non vérifiée', PpColors.orange),
              if (!compte.aUnMotDePasse && !compte.estSupprime)
                _Puce('Sans mot de passe', PpColors.bleu),
              _Puce(
                '${compte.sessionsActives} session(s)',
                PpColors.texteSecondaireClair,
              ),
            ],
          ),
          if (compte.motifSuspension != null) ...[
            const SizedBox(height: PpSpacing.sm),
            Text(
              'Motif : ${compte.motifSuspension}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          const SizedBox(height: PpSpacing.sm),
          Text(
            'Créé le ${_dateFr.format(compte.creeLe.toLocal())}'
            '${compte.derniereConnexion == null ? ' · jamais connecté' : ' · vu le ${_dateFr.format(compte.derniereConnexion!.toLocal())}'}',
            style: theme.textTheme.bodySmall,
          ),
          if (!compte.estSupprime) ...[
            const Divider(height: PpSpacing.xl),
            Wrap(
              spacing: PpSpacing.sm,
              runSpacing: PpSpacing.sm,
              children: [
                // Consultation et dépannage : accessibles à Support (RG-ADM-05).
                OutlinedButton.icon(
                  icon: const Icon(Icons.lock_reset_rounded, size: 16),
                  label: const Text('Réinitialiser'),
                  onPressed: () => _agir(
                    context,
                    ref,
                    () => api.declencherReinitialisation(compte.id),
                    'Un lien vient de partir vers ${compte.email}.',
                  ),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.logout_rounded, size: 16),
                  label: const Text('Déconnecter'),
                  onPressed: () => _agir(
                    context,
                    ref,
                    () => api.revoquerToutesSessions(compte.id),
                    'Sessions révoquées.',
                  ),
                ),
                // Recours quand le courriel de vérification n'arrive pas : sans lui, la
                // seule issue serait une écriture directe en base (EF-ADM-11).
                if (!compte.emailVerifie)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.mark_email_read_outlined, size: 16),
                    label: const Text('Vérifier l’adresse'),
                    onPressed: () => _agir(
                      context,
                      ref,
                      () => api.forcerVerificationAdresse(compte.id),
                      'Adresse marquée comme vérifiée.',
                    ),
                  ),
                // Actions réservées à PlatformAdmin (RG-ADM-05), et jamais sur
                // soi-même (RG-ADM-03).
                if (peutAdministrer && !estMoi) ...[
                  if (compte.suspendu)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: const Text('Réactiver'),
                      onPressed: () => _agir(
                        context,
                        ref,
                        () => api.reactiver(compte.id),
                        'Compte réactivé.',
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      icon: const Icon(Icons.pause_rounded, size: 16),
                      label: const Text('Suspendre'),
                      onPressed: () => _suspendre(context, ref, api),
                    ),
                  _MenuRole(
                    compte: compte,
                    onChoisi: (role) => _agir(
                      context,
                      ref,
                      () => api.changerRole(compte.id, role),
                      'Rôle modifié.',
                    ),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(
                      Icons.workspace_premium_outlined,
                      size: 16,
                    ),
                    label: Text(compte.estAbonne ? 'Retirer Premium' : 'Passer Premium'),
                    onPressed: () => _changerFormule(context, ref, api),
                  ),
                  OutlinedButton.icon(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: PpColors.texteSur(
                        PpColors.rouge,
                        theme.brightness,
                      ),
                    ),
                    label: Text(
                      'Supprimer',
                      style: TextStyle(
                        color: PpColors.texteSur(
                          PpColors.rouge,
                          theme.brightness,
                        ),
                      ),
                    ),
                    onPressed: () => _supprimer(context, ref, api),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Enchaîne dialogue puis action. Le contexte n'est réutilisé qu'après contrôle de
  /// `mounted`, faute de quoi une navigation pendant l'attente ferait planter l'appel.
  Future<void> _suspendre(
    BuildContext context,
    WidgetRef ref,
    ComptesApi api,
  ) async {
    final motif = await _demanderMotif(context);

    if (motif == null || !context.mounted) {
      return;
    }

    await _agir(
      context,
      ref,
      () => api.suspendre(compte.id, motif),
      'Compte suspendu.',
    );
  }

  /// Attribue ou retire la formule payante (EF-PRM-04).
  ///
  /// Retirer ne demande qu'un motif ; accorder demande en plus une durée, parce qu'une
  /// formule sans terme ne se renouvelle pas et que le serveur refuse une échéance nulle.
  Future<void> _changerFormule(
    BuildContext context,
    WidgetRef ref,
    ComptesApi api,
  ) async {
    if (compte.estAbonne) {
      final motif = await _demanderMotifFormule(
        context,
        titre: 'Retirer la formule payante',
        action: 'Retirer',
      );

      if (motif == null || !context.mounted) {
        return;
      }

      await _agir(
        context,
        ref,
        () => api.retirerFormule(compte.id, motif),
        'Compte ramené à la formule gratuite.',
      );

      return;
    }

    final choix = await _demanderFormule(context);

    if (choix == null || !context.mounted) {
      return;
    }

    await _agir(
      context,
      ref,
      () => api.accorderFormule(compte.id, choix.echeance, choix.motif),
      'Formule payante accordée.',
    );
  }

  Future<void> _supprimer(
    BuildContext context,
    WidgetRef ref,
    ComptesApi api,
  ) async {
    final confirme = await _confirmerSuppression(context, compte);

    if (confirme != true || !context.mounted) {
      return;
    }

    await _agir(
      context,
      ref,
      () => api.supprimerCompteAdmin(compte.id),
      'Compte supprimé et anonymisé.',
    );
  }

  static Future<String?> _demanderMotif(BuildContext context) {
    final controleur = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspendre ce compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le motif est obligatoire : il figurera au journal d’audit et doit '
              'rester compréhensible dans six mois.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.md),
            TextField(
              controller: controleur,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Motif de la suspension',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final motif = controleur.text.trim();
              Navigator.of(context).pop(motif.isEmpty ? null : motif);
            },
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );
  }

  static Future<bool?> _confirmerSuppression(
    BuildContext context,
    FicheCompte compte,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Supprimer ${compte.nomAffiche} ?'),
      content: Text(
        'Le compte est anonymisé : son adresse est libérée, ses sessions révoquées. '
        'Ses contributions financières aux événements sont conservées, sans quoi les '
        'comptes des autres participants deviendraient faux.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: PpColors.rouge),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
}

class _MenuRole extends StatelessWidget {
  const _MenuRole({required this.compte, required this.onChoisi});

  final FicheCompte compte;
  final void Function(String role) onChoisi;

  @override
  Widget build(BuildContext context) => PopupMenuButton<String>(
    tooltip: 'Changer le rôle',
    onSelected: onChoisi,
    itemBuilder: (context) => [
      for (final role in ['User', 'Support', 'PlatformAdmin'])
        PopupMenuItem(
          value: role,
          enabled: role != compte.rolePlateforme,
          child: Text(switch (role) {
            'User' => 'Utilisateur',
            'Support' => 'Support',
            _ => 'Administrateur',
          }),
        ),
    ],
    child: OutlinedButton.icon(
      onPressed: null,
      icon: const Icon(Icons.badge_outlined, size: 16),
      label: const Text('Rôle'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class _Puce extends StatelessWidget {
  const _Puce(this.texte, this.couleur);

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) {
    final lisible = PpColors.texteSur(couleur, Theme.of(context).brightness);

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
        texte,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: lisible,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Choix fait dans la boîte d'attribution de formule.
class _ChoixFormule {
  const _ChoixFormule({required this.echeance, required this.motif});

  final DateTime echeance;
  final String motif;
}

/// Demande une durée et un motif avant d'accorder la formule payante (EF-PRM-04).
///
/// Trois durées proposées plutôt qu'un sélecteur de date : ce sont les seules qu'un
/// administrateur accorde en pratique, et un calendrier complet pour trois valeurs
/// ajouterait un écran sans rien apporter.
Future<_ChoixFormule?> _demanderFormule(BuildContext context) {
  final controleur = TextEditingController();
  var mois = 1;

  return showDialog<_ChoixFormule>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Accorder la formule payante'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Durée'),
            const SizedBox(height: PpSpacing.sm),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1 mois')),
                ButtonSegment(value: 12, label: Text('1 an')),
              ],
              selected: {mois},
              onSelectionChanged: (choix) =>
                  setState(() => mois = choix.first),
            ),
            const SizedBox(height: PpSpacing.lg),
            TextField(
              controller: controleur,
              autofocus: true,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Motif',
                hintText: 'Client pilote, geste commercial…',
              ),
            ),
            const SizedBox(height: PpSpacing.sm),
            Text(
              'Le motif est consigné au journal d\'audit, qui ne peut plus être '
              'modifié.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final motif = controleur.text.trim();

              if (motif.isEmpty) {
                return;
              }

              Navigator.of(context).pop(
                _ChoixFormule(
                  // Le serveur refuse une échéance passée : la date est calculée à
                  // partir de maintenant, jamais saisie librement.
                  echeance: DateTime.now().add(Duration(days: 30 * mois)),
                  motif: motif,
                ),
              );
            },
            child: const Text('Accorder'),
          ),
        ],
      ),
    ),
  );
}

/// Demande le motif d'un retrait de formule. Obligatoire comme pour une suspension :
/// le journal d'audit doit dire pourquoi (RG-ADM-06).
Future<String?> _demanderMotifFormule(
  BuildContext context, {
  required String titre,
  required String action,
}) {
  final controleur = TextEditingController();

  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titre),
      content: TextField(
        controller: controleur,
        autofocus: true,
        maxLength: 500,
        decoration: const InputDecoration(
          labelText: 'Motif',
          hintText: 'Fin de la période d\'essai…',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            final motif = controleur.text.trim();

            if (motif.isEmpty) {
              return;
            }

            Navigator.of(context).pop(motif);
          },
          child: Text(action),
        ),
      ],
    ),
  );
}
