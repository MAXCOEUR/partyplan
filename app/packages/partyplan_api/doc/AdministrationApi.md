# partyplan_api.api.AdministrationApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**adminAuditLog**](AdministrationApi.md#adminauditlog) | **GET** /v1/admin/audit | Journal d&#39;audit, du plus récent au plus ancien.
[**adminChangeRole**](AdministrationApi.md#adminchangerole) | **PATCH** /v1/admin/users/{userId}/role | Attribue ou retire un rôle plateforme.
[**adminDeleteUser**](AdministrationApi.md#admindeleteuser) | **DELETE** /v1/admin/users/{userId} | Supprime un compte. Les contributions financières sont anonymisées.
[**adminExportUser**](AdministrationApi.md#adminexportuser) | **GET** /v1/admin/users/{userId}/export | Export des données d&#39;un compte qui ne peut plus se connecter.
[**adminGetUser**](AdministrationApi.md#admingetuser) | **GET** /v1/admin/users/{userId} | Fiche technique d&#39;un compte. Ne contient aucune donnée d&#39;événement.
[**adminListUsers**](AdministrationApi.md#adminlistusers) | **GET** /v1/admin/users | Liste les comptes, avec recherche et pagination.
[**adminMetrics**](AdministrationApi.md#adminmetrics) | **GET** /v1/admin/metrics | Indicateurs d&#39;instance.
[**adminRemoveAvatar**](AdministrationApi.md#adminremoveavatar) | **DELETE** /v1/admin/users/{userId}/avatar | Supprime une photo de profil signalée comme inappropriée.
[**adminRevokeSessions**](AdministrationApi.md#adminrevokesessions) | **DELETE** /v1/admin/users/{userId}/sessions | Révoque toutes les sessions d&#39;un compte.
[**adminSuspendUser**](AdministrationApi.md#adminsuspenduser) | **POST** /v1/admin/users/{userId}/suspend | Suspend un compte, avec motif obligatoire. Les sessions sont révoquées.
[**adminTriggerPasswordReset**](AdministrationApi.md#admintriggerpasswordreset) | **POST** /v1/admin/users/{userId}/password-reset | Envoie un lien de réinitialisation à l&#39;adresse du compte.
[**adminUnsuspendUser**](AdministrationApi.md#adminunsuspenduser) | **POST** /v1/admin/users/{userId}/unsuspend | Réactive un compte suspendu.
[**adminVerifyEmail**](AdministrationApi.md#adminverifyemail) | **POST** /v1/admin/users/{userId}/verify-email | Force la vérification d&#39;une adresse, en cas de courriel non délivré.


# **adminAuditLog**
> BuiltList<AuditEntryView> adminAuditLog(page, pageSize)

Journal d'audit, du plus récent au plus ancien.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final AdminListUsersPageParameter page = 56; // AdminListUsersPageParameter | 
final AdminListUsersPageParameter pageSize = 56; // AdminListUsersPageParameter | 

try {
    final response = api.adminAuditLog(page, pageSize);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminAuditLog: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **page** | **AdminListUsersPageParameter**|  | [optional] 
 **pageSize** | **AdminListUsersPageParameter**|  | [optional] 

### Return type

[**BuiltList&lt;AuditEntryView&gt;**](AuditEntryView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminChangeRole**
> adminChangeRole(userId, changeRoleRequest)

Attribue ou retire un rôle plateforme.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final ChangeRoleRequest changeRoleRequest = ; // ChangeRoleRequest | 

try {
    api.adminChangeRole(userId, changeRoleRequest);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminChangeRole: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 
 **changeRoleRequest** | [**ChangeRoleRequest**](ChangeRoleRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminDeleteUser**
> adminDeleteUser(userId)

Supprime un compte. Les contributions financières sont anonymisées.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminDeleteUser(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminDeleteUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminExportUser**
> adminExportUser(userId)

Export des données d'un compte qui ne peut plus se connecter.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminExportUser(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminExportUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminGetUser**
> UserRecord adminGetUser(userId)

Fiche technique d'un compte. Ne contient aucune donnée d'événement.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.adminGetUser(userId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminGetUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

[**UserRecord**](UserRecord.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminListUsers**
> UserPage adminListUsers(search, page, pageSize, includeDeleted)

Liste les comptes, avec recherche et pagination.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String search = search_example; // String | 
final AdminListUsersPageParameter page = 56; // AdminListUsersPageParameter | 
final AdminListUsersPageParameter pageSize = 56; // AdminListUsersPageParameter | 
final bool includeDeleted = true; // bool | 

try {
    final response = api.adminListUsers(search, page, pageSize, includeDeleted);
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminListUsers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **search** | **String**|  | [optional] 
 **page** | **AdminListUsersPageParameter**|  | [optional] 
 **pageSize** | **AdminListUsersPageParameter**|  | [optional] 
 **includeDeleted** | **bool**|  | [optional] 

### Return type

[**UserPage**](UserPage.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminMetrics**
> InstanceMetrics adminMetrics()

Indicateurs d'instance.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();

try {
    final response = api.adminMetrics();
    print(response);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminMetrics: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**InstanceMetrics**](InstanceMetrics.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminRemoveAvatar**
> adminRemoveAvatar(userId)

Supprime une photo de profil signalée comme inappropriée.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminRemoveAvatar(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminRemoveAvatar: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminRevokeSessions**
> adminRevokeSessions(userId)

Révoque toutes les sessions d'un compte.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminRevokeSessions(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminRevokeSessions: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminSuspendUser**
> adminSuspendUser(userId, suspendRequest)

Suspend un compte, avec motif obligatoire. Les sessions sont révoquées.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final SuspendRequest suspendRequest = ; // SuspendRequest | 

try {
    api.adminSuspendUser(userId, suspendRequest);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminSuspendUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 
 **suspendRequest** | [**SuspendRequest**](SuspendRequest.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminTriggerPasswordReset**
> adminTriggerPasswordReset(userId)

Envoie un lien de réinitialisation à l'adresse du compte.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminTriggerPasswordReset(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminTriggerPasswordReset: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminUnsuspendUser**
> adminUnsuspendUser(userId)

Réactive un compte suspendu.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminUnsuspendUser(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminUnsuspendUser: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **adminVerifyEmail**
> adminVerifyEmail(userId)

Force la vérification d'une adresse, en cas de courriel non délivré.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getAdministrationApi();
final String userId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.adminVerifyEmail(userId);
} on DioException catch (e) {
    print('Exception when calling AdministrationApi->adminVerifyEmail: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **userId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

