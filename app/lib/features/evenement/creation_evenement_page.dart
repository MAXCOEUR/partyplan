import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../core/providers.dart';
import '../../design/components/pp_choix_date_heure.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';

/// Assistant de création d'événement (EF-EVT-01, EF-EVT-02).
///
/// Trois étapes, mais deux corrections sans lesquelles un assistant serait plus pénible
/// qu'un formulaire :
///
/// - **navigation libre** — retour sans perte de saisie, et appui direct sur un segment
///   de la barre de progression ;
/// - **« Créer » actif dès l'étape 2** — nom et date suffisent à l'API, et tout reste
///   modifiable ensuite (EF-EVT-03). Imposer l'étape 3 ferait de la description un champ
///   obligatoire de fait.
class CreationEvenementPage extends ConsumerStatefulWidget {
  const CreationEvenementPage({super.key});

  @override
  ConsumerState<CreationEvenementPage> createState() =>
      _CreationEvenementPageState();
}

class _CreationEvenementPageState extends ConsumerState<CreationEvenementPage> {
  static const _etapes = 3;
  static final _dateFr = DateFormat('dd/MM/yyyy', 'fr_FR');

  final _nom = TextEditingController();
  final _lieu = TextEditingController();
  final _description = TextEditingController();

  /// Fixée à l'ouverture de l'assistant, pas à l'appui sur « Créer ».
  ///
  /// Un double appui, ou un appui suivi d'une perte de réseau puis d'un rejeu, ne doit
  /// jamais produire deux événements. `POST /v1/events` exige déjà cette clé.
  late final String _cleIdempotence = _genererCle();

  int _etape = 0;
  DateTime _debut = _prochaineSoiree();
  DateTime? _fin;
  bool _enCours = false;
  String? _erreurNom;
  String? _erreurServeur;

  @override
  void dispose() {
    _nom.dispose();
    _lieu.dispose();
    _description.dispose();
    super.dispose();
  }

  bool get _nomValide => _nom.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.creationTitre),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: PpSpacing.lg),
              child: Text(l10n.creationEtapeSur(_etape + 1, _etapes)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _BarreProgression(
            etape: _etape,
            total: _etapes,
            accessible: (index) => index == 0 || _nomValide,
            onAller: (index) => setState(() => _etape = index),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(PpSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_etape) {
                    0 => _etapeNom(l10n),
                    1 => _etapeQuand(l10n),
                    _ => _etapeDescription(l10n),
                  },
                ),
              ),
              if (_erreurServeur != null) PpFormError(_erreurServeur!),
              const SizedBox(height: PpSpacing.md),
              if (_etape == 0)
                PpPrimaryButton(
                  label: l10n.creationSuite,
                  onPressed: _suivant,
                  icone: Icons.arrow_forward_rounded,
                )
              else ...[
                PpPrimaryButton(
                  label: l10n.creationCreer,
                  onPressed: _enCours ? null : _creer,
                  enCours: _enCours,
                ),
                if (_etape < _etapes - 1)
                  TextButton(
                    onPressed: _suivant,
                    child: Text(l10n.creationSuite),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _etapeNom(PpL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PpSpacing.xl),
      Text(l10n.creationQuestionNom, style: _question(context)),
      const SizedBox(height: PpSpacing.xl),
      PpField(
        label: l10n.creationChampNom,
        controller: _nom,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _suivant(),
        validator: (_) => _erreurNom,
      ),
      if (_erreurNom != null) PpFormError(_erreurNom!),
    ],
  );

  Widget _etapeQuand(PpL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PpSpacing.xl),
      Text(l10n.creationQuestionQuand, style: _question(context)),
      const SizedBox(height: PpSpacing.xl),
      PpChoixDateHeure(
        libelle: l10n.creationChampDate,
        valeur: _debut,
        format: _dateFr,
        onChange: (valeur) => setState(() {
          _debut = valeur;
          if (_fin != null && !_fin!.isAfter(valeur)) {
            _fin = null;
          }
        }),
      ),
      const SizedBox(height: PpSpacing.lg),
      PpChoixDateHeure(
        libelle: l10n.creationChampFinDate,
        valeur: _fin,
        format: _dateFr,
        minimum: _debut,
        onChange: (valeur) => setState(() => _fin = valeur),
      ),
      const SizedBox(height: PpSpacing.xs),
      // Sans cette phrase, la règle EF-EVT-02 est invisible et l'utilisateur croit
      // avoir oublié un champ obligatoire.
      Text(
        l10n.creationFinImplicite,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: PpSpacing.lg),
      PpField(label: l10n.creationChampLieu, controller: _lieu),
    ],
  );

  Widget _etapeDescription(PpL10n l10n) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: PpSpacing.xl),
      Text(l10n.creationQuestionDescription, style: _question(context)),
      const SizedBox(height: PpSpacing.xl),
      PpField(
        label: l10n.creationChampDescription,
        controller: _description,
        lignes: 5,
      ),
    ],
  );

  TextStyle? _question(BuildContext context) =>
      Theme.of(context).textTheme.headlineSmall;

  void _suivant() {
    final l10n = PpL10n.of(context);

    if (_etape == 0 && !_nomValide) {
      setState(() => _erreurNom = l10n.creationNomRequis);
      return;
    }

    setState(() {
      _erreurNom = null;
      _etape = min(_etape + 1, _etapes - 1);
    });
  }

  Future<void> _creer() async {
    final l10n = PpL10n.of(context);

    if (!_nomValide) {
      setState(() {
        _etape = 0;
        _erreurNom = l10n.creationNomRequis;
      });
      return;
    }

    setState(() {
      _enCours = true;
      _erreurServeur = null;
    });

    try {
      final resume = await ref
          .read(evenementsApiProvider)
          .creer(
            nom: _nom.text.trim(),
            debut: _debut,
            fin: _fin,
            adresse: _lieu.text.trim(),
            description: _description.text.trim(),
            cleIdempotence: _cleIdempotence,
          );

      ref.invalidate(mesEvenementsProvider);

      if (mounted) {
        // Remplace seulement l'assistant : revenir mène à l'accueil qui l'a ouvert,
        // sans rouvrir le formulaire d'un événement déjà créé.
        context.replace(PpRoutes.versEvenement(resume.id));
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _enCours = false;
          _erreurServeur = l10n.creationEchec;
        });
      }
    }
  }

  /// Par défaut, la prochaine soirée : demain à 20 h. Un formulaire qui s'ouvre sur
  /// « maintenant » oblige à corriger la date dans presque tous les cas.
  static DateTime _prochaineSoiree() {
    final demain = DateTime.now().add(const Duration(days: 1));

    return DateTime(demain.year, demain.month, demain.day, 20);
  }

  static String _genererCle() {
    final alea = Random.secure();

    return List.generate(
      16,
      (_) => alea.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }
}

/// Barre de progression tactile.
///
/// Chaque segment est une cible d'au moins 44 points (NF-A11Y-02) et porte un libellé
/// sémantique (NF-A11Y-03). Un segment n'est atteignable que si les étapes qui le
/// précèdent sont valides.
class _BarreProgression extends StatelessWidget {
  const _BarreProgression({
    required this.etape,
    required this.total,
    required this.accessible,
    required this.onAller,
  });

  final int etape;
  final int total;
  final bool Function(int) accessible;
  final void Function(int) onAller;

  @override
  Widget build(BuildContext context) {
    final l10n = PpL10n.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PpSpacing.lg,
        0,
        PpSpacing.lg,
        PpSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < total; i++)
            Expanded(
              child: Semantics(
                button: true,
                label: l10n.creationEtapeSemantique(i + 1),
                child: InkWell(
                  key: ValueKey('etape-${i + 1}'),
                  onTap: accessible(i) ? () => onAller(i) : null,
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(
                          horizontal: PpSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: i <= etape
                              ? PpColors.violet
                              : Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(PpRadius.pill),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
