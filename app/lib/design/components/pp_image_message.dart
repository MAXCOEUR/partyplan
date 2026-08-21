import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../tokens.dart';
import 'pp_remonte_au_parent.dart';

/// Image d'une conversation, agrandissable d'un doigt.
///
/// Dans le fil, l'image est une vignette : elle situe le message sans le noyer. Mais
/// une vignette de 200 points ne montre ni les visages d'une photo de groupe ni le code
/// d'un digicode pris en photo — l'agrandissement n'est pas un supplément, c'est ce
/// pour quoi l'image a été envoyée.
class PpImageMessage extends StatelessWidget {
  const PpImageMessage({
    required this.url,
    required this.adresseAgrandie,
    this.hauteur = 200,
    this.etiquette,
    super.key,
  });

  final String url;

  /// Adresse de l'image agrandie. L'agrandissement passe par le routeur plutôt que par
  /// une fenêtre posée par-dessus : le « précédent » du navigateur ne connaît que les
  /// adresses, et refermerait sinon la discussion entière au lieu de l'image.
  final String adresseAgrandie;

  final double hauteur;

  /// Ce que le lecteur d'écran annonce avant « agrandir ».
  final String? etiquette;

  /// Largeur tenue tant que l'image n'est pas arrivée, ou qu'elle manque.
  static const _largeurReservee = 200.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      image: true,
      label: '${etiquette ?? 'Image'}, agrandir',
      child: GestureDetector(
        onTap: () => context.push(adresseAgrandie),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(PpRadius.md),
          // La place de l'image est réservée avant qu'elle arrive : sans cela la
          // vignette n'occupe rien, le fil se recompose sous le doigt à chaque image
          // reçue, et il n'y a rien à toucher tant que le réseau n'a pas répondu.
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: _largeurReservee,
              minHeight: hauteur,
              maxHeight: hauteur,
            ),
            child: Image.network(
              url,
              height: hauteur,
              fit: BoxFit.cover,
              loadingBuilder: (context, enfant, progression) =>
                  progression == null
                  ? enfant
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                    ),
              errorBuilder: (context, _, _) => Container(
                alignment: Alignment.center,
                color: theme.colorScheme.surfaceContainerHighest,
                // Écarté de la sémantique : sans cela le lecteur d'écran annonce le
                // libellé de la vignette suivi de « Image indisponible », les deux
                // fondus en une seule phrase incompréhensible.
                child: const ExcludeSemantics(
                  child: Text('Image indisponible'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Une image seule, en plein écran, zoomable.
class PpVisionneuseImage extends StatefulWidget {
  const PpVisionneuseImage({required this.url, this.versParent, super.key});

  final String url;

  /// Adresse à rejoindre quand il n'y a rien à dépiler — l'image ouverte depuis un
  /// lien collé, ou après un rechargement de la page.
  final String? versParent;

  @override
  State<PpVisionneuseImage> createState() => _PpVisionneuseImageState();
}

class _PpVisionneuseImageState extends State<PpVisionneuseImage> {
  final _cadrage = TransformationController();

  @override
  void dispose() {
    _cadrage.dispose();
    super.dispose();
  }

  /// Double-clic : rapproche sur le point touché, ou revient au plan large.
  ///
  /// Pincer à deux doigts marche aussi, mais demande deux mains sur un téléphone tenu
  /// d'une seule — et ne se fait pas du tout à la souris.
  void _basculerLeZoom(TapDownDetails geste) {
    final agrandi = _cadrage.value.getMaxScaleOnAxis() > 1.01;

    setState(() {
      _cadrage.value = agrandi
          ? Matrix4.identity()
          : (Matrix4.identity()
              ..translateByDouble(
                -geste.localPosition.dx * 1.5,
                -geste.localPosition.dy * 1.5,
                0,
                1,
              )
              ..scaleByDouble(2.5, 2.5, 2.5, 1));
    });
  }

  void _fermer() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final ecran = Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Toucher le fond referme : le geste d'écarter ce qu'on regardait.
              onTap: _fermer,
              onDoubleTapDown: _basculerLeZoom,
              onDoubleTap: () {},
              child: InteractiveViewer(
                transformationController: _cadrage,
                maxScale: 5,
                // L'image prend l'écran entier plutôt que sa taille de fichier : une
                // photo de 400 points de côté laissée telle quelle n'occuperait qu'un
                // coin, et le geste d'agrandir n'aurait rien donné. « Contain » garde
                // les proportions, sans rogner.
                child: SizedBox.expand(
                  key: const Key('image-plein-ecran'),
                  child: Image.network(
                    widget.url,
                    fit: BoxFit.contain,
                    errorBuilder: (context, _, _) => const Center(
                      child: Text(
                        'Image indisponible',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(PpSpacing.xs),
                child: IconButton(
                  tooltip: 'Fermer',
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  style: IconButton.styleFrom(backgroundColor: Colors.black38),
                  onPressed: _fermer,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // Échap referme, comme partout ailleurs sur un écran posé par-dessus un autre.
    final avecClavier = CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _fermer},
      child: Focus(autofocus: true, child: ecran),
    );

    return widget.versParent == null
        ? avecClavier
        : PpRemonteAuParent(versParent: widget.versParent!, child: avecClavier);
  }
}
