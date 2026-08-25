import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article_course.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_claim_chip.dart';
import '../../design/components/pp_money.dart';
import '../../design/components/pp_progress.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import 'achat_feuille.dart';
import 'article_feuille.dart';

/// Liste de courses d'un événement (`EF-CRS-01` à `EF-CRS-10`).
///
/// L'écran est organisé autour d'une seule question : qui prend quoi. L'avancement est
/// en tête, les articles groupés par catégorie, et l'attribution se fait d'un appui —
/// c'est le geste que l'on répète en marchant dans un magasin.
class CoursesPage extends ConsumerWidget {
  const CoursesPage({required this.evenementId, super.key});

  final String evenementId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(listeCoursesProvider(evenementId));

    return liste.when(
      loading: () => const PpLoadingState(),
      error: (_, _) => PpErrorState(
        message: 'Impossible de charger la liste de courses.',
        onRetry: () => ref.invalidate(listeCoursesProvider(evenementId)),
      ),
      data: (donnees) => _Liste(evenementId: evenementId, liste: donnees),
    );
  }
}

class _Liste extends ConsumerWidget {
  const _Liste({required this.evenementId, required this.liste});

  final String evenementId;
  final ListeCourses liste;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (liste.articles.isEmpty) {
      return const PpEmptyState(
        titre: 'Rien à acheter pour l’instant',
        explication:
            'Ajoute les boissons, la nourriture et le matériel. '
            'Chacun s’attribue ce qu’il prend en route.',
        icone: Icons.shopping_cart_rounded,
      );
    }

    final groupes = liste.parCategorie;

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(listeCoursesProvider(evenementId)),
      child: ListView(
        padding: const EdgeInsets.all(PpSpacing.lg),
        children: [
          _Avancement(avancement: liste.avancement),
          const SizedBox(height: PpSpacing.lg),
          for (final entree in groupes.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                left: PpSpacing.xs,
                bottom: PpSpacing.sm,
              ),
              child: Text(
                entree.key.libelle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final article in entree.value) ...[
              _CarteArticle(evenementId: evenementId, article: article),
              const SizedBox(height: PpSpacing.sm),
            ],
            const SizedBox(height: PpSpacing.md),
          ],
        ],
      ),
    );
  }
}

/// Avancement de la liste : ce qui est pris, et ce qui est réellement acheté.
///
/// Deux barres et non une : « pris » n'implique pas « acheté », et les confondre
/// laisserait croire la liste réglée alors que rien n'est en magasin (`EF-CRS-09`).
class _Avancement extends StatelessWidget {
  const _Avancement({required this.avancement});

  final AvancementCourses avancement;

  @override
  Widget build(BuildContext context) => PpCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PpProgress(
          fait: avancement.pris,
          total: avancement.total,
          libelle: 'Pris en charge',
          couleur: PpColors.rose,
        ),
        const SizedBox(height: PpSpacing.md),
        PpProgress(
          fait: avancement.achetes,
          total: avancement.total,
          libelle: 'Achetés',
        ),
      ],
    ),
  );
}

class _CarteArticle extends ConsumerStatefulWidget {
  const _CarteArticle({required this.evenementId, required this.article});

  final String evenementId;
  final ArticleCourse article;

  @override
  ConsumerState<_CarteArticle> createState() => _CarteArticleState();
}

class _CarteArticleState extends ConsumerState<_CarteArticle> {
  bool _enCours = false;

  ArticleCourse get _article => widget.article;

  /// S'attribue l'article, ou retire son attribution.
  ///
  /// Un article pris par quelqu'un d'autre n'est pas actionnable : l'attribution est
  /// unique et contrôlée côté serveur (`RG-CRS-01`), et proposer le geste pour le
  /// refuser ensuite vaudrait moins que ne pas le proposer.
  Future<void> _basculerAttribution() async {
    if (_article.estPris && !_article.prisParMoi) {
      return;
    }

    setState(() => _enCours = true);

    final api = ref.read(coursesApiProvider);

    try {
      if (_article.prisParMoi) {
        await api.liberer(widget.evenementId, _article.id);
      } else {
        await api.attribuer(widget.evenementId, _article.id);
      }
    } on ApiException catch (erreur) {
      if (!mounted) {
        return;
      }

      // Deux personnes qui prennent le même article au même instant, c'est le cas
      // normal d'une liste partagée. On le dit, et on recharge pour montrer qui l'a
      // pris — réessayer ne ferait que reproduire le refus.
      final message = erreur.code == 'shopping.already_claimed'
          ? 'Quelqu’un vient de le prendre.'
          : erreur.title;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Action impossible pour le moment.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
        ref.invalidate(listeCoursesProvider(widget.evenementId));
      }
    }
  }

  /// Supprime l'article, après confirmation.
  ///
  /// Un article supprimé par erreur au milieu d'une liste partagée est une perte
  /// silencieuse : personne ne sait plus ce qui manquait.
  Future<void> _supprimer() async {
    final confirme = await showDialog<bool>(
      context: context,
      builder: (contexte) => AlertDialog(
        title: Text('Supprimer « ${_article.nom} » ?'),
        content: const Text(
          'L’article disparaîtra de la liste pour tout le monde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(contexte).pop(true),
            child: const Text('Supprimer l’article'),
          ),
        ],
      ),
    );

    if (confirme != true || !mounted) {
      return;
    }

    try {
      await ref
          .read(coursesApiProvider)
          .supprimer(widget.evenementId, _article.id);
    } on ApiException catch (erreur) {
      if (mounted) {
        // Le serveur refuse la suppression d'un article rattaché à une dépense
        // (`EF-CRS-08`) : son message dit pourquoi mieux qu'un texte générique.
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(erreur.title)));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suppression impossible pour le moment.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        ref.invalidate(listeCoursesProvider(widget.evenementId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final article = _article;

    return PpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (article.estAchete) ...[
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: PpColors.vert,
                          ),
                          const SizedBox(width: PpSpacing.xs),
                        ],
                        Flexible(
                          child: Text(
                            article.nom,
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: PpSpacing.xs),
                    Text(
                      article.quantiteLisible,
                      style: theme.textTheme.bodySmall,
                    ),
                    if (article.achatPartiel)
                      Padding(
                        padding: const EdgeInsets.only(top: PpSpacing.xs),
                        child: Text(
                          'Il reste ${_nombre(article.quantiteRestante)} à prendre',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PpColors.orange,
                          ),
                        ),
                      ),
                    if (article.note != null && article.note!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: PpSpacing.xs),
                        child: Text(
                          article.note!,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (article.prixPaye != null)
                      Padding(
                        padding: const EdgeInsets.only(top: PpSpacing.xs),
                        child: Row(
                          children: [
                            Text('Payé ', style: theme.textTheme.bodySmall),
                            PpMoney(
                              article.prixPaye!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      )
                    // Le prix estimé est annoncé comme tel et jamais additionné : il
                    // n'entre dans aucun calcul de répartition (`RG-CRS-03`).
                    else if (article.prixEstime != null)
                      Padding(
                        padding: const EdgeInsets.only(top: PpSpacing.xs),
                        child: Text(
                          'Prix estimé ${_euros(article.prixEstime!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: PpSpacing.sm),
              PpClaimChip(
                libelleLibre: 'À prendre',
                nomAttributaire: article.nomAttributaire,
                photoAttributaire: article.photoAttributaire,
                enCours: _enCours,
                onPressed: article.estPris && !article.prisParMoi
                    ? null
                    : _basculerAttribution,
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (choix) => switch (choix) {
                  'modifier' => ouvrirFeuilleArticle(
                    context,
                    widget.evenementId,
                    article: article,
                  ),
                  'supprimer' => _supprimer(),
                  _ => null,
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'modifier', child: Text('Modifier')),
                  PopupMenuItem(value: 'supprimer', child: Text('Supprimer')),
                ],
              ),
            ],
          ),
          // Déclarer l'achat n'est proposé qu'à celui qui s'en occupe : le faire pour
          // autrui créerait une dépense à son nom. Une fois l'achat déclaré, le même
          // geste sert à corriger le prix — la dépense engendrée porte ce montant, et
          // sans correction les comptes restent faux.
          //
          // Sur sa propre ligne, en pleine largeur : à l'étroit, un bouton glissé
          // entre la pastille d'attribution et le menu débordait de la carte.
          if (article.prisParMoi)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    ouvrirFeuilleAchat(context, widget.evenementId, article),
                icon: Icon(
                  article.estAchete
                      ? Icons.edit_outlined
                      : Icons.shopping_bag_outlined,
                  size: 18,
                ),
                label: Text(article.estAchete ? 'Corriger le prix' : 'Acheté'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Nombre sans décimale inutile : « 6 » plutôt que « 6.0 ».
String _nombre(double valeur) => valeur == valeur.roundToDouble()
    ? valeur.toStringAsFixed(0)
    : valeur.toString();

/// Montant en euros, typographie française : espace insécable avant le symbole.
String _euros(double valeur) =>
    '${valeur.toStringAsFixed(2).replaceAll('.', ',')}${PpMoney.espaceInsecable}€';
