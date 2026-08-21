import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for MeApi
void main() {
  final instance = PartyplanApi().getMeApi();

  group(MeApi, () {
    // Supprime le compte. Les contributions financières sont anonymisées.
    //
    //Future deleteMyAccount(DeleteAccountRequest deleteAccountRequest) async
    test('test deleteMyAccount', () async {
      // TODO
    });

    // Supprime la photo et revient à l'avatar par défaut.
    //
    //Future deleteMyAvatar() async
    test('test deleteMyAvatar', () async {
      // TODO
    });

    // Export complet des données du compte, sans intervention humaine.
    //
    //Future exportMyData() async
    test('test exportMyData', () async {
      // TODO
    });

    // Profil de l'appelant.
    //
    //Future<MyProfile> getMe() async
    test('test getMe', () async {
      // TODO
    });

    // Sessions actives de l'appelant.
    //
    //Future<BuiltList<MySession>> listMySessions() async
    test('test listMySessions', () async {
      // TODO
    });

    // Demande un changement d'adresse. Effectif après confirmation.
    //
    //Future requestEmailChange(ChangeEmailRequest changeEmailRequest) async
    test('test requestEmailChange', () async {
      // TODO
    });

    // Révoque toutes les sessions sauf la session courante.
    //
    //Future revokeMyOtherSessions() async
    test('test revokeMyOtherSessions', () async {
      // TODO
    });

    // Révoque une session, y compris la session courante.
    //
    //Future revokeMySession(String sessionId) async
    test('test revokeMySession', () async {
      // TODO
    });

    // Téléverse une photo de profil (multipart, champ « file »).
    //
    //Future setMyAvatar() async
    test('test setMyAvatar', () async {
      // TODO
    });

    // Modifie le nom affiché, la langue et le fuseau horaire.
    //
    //Future<MyProfile> updateMe(UpdateProfileRequest updateProfileRequest) async
    test('test updateMe', () async {
      // TODO
    });

  });
}
