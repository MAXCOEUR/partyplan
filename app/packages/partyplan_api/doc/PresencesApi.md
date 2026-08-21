# partyplan_api.api.PresencesApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**leaveEvent**](PresencesApi.md#leaveevent) | **DELETE** /v1/events/{eventId}/members/me | Quitte l&#39;événement. Le propriétaire doit d&#39;abord transférer.
[**listMembers**](PresencesApi.md#listmembers) | **GET** /v1/events/{eventId}/members | Participants, avec statut et horaires.
[**removeMember**](PresencesApi.md#removemember) | **DELETE** /v1/events/{eventId}/members/{memberId} | Exclut un participant. Ses données financières subsistent.
[**setMyAttendance**](PresencesApi.md#setmyattendance) | **PATCH** /v1/events/{eventId}/members/me | Déclare sa présence. Chacun ne modifie que la sienne.
[**transferOwnership**](PresencesApi.md#transferownership) | **POST** /v1/events/{eventId}/members/{memberId}/transfer-ownership | Transfère la propriété. L&#39;ancien propriétaire devient administrateur. En-tête Idempotency-Key obligatoire.


# **leaveEvent**
> leaveEvent(eventId)

Quitte l'événement. Le propriétaire doit d'abord transférer.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getPresencesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.leaveEvent(eventId);
} on DioException catch (e) {
    print('Exception when calling PresencesApi->leaveEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listMembers**
> BuiltList<MemberView> listMembers(eventId)

Participants, avec statut et horaires.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getPresencesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.listMembers(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PresencesApi->listMembers: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**BuiltList&lt;MemberView&gt;**](MemberView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **removeMember**
> removeMember(eventId, memberId)

Exclut un participant. Ses données financières subsistent.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getPresencesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String memberId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.removeMember(eventId, memberId);
} on DioException catch (e) {
    print('Exception when calling PresencesApi->removeMember: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **memberId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setMyAttendance**
> MemberView setMyAttendance(eventId, attendanceBody)

Déclare sa présence. Chacun ne modifie que la sienne.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getPresencesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final AttendanceBody attendanceBody = ; // AttendanceBody | 

try {
    final response = api.setMyAttendance(eventId, attendanceBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling PresencesApi->setMyAttendance: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **attendanceBody** | [**AttendanceBody**](AttendanceBody.md)|  | 

### Return type

[**MemberView**](MemberView.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **transferOwnership**
> transferOwnership(eventId, memberId)

Transfère la propriété. L'ancien propriétaire devient administrateur. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getPresencesApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final String memberId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    api.transferOwnership(eventId, memberId);
} on DioException catch (e) {
    print('Exception when calling PresencesApi->transferOwnership: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **memberId** | **String**|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

