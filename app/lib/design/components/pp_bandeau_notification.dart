import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/bandeau_notification.dart';
import '../../core/notifications/notification_recue.dart';
import '../tokens.dart';

/// Annonce une notification reçue pendant que l'application est ouverte.
///
/// Posé une seule fois, au-dessus de l'écran courant : Android ne montre rien de
/// lui-même quand l'application est au premier plan — FCM remet le message à
/// l'application au lieu de le déposer dans le volet — et sans ce bandeau, une dépense
/// ajoutée pendant qu'on lit la discussion ne produirait rien, nulle part.
///
/// Il ne sait rien des catégories : ce qui mérite d'être annoncé se décide dans
/// `RegleAffichagePremierPlan`, qui s'éprouve sans monter d'application.
class PpBandeauNotification extends ConsumerStatefulWidget {
  const PpBandeauNotification({
    required this.child,
    required this.aller,
    super.key,
  });

  final Widget child;

  /// Ouvre la destination portée par la notification tapée.
  final void Function(String destination) aller;

  /// Au-delà, le bandeau s'efface seul. Assez pour lire deux lignes sans lever les yeux
  /// de ce qu'on faisait, trop court pour gêner.
  static const duree = Duration(seconds: 5);

  @override
  ConsumerState<PpBandeauNotification> createState() =>
      _PpBandeauNotificationState();
}

class _PpBandeauNotificationState extends ConsumerState<PpBandeauNotification> {
  Timer? _minuterie;

  @override
  void dispose() {
    _minuterie?.cancel();
    super.dispose();
  }

  /// Repart de zéro à chaque notification : la seconde ne doit pas hériter du temps
  /// déjà écoulé pour la première.
  void _armer(NotificationRecue? recue) {
    _minuterie?.cancel();

    if (recue == null) {
      return;
    }

    _minuterie = Timer(PpBandeauNotification.duree, _effacer);
  }

  void _effacer() {
    _minuterie?.cancel();

    // Le provider peut avoir été démonté entre-temps — un changement de session vide le
    // conteneur, et la minuterie survivrait à l'écran.
    if (mounted) {
      ref.read(bandeauNotificationProvider.notifier).effacer();
    }
  }

  void _ouvrir(NotificationRecue recue) {
    final destination = recue.destination;
    _effacer();

    // Une notification sans destination exploitable s'efface sans rien ouvrir : elle a
    // été vue, c'était son rôle.
    if (destination != null) {
      widget.aller(destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(bandeauNotificationProvider, (_, recue) => _armer(recue));

    final recue = ref.watch(bandeauNotificationProvider);

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: PpDuration.normale,
              // Le bandeau vient d'où viendrait la notification du système : du haut.
              transitionBuilder: (enfant, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, -1),
                  end: Offset.zero,
                ).animate(animation),
                child: FadeTransition(opacity: animation, child: enfant),
              ),
              child: recue == null
                  ? const SizedBox.shrink()
                  : KeyedSubtree(
                      key: const Key('bandeau-notification'),
                      child: _Carte(
                        recue: recue,
                        onTap: () => _ouvrir(recue),
                        onEcarte: _effacer,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Carte extends StatelessWidget {
  const _Carte({
    required this.recue,
    required this.onTap,
    required this.onEcarte,
  });

  final NotificationRecue recue;
  final VoidCallback onTap;
  final VoidCallback onEcarte;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(PpSpacing.sm),
      child: Dismissible(
        // Clé liée à la notification et non au bandeau : réutilisée telle quelle, une
        // seconde notification serait tenue pour déjà écartée et ne paraîtrait pas.
        key: ObjectKey(recue),
        direction: DismissDirection.up,
        onDismissed: (_) => onEcarte(),
        child: Semantics(
          liveRegion: true,
          button: true,
          child: Material(
            color: theme.colorScheme.surfaceContainerHigh,
            elevation: 3,
            borderRadius: BorderRadius.circular(PpRadius.card),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: PpSpacing.lg,
                  vertical: PpSpacing.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _icone(recue.categorie),
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: PpSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (recue.titre.isNotEmpty)
                            Text(
                              recue.titre,
                              style: theme.textTheme.titleSmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (recue.corps.isNotEmpty)
                            Text(
                              recue.corps,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              // Deux lignes : un message plus long se lit dans la
                              // discussion, pas dans un bandeau qui passe.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Repère visuel par famille de notification.
  ///
  /// Une catégorie inconnue reçoit l'icône générique plutôt que rien : elle doit rester
  /// affichable le jour où le serveur en ajoute une.
  static IconData _icone(String? categorie) => switch (categorie) {
    'discussion.message' || 'discussion.mention' => Icons.forum_rounded,
    'expense.new' || 'balance.due' => Icons.receipt_long_rounded,
    'shopping.unclaimed' => Icons.shopping_basket_rounded,
    'poll.new' => Icons.how_to_vote_rounded,
    'invitation.answer' || 'invitation.pending' => Icons.mail_rounded,
    'event.changed' || 'event.starting_soon' => Icons.event_rounded,
    _ => Icons.notifications_rounded,
  };
}
