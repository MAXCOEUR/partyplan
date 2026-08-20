import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../core/media/type_mime_image.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../design/components/pp_avatar.dart';
import '../../design/components/pp_card.dart';
import '../../design/components/pp_form.dart';
import '../../design/components/pp_states.dart';
import '../../design/tokens.dart';
import '../../l10n/generated/pp_localisations.dart';
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
      setState(() => _erreur = PpL10n.of(context).erreurEnregistrement);
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
      setState(() => _erreur = PpL10n.of(context).erreurReseau);
    } finally {
      if (mounted) {
        setState(() => _enCours = false);
      }
    }
  }

  /// Choisit une image, la recadre, puis la téléverse (EF-USR-04, EF-USR-05).
  ///
  /// Le recadrage est proposé mais non imposé : le serveur recadre de toute façon au
  /// centre et redimensionne (RG-USR-01), donc un refus de recadrer donne un résultat
  /// correct. Le rendre obligatoire ajouterait une étape sans nécessité.
  Future<void> _choisirPhoto() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });

    try {
      final fichier = await FilePicker.pickFile(type: FileType.image);

      if (fichier == null) {
        return;
      }

      // Contrôle local avant envoi : inutile de faire monter cinq mégaoctets pour se
      // faire refuser (RG-USR-01).
      if (await fichier.length() > _tailleMaximale) {
        setState(() => _erreur = 'L’image ne doit pas dépasser 5 Mo.');
        return;
      }

      var octets = await fichier.readAsBytes();
      var nom = fichier.name;

      // Le recadrage n'est proposé que si le fichier est sur le disque : sur le web
      // `path` est nul et le recadreur natif n'aurait rien à ouvrir. Il reste facultatif,
      // car le serveur recadre de toute façon au centre.
      final chemin = fichier.path;

      if (chemin != null) {
        final recadree = await ImageCropper().cropImage(
          sourcePath: chemin,
          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: 'Recadre ta photo',
              lockAspectRatio: true,
              initAspectRatio: CropAspectRatioPreset.square,
              aspectRatioPresets: const [CropAspectRatioPreset.square],
            ),
            IOSUiSettings(
              title: 'Recadre ta photo',
              aspectRatioLockEnabled: true,
              aspectRatioPickerButtonHidden: true,
            ),
          ],
        );

        if (recadree != null) {
          octets = await recadree.readAsBytes();
          // Le recadreur réencode en JPEG : conserver le nom d'origine annoncerait un
          // PNG là où les octets sont un JPEG, et le serveur refuserait.
          nom = 'photo.jpg';
        }
      }

      final typeMime = typeMimeImage(nom);

      if (typeMime == null) {
        setState(() => _erreur = 'Formats acceptés : JPEG, PNG, WebP et HEIC.');
        return;
      }

      await ref
          .read(comptesApiProvider)
          .televerserPhoto(octets: octets, nomFichier: nom, typeMime: typeMime);

      ref.invalidate(profilProvider);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Photo enregistrée.')));
      }
    } on ApiException catch (erreur) {
      setState(() => _erreur = erreur.title);
    } on Exception {
      setState(() => _erreur = PpL10n.of(context).erreurEnregistrement);
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
        setState(() => _erreur = PpL10n.of(context).erreurEnregistrement);
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
          message: PpL10n.of(context).erreurReseau,
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
                    // Wrap et non Row : sur 320 points de large, deux boutons côte à
                    // côte débordent.
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: PpSpacing.sm,
                      runSpacing: PpSpacing.sm,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _enCours ? null : _choisirPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            size: 18,
                          ),
                          label: Text(
                            donnees.urlPhoto == null
                                ? 'Ajouter une photo'
                                : 'Changer la photo',
                          ),
                        ),
                        if (donnees.urlPhoto != null)
                          OutlinedButton.icon(
                            onPressed: _enCours ? null : _supprimerPhoto,
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            label: const Text('Supprimer'),
                          ),
                      ],
                    ),
                    if (donnees.urlPhoto == null) ...[
                      const SizedBox(height: PpSpacing.sm),
                      Text(
                        'À défaut de photo, l’avatar est généré depuis tes initiales, '
                        'sans appel à aucun service externe.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

/// Taille maximale acceptée par le serveur (RG-USR-01).
const _tailleMaximale = 5 * 1024 * 1024;
