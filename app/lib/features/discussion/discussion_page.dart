import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/membre.dart';
import '../../core/models/message.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_states.dart';
import '../../design/components/pp_texte_message.dart';
import '../../design/tokens.dart';
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

  @override
  void dispose() {
    _saisie.dispose();
    _defilement.dispose();
    super.dispose();
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
      await ref.read(discussionApiProvider).envoyer(
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

  void _signaler(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _ouvrirLien(String url) async {
    final cible = Uri.tryParse(url);

    if (cible == null || !await launchUrl(cible, mode: LaunchMode.externalApplication)) {
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
            data: (donnees) => donnees.estVide
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
                    defilement: _defilement,
                    surLien: _ouvrirLien,
                    surReponse: (message) =>
                        setState(() => _citation = message),
                  ),
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
          membres: ref.watch(membresProvider(widget.evenementId)).value ?? [],
          onEnvoyer: _envoyer,
        ),
      ],
    );
  }
}

class _Fil extends StatelessWidget {
  const _Fil({
    required this.evenementId,
    required this.messages,
    required this.defilement,
    required this.surLien,
    required this.surReponse,
  });

  final String evenementId;
  final List<Message> messages;
  final ScrollController defilement;
  final void Function(String) surLien;
  final void Function(Message) surReponse;

  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: defilement,
    padding: const EdgeInsets.all(PpSpacing.lg),
    itemCount: messages.length,
    itemBuilder: (context, index) => _Bulle(
      evenementId: evenementId,
      message: messages[index],
      // L'auteur n'est répété que lorsqu'il change : une suite de messages d'une même
      // personne n'a pas besoin de son nom à chaque ligne.
      montrerAuteur: index == 0 ||
          messages[index - 1].auteurMembreId != messages[index].auteurMembreId,
      surLien: surLien,
      surReponse: surReponse,
    ),
  );
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

    return Padding(
      padding: EdgeInsets.only(
        top: montrerAuteur ? PpSpacing.md : PpSpacing.xs,
        bottom: PpSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 36,
            child: montrerAuteur
                ? PpAvatar(nom: message.auteur, taille: 32)
                : null,
          ),
          const SizedBox(width: PpSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (montrerAuteur)
                  Row(
                    children: [
                      Text(
                        message.leMien ? 'Moi' : message.auteur,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(width: PpSpacing.sm),
                      Text(
                        _heure.format(message.envoyeLe),
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
                if (message.citation != null)
                  _Citation(citation: message.citation!),
                _Corps(message: message, surLien: surLien),
                if (message.reactions.isNotEmpty)
                  _Reactions(evenementId: evenementId, message: message),
              ],
            ),
          ),
          _MenuMessage(
            evenementId: evenementId,
            message: message,
            surReponse: surReponse,
          ),
        ],
      ),
    );
  }
}

/// Corps d'un message, ou la trace de sa suppression.
class _Corps extends StatelessWidget {
  const _Corps({required this.message, required this.surLien});

  final Message message;
  final void Function(String) surLien;

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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(PpRadius.md),
              child: Image.network(
                message.urlPieceJointe!,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => Container(
                  height: 80,
                  alignment: Alignment.center,
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: const Text('Image indisponible'),
                ),
              ),
            ),
          ),
        if (message.corps != null && message.corps!.isNotEmpty)
          PpTexteMessage(
            texte: message.corps!,
            mentions: message.mentions,
            surLien: surLien,
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
          left: BorderSide(color: PpColors.violet.withValues(alpha: 0.6), width: 3),
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

  /// Réactions proposées d'emblée. Une palette courte : le choix exhaustif d'emoji
  /// transforme un geste d'une seconde en fouille dans un catalogue.
  static const emojis = ['👍', '🎉', '😂', '❤️', '😮'];

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
      PopupMenuItem(
        value: 'epingler',
        child: Text(message.epingle ? 'Retirer l’épingle' : 'Épingler'),
      ),
      for (final emoji in emojis)
        PopupMenuItem(value: 'emoji:$emoji', child: Text('Réagir $emoji')),
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

    if (choix.startsWith('emoji:')) {
      await api.basculerReaction(
        evenementId,
        message.id,
        choix.substring('emoji:'.length),
      );
      ref.invalidate(filDiscussionProvider(evenementId));
      return;
    }

    switch (choix) {
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
    required this.membres,
    required this.onEnvoyer,
  });

  final TextEditingController controleur;
  final bool enCours;
  final List<Membre> membres;
  final VoidCallback onEnvoyer;

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
    final position = curseur < 0 || curseur > texte.length ? texte.length : curseur;
    final avant = texte.substring(0, position);

    final arobase = avant.lastIndexOf('@');

    String? recherche;

    if (arobase >= 0) {
      final debutDeMot = arobase == 0 || avant[arobase - 1] == ' ' || avant[arobase - 1] == '\n';
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
    final position = curseur < 0 || curseur > texte.length ? texte.length : curseur;
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
          onEnvoyer: widget.onEnvoyer,
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
              leading: PpAvatar(nom: membre.nomAffiche, taille: 28),
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
    required this.onEnvoyer,
    required this.theme,
  });

  final TextEditingController controleur;
  final bool enCours;
  final VoidCallback onEnvoyer;
  final ThemeData theme;

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
          Expanded(
            child: TextField(
              key: const Key('discussion-saisie'),
              controller: controleur,
              minLines: 1,
              maxLines: 5,
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
