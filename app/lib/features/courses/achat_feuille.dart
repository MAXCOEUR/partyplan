import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/article_course.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import 'nombre_saisi.dart';

/// Déclaration d'achat d'un article (`EF-CRS-05`, `EF-CRS-06`, `EF-CRS-07`).
///
/// Deux informations, deux conséquences distinctes : la quantité obtenue met la liste à
/// jour, le prix payé engendre une dépense dans les comptes de l'événement. La seconde
/// est annoncée avant validation — découvrir une dépense après coup serait une mauvaise
/// surprise sur un sujet d'argent.
class AchatFeuille extends ConsumerStatefulWidget {
  const AchatFeuille({
    required this.evenementId,
    required this.article,
    super.key,
  });

  final String evenementId;
  final ArticleCourse article;

  @override
  ConsumerState<AchatFeuille> createState() => _AchatFeuilleState();
}

class _AchatFeuilleState extends ConsumerState<AchatFeuille> {
  final _formulaire = GlobalKey<FormState>();
  late final TextEditingController _quantite;
  final _prix = TextEditingController();

  bool _enCours = false;
  String? _erreur;

  @override
  void initState() {
    super.initState();

    // Préremplie avec ce qui était demandé : le cas courant est d'avoir tout trouvé,
    // et la saisie ne doit servir qu'à corriger.
    _quantite = TextEditingController(
      text: nombreVersTexte(widget.article.quantite),
    );

    _prix.addListener(_rafraichirAnnonce);
  }

  @override
  void dispose() {
    _prix.removeListener(_rafraichirAnnonce);
    _quantite.dispose();
    _prix.dispose();
    super.dispose();
  }

  /// L'annonce de la dépense apparaît dès qu'un montant est saisi.
  void _rafraichirAnnonce() => setState(() {});

  double? get _montant => nombreDepuisTexte(_prix.text);

  Future<void> _valider() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref
          .read(coursesApiProvider)
          .acheter(
            widget.evenementId,
            widget.article.id,
            quantiteObtenue: nombreDepuisTexte(_quantite.text),
            prixPaye: _montant,
          );

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final montant = _montant;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      child: Form(
        key: _formulaire,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.article.nom, style: theme.textTheme.titleMedium),
            const SizedBox(height: PpSpacing.xs),
            Text(
              'Demandé : ${widget.article.quantiteLisible}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: PpSpacing.lg),
            if (_erreur != null) ...[
              PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.lg),
            ],
            PpField(
              key: const Key('achat-quantite'),
              label: 'Quantité obtenue',
              controller: _quantite,
              enabled: !_enCours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              aide:
                  'Moins que prévu ? Le reste apparaîtra comme restant à prendre.',
              validator: _nombrePositif,
            ),
            const SizedBox(height: PpSpacing.lg),
            PpField(
              key: const Key('achat-prix'),
              label: 'Prix payé',
              controller: _prix,
              enabled: !_enCours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              aide: 'Laisse vide si tu ne veux rien te faire rembourser.',
              validator: _nombrePositif,
            ),
            if (montant != null && montant > 0) ...[
              const SizedBox(height: PpSpacing.md),
              _AnnonceDepense(montant: montant),
            ],
            const SizedBox(height: PpSpacing.xl),
            PpPrimaryButton(
              label: 'C’est acheté',
              enCours: _enCours,
              onPressed: _valider,
            ),
          ],
        ),
      ),
    );
  }

  /// Refuse un nombre négatif ou illisible, accepte le champ vide.
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

/// Annonce la dépense qui va être créée (`EF-CRS-07`).
class _AnnonceDepense extends StatelessWidget {
  const _AnnonceDepense({required this.montant});

  final double montant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(PpSpacing.md),
      decoration: BoxDecoration(
        color: PpColors.vert.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(PpRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_rounded, size: 18),
          const SizedBox(width: PpSpacing.sm),
          Expanded(
            child: Text(
              'Une dépense à ton nom sera ajoutée, partagée entre les présents.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ouvre la feuille de déclaration d'achat.
Future<void> ouvrirFeuilleAchat(
  BuildContext context,
  String evenementId,
  ArticleCourse article,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (contexte) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.viewInsetsOf(contexte).bottom,
    ),
    child: AchatFeuille(evenementId: evenementId, article: article),
  ),
);
