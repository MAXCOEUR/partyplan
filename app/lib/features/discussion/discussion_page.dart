import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/router.dart';
import '../../core/media/type_mime_image.dart';
import '../../core/models/membre.dart';
import '../../core/models/message.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_image_message.dart';
import '../../design/components/pp_selecteur_emoji.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_texte_message.dart';
import '../../design/tokens.dart';
import '../sondages/sondage_feuille.dart';
import '../sondages/sondages_page.dart';
import 'epingler_feuille.dart';

/// Discussion d'un événement (EF-MSG-01 à EF-MSG-06).
///
/// Un seul fil, sans salons : une soirée à six personnes se retrouverait avec des
/// salons vides, et ce qui compte se perdrait dans celui que personne ne lit. Ce qu'on
/// veut retrouver s'épingle dans un dossier.
class DiscussionPage extends ConsumerStatefulWidget {
  const DiscussionPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  ConsumerState<DiscussionPage> createState() => _DiscussionPageState();
}

class _DiscussionPageState extends ConsumerState<DiscussionPage> {
  final _saisie = TextEditingController();
  final _defilement = ScrollController();

  /// Message auquel on répond. Rappelé au-dessus de la saisie : sans ce rappel, on ne
  /// sait plus à quoi l'on répond au moment d'écrire.
  Message? _citation;

  bool _envoiEnCours = false;

  /// Vrai pendant le dépôt d'une image. Le geste est long sur un réseau de soirée :
  /// sans repère, on appuie une seconde fois.
  bool _imageEnCours = false;

  /// Plafond accepté par le serveur. Vérifié ici d'abord, pour ne pas faire attendre
  /// une montée vouée au refus.
  static const _tailleMaximale = 12 * 1024 * 1024;

  /// Combien de temps la ligne « Nouveaux messages » reste affichée.
  ///
  /// Elle sert à se repérer en arrivant, pas à rester : passé le premier regard, c'est
  /// une barre qui traverse la conversation sans plus rien dire.
  static const _dureeDeLaLigne = Duration(seconds: 10);

  /// Distance au haut du fil qui déclenche le chargement des messages plus anciens.
  ///
  /// Anticipée d'un écran : attendre le bord même laisserait voir un vide le temps de
  /// la requête.
  static const _margeDeRemontee = 600.0;

  /// Message sur lequel la vue est ancrée : le premier non lu à l'arrivée.
  ///
  /// Une fois posé, il ne change plus tant qu'on est sur l'écran. La ligne de reprise
  /// s'efface au bout de dix secondes, l'ancrage non : le déplacer ferait sauter la
  /// conversation jusqu'en bas sous les yeux de qui est en train de lire.
  String? _ancreAu;

  /// Vrai tant que la ligne « Nouveaux messages » est affichée.
  bool _ligneVisible = false;

  /// Vrai une fois la lecture prise en compte, pour ne pas la resignaler à chaque
  /// reconstruction de l'écran.
  bool _lectureSignalee = false;

  Timer? _effacementDeLaLigne;

  @override
  void initState() {
    super.initState();
    _defilement.addListener(_surDefilement);
  }

  @override
  void dispose() {
    _effacementDeLaLigne?.cancel();
    _defilement
      ..removeListener(_surDefilement)
      ..dispose();
    _saisie.dispose();
    super.dispose();
  }

  /// Charge la page précédente quand on approche du haut du fil.
  void _surDefilement() {
    if (!_defilement.hasClients) {
      return;
    }

    // Le centre du fil est la frontière de lecture : les messages plus anciens
    // s'étendent au-dessus, en positions négatives.
    final restant =
        _defilement.position.pixels - _defilement.position.minScrollExtent;

    if (restant < _margeDeRemontee) {
      ref
          .read(filDiscussionProvider(widget.evenementId).notifier)
          .chargerPlusAncien();
    }
  }

  /// Pose la ligne de reprise à l'arrivée, puis la retire et signale la lecture.
  void _prendreEnCompteLaLecture(FilDiscussion fil) {
    if (_lectureSignalee) {
      return;
    }

    _lectureSignalee = true;

    if (fil.nonLus == 0) {
      return;
    }

    // Le premier non lu peut se trouver au-dessus de la page reçue : les pages
    // intermédiaires sont demandées d'abord, sinon le repère désigne un message absent
    // de l'écran et il n'y a rien à montrer.
    unawaited(
      ref
          .read(filDiscussionProvider(widget.evenementId).notifier)
          .rattraperLesNonLus(),
    );

    // La ligne est posée hors de la phase de construction : l'état se change après la
    // frame, jamais pendant qu'elle se dessine.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _ancreAu = fil.premierNonLuId;
        _ligneVisible = true;
      });

      _effacementDeLaLigne = Timer(_dureeDeLaLigne, () {
        if (!mounted) {
          return;
        }

        setState(() => _ligneVisible = false);
        ref
            .read(filDiscussionProvider(widget.evenementId).notifier)
            .marquerLu();
      });
    });
  }

  Future<void> _envoyer() async {
    final texte = _saisie.text.trim();

    if (texte.isEmpty || _envoiEnCours) {
      return;
    }

    setState(() => _envoiEnCours = true);

    // Les mentions sont déduites des noms écrits dans le message : taper « @Lucas »
    // suffit, sans passer par un sélecteur. Le serveur refuse un nom qui n'est pas
    // membre, ce qui borne l'erreur de frappe.
    final membres = ref.read(membresProvider(widget.evenementId)).value ?? [];
    final cites = membres
        .where((m) => texte.contains('@${m.nomAffiche}'))
        .map((m) => m.id)
        .toList();

    try {
      await ref
          .read(discussionApiProvider)
          .envoyer(
            widget.evenementId,
            corps: texte,
            repondreA: _citation?.id,
            mentions: cites,
          );

      _saisie.clear();
      setState(() => _citation = null);

      ref.invalidate(filDiscussionProvider(widget.evenementId));
    } on ApiException catch (erreur) {
      _signaler(erreur.title);
    } on Exception {
      _signaler('Message non envoyé. Réessaie.');
    } finally {
      if (mounted) {
        setState(() => _envoiEnCours = false);
      }
    }
  }

  /// Choisit une image et l'envoie comme message.
  ///
  /// Le fichier part tel quel : c'est le serveur qui réduit et réencode, ce qui
  /// s'applique quel que soit l'appareil et supprime les métadonnées EXIF — dont la
  /// géolocalisation qu'un téléphone inscrit dans chaque photo.
  Future<void> _joindreUneImage() async {
    if (_imageEnCours) {
      return;
    }

    final fichier = await FilePicker.pickFile(type: FileType.image);

    // L'écran a pu être quitté pendant que le sélecteur était ouvert : reprendre ici
    // sans vérifier ferait échouer la mise à jour d'état sur un widget démonté.
    if (fichier == null || !mounted) {
      return;
    }

    final typeMime = typeMimeImage(fichier.name);

    if (typeMime == null) {
      _signaler('Formats acceptés : JPEG, PNG, WebP et HEIC.');
      return;
    }

    // Contrôle local avant envoi : inutile de faire monter douze mégaoctets pour se
    // faire refuser au bout.
    if (await fichier.length() > _tailleMaximale) {
      _signaler('L’image ne doit pas dépasser 12 Mo.');
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() => _imageEnCours = true);

    try {
      final api = ref.read(discussionApiProvider);

      final adresse = await api.deposerImage(
        widget.evenementId,
        octets: await fichier.readAsBytes(),
        nomFichier: fichier.name,
        typeMime: typeMime,
      );

      // La légende éventuellement déjà écrite part avec l'image, plutôt que d'être
      // perdue ou envoyée séparément.
      final legende = _saisie.text.trim();

      await api.envoyer(
        widget.evenementId,
        corps: legende.isEmpty ? null : legende,
        urlPieceJointe: adresse,
        repondreA: _citation?.id,
      );

      _saisie.clear();
      setState(() => _citation = null);

      ref.invalidate(filDiscussionProvider(widget.evenementId));
    } on ApiException catch (erreur) {
      _signaler(erreur.title);
    } on Exception {
      _signaler('Image non envoyée. Réessaie.');
    } finally {
      if (mounted) {
        setState(() => _imageEnCours = false);
      }
    }
  }

  void _signaler(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _ouvrirLien(String url) async {
    final cible = Uri.tryParse(url);

    if (cible == null ||
        !await launchUrl(cible, mode: LaunchMode.externalApplication)) {
      _signaler('Ce lien n’a pas pu être ouvert.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fil = ref.watch(filDiscussionProvider(widget.evenementId));

    return Column(
      children: [
        Expanded(
          child: fil.when(
            loading: () => const PpLoadingState(),
            error: (_, _) => PpErrorState(
              message: 'Impossible de charger la discussion.',
              onRetry: () =>
                  ref.invalidate(filDiscussionProvider(widget.evenementId)),
            ),
            data: (donnees) {
              _prendreEnCompteLaLecture(donnees);

              return donnees.estVide
                  ? const PpEmptyState(
                      titre: 'Rien de dit pour l’instant',
                      explication:
                          'Pose une question, partage un lien, ou envoie une photo. '
                          'Ce qui compte se garde en l’épinglant.',
                      icone: Icons.forum_rounded,
                    )
                  : _Fil(
                      evenementId: widget.evenementId,
                      messages: donnees.messages,
                      encorePlusHaut: donnees.encorePlusHaut,
                      ancreAu: _ancreAu,
                      ligneVisible: _ligneVisible,
                      defilement: _defilement,
                      surLien: _ouvrirLien,
                      surReponse: (message) =>
                          setState(() => _citation = message),
                    );
            },
          ),
        ),
        if (_citation != null)
          _RappelCitation(
            message: _citation!,
            onFermer: () => setState(() => _citation = null),
          ),
        _Saisie(
          controleur: _saisie,
          enCours: _envoiEnCours,
          imageEnCours: _imageEnCours,
          evenementId: widget.evenementId,
          membres: ref.watch(membresProvider(widget.evenementId)).value ?? [],
          onEnvoyer: _envoyer,
          onImage: _joindreUneImage,
        ),
      ],
    );
  }
}

/// Le fil, du plus ancien au plus récent, ancré en bas.
///
/// La liste est construite à l'envers plutôt que défilée après coup : une conversation
/// s'ouvre sur son dernier message, et une liste ordinaire qu'on fait sauter en bas
/// après le premier rendu se voit sauter. À l'envers, le bas est le point de départ
/// naturel, et les messages plus anciens s'ajoutent au-dessus sans déplacer ce qu'on
/// lit — c'est ce qui permet de remonter le fil sans perdre sa place.
class _Fil extends StatelessWidget {
  const _Fil({
    required this.evenementId,
    required this.messages,
    required this.encorePlusHaut,
    required this.ancreAu,
    required this.ligneVisible,
    required this.defilement,
    required this.surLien,
    required this.surReponse,
  });

  final String evenementId;
  final List<Message> messages;

  /// Vrai s'il reste du fil au-dessus : un indicateur le dit pendant le chargement.
  final bool encorePlusHaut;

  /// Message sur lequel la vue s'ouvre, et frontière entre lu et non lu.
  final String? ancreAu;

  /// Vrai tant que la ligne « Nouveaux messages » doit être montrée. L'ancrage lui
  /// survit : la ligne disparaît sans que la conversation bouge.
  final bool ligneVisible;

  final ScrollController defilement;
  final void Function(String) surLien;
  final void Function(Message) surReponse;

  /// Ancre de la vue : le premier message non lu, ou le bas du fil.
  static final _centre = GlobalKey();

  Widget _bulle(int index) {
    final message = messages[index];

    return _Bulle(
      evenementId: evenementId,
      message: message,
      // L'auteur n'est répété que lorsqu'il change : une suite de messages d'une même
      // personne n'a pas besoin de son nom à chaque ligne.
      montrerAuteur:
          index == 0 ||
          messages[index - 1].auteurMembreId != message.auteurMembreId,
      surLien: surLien,
      surReponse: surReponse,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Rang du premier message non lu. Le fil s'ouvre juste là ; sans repère, il s'ouvre
    // sur son dernier message.
    final frontiere = ancreAu == null
        ? messages.length
        : messages.indexWhere((m) => m.id == ancreAu);

    final coupe = frontiere < 0 ? messages.length : frontiere;
    final lus = messages.take(coupe).toList();
    final nouveaux = messages.skip(coupe).toList();

    return CustomScrollView(
      controller: defilement,
      // Le centre est la frontière entre lu et non lu : ce qui précède s'étend vers le
      // haut, ce qui suit vers le bas. C'est ce qui permet d'ouvrir la conversation sur
      // le premier message non lu sans faire sauter la vue après le premier rendu.
      center: _centre,
      // Sans non-lu, le centre est vide et se colle au bas de la fenêtre : le fil
      // s'ouvre alors sur son dernier message, comme n'importe quelle messagerie.
      anchor: nouveaux.isEmpty ? 1.0 : 0.0,
      slivers: [
        // Avant le centre : les messages lus, du plus récent au plus ancien. La liste
        // remonte, donc son ordre s'inverse.
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: PpSpacing.lg),
          sliver: SliverList.builder(
            itemCount: lus.length + (encorePlusHaut ? 1 : 0),
            itemBuilder: (context, indexInverse) => indexInverse >= lus.length
                ? const _AttenteEnHautDuFil()
                : _bulle(coupe - 1 - indexInverse),
          ),
        ),
        SliverPadding(
          key: _centre,
          padding: const EdgeInsets.symmetric(horizontal: PpSpacing.lg),
          sliver: SliverList.builder(
            itemCount: nouveaux.isEmpty ? 0 : nouveaux.length + 1,
            itemBuilder: (context, index) => index == 0
                // L'entête garde sa place quand la ligne s'efface : la retirer de la
                // liste décalerait tout ce qui suit, et la vue sauterait.
                ? (ligneVisible
                      ? const _LigneDeReprise()
                      : const SizedBox.shrink())
                : _bulle(coupe + index - 1),
          ),
        ),
      ],
    );
  }
}

/// Roue d'attente posée là où les messages plus anciens vont apparaître.
class _AttenteEnHautDuFil extends StatelessWidget {
  const _AttenteEnHautDuFil();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: PpSpacing.lg),
    child: Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

/// Séparateur posé au-dessus du premier message non lu.
class _LigneDeReprise extends StatelessWidget {
  const _LigneDeReprise();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: PpSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Divider(color: PpColors.violet, thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PpSpacing.sm),
            child: Text(
              'Nouveaux messages',
              style: theme.textTheme.labelSmall?.copyWith(
                color: PpColors.violet,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Divider(color: PpColors.violet, thickness: 1)),
        ],
      ),
    );
  }
}

class _Bulle extends ConsumerWidget {
  const _Bulle({
    required this.evenementId,
    required this.message,
    required this.montrerAuteur,
    required this.surLien,
    required this.surReponse,
  });

  static final _heure = DateFormat('HH:mm', 'fr_FR');

  final String evenementId;
  final Message message;
  final bool montrerAuteur;
  final void Function(String) surLien;
  final void Function(Message) surReponse;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final mien = message.leMien;

    // Les miens à droite, les autres à gauche. C'est la convention de toutes les
    // messageries, et elle porte une information réelle : on sait qui parle avant
    // d'avoir lu le nom.
    final bulle = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PpSpacing.md,
        vertical: PpSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: mien
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainer,
        // Un coin resserré du côté de qui parle : c'est ce qui fait lire la forme comme
        // une bulle plutôt que comme une carte.
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(PpRadius.card),
          topRight: const Radius.circular(PpRadius.card),
          bottomLeft: Radius.circular(mien ? PpRadius.card : PpRadius.sm),
          bottomRight: Radius.circular(mien ? PpRadius.sm : PpRadius.card),
        ),
      ),
      child: _ContenuBulle(
        evenementId: evenementId,
        message: message,
        montrerAuteur: montrerAuteur,
        heure: _heure,
        surLien: surLien,
      ),
    );

    final menu = _MenuMessage(
      evenementId: evenementId,
      message: message,
      surReponse: surReponse,
    );

    // L'avatar n'apparaît que pour les autres : sur ses propres messages, il occupe une
    // place sans rien apprendre. Réservée quand même sur les messages groupés, sinon la
    // suite d'un même auteur se décale sous son début.
    final avatar = SizedBox(
      width: 36,
      child: montrerAuteur
          ? PpAvatar(
              nom: message.auteur,
              urlPhoto: message.auteurPhoto,
              taille: 32,
            )
          : null,
    );

    return Padding(
      padding: EdgeInsets.only(
        top: montrerAuteur ? PpSpacing.md : PpSpacing.xs,
        bottom: PpSpacing.xs,
      ),
      // La largeur vient des contraintes reçues, pas de MediaQuery. Le fil vit dans un
      // rail qui borne la colonne à 600 pixels : une fraction de la largeur de fenêtre
      // dépassait la place réellement disponible, et la ligne débordait. Se dimensionner
      // sur la fenêtre plutôt que sur son parent est un défaut classique, invisible
      // jusqu'au jour où l'un des deux change.
      child: LayoutBuilder(
        builder: (context, contraintes) {
          // L'avatar et le menu prennent une centaine de pixels : les retirer garantit
          // que la bulle tient, y compris sur un téléphone de 320 points.
          final place = contraintes.maxWidth - 100;
          final maxBulle = place < 140 ? contraintes.maxWidth * 0.6 : place;

          return Row(
            mainAxisAlignment: mien
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!mien) ...[avatar, const SizedBox(width: PpSpacing.sm)],
              if (mien) menu,
              // Flexible et non Align : Align occupe tout l'espace que son parent lui
              // accorde, et la bulle s'étirait sur toute la largeur pour un message de
              // trois mots. Flexible est lâche, donc le Container se dimensionne sur son
              // contenu et ne s'étire pas.
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxBulle),
                  child: bulle,
                ),
              ),
              if (!mien) menu,
            ],
          );
        },
      ),
    );
  }
}

/// Intérieur d'une bulle : l'entête, la citation, le corps et les réactions.
///
/// Séparé pour que la bulle elle-même reste lisible : sa seule affaire est la forme, la
/// couleur et l'alignement.
class _ContenuBulle extends StatelessWidget {
  const _ContenuBulle({
    required this.evenementId,
    required this.message,
    required this.montrerAuteur,
    required this.heure,
    required this.surLien,
  });

  final String evenementId;
  final Message message;
  final bool montrerAuteur;
  final DateFormat heure;
  final void Function(String) surLien;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mien = message.leMien;

    // Sur un aplat violet, les couleurs de texte du thème ne conviennent plus : c'est
    // `onPrimary` qui garantit le contraste, et le thème l'ignore ici.
    final surAplat = mien ? theme.colorScheme.onPrimary : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (montrerAuteur && !mien)
          Row(
            children: [
              Text(message.auteur, style: theme.textTheme.labelLarge),
              const SizedBox(width: PpSpacing.sm),
              Text(
                heure.format(message.envoyeLe),
                style: theme.textTheme.labelSmall,
              ),
              if (message.epingle) ...[
                const SizedBox(width: PpSpacing.xs),
                const Icon(
                  Icons.push_pin_rounded,
                  size: 12,
                  color: PpColors.violet,
                ),
              ],
            ],
          ),
        if (message.citation != null) _Citation(citation: message.citation!),
        DefaultTextStyle.merge(
          style: surAplat == null ? null : TextStyle(color: surAplat),
          child: _Corps(
            evenementId: evenementId,
            message: message,
            surLien: surLien,
            surAplat: mien,
          ),
        ),
        // L'heure passe sous le texte pour les miens : sans nom d'auteur au-dessus, elle
        // n'aurait nulle part où se poser.
        if (mien)
          Padding(
            padding: const EdgeInsets.only(top: PpSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (message.epingle) ...[
                  Icon(
                    Icons.push_pin_rounded,
                    size: 12,
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: PpSpacing.xs),
                ],
                Text(
                  heure.format(message.envoyeLe),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        if (message.reactions.isNotEmpty)
          _Reactions(evenementId: evenementId, message: message),
      ],
    );
  }
}

/// Corps d'un message, ou la trace de sa suppression.
class _Corps extends StatelessWidget {
  const _Corps({
    required this.evenementId,
    required this.message,
    required this.surLien,
    required this.surAplat,
  });

  final String evenementId;
  final Message message;
  final void Function(String) surLien;

  /// Le corps est-il posé sur l'aplat d'une bulle « mienne » ?
  final bool surAplat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message.supprime) {
      return Text(
        'Message supprimé',
        style: theme.textTheme.bodyMedium?.copyWith(
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.porteUneImage)
          Padding(
            padding: const EdgeInsets.only(bottom: PpSpacing.xs),
            child: PpImageMessage(
              url: message.urlPieceJointe!,
              adresseAgrandie: PpRoutes.versImage(
                evenementId,
                message.urlPieceJointe!,
              ),
              etiquette: 'Image de ${message.auteur}',
            ),
          ),
        if (message.corps != null && message.corps!.isNotEmpty)
          PpTexteMessage(
            texte: message.corps!,
            mentions: message.mentions,
            surLien: surLien,
            surAplat: surAplat,
          ),
        // Le sondage se répond dans le fil : quitter la conversation pour voter
        // ferait perdre le contexte de la question.
        if (message.sondageId != null)
          Padding(
            padding: const EdgeInsets.only(top: PpSpacing.sm),
            child: _SondageDuMessage(
              evenementId: evenementId,
              sondageId: message.sondageId!,
            ),
          ),
        if (message.modifie)
          Text(
            'modifié',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Message cité au-dessus d'une réponse.
class _Citation extends StatelessWidget {
  const _Citation({required this.citation});

  final Citation citation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: PpSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: PpSpacing.sm,
        vertical: PpSpacing.xs,
      ),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: PpColors.violet.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(citation.auteur, style: theme.textTheme.labelSmall),
          Text(
            citation.corps ?? 'Message supprimé',
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Pastilles de réaction. Appuyer sur l'une la pose ou la retire.
class _Reactions extends ConsumerWidget {
  const _Reactions({required this.evenementId, required this.message});

  final String evenementId;
  final Message message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: PpSpacing.xs),
      child: Wrap(
        spacing: PpSpacing.xs,
        children: [
          for (final reaction in message.reactions)
            InkWell(
              key: Key('reaction-${message.id}-${reaction.emoji}'),
              borderRadius: BorderRadius.circular(PpRadius.pill),
              onTap: () => _basculer(ref, reaction.emoji),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: PpSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: reaction.laMienne
                      ? PpColors.violet.withValues(alpha: 0.16)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(PpRadius.pill),
                ),
                child: Text(
                  '${reaction.emoji} ${reaction.nombre}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _basculer(WidgetRef ref, String emoji) async {
    try {
      await ref
          .read(discussionApiProvider)
          .basculerReaction(evenementId, message.id, emoji);
    } on Exception {
      // Silencieux : une réaction perdue n'empêche rien, et un message d'erreur sur un
      // geste aussi léger serait plus gênant que l'échec lui-même.
    } finally {
      ref.invalidate(filDiscussionProvider(evenementId));
    }
  }
}

/// Actions d'un message : réagir, répondre, épingler, et pour l'auteur modifier ou
/// supprimer.
class _MenuMessage extends ConsumerWidget {
  const _MenuMessage({
    required this.evenementId,
    required this.message,
    required this.surReponse,
  });

  final String evenementId;
  final Message message;
  final void Function(Message) surReponse;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
    key: Key('menu-${message.id}'),
    icon: const Icon(Icons.more_vert_rounded, size: 18),
    onSelected: (choix) => _agir(context, ref, choix),
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'repondre', child: Text('Répondre')),
      // Une seule entrée, qui ouvre le choix : six entrées « Réagir 👍 » ne laissaient
      // le choix qu'entre six emoji, et allongeaient le menu d'autant.
      const PopupMenuItem(value: 'reagir', child: Text('Réagir…')),
      PopupMenuItem(
        value: 'epingler',
        child: Text(message.epingle ? 'Retirer l’épingle' : 'Épingler'),
      ),
      // Modifier et supprimer n'appartiennent qu'à l'auteur : réécrire le message
      // d'un autre permettrait de lui faire dire le contraire de ce qu'il a écrit.
      if (message.leMien && !message.supprime) ...[
        const PopupMenuItem(value: 'modifier', child: Text('Modifier')),
        const PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
      ],
    ],
  );

  Future<void> _agir(BuildContext context, WidgetRef ref, String choix) async {
    final api = ref.read(discussionApiProvider);

    switch (choix) {
      case 'reagir':
        if (context.mounted) {
          final emoji = await ouvrirSelecteurEmoji(context);

          // Refermer sans choisir ne pose rien : la feuille rend alors `null`.
          if (emoji != null) {
            await api.basculerReaction(evenementId, message.id, emoji);
            ref.invalidate(filDiscussionProvider(evenementId));
          }
        }

      case 'repondre':
        surReponse(message);

      case 'epingler':
        if (message.epingle) {
          await api.desepingler(evenementId, message.id);
          ref
            ..invalidate(filDiscussionProvider(evenementId))
            ..invalidate(epinglesProvider(evenementId));
        } else if (context.mounted) {
          await ouvrirFeuilleEpingler(context, evenementId, message.id);
        }

      case 'modifier':
        if (context.mounted) {
          await _modifier(context, ref);
        }

      case 'supprimer':
        await api.supprimer(evenementId, message.id);
        ref.invalidate(filDiscussionProvider(evenementId));
    }
  }

  Future<void> _modifier(BuildContext context, WidgetRef ref) async {
    final champ = TextEditingController(text: message.corps ?? '');

    final valide = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(controller: champ, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (valide == true && champ.text.trim().isNotEmpty) {
      await ref
          .read(discussionApiProvider)
          .modifier(evenementId, message.id, corps: champ.text.trim());
      ref.invalidate(filDiscussionProvider(evenementId));
    }

    champ.dispose();
  }
}

/// Rappel du message auquel on répond, juste au-dessus de la saisie.
class _RappelCitation extends StatelessWidget {
  const _RappelCitation({required this.message, required this.onFermer});

  final Message message;
  final VoidCallback onFermer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: PpSpacing.lg,
        vertical: PpSpacing.sm,
      ),
      color: PpColors.violet.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, size: 16),
          const SizedBox(width: PpSpacing.sm),
          Expanded(
            child: Text(
              'Réponse à ${message.leMien ? 'toi' : message.auteur} : '
              '${message.corps ?? 'message supprimé'}',
              style: theme.textTheme.bodySmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onFermer,
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: 'Ne plus répondre à ce message',
          ),
        ],
      ),
    );
  }
}

/// Barre de saisie, avec le choix des personnes à citer.
class _Saisie extends StatefulWidget {
  const _Saisie({
    required this.controleur,
    required this.enCours,
    required this.imageEnCours,
    required this.evenementId,
    required this.membres,
    required this.onEnvoyer,
    required this.onImage,
  });

  final String evenementId;
  final TextEditingController controleur;
  final bool enCours;
  final bool imageEnCours;
  final List<Membre> membres;
  final VoidCallback onEnvoyer;
  final VoidCallback onImage;

  @override
  State<_Saisie> createState() => _SaisieState();
}

class _SaisieState extends State<_Saisie> {
  /// Nom partiel en cours de frappe après un « @ ». Nul quand on n'est pas en train
  /// de citer quelqu'un.
  String? _recherche;

  @override
  void initState() {
    super.initState();
    widget.controleur.addListener(_surFrappe);
  }

  @override
  void dispose() {
    widget.controleur.removeListener(_surFrappe);
    super.dispose();
  }

  /// Repère une citation en cours de frappe.
  ///
  /// Le « @ » doit ouvrir un mot : « ecris-moi@exemple.fr » n'est pas une tentative de
  /// citer quelqu'un, et proposer la liste là serait une gêne à chaque adresse tapée.
  void _surFrappe() {
    final texte = widget.controleur.text;
    final curseur = widget.controleur.selection.baseOffset;
    final position = curseur < 0 || curseur > texte.length
        ? texte.length
        : curseur;
    final avant = texte.substring(0, position);

    final arobase = avant.lastIndexOf('@');

    String? recherche;

    if (arobase >= 0) {
      final debutDeMot =
          arobase == 0 ||
          avant[arobase - 1] == ' ' ||
          avant[arobase - 1] == '\n';
      final fragment = avant.substring(arobase + 1);

      // Un nom ne contient pas d'espace ici : passée la première, la citation est
      // terminée et la liste n'a plus de raison de rester ouverte.
      if (debutDeMot && !fragment.contains(' ') && !fragment.contains('\n')) {
        recherche = fragment;
      }
    }

    if (recherche != _recherche) {
      setState(() => _recherche = recherche);
    }
  }

  /// Membres correspondant à la recherche, accents et casse ignorés.
  List<Membre> get _propositions {
    final recherche = _recherche;

    if (recherche == null) {
      return const [];
    }

    final motif = _sansAccent(recherche);

    return widget.membres
        .where((m) => _sansAccent(m.nomAffiche).contains(motif))
        .toList();
  }

  /// Remplace le nom partiel par le nom complet, suivi d'une espace.
  void _choisir(Membre membre) {
    final texte = widget.controleur.text;
    final curseur = widget.controleur.selection.baseOffset;
    final position = curseur < 0 || curseur > texte.length
        ? texte.length
        : curseur;
    final avant = texte.substring(0, position);
    final arobase = avant.lastIndexOf('@');

    if (arobase < 0) {
      return;
    }

    final complet = '@${membre.nomAffiche} ';
    final nouveau = texte.replaceRange(arobase, position, complet);

    widget.controleur
      ..text = nouveau
      // Le curseur se replace après l'espace : on continue d'écrire sans avoir à le
      // déplacer soi-même.
      ..selection = TextSelection.collapsed(offset: arobase + complet.length);

    setState(() => _recherche = null);
  }

  /// Comparaison indulgente : personne ne pense à la casse ni aux accents en tapant
  /// vite, et « @luc » doit trouver Lucas.
  static String _sansAccent(String valeur) {
    const accents = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const nus = 'aaaaaaceeeeiiiinooooouuuuyy';

    var propre = valeur.toLowerCase();

    for (var i = 0; i < accents.length; i++) {
      propre = propre.replaceAll(accents[i], nus[i]);
    }

    return propre;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final propositions = _propositions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (propositions.isNotEmpty)
          _ListeMentions(membres: propositions, onChoisir: _choisir),
        _BarreSaisie(
          controleur: widget.controleur,
          enCours: widget.enCours,
          imageEnCours: widget.imageEnCours,
          evenementId: widget.evenementId,
          onEnvoyer: widget.onEnvoyer,
          onImage: widget.onImage,
          theme: theme,
        ),
      ],
    );
  }
}

/// Participants proposés pendant qu'on tape une citation.
class _ListeMentions extends StatelessWidget {
  const _ListeMentions({required this.membres, required this.onChoisir});

  final List<Membre> membres;
  final void Function(Membre) onChoisir;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: PpSpacing.xs),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: PpSpacing.lg,
              vertical: PpSpacing.xs,
            ),
            child: Text(
              'PARTICIPANTS',
              style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2),
            ),
          ),
          for (final membre in membres)
            ListTile(
              key: Key('mention-choix-${membre.id}'),
              dense: true,
              leading: PpAvatar(
                nom: membre.nomAffiche,
                urlPhoto: membre.avatarUrl,
                taille: 28,
              ),
              title: Text(membre.nomAffiche),
              onTap: () => onChoisir(membre),
            ),
        ],
      ),
    );
  }
}

class _BarreSaisie extends StatelessWidget {
  const _BarreSaisie({
    required this.controleur,
    required this.enCours,
    required this.imageEnCours,
    required this.evenementId,
    required this.onEnvoyer,
    required this.onImage,
    required this.theme,
  });

  final TextEditingController controleur;
  final bool enCours;
  final bool imageEnCours;
  final String evenementId;
  final VoidCallback onEnvoyer;
  final VoidCallback onImage;
  final ThemeData theme;

  /// Présente ce qu'on peut ajouter à la conversation.
  ///
  /// Une feuille plutôt qu'une rangée d'icônes : la liste s'allongera — un lieu, un
  /// article de courses — et trois icônes muettes ne disent pas ce qu'elles font.
  ///
  /// Chaque entrée agit dans la foulée de l'appui, sans attendre la fermeture de la
  /// feuille : un navigateur n'ouvre un sélecteur de fichier que pendant le geste de
  /// l'utilisateur, et attendre le résultat d'une feuille modale consomme ce geste —
  /// le sélecteur ne s'ouvrait alors jamais sur le web.
  void _ouvrirAjouts(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (contexte) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('Une image'),
              subtitle: const Text('Réduite avant l’envoi'),
              onTap: () {
                Navigator.of(contexte).pop();
                onImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_vote_outlined),
              title: const Text('Un sondage'),
              subtitle: const Text('Pour trancher une question'),
              onTap: () {
                Navigator.of(contexte).pop();
                ouvrirFeuilleSondage(context, evenementId);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(PpSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            key: const Key('discussion-ajouter'),
            onPressed: imageEnCours ? null : () => _ouvrirAjouts(context),
            icon: imageEnCours
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Ajouter',
          ),
          Expanded(
            // Entrée envoie, Maj+Entrée passe à la ligne. C'est ce que fait toute
            // messagerie de bureau, et l'inverse — Entrée qui saute une ligne — oblige à
            // viser le bouton pour chaque message.
            //
            // Un Shortcuts/Actions n'irait pas : le champ consomme la touche avant eux.
            // KeyboardListener voit l'événement d'abord, et ne le laisse filer que
            // lorsque Maj est enfoncée.
            child: Focus(
              onKeyEvent: (_, evenement) {
                if (evenement is! KeyDownEvent ||
                    evenement.logicalKey != LogicalKeyboardKey.enter ||
                    HardwareKeyboard.instance.isShiftPressed) {
                  // Maj tenue, ou toute autre touche : le champ fait son travail
                  // habituel, saut de ligne compris.
                  return KeyEventResult.ignored;
                }

                if (!enCours) {
                  onEnvoyer();
                }

                // Avalée, sinon le champ insérerait en plus un saut de ligne dans le
                // message suivant.
                return KeyEventResult.handled;
              },
              child: TextField(
                key: const Key('discussion-saisie'),
                controller: controleur,
                minLines: 1,
                maxLines: 5,
                // newline et non send : c'est le KeyboardListener au-dessus qui décide, et
                // le champ doit pouvoir insérer un saut de ligne quand Maj est tenue.
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Écris un message… @ pour citer quelqu’un',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: PpSpacing.md,
                    vertical: PpSpacing.sm,
                  ),
                ),
              ),
            ),
          ),
          IconButton.filled(
            key: const Key('discussion-envoyer'),
            onPressed: enCours ? null : onEnvoyer,
            icon: const Icon(Icons.send_rounded),
            tooltip: 'Envoyer',
          ),
        ],
      ),
    );
  }
}

/// Sondage porté par un message, chargé depuis la liste des sondages.
///
/// La liste est déjà en mémoire pour l'écran des sondages : la relire ici évite un
/// appel par message et garde les décomptes cohérents entre les deux écrans.
class _SondageDuMessage extends ConsumerWidget {
  const _SondageDuMessage({required this.evenementId, required this.sondageId});

  final String evenementId;
  final String sondageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sondages = ref.watch(sondagesProvider(evenementId));

    final sondage = sondages.value?.sondages
        .where((s) => s.id == sondageId)
        .firstOrNull;

    // Sondage supprimé depuis, ou pas encore chargé : le message reste lisible sans
    // lui, et une carte d'erreur ici encombrerait le fil.
    if (sondage == null) {
      return const SizedBox.shrink();
    }

    return CarteSondage(evenementId: evenementId, sondage: sondage);
  }
}
