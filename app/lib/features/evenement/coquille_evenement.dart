import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/temps_reel/ecoute_evenement.dart';
import '../../core/temps_reel/service_temps_reel.dart';

import '../../app/router.dart';
import '../../design/components/pp_barre_app.dart';
import '../../design/components/pp_rail.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
import '../courses/article_feuille.dart';
import '../courses/courses_page.dart';
import '../depenses/depense_feuille.dart';
import '../depenses/depenses_page.dart';
import '../discussion/discussion_page.dart';
import 'tableau_de_bord_page.dart';

/// Coquille de navigation d'un événement.
///
/// Cinq entrées au maximum (RG-UI-01) : tout ce qui vient ensuite — invités,
/// remboursements, tâches, sondages, paramètres — passe sous « Plus ». La contrainte
/// tient parce que c'est en ajoutant un onglet « juste pour cette fois » que la
/// navigation se dégrade.
///
/// Cinq : accueil, courses, dépenses, discussion, et le reste sous « Plus ». La place
/// libérée par le planning — retiré, la date d'un événement se règle dans ses
/// paramètres — revient à la discussion.
class CoquilleEvenement extends ConsumerStatefulWidget {
  const CoquilleEvenement({required this.eventId, super.key});

  final String eventId;

  @override
  ConsumerState<CoquilleEvenement> createState() => _CoquilleEvenementState();
}

class _CoquilleEvenementState extends ConsumerState<CoquilleEvenement> {
  /// Rang de l'onglet Discussion. Nommé parce qu'il sert à trois endroits, et qu'un 3
  /// écrit trois fois se désynchronise le jour où l'ordre des onglets change.
  static const _ongletDiscussion = 3;

  int _onglet = 0;

  EcouteEvenement? _ecoute;

  /// Le service est retenu dans un champ, et non relu dans dispose : Riverpod interdit
  /// d'utiliser `ref` sur un widget démonté, parce qu'il s'appuie sur le BuildContext.
  ServiceTempsReel? _tempsReel;

  @override
  void initState() {
    super.initState();

    // Le temps réel est branché ici et nulle part ailleurs : c'est l'écran qui borne la
    // durée de vie de la connexion, et une soirée qu'on quitte doit la fermer.
    final tempsReel = ref.read(serviceTempsReelProvider);
    _tempsReel = tempsReel;

    // ignore: discarded_futures
    tempsReel.connecter(widget.eventId);

    _ecoute = EcouteEvenement(invalider: _relire)..demarrer(tempsReel);
    // Relire à chaque ouverture. Riverpod ne rejette pas un FutureProvider.family
    // quand plus personne ne l'écoute : sans cette invalidation, ressortir d'une
    // soirée puis y revenir réaffiche les données de la première visite,
    // indéfiniment. Quelqu'un qui rejoint, une présence qui change, un article
    // pris en charge : rien n'apparaissait.
    //
    // Posée dans initState et non dans build, qui est rappelé à chaque changement
    // d'onglet et rechargerait tout à chaque geste.
    WidgetsBinding.instance.addPostFrameCallback((_) => _relire());
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _ecoute?.arreter();
    // ignore: discarded_futures
    _tempsReel?.deconnecter();
    super.dispose();
  }

  /// Redemande au serveur tout ce que cet écran affiche.
  void _relire() {
    if (!mounted) {
      return;
    }

    ref
      ..invalidate(evenementProvider(widget.eventId))
      ..invalidate(membresProvider(widget.eventId))
      ..invalidate(listeCoursesProvider(widget.eventId))
      ..invalidate(depensesProvider(widget.eventId))
      ..invalidate(reglementsProvider(widget.eventId))
      ..invalidate(sondagesProvider(widget.eventId))
      ..invalidate(epinglesProvider(widget.eventId));

    // Le fil de discussion se rafraîchit au lieu d'être invalidé. C'est un notifier
    // paginé : l'invalider le remettrait à sa première page, et les pages remontées
    // comme la position de lecture disparaîtraient à chaque message reçu.
    //
    // Son absence de cette liste était la raison pour laquelle la discussion ne bougeait
    // pas alors que le temps réel fonctionnait : le message arrivait, et rien ne
    // demandait au fil de se relire.
    // ignore: discarded_futures
    ref.read(filDiscussionProvider(widget.eventId).notifier).rafraichir();
  }

  /// Retour à l'accueil.
  ///
  /// `maybePop` d'abord : venant de l'accueil, on rend la pile telle qu'elle était,
  /// position de défilement comprise. Mais après une adhésion par lien, `context.go`
  /// a vidé la pile — un `BackButton` seul n'avait alors rien à dépiler et enfermait
  /// la personne dans la soirée. Même cas en ouvrant depuis une notification.
  Future<void> _revenir() async {
    if (await Navigator.of(context).maybePop()) {
      return;
    }

    if (mounted) {
      context.go(PpRoutes.accueil);
    }
  }

  /// Onglets de la navigation d'événement (RG-UI-01).
  ///
  /// Construits à la demande et non dans une constante : les libellés sont traduits,
  /// donc dépendants du contexte.
  static List<({String libelle, IconData icone, IconData icoineActive})>
  _onglets(BuildContext context) {
    final l10n = PpL10n.of(context);

    return [
      (
        libelle: l10n.ongletAccueil,
        icone: Icons.home_outlined,
        icoineActive: Icons.home_rounded,
      ),
      (
        libelle: l10n.ongletCourses,
        icone: Icons.shopping_cart_outlined,
        icoineActive: Icons.shopping_cart_rounded,
      ),
      (
        libelle: l10n.ongletDepenses,
        icone: Icons.euro_rounded,
        icoineActive: Icons.euro_rounded,
      ),
      (
        libelle: l10n.ongletDiscussion,
        icone: Icons.forum_outlined,
        icoineActive: Icons.forum_rounded,
      ),
      (
        libelle: l10n.ongletPlus,
        icone: Icons.more_horiz_rounded,
        icoineActive: Icons.more_horiz_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final onglets = _onglets(context);
    final evenement = ref.watch(evenementProvider(widget.eventId)).value;

    // Pastille de messages non lus sur l'onglet Discussion. Masquée quand on y est
    // déjà : signaler du non-lu à quelqu'un en train de lire n'a pas de sens, et le
    // repère de lecture avance de lui-même.
    final nonLus = _onglet == _ongletDiscussion
        ? 0
        : ref.watch(filDiscussionProvider(widget.eventId)).value?.nonLus ?? 0;

    // Au-delà de ce seuil, une barre de navigation basse étalée sur toute la largeur
    // sépare le geste du regard : la place est alors sur le côté.
    final large = MediaQuery.sizeOf(context).width >= PpBreakpoints.large;

    return Scaffold(
      appBar: PpBarreApp(
        bouton: BackButton(
          key: const Key('retour-evenement'),
          onPressed: _revenir,
        ),
        // Sondages et épingles prolongent la conversation : les chercher sous « Plus »
        // oblige à quitter le fil pour y revenir. Ils n'apparaissent que sur cet
        // onglet — ailleurs, ce serait deux icônes de plus dans une barre déjà
        // chargée.
        actions: [
          // Sur navigateur, le RefreshIndicator exige un geste de survol
          // inatteignable à la souris : sans cette commande, il n'existait aucun
          // moyen d'actualiser.
          IconButton(
            key: const Key('actualiser-evenement'),
            tooltip: 'Actualiser',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _relire,
          ),
          if (_onglet == _ongletDiscussion) ...[
            IconButton(
              key: const Key('acces-sondages'),
              tooltip: 'Sondages',
              icon: const Icon(Icons.how_to_vote_outlined),
              onPressed: () =>
                  context.push(PpRoutes.versSondages(widget.eventId)),
            ),
            IconButton(
              key: const Key('acces-epingles'),
              tooltip: 'Messages épinglés',
              icon: const Icon(Icons.push_pin_outlined),
              onPressed: () =>
                  context.push(PpRoutes.versEpingles(widget.eventId)),
            ),
          ],
        ],
        // Le nom de l'événement, pas celui de l'onglet : « Courses » ne dit pas de
        // quelle soirée il s'agit, et l'on peut être membre de trois événements.
        titre: Text(evenement?.nom ?? onglets[_onglet].libelle),
        basDeBarre: evenement == null
            ? null
            : _SousTitreEvenement(
                onglet: onglets[_onglet].libelle,
                membres: evenement.nombreMembres,
                presents: evenement.nombrePresents,
              ),
      ),
      // IndexedStack et non reconstruction : changer d'onglet ne doit ni recharger le
      // tableau de bord, ni perdre la position de défilement.
      body: _Corps(
        large: large,
        onglets: onglets,
        selection: _onglet,
        ongletDePastille: _ongletDiscussion,
        nonLus: nonLus,
        onSelection: (index) => setState(() => _onglet = index),
        child: IndexedStack(
          index: _onglet,
          children: [
            TableauDeBordPage(evenementId: widget.eventId),
            CoursesPage(evenementId: widget.eventId),
            DepensesPage(evenementId: widget.eventId),
            DiscussionPage(evenementId: widget.eventId),
            _MenuPlus(evenementId: widget.eventId),
          ],
        ),
      ),
      floatingActionButtonLocation: const PpFabDansLeRail(),
      floatingActionButton: switch (_onglet) {
        1 => FloatingActionButton.extended(
          onPressed: () => ouvrirFeuilleArticle(context, widget.eventId),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ajouter'),
        ),
        2 => FloatingActionButton.extended(
          onPressed: () => ouvrirFeuilleDepense(context, widget.eventId),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Dépense'),
        ),
        _ => null,
      },
      bottomNavigationBar: large
          ? null
          : NavigationBar(
              selectedIndex: _onglet,
              onDestinationSelected: (index) => setState(() => _onglet = index),
              destinations: [
                for (final onglet in onglets)
                  NavigationDestination(
                    icon: _AvecPastille(
                      nombre: onglets.indexOf(onglet) == _ongletDiscussion
                          ? nonLus
                          : 0,
                      child: Icon(onglet.icone),
                    ),
                    selectedIcon: Icon(onglet.icoineActive),
                    label: onglet.libelle,
                  ),
              ],
            ),
    );
  }
}

/// Deuxième ligne de la barre : l'onglet ouvert et l'état des présences.
///
/// Le titre porte le nom de l'événement, cette ligne dit où l'on est et combien de
/// monde est attendu. Deux informations que l'on cherche sans arrêt en préparant une
/// soirée, et qui n'ont pas à coûter une navigation.
class _SousTitreEvenement extends StatelessWidget
    implements PreferredSizeWidget {
  const _SousTitreEvenement({
    required this.onglet,
    required this.membres,
    required this.presents,
  });

  final String onglet;
  final int membres;
  final int presents;

  @override
  Size get preferredSize => const Size.fromHeight(28);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(
        left: PpSpacing.lg,
        right: PpSpacing.lg,
        bottom: PpSpacing.sm,
      ),
      child: Row(
        children: [
          // Le nom de l'onglet ne se coupe pas : c'est le repère, et il est court.
          Text(
            onglet.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: PpColors.violet,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: PpSpacing.sm),
          Text('·', style: theme.textTheme.labelSmall),
          const SizedBox(width: PpSpacing.sm),
          // La chaîne traduite, et non une concaténation : elle porte les règles
          // d'accord des deux nombres. Construite à la main, elle affichait
          // « 1 présents sur 1 invités ».
          //
          // Flexible et non Text nu : « Personne n'a encore confirmé » est bien plus
          // longue que « 2 présents sur 2 », et la ligne débordait de soixante pixels
          // sur un écran étroit.
          Flexible(
            child: Text(
              PpL10n.of(context).presencesSurInvites(presents, membres),
              style: theme.textTheme.labelSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dispose la navigation : sur le côté quand la place le permet, en bas sinon.
///
/// Le contenu est posé dans un rail, faute de quoi une carte s'étirerait sur toute la
/// largeur d'un écran de bureau et son bouton d'action se retrouverait à l'autre bout.
class _Corps extends StatelessWidget {
  const _Corps({
    required this.large,
    required this.onglets,
    required this.selection,
    required this.ongletDePastille,
    required this.nonLus,
    required this.onSelection,
    required this.child,
  });

  final bool large;
  final List<({String libelle, IconData icone, IconData icoineActive})> onglets;
  final int selection;

  /// Onglet portant la pastille de non-lus, et leur nombre.
  final int ongletDePastille;
  final int nonLus;

  final ValueChanged<int> onSelection;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final contenu = PpRail(child: child);

    if (!large) {
      return contenu;
    }

    return Row(
      children: [
        NavigationRail(
          selectedIndex: selection,
          onDestinationSelected: onSelection,
          labelType: NavigationRailLabelType.all,
          destinations: [
            for (final (rang, onglet) in onglets.indexed)
              NavigationRailDestination(
                icon: _AvecPastille(
                  nombre: rang == ongletDePastille ? nonLus : 0,
                  child: Icon(onglet.icone),
                ),
                selectedIcon: Icon(onglet.icoineActive),
                label: Text(onglet.libelle),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(child: contenu),
      ],
    );
  }
}

/// Entrées qui ne tiennent pas dans les cinq onglets (RG-UI-01).
class _MenuPlus extends StatelessWidget {
  const _MenuPlus({required this.evenementId});

  final String evenementId;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.people_outline_rounded),
          title: Text(l10n.menuPlusInvites),
          onTap: () => context.push(PpRoutes.versInvites(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.how_to_vote_outlined),
          title: const Text('Sondages'),
          onTap: () => context.push(PpRoutes.versSondages(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.push_pin_outlined),
          title: const Text('Épinglé'),
          onTap: () => context.push(PpRoutes.versEpingles(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.handshake_rounded),
          title: const Text('Qui rend quoi'),
          onTap: () => context.push(PpRoutes.versReglements(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_rounded),
          title: Text(l10n.menuPlusInviter),
          onTap: () => context.push(PpRoutes.versInvitation(evenementId)),
        ),
        ListTile(
          leading: const Icon(Icons.settings_outlined),
          title: Text(l10n.menuPlusParametres),
          onTap: () => context.push(PpRoutes.versParametres(evenementId)),
        ),
      ],
    );
  }
}

/// Icône surmontée d'une pastille de non-lus.
///
/// Le nombre plutôt qu'un simple point : « trois messages » et « quarante messages »
/// ne se lisent pas de la même façon, et on décide d'ouvrir ou non en fonction. Au-delà
/// de neuf, la pastille s'élargirait au point de déborder l'icône, d'où le « 9+ ».
class _AvecPastille extends StatelessWidget {
  const _AvecPastille({required this.nombre, required this.child});

  final int nombre;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (nombre <= 0) {
      return child;
    }

    // Le rose ici est délibéré et reste dans la charte : une pastille de non-lus est
    // une sollicitation, pas un état d'avancement, et c'est le seul endroit de la
    // navigation où l'accent secondaire a un rôle. Le contraste vient du rôle du thème,
    // pas d'un blanc écrit en dur.
    final schema = Theme.of(context).colorScheme;

    return Badge(
      label: Text(nombre > 9 ? '9+' : '$nombre'),
      backgroundColor: schema.secondary,
      textColor: schema.onSecondary,
      child: child,
    );
  }
}
