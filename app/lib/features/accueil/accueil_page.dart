import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/dates.dart';
import '../../core/models/evenement.dart';
import '../../core/models/membre.dart';
import '../../core/providers.dart';
import '../../core/session/role_plateforme.dart';
import '../../design/components/pp_bandeau_hors_ligne.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_date_pastille.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_status_chip.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/marque.dart';
import '../evenement/presence_vers_pastille.dart';

/// Écran d'accueil : les événements de la personne, à venir puis passés (EF-EVT-05).
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);
    final evenements = ref.watch(mesEvenementsProvider);
    // Le rôle est lu dans le jeton déjà en mémoire, non demandé au serveur : charger
    // le profil au démarrage ajouterait un appel réseau à chaque lancement de
    // l'application pour décider de l'affichage d'une seule icône.
    final personnelPlateforme = ref
        .watch(rolePlateformeProvider)
        .maybeWhen(data: estPersonnelPlateforme, orElse: () => false);

    return Scaffold(
      appBar: PpBarreApp(
        titre: const Text(PpMarque.nom),
        actions: [
          // Gérer les comptes est le travail quotidien d'un administrateur : enterrée
          // dans « Mon profil », l'entrée se cherche à chaque fois.
          if (personnelPlateforme)
            IconButton(
              onPressed: () => context.push(PpRoutes.adminComptes),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              tooltip: l10n.accueilAdministration,
            ),
          IconButton(
            onPressed: () => context.push(PpRoutes.profil),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: l10n.accueilMonProfil,
          ),
        ],
      ),
      // Le bouton suit le rail : collé à l'angle de l'écran, il se retrouverait loin
      // de la liste sur laquelle il agit.
      floatingActionButtonLocation: const PpFabDansLeRail(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(PpRoutes.creationEvenement),
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.creerUnEvenement),
      ),
      body: Column(
        children: [
          PpBandeauHorsLigne(
            onReessayer: () => ref.invalidate(mesEvenementsProvider),
          ),
          Expanded(
            // Le rail borne la largeur : étirée sur un écran de bureau, une carte
            // d'événement place son titre à gauche et son état de présence à l'autre
            // bout, et la liste ne se lit plus d'un regard.
            child: PpRail(
              child: evenements.when(
                loading: () => const PpLoadingState(),
                error: (_, _) => PpErrorState(
                  message: l10n.accueilChargementErreur,
                  onRetry: () => ref.invalidate(mesEvenementsProvider),
                ),
                data: (liste) => liste.isEmpty
                    ? _etatVide(context)
                    : _Liste(evenements: liste),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _etatVide(BuildContext context) {
    final l10n = PpL10n.of(context);

    return PpEmptyState(
      titre: l10n.accueilVideTitre,
      explication: l10n.accueilVideExplication,
      action: Column(
        children: [
          FilledButton.icon(
            onPressed: () => context.push(PpRoutes.creationEvenement),
            icon: const Icon(Icons.add_rounded),
            label: Text(l10n.creerUnEvenement),
          ),
          const SizedBox(height: PpSpacing.sm),
          TextButton(
            onPressed: () => context.push(PpRoutes.rejoindreParCode),
            child: Text(l10n.rejoindreUnEvenement),
          ),
        ],
      ),
    );
  }
}

/// Liste sectionnée : à venir d'abord, du plus proche au plus lointain ; puis les
/// passés, du plus récent au plus ancien.
///
/// L'appartenance à une section vient du serveur (`isPast`) et n'est jamais recalculée :
/// l'horloge d'un téléphone peut être fausse, et une soirée passerait du mauvais côté.
class _Liste extends ConsumerWidget {
  const _Liste({required this.evenements});

  final List<EvenementDeLaListe> evenements;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = PpL10n.of(context);

    final aVenir = evenements.where((e) => !e.estPasse).toList()
      ..sort((a, b) => a.debut.compareTo(b.debut));
    final passes = evenements.where((e) => e.estPasse).toList()
      ..sort((a, b) => b.debut.compareTo(a.debut));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mesEvenementsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          PpSpacing.lg,
          PpSpacing.sm,
          PpSpacing.lg,
          PpSpacing.xxxl * 2,
        ),
        children: [
          if (aVenir.isNotEmpty) ...[
            _ProchaineSoiree(evenement: aVenir.first),
            const SizedBox(height: PpSpacing.lg),
            PpEyebrow(l10n.evenementsAVenir),
            const SizedBox(height: PpSpacing.sm),
            for (final e in aVenir) _Carte(evenement: e),
          ],
          if (passes.isNotEmpty) ...[
            const SizedBox(height: PpSpacing.lg),
            PpEyebrow(l10n.evenementsPasses),
            const SizedBox(height: PpSpacing.sm),
            for (final e in passes) _Carte(evenement: e, estompee: true),
          ],
        ],
      ),
    );
  }
}

/// Annonce la soirée la plus proche, et dans combien de temps elle tombe.
///
/// C'est la question que l'on se pose en ouvrant l'application : « c'est bientôt ? ».
/// Une liste, même bien rangée, ne répond à rien — il faut lire, comparer les dates,
/// et faire soi-même le calcul.
///
/// Le dégradé de marque n'apparaît qu'ici, sur cette annonce et sur la pastille de la
/// soirée à venir. Étendu aux autres surfaces, il cesserait de désigner quoi que ce
/// soit.
class _ProchaineSoiree extends StatelessWidget {
  const _ProchaineSoiree({required this.evenement});

  final EvenementDeLaListe evenement;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jours = joursCalendairesJusqua(evenement.debut);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.lg),
      decoration: BoxDecoration(
        gradient: PpColors.degradeMarque,
        borderRadius: BorderRadius.circular(PpRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROCHAINE SOIRÉE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: PpSpacing.sm),
          Text(
            PpL10n.of(context).tdbDansNJours(jours),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PpSpacing.xs),
          Text(
            evenement.nom,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Carton d'invitation d'une soirée.
///
/// La date est traitée comme un objet, à gauche, et non comme une ligne de texte : on
/// cherche « c'est quand » avant de lire le nom. Le reste — heure, lieu, présences —
/// se lit ensuite, dans cet ordre.
class _Carte extends StatelessWidget {
  const _Carte({required this.evenement, this.estompee = false});

  static final _heureEtLieu = DateFormat('EEEE, HH:mm', 'fr_FR');

  final EvenementDeLaListe evenement;
  final bool estompee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = PpL10n.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.md),
      child: Opacity(
        opacity: estompee ? 0.7 : 1,
        child: PpCard(
          onTap: () => context.push(PpRoutes.versEvenement(evenement.id)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PpDatePastille(date: evenement.debut, estompee: estompee),
              const SizedBox(width: PpSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (evenement.monRole.peutGerer)
                      PpEyebrow(
                        evenement.monRole == RoleMembre.proprietaire
                            ? l10n.roleProprietaire
                            : l10n.roleAdministrateur,
                        couleur: PpColors.violet,
                      ),
                    // Le rôle est placé au-dessus du titre et non à côté : un nom long et une
                    // étiquette « CO-ORGANISATEUR » ne tiennent pas sur une ligne de
                    // téléphone, et tronquer le nom de l'événement serait le pire choix.
                    Text(evenement.nom, style: theme.textTheme.titleLarge),
                    const SizedBox(height: PpSpacing.xs),
                    Text(
                      [
                        _heureEtLieu.format(evenement.debut),
                        ?evenement.adresse,
                      ].join(' · '),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: PpSpacing.md),
                    // Wrap et non Row : sur un téléphone étroit, « Arrive plus tard » suivi
                    // de « 12 présents sur 24 invités » dépasse la largeur disponible.
                    Wrap(
                      spacing: PpSpacing.sm,
                      runSpacing: PpSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PpStatusChip(
                          presence: versPastille(evenement.monStatut),
                        ),
                        Text(
                          l10n.presencesSurInvites(
                            evenement.presents,
                            evenement.invites,
                          ),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
