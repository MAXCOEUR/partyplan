import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article_course.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import 'nombre_saisi.dart';

/// Ajout ou modification d'un article de courses (`EF-CRS-01`, `EF-CRS-08`).
///
/// Un seul écran pour les deux gestes : les champs sont identiques, et deux formulaires
/// finiraient par diverger sur la validation.
///
/// Seul le libellé est exigé. Quantité, unité, prix estimé et remarque restent
/// facultatifs : devant une liste de courses on note « chips » et on passe au suivant,
/// et un formulaire qui réclame six champs ne sera pas rempli.
class ArticleFeuille extends ConsumerStatefulWidget {
  const ArticleFeuille({required this.evenementId, this.article, super.key});

  final String evenementId;

  /// Article à modifier. Nul pour un ajout.
  final ArticleCourse? article;

  @override
  ConsumerState<ArticleFeuille> createState() => _ArticleFeuilleState();
}

class _ArticleFeuilleState extends ConsumerState<ArticleFeuille> {
  final _formulaire = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _quantite;
  late final TextEditingController _unite;
  late final TextEditingController _prix;
  late final TextEditingController _note;

  late CategorieCourse _categorie;

  bool _enCours = false;
  String? _erreur;

  bool get _modification => widget.article != null;

  @override
  void initState() {
    super.initState();

    final article = widget.article;

    _nom = TextEditingController(text: article?.nom ?? '');
    _quantite = TextEditingController(
      text: article == null ? '' : nombreVersTexte(article.quantite),
    );
    _unite = TextEditingController(text: article?.unite ?? '');
    _prix = TextEditingController(
      text: article?.prixEstime == null
          ? ''
          : montantVersTexte(article!.prixEstime!),
    );
    _note = TextEditingController(text: article?.note ?? '');

    // À l'ajout, la catégorie par défaut est « autres » : ranger est un travail, et
    // l'imposer à la saisie ferait abandonner l'ajout.
    _categorie = article?.categorie ?? CategorieCourse.autres;
  }

  @override
  void dispose() {
    _nom.dispose();
    _quantite.dispose();
    _unite.dispose();
    _prix.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    final api = ref.read(coursesApiProvider);

    try {
      if (_modification) {
        await api.modifier(
          widget.evenementId,
          widget.article!.id,
          nom: _nom.text.trim(),
          categorie: _categorie,
          quantite: nombreDepuisTexte(_quantite.text),
          unite: _unite.text.trim(),
          prixEstime: nombreDepuisTexte(_prix.text),
          note: _note.text.trim(),
        );
      } else {
        await api.ajouter(
          widget.evenementId,
          nom: _nom.text.trim(),
          categorie: _categorie,
          quantite: nombreDepuisTexte(_quantite.text),
          unite: _unite.text.trim(),
          prixEstime: nombreDepuisTexte(_prix.text),
          note: _note.text.trim(),
        );
      }

      ref.invalidate(listeCoursesProvider(widget.evenementId));

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = 'Enregistrement impossible pour le moment.');
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(PpSpacing.lg),
    child: Form(
      key: _formulaire,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _modification ? 'Modifier l’article' : 'Ajouter à la liste',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: PpSpacing.lg),
          if (_erreur != null) ...[
            PpFormError(_erreur!),
            const SizedBox(height: PpSpacing.lg),
          ],
          PpField(
            key: const Key('article-nom'),
            label: 'Article',
            hint: 'Chips, glace, gobelets…',
            controller: _nom,
            enabled: !_enCours,
            validator: (valeur) => valeur == null || valeur.trim().isEmpty
                ? 'Indique ce qu’il faut acheter.'
                : null,
          ),
          const SizedBox(height: PpSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: PpField(
                  key: const Key('article-quantite'),
                  label: 'Quantité',
                  controller: _quantite,
                  enabled: !_enCours,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: _nombrePositif,
                ),
              ),
              const SizedBox(width: PpSpacing.md),
              Expanded(
                child: PpField(
                  key: const Key('article-unite'),
                  label: 'Unité',
                  hint: 'paquets, kg…',
                  controller: _unite,
                  enabled: !_enCours,
                ),
              ),
            ],
          ),
          const SizedBox(height: PpSpacing.lg),
          _ChoixCategorie(
            valeur: _categorie,
            onChange: _enCours
                ? null
                : (categorie) => setState(() => _categorie = categorie),
          ),
          const SizedBox(height: PpSpacing.lg),
          PpField(
            key: const Key('article-prix'),
            label: 'Prix estimé',
            controller: _prix,
            enabled: !_enCours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            aide:
                'Indicatif seulement : le prix estimé n’entre dans aucun '
                'remboursement.',
            validator: _nombrePositif,
          ),
          const SizedBox(height: PpSpacing.lg),
          PpField(
            key: const Key('article-note'),
            label: 'Remarque',
            hint: 'blondes, sans gluten…',
            controller: _note,
            enabled: !_enCours,
            lignes: 2,
          ),
          const SizedBox(height: PpSpacing.xl),
          PpPrimaryButton(
            label: _modification ? 'Enregistrer' : 'Ajouter',
            enCours: _enCours,
            onPressed: _enregistrer,
          ),
        ],
      ),
    ),
  );

  /// Refuse un nombre négatif ou illisible, accepte le champ vide.
  ///
  /// La virgule est acceptée : un clavier français en produit une, et refuser
  /// « 30,50 » sur un écran français serait absurde.
  static String? _nombrePositif(String? valeur) {
    if (valeur == null || valeur.trim().isEmpty) {
      return null;
    }

    final nombre = nombreDepuisTexte(valeur);

    if (nombre == null) {
      return 'Indique un nombre.';
    }

    return nombre < 0 ? 'Le nombre doit être positif.' : null;
  }
}

/// Choix de la catégorie, quatre pastilles côte à côte (`EF-CRS-02`).
class _ChoixCategorie extends StatelessWidget {
  const _ChoixCategorie({required this.valeur, required this.onChange});

  final CategorieCourse valeur;
  final void Function(CategorieCourse)? onChange;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Catégorie', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: PpSpacing.sm),
      Wrap(
        spacing: PpSpacing.sm,
        runSpacing: PpSpacing.sm,
        children: [
          for (final categorie in CategorieCourse.values)
            ChoiceChip(
              label: Text(categorie.libelle),
              selected: categorie == valeur,
              onSelected: onChange == null ? null : (_) => onChange!(categorie),
            ),
        ],
      ),
    ],
  );
}

/// Ouvre la feuille d'ajout, ou de modification si [article] est fourni.
///
/// Une feuille modale plutôt qu'un écran : ajouter un article est un aller-retour de
/// quelques secondes, et empiler un écran pour cela ferait perdre la liste de vue.
Future<void> ouvrirFeuilleArticle(
  BuildContext context,
  String evenementId, {
  ArticleCourse? article,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (contexte) => Padding(
    // Laisse la place au clavier : sans cela, le bouton de validation reste caché
    // dessous et le formulaire paraît sans issue.
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexte).bottom),
    child: ArticleFeuille(evenementId: evenementId, article: article),
  ),
);
