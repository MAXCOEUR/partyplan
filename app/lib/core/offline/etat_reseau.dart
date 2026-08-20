import 'package:flutter/foundation.dart';

enum ModeReseau { enLigne, horsLigne, rejeuEnCours }

/// État réseau observable par les écrans.
///
/// Les écrans ne connaissent que cet objet : ni le cache, ni la file. C'est ce qui
/// permet d'ajouter un module sans qu'aucun de ses écrans n'ait à savoir comment le
/// hors ligne fonctionne.
class EtatReseau extends ChangeNotifier {
  ModeReseau _mode = ModeReseau.enLigne;
  DateTime? _fraicheur;
  int _enAttente = 0;

  ModeReseau get mode => _mode;

  /// Date de la dernière donnée servie depuis le cache. `null` en ligne.
  DateTime? get fraicheur => _fraicheur;

  int get enAttente => _enAttente;

  void signalerEnLigne() {
    if (_mode != ModeReseau.enLigne || _fraicheur != null) {
      _mode = ModeReseau.enLigne;
      _fraicheur = null;
      notifyListeners();
    }
  }

  void signalerHorsLigne({DateTime? fraicheur}) {
    _mode = ModeReseau.horsLigne;
    _fraicheur = fraicheur;
    notifyListeners();
  }

  void signalerRejeu() {
    _mode = ModeReseau.rejeuEnCours;
    notifyListeners();
  }

  void majEnAttente(int valeur) {
    if (_enAttente != valeur) {
      _enAttente = valeur;
      notifyListeners();
    }
  }
}
