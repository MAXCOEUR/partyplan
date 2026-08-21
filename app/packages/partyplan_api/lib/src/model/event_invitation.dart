//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';

part 'event_invitation.g.dart';

/// Coordonnées de partage d'un événement (EF-INV-01 à EF-INV-03).
///
/// Properties:
/// * [token] 
/// * [shortCode] 
/// * [joinUrl] 
/// * [joinEnabled] 
@BuiltValue()
abstract class EventInvitation implements Built<EventInvitation, EventInvitationBuilder> {
  @BuiltValueField(wireName: r'token')
  String get token;

  @BuiltValueField(wireName: r'shortCode')
  String get shortCode;

  @BuiltValueField(wireName: r'joinUrl')
  String get joinUrl;

  @BuiltValueField(wireName: r'joinEnabled')
  bool get joinEnabled;

  EventInvitation._();

  factory EventInvitation([void updates(EventInvitationBuilder b)]) = _$EventInvitation;

  @BuiltValueHook(initializeBuilder: true)
  static void _defaults(EventInvitationBuilder b) => b;

  @BuiltValueSerializer(custom: true)
  static Serializer<EventInvitation> get serializer => _$EventInvitationSerializer();
}

class _$EventInvitationSerializer implements PrimitiveSerializer<EventInvitation> {
  @override
  final Iterable<Type> types = const [EventInvitation, _$EventInvitation];

  @override
  final String wireName = r'EventInvitation';

  Iterable<Object?> _serializeProperties(
    Serializers serializers,
    EventInvitation object, {
    FullType specifiedType = FullType.unspecified,
  }) sync* {
    yield r'token';
    yield serializers.serialize(
      object.token,
      specifiedType: const FullType(String),
    );
    yield r'shortCode';
    yield serializers.serialize(
      object.shortCode,
      specifiedType: const FullType(String),
    );
    yield r'joinUrl';
    yield serializers.serialize(
      object.joinUrl,
      specifiedType: const FullType(String),
    );
    yield r'joinEnabled';
    yield serializers.serialize(
      object.joinEnabled,
      specifiedType: const FullType(bool),
    );
  }

  @override
  Object serialize(
    Serializers serializers,
    EventInvitation object, {
    FullType specifiedType = FullType.unspecified,
  }) {
    return _serializeProperties(serializers, object, specifiedType: specifiedType).toList();
  }

  void _deserializeProperties(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
    required List<Object?> serializedList,
    required EventInvitationBuilder result,
    required List<Object?> unhandled,
  }) {
    for (var i = 0; i < serializedList.length; i += 2) {
      final key = serializedList[i] as String;
      final value = serializedList[i + 1];
      switch (key) {
        case r'token':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.token = valueDes;
          break;
        case r'shortCode':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.shortCode = valueDes;
          break;
        case r'joinUrl':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(String),
          ) as String;
          result.joinUrl = valueDes;
          break;
        case r'joinEnabled':
          final valueDes = serializers.deserialize(
            value,
            specifiedType: const FullType(bool),
          ) as bool;
          result.joinEnabled = valueDes;
          break;
        default:
          unhandled.add(key);
          unhandled.add(value);
          break;
      }
    }
  }

  @override
  EventInvitation deserialize(
    Serializers serializers,
    Object serialized, {
    FullType specifiedType = FullType.unspecified,
  }) {
    final result = EventInvitationBuilder();
    final serializedList = (serialized as Iterable<Object?>).toList();
    final unhandled = <Object?>[];
    _deserializeProperties(
      serializers,
      serialized,
      specifiedType: specifiedType,
      serializedList: serializedList,
      unhandled: unhandled,
      result: result,
    );
    return result.build();
  }
}


