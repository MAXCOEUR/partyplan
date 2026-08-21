# partyplan_api.api.MeApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**deleteMyAccount**](MeApi.md#deletemyaccount) | **DELETE** /v1/me | Supprime le compte. Les contributions financières sont anonymisées.
[**deleteMyAvatar**](MeApi.md#deletemyavatar) | **DELETE** /v1/me/avatar | Supprime la photo et revient à l&#39;avatar par défaut.
[**exportMyData**](MeApi.md#exportmydata) | **GET** /v1/me/export | Export complet des données du compte, sans intervention humaine.
[**getMe**](MeApi.md#getme) | **GET** /v1/me | Profil de l&#39;appelant.
[**listMySessions**](MeApi.md#listmysessions) | **GET** /v1/me/sessions | Sessions actives de l&#39;appelant.
[**requestEmailChange**](MeApi.md#requestemailchange) | **POST** /v1/me/email | Demande un changement d&#39;adresse. Effectif après confirmation.
[**revokeMyOtherSessions**](MeApi.md#revokemyothersessions) | **DELETE** /v1/me/sessions | Révoque toutes les sessions sauf la session courante.
[**revokeMySession**](MeApi.md#revokemysession) | **DELETE** /v1/me/sessions/{sessionId} | Révoque une session, y compris la session courante.
[**setMyAvatar**](MeApi.md#setmyavatar) | **PUT** /v1/me/avatar | Téléverse une photo de profil (multipart, champ « file »).
[**updateMe**](MeApi.md#updateme) | **PATCH** /v1/me | Modifie le nom affiché, la langue et le fuseau horaire.


# **deleteMyAccount**
> deleteMyAccount(deleteAccountRequest)

Supprime le compte. Les contributions financières sont anonymisées.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();
final DeleteAccountRequest deleteAccountRequest = ; // DeleteAccountRequest | 

try {
    api.deleteMyAccount(deleteAccountRequest);
} on DioException catch (e) {
    print('Exception when calling MeApi->deleteMyAccount: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **deleteAccountRequest** | [**DeleteAccountRequest**](DeleteAccountRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteMyAvatar**
> deleteMyAvatar()

Supprime la photo et revient à l'avatar par défaut.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    api.deleteMyAvatar();
} on DioException catch (e) {
    print('Exception when calling MeApi->deleteMyAvatar: $e\n');
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

# **exportMyData**
> exportMyData()

Export complet des données du compte, sans intervention humaine.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    api.exportMyData();
} on DioException catch (e) {
    print('Exception when calling MeApi->exportMyData: $e\n');
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

# **getMe**
> MyProfile getMe()

Profil de l'appelant.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    final response = api.getMe();
    print(response);
} on DioException catch (e) {
    print('Exception when calling MeApi->getMe: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**MyProfile**](MyProfile.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listMySessions**
> BuiltList<MySession> listMySessions()

Sessions actives de l'appelant.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    final response = api.listMySessions();
    print(response);
} on DioException catch (e) {
    print('Exception when calling MeApi->listMySessions: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BuiltList&lt;MySession&gt;**](MySession.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **requestEmailChange**
> requestEmailChange(changeEmailRequest)

Demande un changement d'adresse. Effectif après confirmation.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();
final ChangeEmailRequest changeEmailRequest = ; // ChangeEmailRequest | 

try {
    api.requestEmailChange(changeEmailRequest);
} on DioException catch (e) {
    print('Exception when calling MeApi->requestEmailChange: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **changeEmailRequest** | [**ChangeEmailRequest**](ChangeEmailRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **revokeMyOtherSessions**
> revokeMyOtherSessions()

Révoque toutes les sessions sauf la session courante.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    api.revokeMyOtherSessions();
} on DioException catch (e) {
    print('Exception when calling MeApi->revokeMyOtherSessions: $e\n');
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

# **revokeMySession**
> revokeMySession(sessionId)

Révoque une session, y compris la session courante.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();
final String sessionId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.revokeMySession(sessionId);
} on DioException catch (e) {
    print('Exception when calling MeApi->revokeMySession: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **sessionId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMyAvatar**
> setMyAvatar()

Téléverse une photo de profil (multipart, champ « file »).

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();

try {
    api.setMyAvatar();
} on DioException catch (e) {
    print('Exception when calling MeApi->setMyAvatar: $e\n');
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

# **updateMe**
> MyProfile updateMe(updateProfileRequest)

Modifie le nom affiché, la langue et le fuseau horaire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getMeApi();
final UpdateProfileRequest updateProfileRequest = ; // UpdateProfileRequest | 

try {
    final response = api.updateMe(updateProfileRequest);
    print(response);
} on DioException catch (e) {
    print('Exception when calling MeApi->updateMe: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **updateProfileRequest** | [**UpdateProfileRequest**](UpdateProfileRequest.md)|  | 

### Return type

[**MyProfile**](MyProfile.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

