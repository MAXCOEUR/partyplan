import 'package:test/test.dart';
import 'package:partyplan_api/partyplan_api.dart';


/// tests for AuthApi
void main() {
  final instance = PartyplanApi().getAuthApi();

  group(AuthApi, () {
    // Active la double authentification et remet les codes de secours.
    //
    //Future<TotpActivation> activateTotp(TotpActivateRequest totpActivateRequest) async
    test('test activateTotp', () async {
      // TODO
    });

    // Change le mot de passe et révoque les autres sessions.
    //
    //Future changePassword(ChangePasswordRequest changePasswordRequest) async
    test('test changePassword', () async {
      // TODO
    });

    // Rattache au compte les participations rejointes sans compte.
    //
    //Future<ClaimGuestResponse> claimGuestParticipations(ClaimGuestRequest claimGuestRequest) async
    test('test claimGuestParticipations', () async {
      // TODO
    });

    // Désactive la double authentification. Exige le mot de passe.
    //
    //Future disableTotp(TotpDisableRequest totpDisableRequest) async
    test('test disableTotp', () async {
      // TODO
    });

    // Envoie un code de réinitialisation. Réponse identique si l'adresse est inconnue.
    //
    //Future forgotPassword(ForgotPasswordRequest forgotPasswordRequest) async
    test('test forgotPassword', () async {
      // TODO
    });

    // Rattache une connexion tierce au compte courant.
    //
    //Future linkProvider(String provider, ExternalSignInRequest externalSignInRequest) async
    test('test linkProvider', () async {
      // TODO
    });

    // Moyens de connexion du compte courant, et fournisseurs disponibles.
    //
    //Future<SignInMethods> listSignInMethods() async
    test('test listSignInMethods', () async {
      // TODO
    });

    // Ouvre une session, ou renvoie un défi de second facteur.
    //
    //Future<LoginResponse> login(LoginRequest loginRequest) async
    test('test login', () async {
      // TODO
    });

    // Révoque la session courante.
    //
    //Future logout() async
    test('test logout', () async {
      // TODO
    });

    // Renouvelle la session. Le jeton présenté est invalidé.
    //
    //Future<TokenResponse> refresh(RefreshRequest refreshRequest) async
    test('test refresh', () async {
      // TODO
    });

    // Régénère les codes de secours. Les précédents deviennent inutilisables.
    //
    //Future<TotpActivation> regenerateRecoveryCodes() async
    test('test regenerateRecoveryCodes', () async {
      // TODO
    });

    // Crée un compte et ouvre une session.
    //
    //Future<TokenResponse> register(RegisterRequest registerRequest) async
    test('test register', () async {
      // TODO
    });

    // Définit un nouveau mot de passe et révoque toutes les sessions.
    //
    //Future resetPassword(ResetPasswordRequest resetPasswordRequest) async
    test('test resetPassword', () async {
      // TODO
    });

    // Génère un secret et l'URI otpauth. N'active rien.
    //
    //Future<TotpEnrollment> setupTotp() async
    test('test setupTotp', () async {
      // TODO
    });

    // Connexion Google. Sans clé configurée, renvoie une erreur explicite.
    //
    //Future<LoginResponse> signInWithGoogle(ExternalSignInRequest externalSignInRequest) async
    test('test signInWithGoogle', () async {
      // TODO
    });

    // Détache une connexion tierce. Refusé si c'est le dernier accès.
    //
    //Future unlinkProvider(String provider) async
    test('test unlinkProvider', () async {
      // TODO
    });

    // Confirme une adresse à partir du code reçu.
    //
    //Future verifyEmail(VerifyEmailRequest verifyEmailRequest) async
    test('test verifyEmail', () async {
      // TODO
    });

    // Achève la connexion avec un code temporel ou un code de secours.
    //
    //Future<TokenResponse> verifySecondFactor(MfaVerifyRequest mfaVerifyRequest) async
    test('test verifySecondFactor', () async {
      // TODO
    });

  });
}
