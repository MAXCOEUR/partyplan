import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/depense.dart';
import '../../core/models/membre.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_form.dart';
import '../../design/tokens.dart';
import '../courses/nombre_saisi.dart';

/// Saisie d'une dépense qui ne vient pas des courses (`EF-DEP-01`, `EF-DEP-02`).
///
/// Location de salle, taxi, matériel, cadeau commun : tout ce qu'on paie pour une
/// soirée sans passer par la liste de courses. Les achats de courses arrivent dans la
/// même liste, engendrés par la déclaration d'achat.
///
/// Trois modes d'assiette, présentés dans l'ordre de leur fréquence réelle. Le premier
/// est présélectionné : demander à chaque saisie qui participe alourdirait le geste le
/// plus courant.
class DepenseFeuille extends ConsumerStatefulWidget {
  const DepenseFeuille({required this.evenementId, this.depense, super.key});

  final String evenementId;

  /// Dépense à corriger. Nulle pour une saisie neuve.
  ///
  /// Une somme se saisit vite et se trompe souvent : sans correction, il faudrait
  /// supprimer puis ressaisir, en perdant l'assiette au passage.
  final Depense? depense;

  @override
  ConsumerState<DepenseFeuille> createState() => _DepenseFeuilleState();
}

class _DepenseFeuilleState extends ConsumerState<DepenseFeuille> {
  final _formulaire = GlobalKey<FormState>();
  final _libelle = TextEditingController();
  final _montant = TextEditingController();

  ModeAssiette _mode = ModeAssiette.tousLesPresents;

  /// Payeur choisi. Nul tant que la liste des membres n'est pas chargée : c'est alors
  /// l'appelant qui est présélectionné, le cas courant.
  String? _payeur;

  /// Poids par membre, en mode sélection ou parts inégales. Absent du dictionnaire
  /// signifie « ne participe pas ».
  final Map<String, int> _parts = {};

  bool _enCours = false;
  String? _erreur;

  bool get _correction => widget.depense != null;

  @override
  void initState() {
    super.initState();

    final depense = widget.depense;

    if (depense != null) {
      _libelle.text = depense.libelle;
      _montant.text = montantVersTexte(depense.montant);
      // L'assiette d'origine n'est pas rejouable depuis la liste : la correction repart
      // du partage entre présents, et le détail se réajuste si besoin.
      _payeur = depense.payeurMembreId;
    }
  }

  @override
  void dispose() {
    _libelle.dispose();
    _montant.dispose();
    super.dispose();
  }

  /// Membres à proposer : ceux qui sont comptés présents.
  ///
  /// Un absent n'est pas proposé par défaut — faire payer une soirée à quelqu'un qui
  /// n'y était pas est la faute la plus fâcheuse de ce genre d'application.
  List<Membre> _participants(List<Membre> membres) =>
      membres.where((m) => m.statut.compteCommePresent).toList();

  void _changerMode(ModeAssiette mode, List<Membre> membres) {
    setState(() {
      _mode = mode;

      if (mode == ModeAssiette.tousLesPresents) {
        _parts.clear();
        return;
      }

      // Tout le monde participe au départ : on retire, on n'ajoute pas. Partir d'une
      // liste vide obligerait à cocher huit personnes pour le cas le plus proche du
      // partage complet.
      _parts
        ..clear()
        ..addEntries(_participants(membres).map((m) => MapEntry(m.id, 1)));
    });
  }

  /// Ligne de membre de l'appelant, parmi ceux proposés.
  static Membre? _moi(List<Membre> membres) =>
      membres.where((m) => m.cestMoi).firstOrNull;

  Future<void> _enregistrer() async {
    if (!_formulaire.currentState!.validate()) {
      return;
    }

    final montant = nombreDepuisTexte(_montant.text);

    // RG-DEP-01 : montant strictement positif. Une dépense à zéro euro polluerait les
    // soldes sans rien représenter.
    if (montant == null || montant <= 0) {
      setState(() => _erreur = 'Indique un montant supérieur à zéro.');
      return;
    }

    if (_mode != ModeAssiette.tousLesPresents && _parts.isEmpty) {
      setState(() => _erreur = 'Choisis au moins une personne à partager.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    // Le payeur est transmis explicitement, même quand c'est l'appelant : laisser le
    // serveur le déduire d'un champ absent rendrait la requête ambiguë à la relecture.
    final membres = ref.read(membresProvider(widget.evenementId)).value ?? [];
    final payeur = _payeur ?? _moi(_participants(membres))?.id;

    final parts = _mode == ModeAssiette.tousLesPresents
        ? null
        : [
            for (final entree in _parts.entries)
              PartDemandee(entree.key, entree.value),
          ];

    try {
      final api = ref.read(depensesApiProvider);
      final depense = widget.depense;

      if (depense == null) {
        await api.creer(
          widget.evenementId,
          libelle: _libelle.text.trim(),
          montant: montant,
          mode: _mode,
          payeurMembreId: payeur,
          parts: parts,
        );
      } else {
        await api.modifier(
          widget.evenementId,
          depense.id,
          libelle: _libelle.text.trim(),
          montant: montant,
          mode: _mode,
          payeurMembreId: payeur,
          parts: parts,
        );
      }

      ref.invalidate(depensesProvider(widget.evenementId));
      // Les soldes découlent des dépenses : les laisser en cache afficherait des
      // chiffres que l'on sait faux.
      ref.invalidate(reglementsProvider(widget.evenementId));

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
    final membres = ref.watch(membresProvider(widget.evenementId)).value ?? [];
    final participants = _participants(membres);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(PpSpacing.lg),
      child: Form(
        key: _formulaire,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _correction ? 'Corriger la dépense' : 'Nouvelle dépense',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: PpSpacing.lg),
            if (_erreur != null) ...[
              PpFormError(_erreur!),
              const SizedBox(height: PpSpacing.lg),
            ],
            PpField(
              key: const Key('depense-libelle'),
              label: 'Dépense',
              hint: 'Location de la salle, taxi, matériel…',
              controller: _libelle,
              enabled: !_enCours,
              validator: (valeur) => valeur == null || valeur.trim().isEmpty
                  ? 'Indique ce qui a été payé.'
                  : null,
            ),
            const SizedBox(height: PpSpacing.lg),
            PpField(
              key: const Key('depense-montant'),
              label: 'Montant payé',
              controller: _montant,
              enabled: !_enCours,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (valeur) {
                final nombre = nombreDepuisTexte(valeur);
                if (nombre == null) {
                  return 'Indique un montant.';
                }
                return nombre <= 0 ? 'Le montant doit être positif.' : null;
              },
            ),
            const SizedBox(height: PpSpacing.lg),
            _ChoixPayeur(
              membres: participants,
              // À la saisie, l'appelant est présélectionné : c'est presque toujours lui
              // qui a payé, et le choisir à chaque fois serait un geste de trop.
              valeur: _payeur ?? _moi(participants)?.id,
              onChange: _enCours ? null : (id) => setState(() => _payeur = id),
            ),
            const SizedBox(height: PpSpacing.lg),
            _ChoixMode(
              valeur: _mode,
              onChange: _enCours ? null : (mode) => _changerMode(mode, membres),
            ),
            if (_mode != ModeAssiette.tousLesPresents) ...[
              const SizedBox(height: PpSpacing.lg),
              _ChoixParticipants(
                membres: participants,
                parts: _parts,
                avecPoids: _mode == ModeAssiette.partsPersonnalisees,
                onBascule: (id) => setState(() {
                  if (_parts.containsKey(id)) {
                    _parts.remove(id);
                  } else {
                    _parts[id] = 1;
                  }
                }),
                onPoids: (id, delta) => setState(() {
                  final actuel = _parts[id] ?? 0;
                  final nouveau = actuel + delta;
                  if (nouveau <= 0) {
                    _parts.remove(id);
                  } else {
                    _parts[id] = nouveau;
                  }
                }),
              ),
            ],
            const SizedBox(height: PpSpacing.xl),
            PpPrimaryButton(
              label: _correction ? 'Enregistrer' : 'Ajouter la dépense',
              enCours: _enCours,
              onPressed: _enregistrer,
            ),
            if (_correction) ...[
              const SizedBox(height: PpSpacing.sm),
              Text(
                'La version précédente est conservée : un montant qui change sans '
                'trace rendrait un désaccord insoluble.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Qui a payé. Par défaut l'appelant.
///
/// Chaque personne y figure sous son identifiant de membre, y compris l'appelant.
/// « Moi » était auparavant porté par la valeur nulle : corriger sa propre dépense
/// plaçait alors dans le sélecteur un identifiant qui ne correspondait à aucune entrée,
/// et Flutter refusait de construire la liste.
class _ChoixPayeur extends StatelessWidget {
  const _ChoixPayeur({
    required this.membres,
    required this.valeur,
    required this.onChange,
  });

  final List<Membre> membres;

  /// Identifiant du payeur choisi. Nul tant que rien n'est chargé.
  final String? valeur;

  final void Function(String?)? onChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Une valeur absente de la liste ferait échouer la construction : mieux vaut
    // n'en présélectionner aucune que planter.
    final connue = membres.any((m) => m.id == valeur);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Qui a payé', style: theme.textTheme.bodyMedium),
        const SizedBox(height: PpSpacing.xs),
        DropdownButtonFormField<String?>(
          key: const Key('depense-payeur'),
          initialValue: connue ? valeur : null,
          onChanged: onChange,
          items: [
            for (final membre in membres)
              DropdownMenuItem(
                value: membre.id,
                child: Text(membre.cestMoi ? 'Moi' : membre.nomAffiche),
              ),
          ],
        ),
      ],
    );
  }
}

/// Mode d'assiette (`EF-DEP-02`), dans l'ordre de fréquence réelle.
class _ChoixMode extends StatelessWidget {
  const _ChoixMode({required this.valeur, required this.onChange});

  final ModeAssiette valeur;
  final void Function(ModeAssiette)? onChange;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Partagée entre', style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: PpSpacing.sm),
      Wrap(
        spacing: PpSpacing.sm,
        runSpacing: PpSpacing.sm,
        children: [
          for (final mode in ModeAssiette.values)
            ChoiceChip(
              label: Text(mode.libelle),
              selected: mode == valeur,
              onSelected: onChange == null ? null : (_) => onChange!(mode),
            ),
        ],
      ),
    ],
  );
}

/// Choix des participants, avec ou sans poids.
class _ChoixParticipants extends StatelessWidget {
  const _ChoixParticipants({
    required this.membres,
    required this.parts,
    required this.avecPoids,
    required this.onBascule,
    required this.onPoids,
  });

  final List<Membre> membres;
  final Map<String, int> parts;
  final bool avecPoids;
  final void Function(String) onBascule;
  final void Function(String, int) onPoids;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          avecPoids ? 'Combien de parts chacun' : 'Qui participe',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: PpSpacing.xs),
        for (final membre in membres)
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  key: Key('participant-${membre.id}'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: parts.containsKey(membre.id),
                  onChanged: (_) => onBascule(membre.id),
                  title: Text(membre.nomAffiche),
                ),
              ),
              if (avecPoids && parts.containsKey(membre.id)) ...[
                IconButton(
                  key: Key('part-moins-${membre.id}'),
                  onPressed: () => onPoids(membre.id, -1),
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Une part de moins',
                ),
                Text('${parts[membre.id]}', style: theme.textTheme.titleSmall),
                IconButton(
                  key: Key('part-plus-${membre.id}'),
                  onPressed: () => onPoids(membre.id, 1),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Une part de plus',
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Ouvre la feuille de saisie, ou de correction si [depense] est fournie.
Future<void> ouvrirFeuilleDepense(
  BuildContext context,
  String evenementId, {
  Depense? depense,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (contexte) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(contexte).bottom),
    child: DepenseFeuille(evenementId: evenementId, depense: depense),
  ),
);
