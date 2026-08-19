import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/pp_strings.dart';
import '../../l10n/validateurs.dart';

/// Modification du profil : nom affiché, adresse, photo (EF-USR-02 à EF-USR-07).
class ProfilEditionPage extends ConsumerStatefulWidget {
  const ProfilEditionPage({super.key});

  @override
  ConsumerState<ProfilEditionPage> createState() => _ProfilEditionPageState();
}

class _ProfilEditionPageState extends ConsumerState<ProfilEditionPage> {
  final _nom = TextEditingController();
  final _nouvelleAdresse = TextEditingController();
  bool _initialise = false;
  bool _enCours = false;
  String? _erreur;

  @override
  void dispose() {
    _nom.dispose();
    _nouvelleAdresse.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final nom = _nom.text.trim();

    if (Validateurs.prenom(nom) != null) {
      setState(() => _erreur = 'Indique ton prénom.');
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref.read(comptesApiProvider).modifierProfil(nomAffiche: nom);
      ref.invalidate(profilProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profil enregistré.')));
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurEnregistrement);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _demanderChangementAdresse() async {
    final adresse = _nouvelleAdresse.text.trim();

    if (Validateurs.adresse(adresse) != null) {
      setState(() => _erreur = Validateurs.adresse(adresse));
      return;
    }

    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      await ref.read(comptesApiProvider).demanderChangementAdresse(adresse);
      _nouvelleAdresse.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Un code vient de partir vers la nouvelle adresse. '
              'Ton adresse actuelle reste active jusqu’à confirmation.',
            ),
          ),
        );
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpStrings.erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  Future<void> _supprimerPhoto() async {
    setState(() => _enCours = true);

    try {
      await ref.read(comptesApiProvider).supprimerPhoto();
      ref.invalidate(profilProvider);
    } on Exception {
      if (mounted) {
        setState(() => _erreur = PpStrings.erreurEnregistrement);
      }
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profil = ref.watch(profilProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: profil.when(
        loading: () => const PpLoadingState(),
        error: (_, _) => PpErrorState(
          message: PpStrings.erreurReseau,
          onRetry: () => ref.invalidate(profilProvider),
        ),
        data: (donnees) {
          if (!_initialise) {
            _nom.text = donnees.nomAffiche;
            _initialise = true;
          }

          return ListView(
            padding: const EdgeInsets.all(PpSpacing.lg),
            children: [
              PpCard(
                child: Column(
                  children: [
                    PpAvatar(
                      nom: donnees.nomAffiche,
                      urlPhoto: donnees.urlPhoto,
                      taille: 96,
                    ),
                    const SizedBox(height: PpSpacing.md),
                    if (donnees.urlPhoto == null)
                      Text(
                        'Ta photo sera bientôt téléversable depuis l’application. '
                        'En attendant, l’avatar est généré depuis tes initiales.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: _enCours ? null : _supprimerPhoto,
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Supprimer la photo'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: PpSpacing.lg),
              if (_erreur != null) ...[
                PpFormError(_erreur!),
                const SizedBox(height: PpSpacing.lg),
              ],
              PpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PpEyebrow('Identité'),
                    const SizedBox(height: PpSpacing.md),
                    PpField(
                      label: 'Prénom',
                      controller: _nom,
                      enabled: !_enCours,
                      aide:
                          'Les événements en cours conservent le nom utilisé à '
                          'chaque action : personne ne peut se dissocier d’une dette.',
                    ),
                    const SizedBox(height: PpSpacing.lg),
                    PpPrimaryButton(
                      label: 'Enregistrer',
                      enCours: _enCours,
                      onPressed: _enregistrer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PpSpacing.lg),
              PpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const PpEyebrow('Adresse e-mail'),
                    const SizedBox(height: PpSpacing.md),
                    Text(
                      donnees.email ?? 'Aucune adresse',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: PpSpacing.lg),
                    PpField(
                      label: 'Nouvelle adresse',
                      controller: _nouvelleAdresse,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !_enCours,
                      aide:
                          'Un code partira vers la nouvelle adresse. Le changement ne '
                          'prend effet qu’après confirmation, et déconnecte tes sessions.',
                    ),
                    const SizedBox(height: PpSpacing.lg),
                    OutlinedButton(
                      onPressed: _enCours ? null : _demanderChangementAdresse,
                      child: const Text('Demander le changement'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PpSpacing.xl),
            ],
          );
        },
      ),
    );
  }
}

/// Conversion d'un fichier choisi en octets, isolée pour rester testable.
Uint8List octetsDe(List<int> source) => Uint8List.fromList(source);
