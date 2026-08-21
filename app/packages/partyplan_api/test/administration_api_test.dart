import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for AdministrationApi
void main() {
  final instance = PartyplanApi().getAdministrationApi();

  group(AdministrationApi, () {
    // Journal d'audit, du plus récent au plus ancien.
    //
    //Future<BuiltList<AuditEntryView>> adminAuditLog({ AdminListUsersPageParameter page, AdminListUsersPageParameter pageSize }) async
    test('test adminAuditLog', () async {
      // TODO
    });

    // Attribue ou retire un rôle plateforme.
    //
    //Future adminChangeRole(String userId, ChangeRoleRequest changeRoleRequest) async
    test('test adminChangeRole', () async {
      // TODO
    });

    // Supprime un compte. Les contributions financières sont anonymisées.
    //
    //Future adminDeleteUser(String userId) async
    test('test adminDeleteUser', () async {
      // TODO
    });

    // Export des données d'un compte qui ne peut plus se connecter.
    //
    //Future adminExportUser(String userId) async
    test('test adminExportUser', () async {
      // TODO
    });

    // Fiche technique d'un compte. Ne contient aucune donnée d'événement.
    //
    //Future<UserRecord> adminGetUser(String userId) async
    test('test adminGetUser', () async {
      // TODO
    });

    // Liste les comptes, avec recherche et pagination.
    //
    //Future<UserPage> adminListUsers({ String search, AdminListUsersPageParameter page, AdminListUsersPageParameter pageSize, bool includeDeleted }) async
    test('test adminListUsers', () async {
      // TODO
    });

    // Indicateurs d'instance.
    //
    //Future<InstanceMetrics> adminMetrics() async
    test('test adminMetrics', () async {
      // TODO
    });

    // Supprime une photo de profil signalée comme inappropriée.
    //
    //Future adminRemoveAvatar(String userId) async
    test('test adminRemoveAvatar', () async {
      // TODO
    });

    // Révoque toutes les sessions d'un compte.
    //
    //Future adminRevokeSessions(String userId) async
    test('test adminRevokeSessions', () async {
      // TODO
    });

    // Suspend un compte, avec motif obligatoire. Les sessions sont révoquées.
    //
    //Future adminSuspendUser(String userId, SuspendRequest suspendRequest) async
    test('test adminSuspendUser', () async {
      // TODO
    });

    // Envoie un lien de réinitialisation à l'adresse du compte.
    //
    //Future adminTriggerPasswordReset(String userId) async
    test('test adminTriggerPasswordReset', () async {
      // TODO
    });

    // Réactive un compte suspendu.
    //
    //Future adminUnsuspendUser(String userId) async
    test('test adminUnsuspendUser', () async {
      // TODO
    });

    // Force la vérification d'une adresse, en cas de courriel non délivré.
    //
    //Future adminVerifyEmail(String userId) async
    test('test adminVerifyEmail', () async {
      // TODO
    });

  });
}
