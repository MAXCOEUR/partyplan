import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_recue.dart';

/// La notification actuellement annoncée à l'écran, s'il y en a une.
///
/// Une seule à la fois, sans file : une notification chasse la précédente. Empiler des
/// bandeaux au-dessus d'un écran qu'on est en train de lire reproduirait exactement le
/// bruit que la règle d'affichage cherche à éviter.
class BandeauNotification extends Notifier<NotificationRecue?> {
  @override
  NotificationRecue? build() => null;

  void montrer(NotificationRecue recue) => state = recue;

  void effacer() => state = null;
}

final bandeauNotificationProvider =
    NotifierProvider<BandeauNotification, NotificationRecue?>(
      BandeauNotification.new,
    );
