# partyplan_api.api.AuthApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**activateTotp**](AuthApi.md#activatetotp) | **POST** /v1/auth/totp/activate | Active la double authentification et remet les codes de secours.
[**changePassword**](AuthApi.md#changepassword) | **POST** /v1/auth/password/change | Change le mot de passe et révoque les autres sessions.
[**claimGuestParticipations**](AuthApi.md#claimguestparticipations) | **POST** /v1/auth/guest-claim | Rattache au compte les participations rejointes sans compte.
[**disableTotp**](AuthApi.md#disabletotp) | **DELETE** /v1/auth/totp | Désactive la double authentification. Exige le mot de passe.
[**forgotPassword**](AuthApi.md#forgotpassword) | **POST** /v1/auth/password/forgot | Envoie un code de réinitialisation. Réponse identique si l&#39;adresse est inconnue.
[**linkProvider**](AuthApi.md#linkprovider) | **POST** /v1/auth/providers/{provider}/link | Rattache une connexion tierce au compte courant.
[**listSignInMethods**](AuthApi.md#listsigninmethods) | **GET** /v1/auth/providers | Moyens de connexion du compte courant, et fournisseurs disponibles.
[**login**](AuthApi.md#login) | **POST** /v1/auth/login | Ouvre une session, ou renvoie un défi de second facteur.
[**logout**](AuthApi.md#logout) | **POST** /v1/auth/logout | Révoque la session courante.
[**refresh**](AuthApi.md#refresh) | **POST** /v1/auth/refresh | Renouvelle la session. Le jeton présenté est invalidé.
[**regenerateRecoveryCodes**](AuthApi.md#regeneraterecoverycodes) | **POST** /v1/auth/totp/recovery-codes | Régénère les codes de secours. Les précédents deviennent inutilisables.
[**register**](AuthApi.md#register) | **POST** /v1/auth/register | Crée un compte et ouvre une session.
[**resetPassword**](AuthApi.md#resetpassword) | **POST** /v1/auth/password/reset | Définit un nouveau mot de passe et révoque toutes les sessions.
[**setupTotp**](AuthApi.md#setuptotp) | **POST** /v1/auth/totp/setup | Génère un secret et l&#39;URI otpauth. N&#39;active rien.
[**signInWithGoogle**](AuthApi.md#signinwithgoogle) | **POST** /v1/auth/google | Connexion Google. Sans clé configurée, renvoie une erreur explicite.
[**unlinkProvider**](AuthApi.md#unlinkprovider) | **DELETE** /v1/auth/providers/{provider} | Détache une connexion tierce. Refusé si c&#39;est le dernier accès.
[**verifyEmail**](AuthApi.md#verifyemail) | **POST** /v1/auth/email/verify | Confirme une adresse à partir du code reçu.
[**verifySecondFactor**](AuthApi.md#verifysecondfactor) | **POST** /v1/auth/mfa/verify | Achève la connexion avec un code temporel ou un code de secours.


# **activateTotp**
> TotpActivation activateTotp(totpActivateRequest)

Active la double authentification et remet les codes de secours.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final TotpActivateRequest totpActivateRequest = ; // TotpActivateRequest | 

try {
    final response = api.activateTotp(totpActivateRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->activateTotp: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **totpActivateRequest** | [**TotpActivateRequest**](TotpActivateRequest.md)|  | 

### Return type

[**TotpActivation**](TotpActivation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **changePassword**
> changePassword(changePasswordRequest)

Change le mot de passe et révoque les autres sessions.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final ChangePasswordRequest changePasswordRequest = ; // ChangePasswordRequest | 

try {
    api.changePassword(changePasswordRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->changePassword: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **changePasswordRequest** | [**ChangePasswordRequest**](ChangePasswordRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **claimGuestParticipations**
> ClaimGuestResponse claimGuestParticipations(claimGuestRequest)

Rattache au compte les participations rejointes sans compte.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final ClaimGuestRequest claimGuestRequest = ; // ClaimGuestRequest | 

try {
    final response = api.claimGuestParticipations(claimGuestRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->claimGuestParticipations: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **claimGuestRequest** | [**ClaimGuestRequest**](ClaimGuestRequest.md)|  | 

### Return type

[**ClaimGuestResponse**](ClaimGuestResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **disableTotp**
> disableTotp(totpDisableRequest)

Désactive la double authentification. Exige le mot de passe.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final TotpDisableRequest totpDisableRequest = ; // TotpDisableRequest | 

try {
    api.disableTotp(totpDisableRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->disableTotp: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **totpDisableRequest** | [**TotpDisableRequest**](TotpDisableRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **forgotPassword**
> forgotPassword(forgotPasswordRequest)

Envoie un code de réinitialisation. Réponse identique si l'adresse est inconnue.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final ForgotPasswordRequest forgotPasswordRequest = ; // ForgotPasswordRequest | 

try {
    api.forgotPassword(forgotPasswordRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->forgotPassword: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **forgotPasswordRequest** | [**ForgotPasswordRequest**](ForgotPasswordRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **linkProvider**
> linkProvider(provider, externalSignInRequest)

Rattache une connexion tierce au compte courant.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final String provider = provider_example; // String | 
final ExternalSignInRequest externalSignInRequest = ; // ExternalSignInRequest | 

try {
    api.linkProvider(provider, externalSignInRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->linkProvider: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 
 **externalSignInRequest** | [**ExternalSignInRequest**](ExternalSignInRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listSignInMethods**
> SignInMethods listSignInMethods()

Moyens de connexion du compte courant, et fournisseurs disponibles.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();

try {
    final response = api.listSignInMethods();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->listSignInMethods: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**SignInMethods**](SignInMethods.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **login**
> LoginResponse login(loginRequest)

Ouvre une session, ou renvoie un défi de second facteur.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final LoginRequest loginRequest = ; // LoginRequest | 

try {
    final response = api.login(loginRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->login: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **loginRequest** | [**LoginRequest**](LoginRequest.md)|  | 

### Return type

[**LoginResponse**](LoginResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **logout**
> logout()

Révoque la session courante.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();

try {
    api.logout();
} on DioException catch (e) {
    print('Exception when calling AuthApi->logout: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **refresh**
> TokenResponse refresh(refreshRequest)

Renouvelle la session. Le jeton présenté est invalidé.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final RefreshRequest refreshRequest = ; // RefreshRequest | 

try {
    final response = api.refresh(refreshRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->refresh: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **refreshRequest** | [**RefreshRequest**](RefreshRequest.md)|  | 

### Return type

[**TokenResponse**](TokenResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **regenerateRecoveryCodes**
> TotpActivation regenerateRecoveryCodes()

Régénère les codes de secours. Les précédents deviennent inutilisables.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();

try {
    final response = api.regenerateRecoveryCodes();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->regenerateRecoveryCodes: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**TotpActivation**](TotpActivation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **register**
> TokenResponse register(registerRequest)

Crée un compte et ouvre une session.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final RegisterRequest registerRequest = ; // RegisterRequest | 

try {
    final response = api.register(registerRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->register: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **registerRequest** | [**RegisterRequest**](RegisterRequest.md)|  | 

### Return type

[**TokenResponse**](TokenResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **resetPassword**
> resetPassword(resetPasswordRequest)

Définit un nouveau mot de passe et révoque toutes les sessions.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final ResetPasswordRequest resetPasswordRequest = ; // ResetPasswordRequest | 

try {
    api.resetPassword(resetPasswordRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->resetPassword: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **resetPasswordRequest** | [**ResetPasswordRequest**](ResetPasswordRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setupTotp**
> TotpEnrollment setupTotp()

Génère un secret et l'URI otpauth. N'active rien.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();

try {
    final response = api.setupTotp();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->setupTotp: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**TotpEnrollment**](TotpEnrollment.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **signInWithGoogle**
> LoginResponse signInWithGoogle(externalSignInRequest)

Connexion Google. Sans clé configurée, renvoie une erreur explicite.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final ExternalSignInRequest externalSignInRequest = ; // ExternalSignInRequest | 

try {
    final response = api.signInWithGoogle(externalSignInRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->signInWithGoogle: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **externalSignInRequest** | [**ExternalSignInRequest**](ExternalSignInRequest.md)|  | 

### Return type

[**LoginResponse**](LoginResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **unlinkProvider**
> unlinkProvider(provider)

Détache une connexion tierce. Refusé si c'est le dernier accès.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final String provider = provider_example; // String | 

try {
    api.unlinkProvider(provider);
} on DioException catch (e) {
    print('Exception when calling AuthApi->unlinkProvider: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **provider** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **verifyEmail**
> verifyEmail(verifyEmailRequest)

Confirme une adresse à partir du code reçu.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final VerifyEmailRequest verifyEmailRequest = ; // VerifyEmailRequest | 

try {
    api.verifyEmail(verifyEmailRequest);
} on DioException catch (e) {
    print('Exception when calling AuthApi->verifyEmail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **verifyEmailRequest** | [**VerifyEmailRequest**](VerifyEmailRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **verifySecondFactor**
> TokenResponse verifySecondFactor(mfaVerifyRequest)

Achève la connexion avec un code temporel ou un code de secours.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAuthApi();
final MfaVerifyRequest mfaVerifyRequest = ; // MfaVerifyRequest | 

try {
    final response = api.verifySecondFactor(mfaVerifyRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AuthApi->verifySecondFactor: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **mfaVerifyRequest** | [**MfaVerifyRequest**](MfaVerifyRequest.md)|  | 

### Return type

[**TokenResponse**](TokenResponse.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

