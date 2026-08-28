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
import '../../design/components/pp_apparition.dart';
import '../../design/components/pp_bandeau_hors_ligne.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_date_pastille.dart';
import '../../design/components/pp_formule.dart';
import '../../design/components/pp_rail.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_status_chip.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../../l10n/marque.dart';
import '../evenement/presence_vers_pastille.dart';

/// Écran d'accueil : les événements de la personne, à venir puis passés (EF-EVT-05).
class AccueilPage extends ConsumerWidget {
  const AccueilPage({super.key, this.maintenant});

  final DateTime? maintenant;

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
      body: Column(
        children: [
          PpBandeauHorsLigne(
            onReessayer: () => ref.invalidate(mesEvenementsProvider),
          ),
          const _ActionsAccueil(),
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
                    : _Liste(evenements: liste, maintenant: maintenant),
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
    );
  }
}

/// Les deux façons d'ajouter une soirée restent ensemble et toujours visibles.
///
/// Elles ne dépendent pas du chargement ni du contenu de la liste : posséder déjà une
/// soirée n'empêche ni d'en organiser une autre, ni de rejoindre celle d'un proche.
class _ActionsAccueil extends StatelessWidget {
  const _ActionsAccueil();

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return PpRail(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PpSpacing.lg,
          PpSpacing.sm,
          PpSpacing.lg,
          PpSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push(PpRoutes.creationEvenement),
                icon: const Icon(Icons.add_rounded),
                label: Text(l10n.creerUnEvenement),
              ),
            ),
            const SizedBox(width: PpSpacing.sm),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(PpRoutes.rejoindreParCode),
                icon: const Icon(Icons.vpn_key_outlined),
                label: Text(l10n.rejoindreUnEvenement),
              ),
            ),
          ],
        ),
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
  const _Liste({required this.evenements, this.maintenant});

  final List<EvenementDeLaListe> evenements;
  final DateTime? maintenant;

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
            PpApparition(
              child: _ProchaineSoiree(
                evenement: aVenir.first,
                maintenant: maintenant,
              ),
            ),
            const SizedBox(height: PpSpacing.lg),
            PpEyebrow(l10n.evenementsAVenir),
            const SizedBox(height: PpSpacing.sm),
            for (final (rang, e) in aVenir.indexed)
              PpApparition(
                rang: rang + 1,
                child: _Carte(evenement: e),
              ),
          ],
          if (passes.isNotEmpty) ...[
            const SizedBox(height: PpSpacing.lg),
            PpEyebrow(l10n.evenementsPasses),
            const SizedBox(height: PpSpacing.sm),
            // Le rang repart de zéro : ces cartes sont plus bas, donc rarement visibles
            // au premier écran, et prolonger le décalage les ferait arriver en retard.
            for (final (rang, e) in passes.indexed)
              PpApparition(
                rang: rang,
                child: _Carte(evenement: e, estompee: true),
              ),
          ],
          const SizedBox(height: PpSpacing.xl),
          const _QuotaFormule(),
        ],
      ),
    );
  }
}

/// Quota consommé, en pied de liste (EF-PRM-05).
///
/// En pied et non en tête : ce n'est pas la question qu'on se pose en ouvrant
/// l'application. Mais visible tout de même, parce qu'une limite découverte au seul
/// moment du refus est une mauvaise surprise.
///
/// Le décompte se fait sur la liste déjà chargée : le rôle de l'appelant et le caractère
/// passé de chaque soirée y figurent, et une route de plus serait un aller-retour réseau
/// pour deux lignes de calcul.
///
/// La formule, elle, vient du profil, que l'accueil ne chargeait pas jusqu'ici. La
/// requête est donc nouvelle, mais elle ne retarde aucun affichage : tant qu'elle n'a pas
/// répondu, ce bloc s'efface et la liste reste complète au-dessus. `NF-PERF-04` mesure le
/// premier affichage utile, qui n'attend pas cette réponse.
class _QuotaFormule extends ConsumerWidget {
  const _QuotaFormule();

  /// Reprend RG-PRM-01. Codé ici faute d'être exposé par l'API : ce n'est qu'un
  /// affichage, le serveur reste seul à appliquer la règle, et un écart se verrait au
  /// premier refus.
  static const _quota = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profil = ref.watch(profilProvider).value;
    final evenements = ref.watch(mesEvenementsProvider).value;

    if (profil == null || evenements == null || profil.estAbonne) {
      return const SizedBox.shrink();
    }

    final possedes = evenements
        .where((e) => !e.estPasse && e.monRole == RoleMembre.proprietaire)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PpSpacing.xs),
      child: PpFormule(
        premiumJusquau: profil.premiumJusquau,
        evenementsPossedes: possedes,
        quotaEvenements: _quota,
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
  const _ProchaineSoiree({required this.evenement, this.maintenant});

  final EvenementDeLaListe evenement;
  final DateTime? maintenant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jours = joursCalendairesJusqua(evenement.debut, depuis: maintenant);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.lg),
      decoration: BoxDecoration(
        gradient: PpColors.degradeMarque,
        borderRadius: BorderRadius.circular(PpRadius.card),
        // Cette annonce est l'élément le plus haut de l'écran : sans ombre, un aplat de
        // couleur posé à plat sur un fond pâle se lit comme un bloc collé.
        boxShadow: PpElevation.flottant(theme.brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROCHAINE SOIRÉE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: PpSpacing.sm),
          Text(
            PpL10n.of(context).tdbDansNJours(jours),
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: PpSpacing.xs),
          Text(
            evenement.nom,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.92),
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
