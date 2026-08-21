# partyplan_api.api.EventsApi

## Load the API package
```dart
import 'package:partyplan_api/api.dart';
```

All URIs are relative to *https://api.partyplan.maxencecoeur.fr*

Method | HTTP request | Description
------------- | ------------- | -------------
[**createEvent**](EventsApi.md#createevent) | **POST** /v1/events | Crée un événement. En-tête Idempotency-Key obligatoire.
[**deleteEvent**](EventsApi.md#deleteevent) | **DELETE** /v1/events/{eventId} | Supprime l&#39;événement. Confirmation renforcée exigée par « force ».
[**getEvent**](EventsApi.md#getevent) | **GET** /v1/events/{eventId} | Synthèse d&#39;un événement dont l&#39;appelant est membre.
[**getInvitation**](EventsApi.md#getinvitation) | **GET** /v1/events/{eventId}/invitation | Lien, code court et état d&#39;ouverture de l&#39;événement.
[**listEvents**](EventsApi.md#listevents) | **GET** /v1/events | Événements de l&#39;appelant, à venir puis passés.
[**rotateInvitation**](EventsApi.md#rotateinvitation) | **POST** /v1/events/{eventId}/invitation/rotate | Régénère lien et code court. Les précédents deviennent invalides.
[**setJoinEnabled**](EventsApi.md#setjoinenabled) | **PATCH** /v1/events/{eventId}/join-enabled | Ouvre ou ferme les nouvelles arrivées.
[**updateEvent**](EventsApi.md#updateevent) | **PATCH** /v1/events/{eventId} | Modifie l&#39;événement. Un changement de date ou de lieu est journalisé.


# **createEvent**
> EventSummary createEvent(createEventBody)

Crée un événement. En-tête Idempotency-Key obligatoire.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final CreateEventBody createEventBody = ; // CreateEventBody | 

try {
    final response = api.createEvent(createEventBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->createEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **createEventBody** | [**CreateEventBody**](CreateEventBody.md)|  | 

### Return type

[**EventSummary**](EventSummary.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **deleteEvent**
> deleteEvent(eventId, force)

Supprime l'événement. Confirmation renforcée exigée par « force ».

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final bool force = true; // bool | 

try {
    api.deleteEvent(eventId, force);
} on DioException catch (e) {
    print('Exception when calling EventsApi->deleteEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **force** | **bool**|  | [optional] 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getEvent**
> EventSummary getEvent(eventId)

Synthèse d'un événement dont l'appelant est membre.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getEvent(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->getEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**EventSummary**](EventSummary.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json, application/problem+json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **getInvitation**
> EventInvitation getInvitation(eventId)

Lien, code court et état d'ouverture de l'événement.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.getInvitation(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->getInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**EventInvitation**](EventInvitation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **listEvents**
> BuiltList<EventListItem> listEvents()

Événements de l'appelant, à venir puis passés.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();

try {
    final response = api.listEvents();
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->listEvents: $e\n');
}
```

### Parameters
This endpoint does not need any parameter.

### Return type

[**BuiltList&lt;EventListItem&gt;**](EventListItem.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **rotateInvitation**
> EventInvitation rotateInvitation(eventId)

Régénère lien et code court. Les précédents deviennent invalides.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 

try {
    final response = api.rotateInvitation(eventId);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->rotateInvitation: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 

### Return type

[**EventInvitation**](EventInvitation.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **setJoinEnabled**
> setJoinEnabled(eventId, joinEnabledBody)

Ouvre ou ferme les nouvelles arrivées.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final JoinEnabledBody joinEnabledBody = ; // JoinEnabledBody | 

try {
    api.setJoinEnabled(eventId, joinEnabledBody);
} on DioException catch (e) {
    print('Exception when calling EventsApi->setJoinEnabled: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **joinEnabledBody** | [**JoinEnabledBody**](JoinEnabledBody.md)|  | 

### Return type

void (empty response body)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: Not defined

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

# **updateEvent**
> EventSummary updateEvent(eventId, updateEventBody)

Modifie l'événement. Un changement de date ou de lieu est journalisé.

### Example
```dart
import 'package:partyplan_api/api.dart';

final api = PartyplanApi().getEventsApi();
final String eventId = 38400000-8cf0-11bd-b23e-10b96e4ef00d; // String | 
final UpdateEventBody updateEventBody = ; // UpdateEventBody | 

try {
    final response = api.updateEvent(eventId, updateEventBody);
    print(response);
} on DioException catch (e) {
    print('Exception when calling EventsApi->updateEvent: $e\n');
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **eventId** | **String**|  | 
 **updateEventBody** | [**UpdateEventBody**](UpdateEventBody.md)|  | 

### Return type

[**EventSummary**](EventSummary.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

